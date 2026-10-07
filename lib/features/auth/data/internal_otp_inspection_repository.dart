import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:passwordless_identity/passwordless_identity.dart';

typedef InternalOtpInspectionTransport =
    Future<InternalOtpInspectionResponse> Function(Uri uri);

class InternalOtpInspectionResponse {
  const InternalOtpInspectionResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

/// Development-only decorator used by `main_internal.dart`.
///
/// The production entrypoint must never import this file. It reads a generated
/// code from the API's separately gated loopback inspection endpoint and
/// enriches the real durable challenge returned by the public contract. The
/// participant still enters that code and invokes the ordinary public verify
/// operation; inspection never consumes a challenge or creates a session.
class InternalOtpInspectionRepository implements PasswordlessAuthRepository {
  InternalOtpInspectionRepository({
    required PasswordlessAuthRepository delegate,
    required Uri baseUri,
    InternalOtpInspectionTransport? inspectionTransport,
  }) : _delegate = delegate,
       _baseUri = baseUri,
       _inspectionTransport = inspectionTransport ?? _ioInspectionTransport {
    if (kReleaseMode) {
      throw StateError(
        'Internal OTP inspection is unavailable in release builds.',
      );
    }
    if (!_isLoopback(baseUri.host)) {
      throw ArgumentError(
        'Internal OTP inspection requires a loopback API host.',
      );
    }
  }

  final PasswordlessAuthRepository _delegate;
  final Uri _baseUri;
  final InternalOtpInspectionTransport _inspectionTransport;

  @override
  Future<AuthChallenge> requestOtp({
    required String phoneNumber,
    required String installationId,
    required String idempotencyKey,
  }) async => _inspect(
    await _delegate.requestOtp(
      phoneNumber: phoneNumber,
      installationId: installationId,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<AuthChallenge> resendOtp({
    required String challengeId,
    required String installationId,
    required String idempotencyKey,
  }) async => _inspect(
    await _delegate.resendOtp(
      challengeId: challengeId,
      installationId: installationId,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<AuthChallenge> requestDeletionChallenge({
    required String accessToken,
    required String idempotencyKey,
  }) async => _inspect(
    await _delegate.requestDeletionChallenge(
      accessToken: accessToken,
      idempotencyKey: idempotencyKey,
    ),
  );

  Future<AuthChallenge> _inspect(AuthChallenge challenge) async {
    try {
      final response = await _inspectionTransport(
        _baseUri.resolve(
          '/internal/v1/otp-challenges/'
          '${Uri.encodeComponent(challenge.id)}',
        ),
      );
      final body = response.body;
      if (response.statusCode != HttpStatus.ok) {
        throw const AuthException(
          code: 'INTERNAL_OTP_INSPECTION_UNAVAILABLE',
          message: 'We could not send a verification code. Try again.',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map ||
          decoded['challengeId'] != challenge.id ||
          decoded['verificationCode'] is! String ||
          !RegExp(
            r'^(?:[0-9]{4}|[0-9]{6})$',
          ).hasMatch(decoded['verificationCode'] as String)) {
        throw const AuthException(
          code: 'INTERNAL_OTP_INSPECTION_INVALID',
          message: 'We could not prepare the verification code. Try again.',
        );
      }
      final verificationCode = decoded['verificationCode'] as String;

      return AuthChallenge(
        id: challenge.id,
        destinationMasked: challenge.destinationMasked,
        expiresAt: challenge.expiresAt,
        resendAvailableAt: challenge.resendAvailableAt,
        internalVerificationCode: verificationCode,
      );
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        code: 'INTERNAL_OTP_INSPECTION_TIMEOUT',
        message: 'Sending the verification code took too long. Try again.',
      );
    } on IOException {
      throw const AuthException(
        code: 'INTERNAL_OTP_INSPECTION_UNAVAILABLE',
        message: 'We could not send a verification code. Try again.',
      );
    } on FormatException {
      throw const AuthException(
        code: 'INTERNAL_OTP_INSPECTION_INVALID',
        message: 'We could not prepare the verification code. Try again.',
      );
    }
  }

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
    required String installationId,
    required String idempotencyKey,
  }) => _delegate.verifyOtp(
    challengeId: challengeId,
    code: code,
    installationId: installationId,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<AuthSession> refreshSession({
    required String refreshToken,
    required String installationId,
    required String idempotencyKey,
  }) => _delegate.refreshSession(
    refreshToken: refreshToken,
    installationId: installationId,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<AuthSessionState> getSessionState({required String accessToken}) =>
      _delegate.getSessionState(accessToken: accessToken);

  @override
  Future<void> revokeCurrentSession({
    required String accessToken,
    required String idempotencyKey,
  }) => _delegate.revokeCurrentSession(
    accessToken: accessToken,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<void> revokeAllSessions({
    required String accessToken,
    required String idempotencyKey,
  }) => _delegate.revokeAllSessions(
    accessToken: accessToken,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<ReauthenticationGrant> verifyDeletionChallenge({
    required String accessToken,
    required String challengeId,
    required String code,
    required String idempotencyKey,
  }) => _delegate.verifyDeletionChallenge(
    accessToken: accessToken,
    challengeId: challengeId,
    code: code,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<AccountDeletionResult> requestAccountDeletion({
    required String accessToken,
    required String reauthenticationToken,
    required String expectedAccountState,
    required int expectedContinuationVersion,
    required String idempotencyKey,
  }) => _delegate.requestAccountDeletion(
    accessToken: accessToken,
    reauthenticationToken: reauthenticationToken,
    expectedAccountState: expectedAccountState,
    expectedContinuationVersion: expectedContinuationVersion,
    idempotencyKey: idempotencyKey,
  );

  static Future<InternalOtpInspectionResponse> _ioInspectionTransport(
    Uri uri,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 3));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      return InternalOtpInspectionResponse(
        statusCode: response.statusCode,
        body: await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 5)),
      );
    } finally {
      client.close(force: true);
    }
  }
}

bool _isLoopback(String host) =>
    host == '127.0.0.1' || host == 'localhost' || host == '::1';
