import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../exchange/domain/exchange_models.dart';
import '../domain/ticket_gateway.dart';
import '../domain/ticket_models.dart';

typedef TicketRetryDelay = Future<void> Function(Duration duration);

class TicketApiClient implements TicketGateway {
  TicketApiClient({required ApiClient apiClient, TicketRetryDelay? retryDelay})
    : _apiClient = apiClient,
      _retryDelay = retryDelay ?? Future<void>.delayed;

  final ApiClient _apiClient;
  final TicketRetryDelay _retryDelay;

  @override
  Future<CreatedTicketImport> createImport(
    String countryCode, {
    required String idempotencyKey,
  }) async {
    final normalized = countryCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
      throw const TicketContractException(
        'Enter a valid two-letter ticket country.',
      );
    }
    final response = await _jsonMutation(
      method: 'POST',
      endpoint: '/v1/me/ticket-imports',
      body: {'countryCode': normalized},
      idempotencyKey: idempotencyKey,
      expectedStatus: 201,
    );
    return CreatedTicketImport.fromJson(_decodeObject(response));
  }

  @override
  Future<TicketPage<TicketImportProjection>> listImports({
    TicketImportState? state,
  }) async {
    final query = state == null ? '' : '?state=${state.wireValue}';
    final response = await _read('/v1/me/ticket-imports$query');
    return _page(
      response,
      TicketImportProjection.fromJson,
      'ticket import list',
    );
  }

  @override
  Future<TicketImportProjection> getImport(String ticketImportId) async {
    final response = await _read(
      '/v1/me/ticket-imports/${_resourceId(ticketImportId)}',
    );
    final json = _decodeObject(response);
    _expectTopLevel(json, const {'ticketImport'}, 'ticket import response');
    return TicketImportProjection.fromJson(_map(json['ticketImport']));
  }

  @override
  Future<TicketImportProjection> uploadTicket({
    required TicketUploadAuthorization authorization,
    required List<int> bytes,
    required String filename,
    required String idempotencyKey,
  }) async {
    validateExchangeIdempotencyKey(idempotencyKey);
    if (bytes.length < 12 || bytes.length > authorization.maximumBytes) {
      throw const TicketContractException(
        'Choose one JPEG or PNG ticket image no larger than 10 MiB.',
      );
    }
    final immutableBytes = List<int>.unmodifiable(bytes);
    final sessionScope = _apiClient.captureSessionScope();
    final response = await _retryMutation(
      () => _apiClient.putMultipartFile(
        uploadUrl: authorization.url,
        fieldName: authorization.fieldName,
        bytes: immutableBytes,
        filename: filename,
        extraHeaders: {
          'Idempotency-Key': idempotencyKey,
          'X-Upload-Token': authorization.tokenForImmediateUpload,
        },
        sessionScope: sessionScope,
      ),
      expectedStatus: 200,
    );
    final json = _decodeObject(response);
    _expectTopLevel(json, const {'ticketImport'}, 'ticket upload response');
    return TicketImportProjection.fromJson(_map(json['ticketImport']));
  }

  @override
  Future<CreatedTicketImport> refreshUploadAuthorization(
    String ticketImportId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    if (expectedVersion < 1) {
      throw const TicketContractException(
        'The ticket import version is invalid.',
      );
    }
    final response = await _jsonMutation(
      method: 'POST',
      endpoint:
          '/v1/me/ticket-imports/${_resourceId(ticketImportId)}/upload-authorization',
      body: {'expectedVersion': expectedVersion},
      idempotencyKey: idempotencyKey,
      expectedStatus: 200,
    );
    return CreatedTicketImport.fromJson(_decodeObject(response));
  }

  @override
  Future<ConfirmedTicketImport> confirmImport(
    String ticketImportId, {
    required String contextRef,
    required String? sectionLabel,
    required String? rowLabel,
    required List<String> seatLabels,
    required String idempotencyKey,
  }) async {
    final normalizedSeats = seatLabels
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (!RegExp(
          r'^ticketmaster:event:[A-Za-z0-9_-]{1,200}$',
        ).hasMatch(contextRef) ||
        normalizedSeats.isEmpty ||
        normalizedSeats.length > 3 ||
        normalizedSeats.toSet().length != normalizedSeats.length ||
        normalizedSeats.any((seat) => seat.length > 64)) {
      throw const TicketContractException(
        'Select a real event and enter one to three unique seats.',
      );
    }
    String? optionalLabel(String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return null;
      if (normalized.length > 64) {
        throw const TicketContractException(
          'Section and row must be 64 characters or fewer.',
        );
      }
      return normalized;
    }

    final response = await _jsonMutation(
      method: 'POST',
      endpoint: '/v1/me/ticket-imports/${_resourceId(ticketImportId)}/confirm',
      body: {
        'contextRef': contextRef,
        'sectionLabel': optionalLabel(sectionLabel),
        'rowLabel': optionalLabel(rowLabel),
        'seatLabels': normalizedSeats,
      },
      idempotencyKey: idempotencyKey,
      expectedStatus: 200,
    );
    return ConfirmedTicketImport.fromJson(_decodeObject(response));
  }

  @override
  Future<TicketEvidenceResult> consumeConfirmedImport(
    ConfirmedTicketImport confirmed, {
    required String idempotencyKey,
  }) async {
    final contextRef = confirmed.ticketImport.confirmedContextRef;
    if (contextRef == null) {
      throw const TicketContractException(
        'The confirmed ticket does not contain an event reference.',
      );
    }
    final request = EvidenceSubmissionRequest(
      verticalKey: 'ticketed_experience',
      providerKey: 'ticketmaster_discovery',
      contextRef: contextRef,
      evidenceType: 'ticket_photo',
      protectedObjectRef: confirmed.referenceForImmediateConsumption,
    );
    final response = await _jsonMutation(
      method: 'POST',
      endpoint: '/v1/me/entitlement-evidence',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
      expectedStatus: 201,
    );
    return TicketEvidenceResult.fromJson(_decodeObject(response));
  }

  @override
  Future<TicketPage<TicketBundleProjection>> listTickets() async {
    final response = await _read('/v1/me/ticket-bundles');
    return _page(
      response,
      TicketBundleProjection.fromJson,
      'ticket bundle list',
    );
  }

  @override
  Future<TicketBundleProjection> getTicket(String ticketBundleId) async {
    final response = await _read(
      '/v1/me/ticket-bundles/${_resourceId(ticketBundleId)}',
    );
    final json = _decodeObject(response);
    _expectTopLevel(json, const {'ticketBundle'}, 'ticket bundle response');
    return TicketBundleProjection.fromJson(_map(json['ticketBundle']));
  }

  Future<http.Response> _read(String endpoint) async {
    final response = await _apiClient.get(endpoint);
    if (response.statusCode != 200) {
      throw ApiRequestException.fromResponse(response);
    }
    return response;
  }

  Future<http.Response> _jsonMutation({
    required String method,
    required String endpoint,
    required Map<String, dynamic> body,
    required String idempotencyKey,
    required int expectedStatus,
  }) {
    validateExchangeIdempotencyKey(idempotencyKey);
    final immutableBody = Map<String, dynamic>.unmodifiable(body);
    final sessionScope = _apiClient.captureSessionScope();
    return _retryMutation(
      () => switch (method) {
        'POST' => _apiClient.post(
          endpoint,
          body: immutableBody,
          extraHeaders: {'Idempotency-Key': idempotencyKey},
          sessionScope: sessionScope,
        ),
        'PUT' => _apiClient.put(
          endpoint,
          body: immutableBody,
          extraHeaders: {'Idempotency-Key': idempotencyKey},
          sessionScope: sessionScope,
        ),
        _ => throw StateError('Unsupported ticket command method.'),
      },
      expectedStatus: expectedStatus,
    );
  }

  Future<http.Response> _retryMutation(
    Future<http.Response> Function() request, {
    required int expectedStatus,
  }) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await request();
        if (response.statusCode == 503 && attempt < 3) {
          await _retryDelay(Duration(milliseconds: 250 * (1 << (attempt - 1))));
          continue;
        }
        if (response.statusCode != expectedStatus) {
          throw ApiRequestException.fromResponse(
            response,
            outcomeUnknown: response.statusCode >= 500,
          );
        }
        return response;
      } on ApiRequestException catch (error) {
        if (!error.isTransportFailure || attempt == 3) {
          if (error.isTransportFailure && !error.outcomeUnknown) {
            throw ApiRequestException(
              error.message,
              statusCode: error.statusCode,
              code: error.code,
              correlationId: error.correlationId,
              outcomeUnknown: true,
              retryAt: error.retryAt,
              isTransportFailure: true,
            );
          }
          rethrow;
        }
        await _retryDelay(Duration(milliseconds: 250 * (1 << (attempt - 1))));
      }
    }
    throw StateError('Unreachable ticket command retry state.');
  }
}

TicketPage<T> _page<T>(
  http.Response response,
  T Function(Map<String, dynamic>) parse,
  String name,
) {
  final json = _decodeObject(response);
  _expectTopLevel(json, const {'items', 'total'}, name);
  final items = json['items'];
  final total = json['total'];
  if (items is! List || total is! int || total < 0) {
    throw TicketContractException('$name is invalid.');
  }
  return TicketPage(
    items: List.unmodifiable(items.map((item) => parse(_map(item)))),
    total: total,
  );
}

Map<String, dynamic> _decodeObject(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);
    return _map(decoded);
  } on FormatException {
    throw const TicketContractException(
      'The ticket service returned an unreadable response.',
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) {
    throw const TicketContractException(
      'The ticket service response must be an object.',
    );
  }
  return Map<String, dynamic>.from(value);
}

void _expectTopLevel(
  Map<String, dynamic> json,
  Set<String> expected,
  String name,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key)) ||
      expected.any((key) => !json.containsKey(key))) {
    throw TicketContractException('$name has unexpected fields.');
  }
}

String _resourceId(String value) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    throw const TicketContractException('The ticket identifier is invalid.');
  }
  return Uri.encodeComponent(value);
}
