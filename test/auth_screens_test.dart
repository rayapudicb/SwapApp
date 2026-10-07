import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passwordless_identity/passwordless_identity.dart';
import 'package:provider/provider.dart';
import 'package:swappy_mobile/core/storage/secure_storage.dart';
import 'package:swappy_mobile/core/theme/medusa_flutter_theme.dart';
import 'package:swappy_mobile/features/auth/presentation/otp_verification_screen.dart';
import 'package:swappy_mobile/features/auth/providers/auth_provider.dart';
import 'package:swappy_mobile/features/profile/data/participant_profile_client.dart';

void main() {
  testWidgets('OTP screen never displays or auto-fills an internal code', (
    tester,
  ) async {
    final coordinator = PasswordlessAuthCoordinator(
      repository: _ChallengeRepository(),
      sessionStore: _EmptySessionStore(),
    );
    final auth = AuthProvider(
      coordinator: coordinator,
      profileGateway: _UnusedProfileGateway(),
      legacyStorage: _TestStorage(),
      autoInitialize: false,
    );
    addTearDown(auth.dispose);

    await auth.initialize();
    await auth.requestLoginOtp('+12025550123');
    expect(auth.challenge?.internalVerificationCode, '482901');

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          theme: MedusaTheme.light,
          home: const OtpVerificationScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('482901'), findsNothing);
    expect(find.textContaining('Internal'), findsNothing);
    expect(find.textContaining('development'), findsNothing);
    final codeField = tester.widget<TextField>(find.byType(TextField));
    expect(codeField.controller?.text, isEmpty);
    expect(codeField.obscureText, isTrue);

    FilledButton verifyButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verify and continue'),
    );
    expect(verifyButton().onPressed, isNull);
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump();
    expect(verifyButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    expect(verifyButton().onPressed, isNotNull);
    await tester.tap(find.text('Send another code'));
    await tester.pump();
    await tester.pump();

    final resentCodeField = tester.widget<TextField>(find.byType(TextField));
    expect(resentCodeField.controller?.text, isEmpty);
    expect(find.textContaining('999999'), findsNothing);
  });
}

class _ChallengeRepository implements PasswordlessAuthRepository {
  @override
  Future<AuthChallenge> requestOtp({
    required String phoneNumber,
    required String installationId,
    required String idempotencyKey,
  }) async => AuthChallenge(
    id: 'challenge-1',
    destinationMasked: '+1******0123',
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    resendAvailableAt: DateTime.now(),
    internalVerificationCode: '482901',
  );

  @override
  Future<AuthChallenge> resendOtp({
    required String challengeId,
    required String installationId,
    required String idempotencyKey,
  }) async => AuthChallenge(
    id: 'challenge-2',
    destinationMasked: '+1******0123',
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    resendAvailableAt: DateTime.now().add(const Duration(seconds: 30)),
    internalVerificationCode: '999999',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptySessionStore implements AuthSessionStore {
  @override
  Future<void> clearRefreshSession() async {}

  @override
  Future<String> getOrCreateInstallationId() async =>
      '10000000-0000-4000-8000-000000000001';

  @override
  Future<RefreshSessionState?> readRefreshSession() async => null;

  @override
  Future<void> writeRefreshSession(RefreshSessionState value) async {}
}

class _TestStorage extends SecureStorage {
  @override
  Future<void> clearLegacyAuthTokens() async {}

  @override
  Future<bool> getHasSeenWelcome() async => true;
}

class _UnusedProfileGateway implements ParticipantProfileGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
