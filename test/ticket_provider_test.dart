import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/tickets/domain/ticket_gateway.dart';
import 'package:swappy_mobile/features/tickets/domain/ticket_models.dart';
import 'package:swappy_mobile/features/tickets/providers/ticket_provider.dart';

const importId = '11111111-1111-4111-8111-111111111111';
const candidateId = '22222222-2222-4222-8222-222222222222';

void main() {
  test(
    'recovers an unknown upload outcome with the exact command keys',
    () async {
      final gateway = _RetryingTicketGateway();
      final provider = TicketProvider(
        gateway: gateway,
        pollingDelay: (_) async {},
      );

      expect(
        await provider.uploadTicketImage(
          countryCode: 'IN',
          bytes: const [
            0x89,
            0x50,
            0x4e,
            0x47,
            0x0d,
            0x0a,
            0x1a,
            0x0a,
            0,
            0,
            0,
            0,
          ],
          filename: 'ticket.png',
        ),
        isFalse,
      );
      expect(provider.canRetryUnknownCommand, isTrue);

      expect(await provider.retryUnknownCommand(), isTrue);
      expect(gateway.createKeys.length, 2);
      expect(gateway.createKeys.toSet().length, 1);
      expect(gateway.uploadKeys.length, 2);
      expect(gateway.uploadKeys.toSet().length, 1);
      expect(
        provider.activeImport?.state,
        TicketImportState.awaitingConfirmation,
      );
      expect(provider.canRetryUnknownCommand, isFalse);
    },
  );

  test(
    'does not consume a confirmed reference after a session reset',
    () async {
      final gateway = _SessionResetTicketGateway();
      final provider = TicketProvider(gateway: gateway);

      final pending = provider.confirmImport(
        ticketImport: _ticketImport(TicketImportState.awaitingConfirmation, 3),
        contextRef: 'ticketmaster:event:abc',
        sectionLabel: 'A',
        rowLabel: '12',
        seatLabels: const ['14'],
      );
      await gateway.confirmStarted.future;

      provider.resetForSession();
      gateway.confirmResult.complete(
        ConfirmedTicketImport(
          ticketImport: _ticketImport(TicketImportState.confirmed, 4),
          protectedObjectRef:
              'evidence://ticket-import/abcdefghijklmnopqrstuvwxyz_1234567890',
        ),
      );

      expect(await pending, isFalse);
      expect(gateway.consumeCalls, 0);
      expect(provider.activeImport, isNull);
      expect(provider.tickets, isEmpty);
    },
  );
}

class _SessionResetTicketGateway extends _RetryingTicketGateway {
  final Completer<void> confirmStarted = Completer<void>();
  final Completer<ConfirmedTicketImport> confirmResult =
      Completer<ConfirmedTicketImport>();
  int consumeCalls = 0;

  @override
  Future<ConfirmedTicketImport> confirmImport(
    String ticketImportId, {
    required String contextRef,
    required String? sectionLabel,
    required String? rowLabel,
    required List<String> seatLabels,
    required String idempotencyKey,
  }) {
    confirmStarted.complete();
    return confirmResult.future;
  }

  @override
  Future<TicketEvidenceResult> consumeConfirmedImport(
    ConfirmedTicketImport confirmed, {
    required String idempotencyKey,
  }) {
    consumeCalls++;
    throw StateError('A stale reference must not be consumed.');
  }
}

class _RetryingTicketGateway implements TicketGateway {
  final List<String> createKeys = [];
  final List<String> uploadKeys = [];
  var uploadCalls = 0;

  @override
  Future<CreatedTicketImport> createImport(
    String countryCode, {
    required String idempotencyKey,
  }) async {
    createKeys.add(idempotencyKey);
    return CreatedTicketImport(
      ticketImport: _ticketImport(TicketImportState.awaitingUpload, 1),
      upload: TicketUploadAuthorization(
        method: 'PUT',
        url: '/v1/me/ticket-imports/$importId/content',
        fieldName: 'ticket',
        uploadToken: 'upload_token_abcdefghijklmnopqrstuvwxyz_1234567890',
        expiresAt: DateTime.utc(2026, 8, 13, 13),
        acceptedMimeTypes: const ['image/png'],
        maximumBytes: 10485760,
      ),
    );
  }

  @override
  Future<TicketImportProjection> uploadTicket({
    required TicketUploadAuthorization authorization,
    required List<int> bytes,
    required String filename,
    required String idempotencyKey,
  }) async {
    uploadCalls++;
    uploadKeys.add(idempotencyKey);
    if (uploadCalls == 1) {
      throw const ApiRequestException(
        'Connection lost.',
        outcomeUnknown: true,
        isTransportFailure: true,
      );
    }
    return _ticketImport(TicketImportState.processing, 2);
  }

  @override
  Future<TicketImportProjection> getImport(String ticketImportId) async =>
      _ticketImport(TicketImportState.awaitingConfirmation, 3);

  @override
  Future<TicketPage<TicketImportProjection>> listImports({
    TicketImportState? state,
  }) async => const TicketPage(items: [], total: 0);

  @override
  Future<TicketPage<TicketBundleProjection>> listTickets() async =>
      const TicketPage(items: [], total: 0);

  @override
  Future<TicketBundleProjection> getTicket(String ticketBundleId) =>
      throw UnimplementedError();

  @override
  Future<CreatedTicketImport> refreshUploadAuthorization(
    String ticketImportId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ConfirmedTicketImport> confirmImport(
    String ticketImportId, {
    required String contextRef,
    required String? sectionLabel,
    required String? rowLabel,
    required List<String> seatLabels,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<TicketEvidenceResult> consumeConfirmedImport(
    ConfirmedTicketImport confirmed, {
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

TicketImportProjection _ticketImport(TicketImportState state, int version) =>
    TicketImportProjection.fromJson({
      'id': importId,
      'state': state.wireValue,
      'version': version,
      'countryCode': 'IN',
      'extracted': {
        'eventName': 'City Finals',
        'startsAt': '2026-08-20T18:00:00Z',
        'venueName': 'Central Arena',
        'sectionLabel': 'A',
        'rowLabel': '12',
        'seatLabels': ['14'],
      },
      'confirmedContextRef': null,
      'failureCode': null,
      'eventCandidates': [
        {
          'id': candidateId,
          'contextRef': 'ticketmaster:event:abc',
          'title': 'City Finals',
          'startsAt': '2026-08-20T18:00:00Z',
          'timezone': 'Asia/Kolkata',
          'venueName': 'Central Arena',
          'venueCity': 'Hyderabad',
          'venueCountryCode': 'IN',
          'staticSeatMapUrl': null,
          'confidenceBasisPoints': 9500,
          'rank': 1,
          'sourceObservedAt': '2026-08-13T12:00:00Z',
        },
      ],
      'retentionUntil': '2026-09-13T12:00:00Z',
      'createdAt': '2026-08-13T12:00:00Z',
      'updatedAt': '2026-08-13T12:01:00Z',
    });
