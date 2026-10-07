enum AuthCoordinatorPhase {
  booting,
  signedOut,
  requestingOtp,
  awaitingOtp,
  verifyingOtp,
  refreshing,
  authenticated,
  deletingAccount,
  recoverableFailure,
}

class AuthChallenge {
  const AuthChallenge({
    required this.id,
    required this.destinationMasked,
    required this.expiresAt,
    required this.resendAvailableAt,
    this.internalVerificationCode,
  });

  final String id;
  final String destinationMasked;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;

  /// Present only when a separately gated internal-development repository
  /// decorator has inspected the challenge. A production API must never return
  /// this field in its public challenge response.
  final String? internalVerificationCode;
}

class AuthContinuation {
  const AuthContinuation({
    required this.nextAction,
    required this.nextStep,
    required this.version,
  });

  final String nextAction;
  final String? nextStep;
  final int version;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.sessionId,
    required this.accountState,
    required this.continuation,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
  final String sessionId;
  final String accountState;
  final AuthContinuation continuation;
}

class AuthSessionState {
  const AuthSessionState({
    required this.participantId,
    required this.sessionId,
    required this.expiresAt,
    required this.accountState,
    required this.continuation,
  });

  final String participantId;
  final String sessionId;
  final DateTime expiresAt;
  final String accountState;
  final AuthContinuation continuation;
}

class ReauthenticationGrant {
  const ReauthenticationGrant({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.status,
    required this.requestedAt,
    required this.scheduledFor,
    required this.cancellable,
  });

  final String status;
  final DateTime requestedAt;
  final DateTime scheduledFor;
  final bool cancellable;
}

class AuthException implements Exception {
  const AuthException({
    required this.code,
    required this.message,
    this.outcomeUnknown = false,
    this.sessionInvalid = false,
    this.retryAt,
    this.attemptsRemaining,
    this.correlationId,
  });

  final String code;
  final String message;
  final bool outcomeUnknown;
  final bool sessionInvalid;
  final DateTime? retryAt;
  final int? attemptsRemaining;
  final String? correlationId;

  @override
  String toString() => 'AuthException($code, $message)';
}
