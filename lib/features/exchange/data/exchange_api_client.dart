import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../domain/exchange_gateway.dart';
import '../domain/exchange_conversation_models.dart';
import '../domain/exchange_marketplace_models.dart';
import '../domain/exchange_models.dart';

typedef ExchangeRetryDelay = Future<void> Function(Duration duration);
typedef ExchangeClock = DateTime Function();

class ExchangeRetryPolicy {
  ExchangeRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 250),
  }) {
    if (maxAttempts < 1 || maxAttempts > 5) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be 1-5');
    }
    if (initialDelay.isNegative) {
      throw ArgumentError.value(initialDelay, 'initialDelay', 'is negative');
    }
  }

  final int maxAttempts;
  final Duration initialDelay;

  Duration delayBeforeAttempt(int attempt) => Duration(
    microseconds: initialDelay.inMicroseconds * (1 << (attempt - 2)),
  );
}

/// Typed HTTP implementation of all participant evidence, entitlement and
/// swap-intent endpoints. It stores no response data and emits no logs.
class ExchangeApiClient implements ExchangeGateway {
  ExchangeApiClient({
    required ApiClient apiClient,
    ExchangeRetryPolicy? retryPolicy,
    ExchangeRetryDelay? retryDelay,
    ExchangeClock? clock,
  }) : _apiClient = apiClient,
       _retryPolicy = retryPolicy ?? ExchangeRetryPolicy(),
       _retryDelay = retryDelay ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  final ApiClient _apiClient;
  final ExchangeRetryPolicy _retryPolicy;
  final ExchangeRetryDelay _retryDelay;
  final ExchangeClock _clock;

  @override
  Future<EventPresenceGrant> issueEventPresenceGrant(
    EventPresenceGrantRequest request,
  ) async {
    final response = await _singleAttemptPost(
      endpoint: '/v1/me/event-presence-grants',
      body: request.toJson(),
      expectedStatus: 201,
    );
    return EventPresenceGrant.fromJson(_decodeObject(response));
  }

  @override
  Future<EvidenceProjection> submitEvidence(
    EvidenceSubmissionRequest request, {
    required String idempotencyKey,
  }) async {
    final response = await _mutation(
      method: _MutationMethod.post,
      endpoint: '/v1/me/entitlement-evidence',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
      expectedStatus: 201,
    );
    return _single(
      response,
      key: 'evidence',
      parse: EvidenceProjection.fromJson,
    );
  }

  @override
  Future<ExchangePage<EvidenceProjection>> listEvidence({
    int limit = 50,
    int offset = 0,
    EvidenceState? state,
  }) async {
    final response = await _read(
      _listEndpoint(
        '/v1/me/entitlement-evidence',
        limit: limit,
        offset: offset,
        state: state?.wireValue,
      ),
    );
    return _page(response, EvidenceProjection.fromJson);
  }

  @override
  Future<EvidenceProjection> getEvidence(String evidenceId) async {
    final response = await _read(
      '/v1/me/entitlement-evidence/${_encodedResourceId(evidenceId, 'evidenceId')}',
    );
    return _single(
      response,
      key: 'evidence',
      parse: EvidenceProjection.fromJson,
    );
  }

  @override
  Future<ExchangePage<EntitlementProjection>> listEntitlements({
    int limit = 50,
    int offset = 0,
    EntitlementState? state,
  }) async {
    final response = await _read(
      _listEndpoint(
        '/v1/me/entitlements',
        limit: limit,
        offset: offset,
        state: state?.wireValue,
      ),
    );
    return _page(response, EntitlementProjection.fromJson);
  }

  @override
  Future<EntitlementProjection> getEntitlement(String entitlementId) async {
    final response = await _read(
      '/v1/me/entitlements/${_encodedResourceId(entitlementId, 'entitlementId')}',
    );
    return _single(
      response,
      key: 'entitlement',
      parse: EntitlementProjection.fromJson,
    );
  }

  @override
  Future<SwapIntentProjection> createSwapIntent(
    CreateSwapIntentRequest request, {
    required String idempotencyKey,
  }) async {
    validateSwapIntentExpiry(request.expiresAt, now: _clock());
    final response = await _mutation(
      method: _MutationMethod.post,
      endpoint: '/v1/me/swap-intents',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
      expectedStatus: 201,
    );
    return _single(
      response,
      key: 'intent',
      parse: SwapIntentProjection.fromJson,
    );
  }

  @override
  Future<ExchangePage<SwapIntentProjection>> listSwapIntents({
    int limit = 50,
    int offset = 0,
    SwapIntentState? state,
  }) async {
    final response = await _read(
      _listEndpoint(
        '/v1/me/swap-intents',
        limit: limit,
        offset: offset,
        state: state?.wireValue,
      ),
    );
    return _page(response, SwapIntentProjection.fromJson);
  }

  @override
  Future<SwapIntentDetail> getSwapIntent(String intentId) async {
    final response = await _read(
      '/v1/me/swap-intents/${_encodedResourceId(intentId, 'intentId')}',
    );
    final json = _decodeObject(response);
    _expectExactKeys(json, const {'intent', 'timeline'}, 'swap intent detail');
    final rawTimeline = json['timeline'];
    if (rawTimeline is! List) {
      throw const ExchangeContractException('timeline must be an array.');
    }
    return SwapIntentDetail(
      intent: SwapIntentProjection.fromJson(_object(json['intent'], 'intent')),
      timeline: List.unmodifiable(
        rawTimeline.map(
          (item) =>
              SwapIntentTimelineItem.fromJson(_object(item, 'timeline item')),
        ),
      ),
    );
  }

  @override
  Future<SwapIntentProjection> updateSwapIntent(
    String intentId,
    UpdateSwapIntentRequest request, {
    required String idempotencyKey,
  }) {
    validateSwapIntentExpiry(request.expiresAt, now: _clock());
    return _intentMutation(
      method: _MutationMethod.patch,
      endpoint:
          '/v1/me/swap-intents/${_encodedResourceId(intentId, 'intentId')}',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<SwapIntentProjection> publishSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => _intentCommand(
    intentId,
    'publish',
    expectedVersion: expectedVersion,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<SwapIntentProjection> pauseSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => _intentCommand(
    intentId,
    'pause',
    expectedVersion: expectedVersion,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<SwapIntentProjection> resumeSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => _intentCommand(
    intentId,
    'resume',
    expectedVersion: expectedVersion,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<SwapIntentProjection> withdrawSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => _intentCommand(
    intentId,
    'withdraw',
    expectedVersion: expectedVersion,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<ExchangePage<SwapPostProjection>> listPublishedSwapPosts({
    String? contextRef,
    int limit = 50,
    int offset = 0,
  }) async {
    validateExchangePage(limit: limit, offset: offset);
    final normalizedContext = contextRef?.trim();
    if (normalizedContext != null &&
        !RegExp(
          r'^ticketmaster:event:[A-Za-z0-9_-]{1,200}$',
        ).hasMatch(normalizedContext)) {
      throw const ExchangeContractException(
        'contextRef must be a supported Ticketmaster event reference.',
      );
    }
    final response = await _read(
      Uri(
        path: '/v1/swap-posts',
        queryParameters: {
          if (normalizedContext != null) 'contextRef': normalizedContext,
          'limit': '$limit',
          'offset': '$offset',
        },
      ).toString(),
    );
    return _page(response, SwapPostProjection.fromJson);
  }

  @override
  Future<SwapPostProjection> getPublishedSwapPost(String postId) async {
    final response = await _read(
      '/v1/swap-posts/${_encodedResourceId(postId, 'postId')}',
    );
    return _single(response, key: 'post', parse: SwapPostProjection.fromJson);
  }

  @override
  Future<SwapRequestProjection> createSwapRequest(
    String targetIntentId,
    CreateSwapRequestRequest request, {
    required String idempotencyKey,
  }) {
    validateSwapRequestExpiry(request.expiresAt, now: _clock());
    return _requestMutation(
      endpoint:
          '/v1/me/swap-intents/${_encodedResourceId(targetIntentId, 'targetIntentId')}/requests',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
      expectedStatus: 201,
    );
  }

  @override
  Future<ExchangePage<SwapRequestProjection>> listSwapRequests({
    int limit = 50,
    int offset = 0,
    SwapRequestState? state,
  }) async {
    final response = await _read(
      _listEndpoint(
        '/v1/me/swap-requests',
        limit: limit,
        offset: offset,
        state: state?.wireValue,
      ),
    );
    return _page(response, SwapRequestProjection.fromJson);
  }

  @override
  Future<SwapRequestDetail> getSwapRequest(String requestId) async {
    final response = await _read(
      '/v1/me/swap-requests/${_encodedResourceId(requestId, 'requestId')}',
    );
    final json = _decodeObject(response);
    _expectExactKeys(json, const {
      'swapRequest',
      'timeline',
    }, 'swap request detail');
    final rawTimeline = json['timeline'];
    if (rawTimeline is! List) {
      throw const ExchangeContractException('timeline must be an array.');
    }
    return SwapRequestDetail(
      swapRequest: SwapRequestProjection.fromJson(
        _object(json['swapRequest'], 'swapRequest'),
      ),
      timeline: List.unmodifiable(
        rawTimeline.map(
          (item) =>
              SwapIntentTimelineItem.fromJson(_object(item, 'timeline item')),
        ),
      ),
    );
  }

  @override
  Future<SwapRequestProjection> selectSwapRequest(
    String requestId,
    SelectSwapRequestRequest request, {
    required String idempotencyKey,
  }) => _requestMutation(
    endpoint:
        '/v1/me/swap-requests/${_encodedResourceId(requestId, 'requestId')}/select',
    body: request.toJson(),
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<SwapRequestProjection> rejectSwapRequest(
    String requestId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => _requestCommand(
    requestId,
    'reject',
    expectedVersion: expectedVersion,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<SwapRequestProjection> withdrawSwapRequest(
    String requestId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => _requestCommand(
    requestId,
    'withdraw',
    expectedVersion: expectedVersion,
    idempotencyKey: idempotencyKey,
  );

  Future<SwapRequestProjection> _requestCommand(
    String requestId,
    String command, {
    required int expectedVersion,
    required String idempotencyKey,
  }) {
    if (expectedVersion < 1) {
      throw const ExchangeContractException(
        'expectedVersion must be at least 1.',
      );
    }
    return _requestMutation(
      endpoint:
          '/v1/me/swap-requests/${_encodedResourceId(requestId, 'requestId')}/$command',
      body: {'expectedVersion': expectedVersion},
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SwapRequestProjection> _requestMutation({
    required String endpoint,
    required Map<String, dynamic> body,
    required String idempotencyKey,
    int expectedStatus = 200,
  }) async {
    final response = await _mutation(
      method: _MutationMethod.post,
      endpoint: endpoint,
      body: body,
      idempotencyKey: idempotencyKey,
      expectedStatus: expectedStatus,
    );
    return _single(
      response,
      key: 'swapRequest',
      parse: SwapRequestProjection.fromJson,
    );
  }

  Future<SwapIntentProjection> _intentCommand(
    String intentId,
    String command, {
    required int expectedVersion,
    required String idempotencyKey,
  }) {
    if (expectedVersion < 1) {
      throw const ExchangeContractException(
        'expectedVersion must be at least 1.',
      );
    }
    return _intentMutation(
      method: _MutationMethod.post,
      endpoint:
          '/v1/me/swap-intents/${_encodedResourceId(intentId, 'intentId')}/$command',
      body: {'expectedVersion': expectedVersion},
      idempotencyKey: idempotencyKey,
    );
  }

  Future<SwapIntentProjection> _intentMutation({
    required _MutationMethod method,
    required String endpoint,
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final response = await _mutation(
      method: method,
      endpoint: endpoint,
      body: body,
      idempotencyKey: idempotencyKey,
      expectedStatus: 200,
    );
    return _single(
      response,
      key: 'intent',
      parse: SwapIntentProjection.fromJson,
    );
  }

  Future<http.Response> _read(String endpoint) async {
    final response = await _apiClient.get(endpoint);
    _requireExpectedStatus(response, 200, mutation: false);
    return response;
  }

  Future<http.Response> _mutation({
    required _MutationMethod method,
    required String endpoint,
    required Map<String, dynamic> body,
    required String idempotencyKey,
    required int expectedStatus,
  }) async {
    validateExchangeIdempotencyKey(idempotencyKey);
    final immutableBody = _immutableJsonObject(body);
    final sessionScope = _apiClient.captureSessionScope();
    final headers = Map<String, String>.unmodifiable({
      'Idempotency-Key': idempotencyKey,
    });

    for (var attempt = 1; attempt <= _retryPolicy.maxAttempts; attempt++) {
      try {
        final response = switch (method) {
          _MutationMethod.post => _apiClient.post(
            endpoint,
            body: immutableBody,
            extraHeaders: headers,
            sessionScope: sessionScope,
          ),
          _MutationMethod.patch => _apiClient.patch(
            endpoint,
            body: immutableBody,
            extraHeaders: headers,
            sessionScope: sessionScope,
          ),
        };
        final completed = await response;
        if (completed.statusCode == 503 && attempt < _retryPolicy.maxAttempts) {
          await _retryDelay(_retryPolicy.delayBeforeAttempt(attempt + 1));
          continue;
        }
        _requireExpectedStatus(completed, expectedStatus, mutation: true);
        return completed;
      } on ApiRequestException catch (error) {
        if (!error.isTransportFailure) rethrow;
        if (attempt < _retryPolicy.maxAttempts) {
          await _retryDelay(_retryPolicy.delayBeforeAttempt(attempt + 1));
          continue;
        }
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
    }
    throw StateError('Unreachable exchange retry state.');
  }

  @override
  Future<SwapAgreement> getAgreement(String agreementId) async {
    final response = await _read(
      '/v1/me/swap-agreements/${_encodedResourceId(agreementId, 'agreementId')}',
    );
    return SwapAgreement.fromJson(_decodeObject(response));
  }

  @override
  Future<SwapAgreement> recordAgreementConsent(
    String agreementId, {
    required EventPresenceGrant presenceGrant,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    final response = await _singleAttemptPost(
      endpoint:
          '/v1/me/swap-agreements/${_encodedResourceId(agreementId, 'agreementId')}/consents',
      body: {
        ...presenceGrant.toCommandJson(),
        'expectedVersion': expectedVersion,
      },
      idempotencyKey: idempotencyKey,
      expectedStatus: 200,
    );
    return SwapAgreement.fromJson(_decodeObject(response));
  }

  @override
  Future<SwapAgreement> recordAgreementHandoff(
    String agreementId, {
    required EventPresenceGrant presenceGrant,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    final response = await _singleAttemptPost(
      endpoint:
          '/v1/me/swap-agreements/${_encodedResourceId(agreementId, 'agreementId')}/handoff-confirmations',
      body: {
        ...presenceGrant.toCommandJson(),
        'expectedVersion': expectedVersion,
      },
      idempotencyKey: idempotencyKey,
      expectedStatus: 200,
    );
    return SwapAgreement.fromJson(_decodeObject(response));
  }

  @override
  Future<SwapAgreement> recordAgreementCashConfirmation(
    String agreementId, {
    required EventPresenceGrant presenceGrant,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    final response = await _singleAttemptPost(
      endpoint:
          '/v1/me/swap-agreements/${_encodedResourceId(agreementId, 'agreementId')}/cash-confirmations',
      body: {
        ...presenceGrant.toCommandJson(),
        'expectedVersion': expectedVersion,
      },
      idempotencyKey: idempotencyKey,
      expectedStatus: 200,
    );
    return SwapAgreement.fromJson(_decodeObject(response));
  }

  @override
  Future<SwapAgreement> cancelAgreement(
    String agreementId, {
    required String? reason,
    required String idempotencyKey,
  }) async {
    final normalizedReason = reason?.trim();
    if (normalizedReason != null && normalizedReason.length > 500) {
      throw const ExchangeContractException(
        'Agreement cancellation reason exceeds 500 characters.',
      );
    }
    final response = await _singleAttemptPost(
      endpoint:
          '/v1/me/swap-agreements/${_encodedResourceId(agreementId, 'agreementId')}/cancel',
      body: {
        if (normalizedReason != null && normalizedReason.isNotEmpty)
          'reason': normalizedReason,
      },
      idempotencyKey: idempotencyKey,
      expectedStatus: 200,
    );
    return SwapAgreement.fromJson(_decodeObject(response));
  }

  @override
  Future<SwapAgreement> disputeAgreement(
    String agreementId, {
    required String reason,
    required String idempotencyKey,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty || normalizedReason.length > 2000) {
      throw const ExchangeContractException(
        'Agreement dispute reason must be between 1 and 2000 characters.',
      );
    }
    final response = await _singleAttemptPost(
      endpoint:
          '/v1/me/swap-agreements/${_encodedResourceId(agreementId, 'agreementId')}/disputes',
      body: {'reason': normalizedReason},
      idempotencyKey: idempotencyKey,
      expectedStatus: 200,
    );
    return SwapAgreement.fromJson(_decodeObject(response));
  }

  @override
  Future<SwapConversationProjection> getSwapConversation(
    String requestId,
  ) async {
    final response = await _read(
      '/v1/me/swap-requests/${_encodedResourceId(requestId, 'requestId')}/conversation',
    );
    return SwapConversationProjection.fromJson(_decodeObject(response));
  }

  @override
  Future<SwapMessageProjection> sendSwapMessage(
    String requestId,
    SendSwapMessageRequest request, {
    required String idempotencyKey,
  }) async {
    final response = await _singleAttemptPost(
      endpoint:
          '/v1/me/swap-requests/${_encodedResourceId(requestId, 'requestId')}/conversation/messages',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
      expectedStatus: 201,
    );
    return SwapMessageProjection.fromJson(_decodeObject(response));
  }

  @override
  Future<SwapConversationReadResult> markSwapConversationRead(
    String requestId, {
    required String idempotencyKey,
  }) async {
    final response = await _singleAttemptPost(
      endpoint:
          '/v1/me/swap-requests/${_encodedResourceId(requestId, 'requestId')}/conversation/read',
      idempotencyKey: idempotencyKey,
      expectedStatus: 200,
    );
    return SwapConversationReadResult.fromJson(_decodeObject(response));
  }

  @override
  Future<SwapAgreement> confirmTransfer(
    String agreementId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) async => throw const ExchangeContractException(
    'Legacy confirm-transfer is not part of the current agreement contract. '
    'Acquire fresh event presence and record a handoff confirmation instead.',
  );

  Future<http.Response> _singleAttemptPost({
    required String endpoint,
    Map<String, dynamic>? body,
    String? idempotencyKey,
    required int expectedStatus,
  }) async {
    if (idempotencyKey != null) {
      validateExchangeIdempotencyKey(idempotencyKey);
    }
    final immutableBody = body == null ? null : _immutableJsonObject(body);
    final sessionScope = _apiClient.captureSessionScope();
    try {
      final response = await _apiClient.post(
        endpoint,
        body: immutableBody,
        extraHeaders: {
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
        sessionScope: sessionScope,
      );
      _requireExpectedStatus(response, expectedStatus, mutation: true);
      return response;
    } on ApiRequestException catch (error) {
      if (!error.isTransportFailure || error.outcomeUnknown) rethrow;
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
  }

  @override
  Future<RevealedEntitlement> getRevealedEntitlement(String agreementId) async {
    throw const ExchangeContractException(
      'Revealed entitlements are not part of the current agreement contract.',
    );
  }
}

enum _MutationMethod { post, patch }

String _listEndpoint(
  String path, {
  required int limit,
  required int offset,
  required String? state,
}) {
  validateExchangePage(limit: limit, offset: offset);
  return Uri(
    path: path,
    queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
      if (state != null) 'state': state,
    },
  ).toString();
}

String _encodedResourceId(String value, String field) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    throw ExchangeContractException('$field must be a UUID.');
  }
  return Uri.encodeComponent(value);
}

Map<String, dynamic> _immutableJsonObject(Map<String, dynamic> source) {
  final decoded = jsonDecode(jsonEncode(source));
  if (decoded is! Map) {
    throw const ExchangeContractException('Request must be a JSON object.');
  }
  return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(decoded));
}

void _requireExpectedStatus(
  http.Response response,
  int expectedStatus, {
  required bool mutation,
}) {
  if (response.statusCode == expectedStatus) return;
  if (response.statusCode >= 200 && response.statusCode < 300) {
    throw ExchangeContractException(
      'Server returned an unexpected success status (${response.statusCode}).',
    );
  }
  ApiClient.requireSuccess(response, outcomeUnknown: mutation);
}

Map<String, dynamic> _decodeObject(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);
    return _object(decoded, 'response');
  } on ExchangeContractException {
    rethrow;
  } on Object {
    throw const ExchangeContractException(
      'Server response is not valid contract JSON.',
    );
  }
}

Map<String, dynamic> _object(Object? value, String field) {
  if (value is! Map) {
    throw ExchangeContractException('$field must be an object.');
  }
  try {
    return Map<String, dynamic>.from(value);
  } on Object {
    throw ExchangeContractException('$field must be a JSON object.');
  }
}

void _expectExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String objectName,
) {
  if (json.length != expected.length ||
      expected.any((key) => !json.containsKey(key)) ||
      json.keys.any((key) => !expected.contains(key))) {
    throw ExchangeContractException(
      '$objectName does not match the response contract.',
    );
  }
}

T _single<T>(
  http.Response response, {
  required String key,
  required T Function(Map<String, dynamic>) parse,
}) {
  final json = _decodeObject(response);
  _expectExactKeys(json, {key}, '$key response');
  return parse(_object(json[key], key));
}

ExchangePage<T> _page<T>(
  http.Response response,
  T Function(Map<String, dynamic>) parse,
) {
  final json = _decodeObject(response);
  _expectExactKeys(json, const {'items', 'total'}, 'list response');
  final rawItems = json['items'];
  final total = json['total'];
  if (rawItems is! List) {
    throw const ExchangeContractException('items must be an array.');
  }
  if (total is! int || total < 0) {
    throw const ExchangeContractException(
      'total must be a non-negative integer.',
    );
  }
  return ExchangePage(
    items: List.unmodifiable(
      rawItems.map((item) => parse(_object(item, 'list item'))),
    ),
    total: total,
  );
}
