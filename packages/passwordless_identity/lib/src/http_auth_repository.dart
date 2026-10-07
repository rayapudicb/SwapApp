import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'auth_models.dart';
import 'auth_repository.dart';

typedef IdentityHttpTransport = Future<IdentityHttpResponse> Function(
  String method,
  Uri uri,
  Map<String, String> headers,
  Object? body,
);

class IdentityHttpResponse {
  const IdentityHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

class HttpPasswordlessAuthRepository implements PasswordlessAuthRepository {
  HttpPasswordlessAuthRepository({
    required this.baseUri,
    IdentityHttpTransport? transport,
  }) : _transport = transport ?? _ioTransport {
    if (!baseUri.hasScheme ||
        !const {'http', 'https'}.contains(baseUri.scheme) ||
        baseUri.host.isEmpty) {
      throw ArgumentError.value(baseUri, 'baseUri', 'must be HTTP or HTTPS');
    }
  }

  final Uri baseUri;
  final IdentityHttpTransport _transport;

  @override
  Future<AuthChallenge> requestOtp({
    required String phoneNumber,
    required String installationId,
    required String idempotencyKey,
  }) async {
    final json = await _requestObject(
      'POST',
      '/v1/auth/otp/challenges',
      body: {'phoneNumber': phoneNumber, 'intent': 'authenticate'},
      installationId: installationId,
      idempotencyKey: idempotencyKey,
      outcomeUnknown: true,
    );
    return _challenge(json);
  }

  @override
  Future<AuthChallenge> resendOtp({
    required String challengeId,
    required String installationId,
    required String idempotencyKey,
  }) async {
    final json = await _requestObject(
      'POST',
      '/v1/auth/otp/challenges/${Uri.encodeComponent(challengeId)}/resend',
      installationId: installationId,
      idempotencyKey: idempotencyKey,
      outcomeUnknown: true,
    );
    return _challenge(json);
  }

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
    required String installationId,
    required String idempotencyKey,
  }) async {
    final json = await _requestObject(
      'POST',
      '/v1/auth/otp/challenges/${Uri.encodeComponent(challengeId)}/verify',
      body: {'code': code, 'installationId': installationId},
      idempotencyKey: idempotencyKey,
      outcomeUnknown: true,
    );
    return _session(json);
  }

  @override
  Future<AuthSession> refreshSession({
    required String refreshToken,
    required String installationId,
    required String idempotencyKey,
  }) async {
    final json = await _requestObject(
      'POST',
      '/v1/auth/sessions/refresh',
      body: {'refreshToken': refreshToken, 'installationId': installationId},
      idempotencyKey: idempotencyKey,
      outcomeUnknown: true,
    );
    return _session(json);
  }

  @override
  Future<AuthSessionState> getSessionState({
    required String accessToken,
  }) async {
    final json = await _requestObject(
      'GET',
      '/v1/auth/session',
      accessToken: accessToken,
      outcomeUnknown: false,
    );
    return _sessionState(json);
  }

  @override
  Future<void> revokeCurrentSession({
    required String accessToken,
    required String idempotencyKey,
  }) async {
    await _request(
      'DELETE',
      '/v1/auth/sessions/current',
      accessToken: accessToken,
      idempotencyKey: idempotencyKey,
      outcomeUnknown: true,
    );
  }

  @override
  Future<void> revokeAllSessions({
    required String accessToken,
    required String idempotencyKey,
  }) async {
    await _request(
      'DELETE',
      '/v1/auth/sessions',
      accessToken: accessToken,
      idempotencyKey: idempotencyKey,
      outcomeUnknown: true,
    );
  }

  @override
  Future<AuthChallenge> requestDeletionChallenge({
    required String accessToken,
    required String idempotencyKey,
  }) async {
    final json = await _requestObject(
      'POST',
      '/v1/me/deletion-challenges',
      accessToken: accessToken,
      idempotencyKey: idempotencyKey,
      outcomeUnknown: true,
    );
    return _challenge(json);
  }

  @override
  Future<ReauthenticationGrant> verifyDeletionChallenge({
    required String accessToken,
    required String challengeId,
    required String code,
    required String idempotencyKey,
  }) async {
    final json = await _requestObject(
      'POST',
      '/v1/me/deletion-challenges/${Uri.encodeComponent(challengeId)}/verify',
      accessToken: accessToken,
      body: {'code': code},
      idempotencyKey: idempotencyKey,
      outcomeUnknown: true,
    );
    return ReauthenticationGrant(
      token: _requiredString(json, 'grantToken'),
      expiresAt: _requiredDate(json, 'expiresAt'),
    );
  }

  @override
  Future<AccountDeletionResult> requestAccountDeletion({
    required String accessToken,
    required String reauthenticationToken,
    required String expectedAccountState,
    required int expectedContinuationVersion,
    required String idempotencyKey,
  }) async {
    final json = await _requestObject(
      'POST',
      '/v1/me/deletion-requests',
      accessToken: accessToken,
      body: {
        'confirmation': 'delete_account',
        'expectedAccountState': expectedAccountState,
        'expectedContinuationVersion': expectedContinuationVersion,
      },
      reauthenticationToken: reauthenticationToken,
      idempotencyKey: idempotencyKey,
      outcomeUnknown: true,
    );
    return AccountDeletionResult(
      status: _requiredString(json, 'status'),
      requestedAt: _requiredDate(json, 'requestedAt'),
      scheduledFor: _requiredDate(json, 'scheduledFor'),
      cancellable: _requiredBool(json, 'cancellable'),
    );
  }

  Future<Map<String, Object?>> _requestObject(
    String method,
    String path, {
    String? accessToken,
    Object? body,
    String? idempotencyKey,
    String? installationId,
    String? reauthenticationToken,
    required bool outcomeUnknown,
  }) async {
    final response = await _request(
      method,
      path,
      accessToken: accessToken,
      body: body,
      idempotencyKey: idempotencyKey,
      installationId: installationId,
      reauthenticationToken: reauthenticationToken,
      outcomeUnknown: outcomeUnknown,
    );
    final decoded = _decode(
      response.body,
      outcomeUnknown: outcomeUnknown,
    );
    if (decoded is! Map) {
      throw AuthException(
        code: 'AUTH_CONTRACT_INVALID',
        message: 'The identity API returned an invalid response.',
        outcomeUnknown: outcomeUnknown,
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<IdentityHttpResponse> _request(
    String method,
    String path, {
    String? accessToken,
    Object? body,
    String? idempotencyKey,
    String? installationId,
    String? reauthenticationToken,
    required bool outcomeUnknown,
  }) async {
    IdentityHttpResponse response;
    try {
      response = await _transport(
          method,
          baseUri.resolve(path),
          {
            HttpHeaders.acceptHeader: 'application/json',
            if (body != null) HttpHeaders.contentTypeHeader: 'application/json',
            if (accessToken != null)
              HttpHeaders.authorizationHeader: 'Bearer $accessToken',
            if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
            if (installationId != null) 'X-App-Installation-ID': installationId,
            if (reauthenticationToken != null)
              'X-Reauthentication-Grant': reauthenticationToken,
          },
          body);
    } on TimeoutException {
      throw AuthException(
        code: 'AUTH_TIMEOUT',
        message: 'The identity request timed out. You can retry safely.',
        outcomeUnknown: outcomeUnknown,
      );
    } on IOException {
      throw AuthException(
        code: 'AUTH_UNREACHABLE',
        message: 'Cannot reach the identity service. Check the connection.',
        outcomeUnknown: outcomeUnknown,
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(
        code: 'AUTH_REQUEST_FAILED',
        message: 'The identity request failed unexpectedly.',
        outcomeUnknown: outcomeUnknown,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    final decoded = _decode(response.body);
    final error = decoded is Map
        ? decoded.map((key, value) => MapEntry(key.toString(), value))
        : const <String, Object?>{};
    final code = _optionalString(error['code']) ?? 'AUTH_REQUEST_REJECTED';
    final message = _optionalString(error['message']) ??
        'The identity request was rejected (${response.statusCode}).';
    final retryAt = _optionalDate(error['retryAt']);
    final attemptsRemaining = error['attemptsRemaining'];
    throw AuthException(
      code: code,
      message: message,
      sessionInvalid: response.statusCode == HttpStatus.unauthorized ||
          const {
            'SESSION_INVALID',
            'SESSION_REVOKED',
            'REFRESH_TOKEN_INVALID',
            'REFRESH_TOKEN_REUSED',
          }.contains(code),
      retryAt: retryAt,
      attemptsRemaining: attemptsRemaining is int ? attemptsRemaining : null,
      correlationId: response.headers['x-correlation-id'] ??
          response.headers['X-Correlation-ID'],
    );
  }

  AuthChallenge _challenge(Map<String, Object?> json) {
    final destinationMasked = _requiredString(json, 'destinationMasked');
    final expiresAt = _requiredDate(json, 'expiresAt');
    final resendAvailableAt = _requiredDate(json, 'resendAvailableAt');
    final compactDestination =
        destinationMasked.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (destinationMasked.length > 32 ||
        RegExp(r'\+[1-9][0-9]{7,14}(?![0-9])').hasMatch(compactDestination) ||
        resendAvailableAt.isAfter(expiresAt)) {
      throw const AuthException(
        code: 'AUTH_CONTRACT_INVALID',
        message: 'The identity API returned an invalid challenge.',
        outcomeUnknown: true,
      );
    }
    return AuthChallenge(
      id: _requiredString(json, 'challengeId'),
      destinationMasked: destinationMasked,
      expiresAt: expiresAt,
      resendAvailableAt: resendAvailableAt,
    );
  }

  AuthSession _session(Map<String, Object?> json) {
    final credentials = _requiredObject(json, 'credentials');
    final accountState = _requiredString(json, 'accountState');
    return AuthSession(
      accessToken: _requiredString(credentials, 'accessToken'),
      refreshToken: _requiredString(credentials, 'refreshToken'),
      accessTokenExpiresAt: _requiredDate(credentials, 'accessTokenExpiresAt'),
      refreshTokenExpiresAt: _requiredDate(
        credentials,
        'refreshTokenExpiresAt',
      ),
      sessionId: _requiredString(credentials, 'sessionId'),
      accountState: accountState,
      continuation: _validatedContinuation(json, accountState),
    );
  }

  AuthSessionState _sessionState(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'participantId',
      'sessionId',
      'expiresAt',
      'accountState',
      'continuationVersion',
      'nextAction',
      'nextStep',
    });
    final accountState = _requiredString(json, 'accountState');
    return AuthSessionState(
      participantId: _requiredUuid(json, 'participantId'),
      sessionId: _requiredUuid(json, 'sessionId'),
      expiresAt: _requiredDate(json, 'expiresAt'),
      accountState: accountState,
      continuation: _validatedContinuation(json, accountState),
    );
  }

  static Future<IdentityHttpResponse> _ioTransport(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request =
          await client.openUrl(method, uri).timeout(const Duration(seconds: 5));
      headers.forEach(request.headers.set);
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(
            const Duration(seconds: 10),
          );
      return IdentityHttpResponse(
        statusCode: response.statusCode,
        body: await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 10)),
      );
    } finally {
      client.close(force: true);
    }
  }
}

AuthContinuation _validatedContinuation(
  Map<String, Object?> json,
  String accountState,
) {
  final version = _requiredInt(json, 'continuationVersion');
  final nextAction = _requiredString(json, 'nextAction');
  final nextStep = _optionalNullableString(json, 'nextStep');
  final validTuple = switch (accountState) {
    'onboarding' => (nextAction == 'profile_required' ||
            nextAction == 'profile_in_progress') &&
        nextStep != null,
    'active' => nextAction == 'home' && nextStep == null,
    'deletion_pending' =>
      nextAction == 'account_deletion_pending' && nextStep == null,
    'deactivated' => nextAction == 'account_deleted' && nextStep == null,
    'suspended' => nextAction == 'account_ineligible' && nextStep == null,
    _ => false,
  };
  if (version < 1 || !validTuple) {
    throw const AuthException(
      code: 'AUTH_CONTRACT_INVALID',
      message: 'The identity service returned an invalid session state.',
      outcomeUnknown: true,
    );
  }
  return AuthContinuation(
    nextAction: nextAction,
    nextStep: nextStep,
    version: version,
  );
}

void _requireExactKeys(
  Map<String, Object?> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw const AuthException(
      code: 'AUTH_CONTRACT_INVALID',
      message: 'The identity service returned an invalid session state.',
      outcomeUnknown: true,
    );
  }
}

Object? _decode(String body, {bool outcomeUnknown = false}) {
  if (body.trim().isEmpty) return null;
  try {
    return jsonDecode(body);
  } on FormatException {
    throw AuthException(
      code: 'AUTH_RESPONSE_UNREADABLE',
      message: 'The identity API returned an unreadable response.',
      outcomeUnknown: outcomeUnknown,
    );
  }
}

Map<String, Object?> _requiredObject(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw AuthException(
      code: 'AUTH_CONTRACT_INVALID',
      message: 'The identity response is missing $key.',
      outcomeUnknown: true,
    );
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw AuthException(
      code: 'AUTH_CONTRACT_INVALID',
      message: 'The identity response is missing $key.',
      outcomeUnknown: true,
    );
  }
  return value;
}

String _requiredUuid(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value)) {
    throw AuthException(
      code: 'AUTH_CONTRACT_INVALID',
      message: 'The identity response contains an invalid $key.',
      outcomeUnknown: true,
    );
  }
  return value.toLowerCase();
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw AuthException(
      code: 'AUTH_CONTRACT_INVALID',
      message: 'The identity response is missing $key.',
      outcomeUnknown: true,
    );
  }
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw AuthException(
      code: 'AUTH_CONTRACT_INVALID',
      message: 'The identity response is missing $key.',
      outcomeUnknown: true,
    );
  }
  return value;
}

String? _optionalNullableString(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw AuthException(
      code: 'AUTH_CONTRACT_INVALID',
      message: 'The identity response is missing $key.',
      outcomeUnknown: true,
    );
  }
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty && value.length <= 64) {
    return value;
  }
  throw AuthException(
    code: 'AUTH_CONTRACT_INVALID',
    message: 'The identity response contains an invalid $key.',
    outcomeUnknown: true,
  );
}

DateTime _requiredDate(Map<String, Object?> json, String key) {
  final value = _optionalDate(json[key]);
  if (value == null) {
    throw AuthException(
      code: 'AUTH_CONTRACT_INVALID',
      message: 'The identity response contains an invalid $key.',
      outcomeUnknown: true,
    );
  }
  return value;
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

DateTime? _optionalDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}
