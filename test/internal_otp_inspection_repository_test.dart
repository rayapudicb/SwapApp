import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passwordless_identity/passwordless_identity.dart';
import 'package:swappy_mobile/features/auth/data/internal_otp_inspection_repository.dart';

void main() {
  final now = DateTime.utc(2026, 7, 26, 12);

  test('loopback inspector enriches the public challenge only', () async {
    Uri? inspectedUri;
    final baseUri = Uri.parse('http://127.0.0.1:3100');
    final delegate = HttpPasswordlessAuthRepository(
      baseUri: baseUri,
      transport: (_, __, ___, ____) async => IdentityHttpResponse(
        statusCode: HttpStatus.accepted,
        body: jsonEncode({
          'challengeId': 'e2ce8402-7aa7-4da0-b7d3-adbf0a66cf68',
          'destinationMasked': '+1 ******0123',
          'expiresAt': '2026-07-26T12:05:00Z',
          'resendAvailableAt': '2026-07-26T12:01:00Z',
        }),
      ),
    );
    final repository = InternalOtpInspectionRepository(
      delegate: delegate,
      baseUri: baseUri,
      inspectionTransport: (uri) async {
        inspectedUri = uri;
        return InternalOtpInspectionResponse(
          statusCode: HttpStatus.ok,
          body: jsonEncode({
            'challengeId': 'e2ce8402-7aa7-4da0-b7d3-adbf0a66cf68',
            'verificationCode': '482901',
          }),
        );
      },
    );

    final challenge = await repository.requestOtp(
      phoneNumber: '+12025550123',
      installationId: 'f66e2cdc-4c5a-48dc-a76a-0655b634ec5c',
      idempotencyKey: '67f668cb-090e-4fbd-b69d-e2394979a1bb',
    );

    expect(
      inspectedUri?.path,
      '/internal/v1/otp-challenges/'
      'e2ce8402-7aa7-4da0-b7d3-adbf0a66cf68',
    );
    expect(challenge.internalVerificationCode, '482901');
  });

  test('inspection never creates a session before ordinary verify', () async {
    var verifyCalls = 0;
    String? submittedCode;
    final baseUri = Uri.parse('http://127.0.0.1:3100');
    final delegate = HttpPasswordlessAuthRepository(
      baseUri: baseUri,
      transport: (method, uri, _, body) async {
        if (method == 'POST' && uri.path == '/v1/auth/otp/challenges') {
          return IdentityHttpResponse(
            statusCode: HttpStatus.accepted,
            body: jsonEncode({
              'challengeId': 'e2ce8402-7aa7-4da0-b7d3-adbf0a66cf68',
              'destinationMasked': '+1 ******0123',
              'expiresAt': '2026-07-26T12:05:00Z',
              'resendAvailableAt': '2026-07-26T12:01:00Z',
            }),
          );
        }
        if (method == 'POST' &&
            uri.path ==
                '/v1/auth/otp/challenges/'
                    'e2ce8402-7aa7-4da0-b7d3-adbf0a66cf68/verify') {
          verifyCalls++;
          submittedCode = (body as Map<String, Object?>)['code'] as String?;
          return IdentityHttpResponse(
            statusCode: HttpStatus.ok,
            body: jsonEncode({
              'credentials': {
                'accessToken':
                    'access-token-with-at-least-thirty-two-characters',
                'accessTokenExpiresAt': '2026-07-26T12:15:00Z',
                'refreshToken':
                    'refresh-token-with-at-least-thirty-two-characters',
                'refreshTokenExpiresAt': '2026-08-25T12:00:00Z',
                'tokenType': 'Bearer',
                'sessionId': '53dd7d86-e795-4687-8d92-bf9d0e08cd5b',
              },
              'accountState': 'onboarding',
              'continuationVersion': 1,
              'nextAction': 'profile_required',
              'nextStep': 'profile_basics_required',
            }),
          );
        }
        throw StateError('Unexpected identity request: $method $uri');
      },
    );
    final repository = InternalOtpInspectionRepository(
      delegate: delegate,
      baseUri: baseUri,
      inspectionTransport: (_) async => InternalOtpInspectionResponse(
        statusCode: HttpStatus.ok,
        body: jsonEncode({
          'challengeId': 'e2ce8402-7aa7-4da0-b7d3-adbf0a66cf68',
          'verificationCode': '482901',
        }),
      ),
    );
    final store = _MemorySessionStore();
    final coordinator = PasswordlessAuthCoordinator(
      repository: repository,
      sessionStore: store,
      clock: () => now,
    );
    await coordinator.bootstrap();

    await coordinator.requestOtp('+12025550123');

    expect(coordinator.phase, AuthCoordinatorPhase.awaitingOtp);
    expect(coordinator.challenge?.internalVerificationCode, '482901');
    expect(verifyCalls, 0);
    expect(store.refreshToken, isNull);

    await coordinator.verifyOtp('482901');

    expect(verifyCalls, 1);
    expect(submittedCode, '482901');
    expect(coordinator.phase, AuthCoordinatorPhase.authenticated);
    expect(
      store.refreshToken,
      'refresh-token-with-at-least-thirty-two-characters',
    );
  });
}

class _MemorySessionStore implements AuthSessionStore {
  RefreshSessionState? _refreshSession;

  String? get refreshToken => _refreshSession?.refreshToken;

  @override
  Future<void> clearRefreshSession() async {
    _refreshSession = null;
  }

  @override
  Future<String> getOrCreateInstallationId() async =>
      'f66e2cdc-4c5a-48dc-a76a-0655b634ec5c';

  @override
  Future<RefreshSessionState?> readRefreshSession() async => _refreshSession;

  @override
  Future<void> writeRefreshSession(RefreshSessionState session) async {
    _refreshSession = session;
  }
}
