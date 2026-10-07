import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../exchange/domain/exchange_models.dart';
import '../domain/ticket_gateway.dart';
import '../domain/ticket_models.dart';

typedef TicketPollingDelay = Future<void> Function(Duration duration);

class TicketProvider extends ChangeNotifier {
  TicketProvider({
    required TicketGateway gateway,
    TicketPollingDelay? pollingDelay,
  }) : _gateway = gateway,
       _pollingDelay = pollingDelay ?? Future<void>.delayed;

  final TicketGateway _gateway;
  final TicketPollingDelay _pollingDelay;

  List<TicketBundleProjection> _tickets = const [];
  List<TicketImportProjection> _imports = const [];
  TicketImportProjection? _activeImport;
  bool _loading = false;
  bool _commandRunning = false;
  bool _polling = false;
  String? _error;
  String? _correlationId;
  String? _lastCompletedImportId;
  _PendingTicketCommand? _pendingCommand;
  int _sessionGeneration = 0;
  int _loadGeneration = 0;
  int _pollGeneration = 0;

  List<TicketBundleProjection> get tickets => List.unmodifiable(_tickets);
  List<TicketImportProjection> get imports => List.unmodifiable(_imports);
  TicketImportProjection? get activeImport => _activeImport;
  bool get loading => _loading;
  bool get commandRunning => _commandRunning;
  bool get polling => _polling;
  String? get error => _error;
  String? get correlationId => _correlationId;
  bool get canRetryUnknownCommand => _pendingCommand != null;
  bool importCompleted(String ticketImportId) =>
      _lastCompletedImportId == ticketImportId;
  String? get pendingCommandLabel => _pendingCommand?.label;

  void resetForSession() {
    _sessionGeneration++;
    _loadGeneration++;
    _pollGeneration++;
    _tickets = const [];
    _imports = const [];
    _activeImport = null;
    _loading = false;
    _commandRunning = false;
    _polling = false;
    _error = null;
    _correlationId = null;
    _lastCompletedImportId = null;
    _pendingCommand = null;
    notifyListeners();
  }

  Future<bool> load() async {
    if (_loading) return false;
    final session = _sessionGeneration;
    final request = ++_loadGeneration;
    _loading = true;
    _error = null;
    _correlationId = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _gateway.listTickets(),
        _gateway.listImports(),
      ]);
      if (!_loadIsCurrent(session, request)) return false;
      final ticketPage = results[0] as TicketPage<TicketBundleProjection>;
      final importPage = results[1] as TicketPage<TicketImportProjection>;
      _tickets = ticketPage.items;
      _imports = importPage.items;
      final activeId = _activeImport?.id;
      if (activeId != null) {
        _activeImport = _imports.cast<TicketImportProjection?>().firstWhere(
          (item) => item?.id == activeId,
          orElse: () => _activeImport,
        );
      }
      return true;
    } on ApiRequestException catch (error) {
      if (_loadIsCurrent(session, request)) _recordError(error);
      return false;
    } on TicketContractException catch (error) {
      if (_loadIsCurrent(session, request)) _error = error.message;
      return false;
    } catch (_) {
      if (_loadIsCurrent(session, request)) {
        _error = 'Your tickets could not be loaded. Try again.';
      }
      return false;
    } finally {
      if (_loadIsCurrent(session, request)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> uploadTicketImage({
    required String countryCode,
    required List<int> bytes,
    required String filename,
  }) async {
    final immutableBytes = List<int>.unmodifiable(bytes);
    final createKey = newExchangeIdempotencyKey();
    final uploadKey = newExchangeIdempotencyKey();
    return _runPendingCommand(
      _PendingTicketCommand(
        label: 'same ticket upload',
        run: () async {
          final session = _sessionGeneration;
          final created = await _gateway.createImport(
            countryCode,
            idempotencyKey: createKey,
          );
          if (!_sessionIsCurrent(session)) return false;
          _upsertImport(created.ticketImport);
          _activeImport = created.ticketImport;
          notifyListeners();

          final uploaded = await _gateway.uploadTicket(
            authorization: created.upload,
            bytes: immutableBytes,
            filename: filename,
            idempotencyKey: uploadKey,
          );
          if (!_sessionIsCurrent(session)) return false;
          _upsertImport(uploaded);
          _activeImport = uploaded;
          notifyListeners();
          await _pollImport(uploaded.id, session: session);
          return true;
        },
      ),
    );
  }

  Future<bool> resumeAwaitingUpload({
    required TicketImportProjection ticketImport,
    required List<int> bytes,
    required String filename,
  }) {
    if (ticketImport.state != TicketImportState.awaitingUpload) {
      _error = 'This ticket import is no longer waiting for an upload.';
      notifyListeners();
      return Future.value(false);
    }
    final immutableBytes = List<int>.unmodifiable(bytes);
    final authorizationKey = newExchangeIdempotencyKey();
    final uploadKey = newExchangeIdempotencyKey();
    return _runPendingCommand(
      _PendingTicketCommand(
        label: 'same resumed ticket upload',
        run: () async {
          final session = _sessionGeneration;
          final refreshed = await _gateway.refreshUploadAuthorization(
            ticketImport.id,
            expectedVersion: ticketImport.version,
            idempotencyKey: authorizationKey,
          );
          if (!_sessionIsCurrent(session)) return false;
          _upsertImport(refreshed.ticketImport);
          _activeImport = refreshed.ticketImport;
          notifyListeners();
          final uploaded = await _gateway.uploadTicket(
            authorization: refreshed.upload,
            bytes: immutableBytes,
            filename: filename,
            idempotencyKey: uploadKey,
          );
          if (!_sessionIsCurrent(session)) return false;
          _upsertImport(uploaded);
          _activeImport = uploaded;
          notifyListeners();
          await _pollImport(uploaded.id, session: session);
          return true;
        },
      ),
    );
  }

  Future<bool> resumeImport(TicketImportProjection ticketImport) async {
    if (_commandRunning) return false;
    final session = _sessionGeneration;
    _activeImport = ticketImport;
    _error = null;
    _correlationId = null;
    notifyListeners();
    if (ticketImport.state.shouldPoll) {
      await _pollImport(ticketImport.id, session: session);
    } else {
      await refreshImport(ticketImport.id);
    }
    return _sessionIsCurrent(session);
  }

  Future<bool> refreshImport(String ticketImportId) async {
    final session = _sessionGeneration;
    try {
      final latest = await _gateway.getImport(ticketImportId);
      if (!_sessionIsCurrent(session)) return false;
      _upsertImport(latest);
      _activeImport = latest;
      _error = null;
      _correlationId = null;
      notifyListeners();
      return true;
    } on ApiRequestException catch (error) {
      if (_sessionIsCurrent(session)) {
        _recordError(error);
        notifyListeners();
      }
      return false;
    } on TicketContractException catch (error) {
      if (_sessionIsCurrent(session)) {
        _error = error.message;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> confirmImport({
    required TicketImportProjection ticketImport,
    required String contextRef,
    required String? sectionLabel,
    required String? rowLabel,
    required List<String> seatLabels,
  }) {
    final confirmKey = newExchangeIdempotencyKey();
    final evidenceKey = newExchangeIdempotencyKey();
    return _runPendingCommand(
      _PendingTicketCommand(
        label: 'ticket confirmation',
        run: () async {
          final session = _sessionGeneration;
          final confirmed = await _gateway.confirmImport(
            ticketImport.id,
            contextRef: contextRef,
            sectionLabel: sectionLabel,
            rowLabel: rowLabel,
            seatLabels: seatLabels,
            idempotencyKey: confirmKey,
          );
          if (!_sessionIsCurrent(session)) return false;
          _upsertImport(confirmed.ticketImport);
          _activeImport = confirmed.ticketImport;
          notifyListeners();
          return _consumeConfirmed(
            confirmed,
            idempotencyKey: evidenceKey,
            session: session,
          );
        },
      ),
    );
  }

  Future<bool> retryUnknownCommand() {
    final pending = _pendingCommand;
    if (pending == null) return Future.value(false);
    return _runPendingCommand(pending, retrying: true);
  }

  void closeActiveImport() {
    _pollGeneration++;
    _polling = false;
    _activeImport = null;
    _error = null;
    _correlationId = null;
    notifyListeners();
  }

  void clearError() {
    if (_commandRunning) return;
    _error = null;
    _correlationId = null;
    notifyListeners();
  }

  Future<bool> _consumeConfirmed(
    ConfirmedTicketImport confirmed, {
    required String idempotencyKey,
    required int session,
  }) async {
    if (!_sessionIsCurrent(session)) return false;
    final result = await _gateway.consumeConfirmedImport(
      confirmed,
      idempotencyKey: idempotencyKey,
    );
    if (!_sessionIsCurrent(session)) return false;
    _tickets = [
      result.ticket,
      ..._tickets.where((ticket) => ticket.id != result.ticket.id),
    ];
    _lastCompletedImportId = confirmed.ticketImport.id;
    _upsertImport(confirmed.ticketImport);
    _activeImport = confirmed.ticketImport;
    return true;
  }

  Future<bool> _runPendingCommand(
    _PendingTicketCommand command, {
    bool retrying = false,
  }) async {
    if (!_prepareCommand(retrying: retrying)) return false;
    final session = _sessionGeneration;
    try {
      final result = await command.run();
      if (!_sessionIsCurrent(session)) return false;
      _pendingCommand = null;
      _error = null;
      _correlationId = null;
      return result;
    } on ApiRequestException catch (error) {
      if (!_sessionIsCurrent(session)) return false;
      _recordError(error);
      _pendingCommand = error.outcomeUnknown ? command : null;
      if (error.statusCode == 409) {
        final importId = _activeImport?.id;
        if (importId != null) await refreshImport(importId);
      }
      return false;
    } on TicketContractException catch (error) {
      if (_sessionIsCurrent(session)) {
        _pendingCommand = null;
        _error = error.message;
      }
      return false;
    } catch (_) {
      if (_sessionIsCurrent(session)) {
        _pendingCommand = null;
        _error = 'The ticket confirmation could not be completed.';
      }
      return false;
    } finally {
      if (_sessionIsCurrent(session)) {
        _commandRunning = false;
        notifyListeners();
      }
    }
  }

  Future<void> _pollImport(
    String ticketImportId, {
    required int session,
  }) async {
    final pollingRequest = ++_pollGeneration;
    _polling = true;
    notifyListeners();
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
        if (!_pollIsCurrent(session, pollingRequest)) return;
        if (attempt > 0) {
          final seconds = 1 << (attempt - 1).clamp(0, 3);
          await _pollingDelay(Duration(seconds: seconds));
        }
        final latest = await _gateway.getImport(ticketImportId);
        if (!_pollIsCurrent(session, pollingRequest)) return;
        _upsertImport(latest);
        _activeImport = latest;
        notifyListeners();
        if (!latest.state.shouldPoll) return;
      }
      if (_pollIsCurrent(session, pollingRequest)) {
        _error =
            'Ticket processing is taking longer than expected. You can '
            'leave this screen and resume it from My uploads.';
      }
    } on ApiRequestException catch (error) {
      if (_pollIsCurrent(session, pollingRequest)) _recordError(error);
    } on TicketContractException catch (error) {
      if (_pollIsCurrent(session, pollingRequest)) _error = error.message;
    } finally {
      if (_pollIsCurrent(session, pollingRequest)) {
        _polling = false;
        notifyListeners();
      }
    }
  }

  bool _prepareCommand({bool retrying = false}) {
    if (_commandRunning) return false;
    if (!retrying && _pendingCommand != null) {
      _error = 'Resolve the previous ticket action before starting another.';
      notifyListeners();
      return false;
    }
    _commandRunning = true;
    _error = null;
    _correlationId = null;
    notifyListeners();
    return true;
  }

  void _recordError(ApiRequestException error) {
    _error = error.outcomeUnknown
        ? 'The server may have accepted this ticket action. Use the safe '
              'retry below; do not start it again.'
        : error.message;
    _correlationId = error.correlationId;
  }

  void _upsertImport(TicketImportProjection ticketImport) {
    _imports = [
      ticketImport,
      ..._imports.where((item) => item.id != ticketImport.id),
    ];
  }

  bool _sessionIsCurrent(int session) => session == _sessionGeneration;
  bool _loadIsCurrent(int session, int request) =>
      _sessionIsCurrent(session) && request == _loadGeneration;
  bool _pollIsCurrent(int session, int request) =>
      _sessionIsCurrent(session) && request == _pollGeneration;
}

class _PendingTicketCommand {
  const _PendingTicketCommand({required this.label, required this.run});

  final String label;
  final Future<bool> Function() run;
}
