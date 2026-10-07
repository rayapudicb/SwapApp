import 'auth_models.dart';

abstract interface class PasswordlessAuthRepository {
  Future<AuthChallenge> requestOtp({
    required String phoneNumber,
    required String installationId,
    required String idempotencyKey,
  });

  Future<AuthChallenge> resendOtp({
    required String challengeId,
    required String installationId,
    required String idempotencyKey,
  });

  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
    required String installationId,
    required String idempotencyKey,
  });

  Future<AuthSession> refreshSession({
    required String refreshToken,
    required String installationId,
    required String idempotencyKey,
  });

  Future<AuthSessionState> getSessionState({
    required String accessToken,
  });

  Future<void> revokeCurrentSession({
    required String accessToken,
    required String idempotencyKey,
  });

  Future<void> revokeAllSessions({
    required String accessToken,
    required String idempotencyKey,
  });

  Future<AuthChallenge> requestDeletionChallenge({
    required String accessToken,
    required String idempotencyKey,
  });

  Future<ReauthenticationGrant> verifyDeletionChallenge({
    required String accessToken,
    required String challengeId,
    required String code,
    required String idempotencyKey,
  });

  Future<AccountDeletionResult> requestAccountDeletion({
    required String accessToken,
    required String reauthenticationToken,
    required String expectedAccountState,
    required int expectedContinuationVersion,
    required String idempotencyKey,
  });
}
