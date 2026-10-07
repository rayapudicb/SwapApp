import 'package:flutter_test/flutter_test.dart';
import 'package:passwordless_identity/passwordless_identity.dart';
import 'package:swappy_mobile/core/storage/secure_storage.dart';
import 'package:swappy_mobile/features/auth/providers/auth_provider.dart';
import 'package:swappy_mobile/features/profile/data/participant_profile_client.dart';

void main() {
  test(
    'signup verifies OTP then persists display name and follows continuation',
    () async {
      final identity = _IdentityRepository();
      final profiles = _ProfileGateway(displayName: null);
      final legacy = _LegacyStorage();
      final coordinator = PasswordlessAuthCoordinator(
        repository: identity,
        sessionStore: _MemorySessionStore(),
      );
      final auth = AuthProvider(
        coordinator: coordinator,
        profileGateway: profiles,
        legacyStorage: legacy,
        autoInitialize: false,
      );

      await auth.initialize();
      expect(auth.routeState, ParticipantRouteState.signedOut);
      expect(legacy.clearCount, 1);

      final requested = await auth.requestSignupOtp(
        displayName: 'Chinni',
        phone: '+12025550123',
      );
      expect(requested, isTrue);
      expect(identity.requestedPhone, '+12025550123');
      expect(auth.routeState, ParticipantRouteState.awaitingOtp);

      final verified = await auth.verifyOtp('1234');

      expect(verified, isTrue);
      expect(profiles.updatedNames, ['Chinni']);
      expect(
        profiles.updateKeys.single,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(identity.sessionReadCount, 1);
      expect(auth.routeState, ParticipantRouteState.home);
      expect(auth.profile?.displayName, 'Chinni');
      auth.dispose();
    },
  );

  test('returning login loads profile without overwriting its name', () async {
    final identity = _IdentityRepository(
      verifyAccountState: 'active',
      verifyContinuation: _homeContinuation,
    );
    final profiles = _ProfileGateway(displayName: 'Existing participant');
    final coordinator = PasswordlessAuthCoordinator(
      repository: identity,
      sessionStore: _MemorySessionStore(),
    );
    final auth = AuthProvider(
      coordinator: coordinator,
      profileGateway: profiles,
      legacyStorage: _LegacyStorage(),
      autoInitialize: false,
    );

    await auth.initialize();
    await auth.requestLoginOtp('+12025550123');
    final verified = await auth.verifyOtp('1234');

    expect(verified, isTrue);
    expect(profiles.updatedNames, isEmpty);
    expect(auth.profile?.displayName, 'Existing participant');
    expect(auth.routeState, ParticipantRouteState.home);
    auth.dispose();
  });

  test('signup cannot overwrite an existing participant name', () async {
    final identity = _IdentityRepository(
      verifyAccountState: 'active',
      verifyContinuation: _homeContinuation,
    );
    final profiles = _ProfileGateway(displayName: 'Existing participant');
    final auth = _authFor(identity, profileGateway: profiles);

    await auth.initialize();
    await auth.requestSignupOtp(
      displayName: 'Replacement name',
      phone: '+12025550123',
    );
    expect(await auth.verifyOtp('1234'), isTrue);

    expect(profiles.updatedNames, isEmpty);
    expect(auth.profile?.displayName, 'Existing participant');
    expect(auth.routeState, ParticipantRouteState.home);
    auth.dispose();
  });

  test(
    'server profile-required continuation routes to profile basics',
    () async {
      final auth = _authFor(
        _IdentityRepository(
          verifyAccountState: 'onboarding',
          verifyContinuation: _profileBasicsContinuation,
        ),
        profileGateway: _ProfileGateway(
          accountState: 'onboarding',
          nextAction: 'profile_required',
          nextStep: AuthProvider.profileBasicsStep,
        ),
      );

      await auth.initialize();
      await auth.requestLoginOtp('+12025550123');
      expect(await auth.verifyOtp('1234'), isTrue);

      expect(auth.routeState, ParticipantRouteState.profileBasics);
      auth.dispose();
    },
  );

  test('onboarding policy-required continuation remains restricted', () async {
    final auth = _authFor(
      _IdentityRepository(
        verifyAccountState: 'onboarding',
        verifyContinuation: const AuthContinuation(
          nextAction: 'profile_in_progress',
          nextStep: 'onboarding_policy_required',
          version: 1,
        ),
      ),
      profileGateway: _ProfileGateway(
        accountState: 'onboarding',
        nextAction: 'profile_in_progress',
        nextStep: 'onboarding_policy_required',
      ),
    );

    await auth.initialize();
    await auth.requestLoginOtp('+12025550123');
    expect(await auth.verifyOtp('1234'), isTrue);

    expect(auth.routeState, ParticipantRouteState.restricted);
    auth.dispose();
  });

  test(
    'latest restricted session supersedes cached home when onboarding reload fails',
    () async {
      final identity = _IdentityRepository(
        verifyAccountState: 'active',
        verifyContinuation: _homeContinuation,
      );
      final profiles = _ProfileGateway(
        accountState: 'active',
        nextAction: 'home',
      );
      final auth = _authFor(identity, profileGateway: profiles);

      await auth.initialize();
      await auth.requestLoginOtp('+12025550123');
      expect(await auth.verifyOtp('1234'), isTrue);
      expect(auth.routeState, ParticipantRouteState.home);

      identity.sessionStateAccountState = 'onboarding';
      identity.sessionStateContinuation = const AuthContinuation(
        nextAction: 'profile_in_progress',
        nextStep: 'onboarding_policy_required',
        version: 1,
      );
      profiles.failOnboarding = true;
      await auth.refreshAccountStatus();

      expect(auth.routeState, ParticipantRouteState.restricted);
      auth.dispose();
    },
  );

  test('latest suspended session supersedes cached home', () async {
    final identity = _IdentityRepository(
      verifyAccountState: 'active',
      verifyContinuation: _homeContinuation,
    );
    final profiles = _ProfileGateway(
      accountState: 'active',
      nextAction: 'home',
    );
    final auth = _authFor(identity, profileGateway: profiles);

    await auth.initialize();
    await auth.requestLoginOtp('+12025550123');
    expect(await auth.verifyOtp('1234'), isTrue);
    expect(auth.routeState, ParticipantRouteState.home);

    identity.sessionStateAccountState = 'suspended';
    identity.sessionStateContinuation = const AuthContinuation(
      nextAction: 'account_ineligible',
      nextStep: null,
      version: 1,
    );
    profiles.failOnboarding = true;
    await auth.refreshAccountStatus();

    expect(auth.routeState, ParticipantRouteState.restricted);
    auth.dispose();
  });

  test('stale home onboarding cannot reopen a suspended session', () async {
    final identity = _IdentityRepository(
      verifyAccountState: 'active',
      verifyContinuation: _homeContinuation,
    );
    final profiles = _ProfileGateway(
      accountState: 'active',
      nextAction: 'home',
    );
    final auth = _authFor(identity, profileGateway: profiles);

    await auth.initialize();
    await auth.requestLoginOtp('+12025550123');
    expect(await auth.verifyOtp('1234'), isTrue);
    expect(auth.routeState, ParticipantRouteState.home);

    identity.sessionStateAccountState = 'suspended';
    identity.sessionStateContinuation = const AuthContinuation(
      nextAction: 'account_ineligible',
      nextStep: null,
      version: 1,
    );
    await auth.refreshAccountStatus();

    expect(auth.routeState, ParticipantRouteState.restricted);
    auth.dispose();
  });

  test('unsupported latest continuation fails closed to restricted', () async {
    final auth = _authFor(
      _IdentityRepository(
        verifyAccountState: 'active',
        verifyContinuation: _homeContinuation,
      ),
      profileGateway: _ProfileGateway(
        accountState: 'active',
        continuationVersion: 2,
        nextAction: 'home',
      ),
    );

    await auth.initialize();
    await auth.requestLoginOtp('+12025550123');
    expect(await auth.verifyOtp('1234'), isTrue);

    expect(auth.routeState, ParticipantRouteState.restricted);
    auth.dispose();
  });

  test('logout revokes the server session and returns to signed out', () async {
    final identity = _IdentityRepository(
      verifyAccountState: 'active',
      verifyContinuation: _homeContinuation,
    );
    final coordinator = PasswordlessAuthCoordinator(
      repository: identity,
      sessionStore: _MemorySessionStore(),
    );
    final auth = AuthProvider(
      coordinator: coordinator,
      profileGateway: _ProfileGateway(),
      legacyStorage: _LegacyStorage(),
      autoInitialize: false,
    );

    await auth.initialize();
    await auth.requestLoginOtp('+12025550123');
    await auth.verifyOtp('1234');
    await auth.logout();

    expect(identity.revokeCurrentCount, 1);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.routeState, ParticipantRouteState.signedOut);
    auth.dispose();
  });

  test('logout all revokes every server session', () async {
    final identity = _IdentityRepository(
      verifyAccountState: 'active',
      verifyContinuation: _homeContinuation,
    );
    final auth = _authFor(identity);
    await auth.initialize();
    await auth.requestLoginOtp('+12025550123');
    await auth.verifyOtp('1234');

    await auth.logoutAll();

    expect(identity.revokeAllCount, 1);
    expect(auth.isAuthenticated, isFalse);
    auth.dispose();
  });

  test(
    'ambiguous session restore remains recoverable instead of signing out',
    () async {
      final identity = _IdentityRepository(
        refreshError: const AuthException(
          code: 'AUTH_TIMEOUT',
          message: 'The session restore result is unknown.',
          outcomeUnknown: true,
        ),
      );
      final coordinator = PasswordlessAuthCoordinator(
        repository: identity,
        sessionStore: _MemorySessionStore(refreshToken: 'stored-refresh'),
      );
      final auth = AuthProvider(
        coordinator: coordinator,
        profileGateway: _ProfileGateway(),
        legacyStorage: _LegacyStorage(),
        autoInitialize: false,
      );

      await auth.initialize();

      expect(auth.routeState, ParticipantRouteState.recoverable);
      expect(auth.isAuthenticated, isFalse);
      expect(
        auth.errorMessage,
        'The request timed out. Check your connection and retry.',
      );
      auth.dispose();
    },
  );

  test(
    'invalid saved session returns to login without a stale error',
    () async {
      final identity = _IdentityRepository(
        refreshError: const AuthException(
          code: 'SESSION_NOT_AVAILABLE',
          message: 'The participant session is not available.',
          sessionInvalid: true,
        ),
      );
      final sessionStore = _MemorySessionStore(refreshToken: 'stored-refresh');
      final auth = AuthProvider(
        coordinator: PasswordlessAuthCoordinator(
          repository: identity,
          sessionStore: sessionStore,
        ),
        profileGateway: _ProfileGateway(),
        legacyStorage: _LegacyStorage(),
        autoInitialize: false,
      );

      await auth.initialize();

      expect(auth.routeState, ParticipantRouteState.signedOut);
      expect(auth.errorMessage, isNull);
      expect(sessionStore.session, isNull);
      auth.dispose();
    },
  );

  test('verification service failures use a recoverable message', () async {
    final auth = _authFor(
      _IdentityRepository(
        verifyError: const AuthException(
          code: 'INTERNAL_SERVER_ERROR',
          message: 'The service could not complete the request.',
        ),
      ),
    );
    await auth.initialize();
    await auth.requestLoginOtp('+12025550123');

    expect(await auth.verifyOtp('1234'), isFalse);
    expect(
      auth.errorMessage,
      'Verification is temporarily unavailable. Try again in a moment.',
    );
    expect(auth.routeState, ParticipantRouteState.awaitingOtp);
    auth.dispose();
  });

  test('legacy preference failures never block identity startup', () async {
    final auth = AuthProvider(
      coordinator: PasswordlessAuthCoordinator(
        repository: _IdentityRepository(),
        sessionStore: _MemorySessionStore(),
      ),
      profileGateway: _ProfileGateway(),
      legacyStorage: _ThrowingLegacyStorage(),
      autoInitialize: false,
    );

    await auth.initialize();
    expect(auth.routeState, ParticipantRouteState.welcome);

    await auth.setHasSeenWelcome(true);
    expect(auth.routeState, ParticipantRouteState.signedOut);
    auth.dispose();
  });

  test(
    'account deletion uses a deletion challenge and server continuation',
    () async {
      final identity = _IdentityRepository(
        verifyAccountState: 'active',
        verifyContinuation: _homeContinuation,
      );
      final auth = _authFor(identity);
      await auth.initialize();
      await auth.requestLoginOtp('+12025550123');
      await auth.verifyOtp('1234');

      final challenge = await auth.requestDeletionChallenge();
      await auth.deleteAccount(challenge: challenge, code: '1234');

      expect(identity.deletionVerificationCode, '1234');
      expect(identity.deletionExpectedAccountState, 'active');
      expect(identity.deletionExpectedContinuationVersion, 1);
      expect(identity.deletionRequestCount, 1);
      expect(auth.isAuthenticated, isFalse);
      auth.dispose();
    },
  );
}

const _profileBasicsContinuation = AuthContinuation(
  nextAction: 'profile_required',
  nextStep: AuthProvider.profileBasicsStep,
  version: 1,
);

const _homeContinuation = AuthContinuation(
  nextAction: 'home',
  nextStep: null,
  version: 1,
);

AuthProvider _authFor(
  _IdentityRepository identity, {
  _ProfileGateway? profileGateway,
}) => AuthProvider(
  coordinator: PasswordlessAuthCoordinator(
    repository: identity,
    sessionStore: _MemorySessionStore(),
  ),
  profileGateway: profileGateway ?? _ProfileGateway(),
  legacyStorage: _LegacyStorage(),
  autoInitialize: false,
);

class _LegacyStorage extends SecureStorage {
  int clearCount = 0;

  @override
  Future<void> clearLegacyAuthTokens() async {
    clearCount++;
  }

  @override
  Future<bool> getHasSeenWelcome() async => true;
}

class _ThrowingLegacyStorage extends SecureStorage {
  @override
  Future<void> clearLegacyAuthTokens() => throw StateError('unavailable');

  @override
  Future<bool> getHasSeenWelcome() => throw StateError('unavailable');

  @override
  Future<void> saveHasSeenWelcome(bool value) =>
      throw StateError('unavailable');
}

class _MemorySessionStore implements AuthSessionStore {
  _MemorySessionStore({String? refreshToken})
    : session = refreshToken == null
          ? null
          : RefreshSessionState(refreshToken: refreshToken);

  RefreshSessionState? session;

  @override
  Future<void> clearRefreshSession() async => session = null;

  @override
  Future<String> getOrCreateInstallationId() async =>
      '10000000-0000-4000-8000-000000000001';

  @override
  Future<RefreshSessionState?> readRefreshSession() async => session;

  @override
  Future<void> writeRefreshSession(RefreshSessionState value) async {
    session = value;
  }
}

class _IdentityRepository implements PasswordlessAuthRepository {
  _IdentityRepository({
    this.verifyAccountState = 'onboarding',
    this.verifyContinuation = _profileBasicsContinuation,
    this.refreshError,
    this.verifyError,
  });

  final String verifyAccountState;
  final AuthContinuation verifyContinuation;
  final AuthException? refreshError;
  final AuthException? verifyError;
  String sessionStateAccountState = 'active';
  AuthContinuation sessionStateContinuation = _homeContinuation;
  String? requestedPhone;
  int sessionReadCount = 0;
  int revokeCurrentCount = 0;
  int revokeAllCount = 0;
  int deletionRequestCount = 0;
  String? deletionVerificationCode;
  String? deletionExpectedAccountState;
  int? deletionExpectedContinuationVersion;

  static final _expires = DateTime.now().add(const Duration(hours: 1));
  static const _sessionId = '20000000-0000-4000-8000-000000000002';

  @override
  Future<AuthChallenge> requestOtp({
    required String phoneNumber,
    required String installationId,
    required String idempotencyKey,
  }) async {
    requestedPhone = phoneNumber;
    return AuthChallenge(
      id: 'challenge-1',
      destinationMasked: '+1******0123',
      expiresAt: _expires,
      resendAvailableAt: DateTime.now(),
      internalVerificationCode: '1234',
    );
  }

  @override
  Future<AuthSession> verifyOtp({
    required String challengeId,
    required String code,
    required String installationId,
    required String idempotencyKey,
  }) async {
    final error = verifyError;
    if (error != null) throw error;
    return AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessTokenExpiresAt: _expires,
      refreshTokenExpiresAt: _expires.add(const Duration(days: 1)),
      sessionId: _sessionId,
      accountState: verifyAccountState,
      continuation: verifyContinuation,
    );
  }

  @override
  Future<AuthSessionState> getSessionState({
    required String accessToken,
  }) async {
    sessionReadCount++;
    return AuthSessionState(
      participantId: '30000000-0000-4000-8000-000000000003',
      sessionId: _sessionId,
      expiresAt: _expires,
      accountState: sessionStateAccountState,
      continuation: sessionStateContinuation,
    );
  }

  @override
  Future<void> revokeCurrentSession({
    required String accessToken,
    required String idempotencyKey,
  }) async {
    revokeCurrentCount++;
  }

  @override
  Future<AuthSession> refreshSession({
    required String refreshToken,
    required String installationId,
    required String idempotencyKey,
  }) async {
    if (refreshError != null) throw refreshError!;
    return AuthSession(
      accessToken: 'refreshed-access-token',
      refreshToken: 'refreshed-refresh-token',
      accessTokenExpiresAt: _expires,
      refreshTokenExpiresAt: _expires.add(const Duration(days: 1)),
      sessionId: _sessionId,
      accountState: verifyAccountState,
      continuation: verifyContinuation,
    );
  }

  @override
  Future<AuthChallenge> resendOtp({
    required String challengeId,
    required String installationId,
    required String idempotencyKey,
  }) => requestOtp(
    phoneNumber: requestedPhone!,
    installationId: installationId,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<void> revokeAllSessions({
    required String accessToken,
    required String idempotencyKey,
  }) async {
    revokeAllCount++;
  }

  @override
  Future<AuthChallenge> requestDeletionChallenge({
    required String accessToken,
    required String idempotencyKey,
  }) async => AuthChallenge(
    id: 'deletion-challenge-1',
    destinationMasked: '+1******0123',
    expiresAt: _expires,
    resendAvailableAt: DateTime.now(),
  );

  @override
  Future<ReauthenticationGrant> verifyDeletionChallenge({
    required String accessToken,
    required String challengeId,
    required String code,
    required String idempotencyKey,
  }) async {
    deletionVerificationCode = code;
    return ReauthenticationGrant(token: 'grant-token', expiresAt: _expires);
  }

  @override
  Future<AccountDeletionResult> requestAccountDeletion({
    required String accessToken,
    required String reauthenticationToken,
    required String expectedAccountState,
    required int expectedContinuationVersion,
    required String idempotencyKey,
  }) async {
    deletionRequestCount++;
    deletionExpectedAccountState = expectedAccountState;
    deletionExpectedContinuationVersion = expectedContinuationVersion;
    return AccountDeletionResult(
      status: 'deletion_pending',
      requestedAt: DateTime.now(),
      scheduledFor: DateTime.now().add(const Duration(days: 30)),
      cancellable: false,
    );
  }
}

class _ProfileGateway implements ParticipantProfileGateway {
  _ProfileGateway({
    this.displayName = 'Chinni',
    this.accountState = 'active',
    this.continuationVersion = 1,
    this.nextAction = 'home',
    this.nextStep,
  });

  String? displayName;
  final String accountState;
  final int continuationVersion;
  final String nextAction;
  final String? nextStep;
  bool failOnboarding = false;
  final List<String> updatedNames = [];
  final List<String> updateKeys = [];

  ParticipantProfile get _profile => ParticipantProfile(
    id: '30000000-0000-4000-8000-000000000003',
    displayName: displayName,
    status: 'onboarding',
    registrationSource: 'passwordless_phone',
    createdAt: DateTime.utc(2026, 8, 3),
    updatedAt: DateTime.utc(2026, 8, 3),
  );

  @override
  Future<ParticipantProfileResult> getProfile() async =>
      ParticipantProfileResult(participant: _profile, correlationId: null);

  @override
  Future<ParticipantOnboardingResult> getOnboarding() async {
    if (failOnboarding) {
      throw const ParticipantProfileException(
        'We could not load your account setup. Try again.',
      );
    }
    return ParticipantOnboardingResult(
      participant: _profile,
      workflow: ParticipantOnboardingWorkflow(
        version: 1,
        status: 'in_progress',
        currentStep: AuthProvider.profileBasicsStep,
        startedAt: DateTime.utc(2026, 8, 3),
        completedAt: null,
        completedSteps: [
          ParticipantOnboardingStepCompletion(
            stepKey: 'profile_basics',
            completedAt: DateTime.utc(2026, 8, 3),
          ),
        ],
      ),
      policy: const ParticipantOnboardingPolicy(
        status: 'development_bypass',
        blockers: [],
      ),
      continuation: ParticipantOnboardingContinuation(
        accountState: accountState,
        version: continuationVersion,
        nextAction: nextAction,
        nextStep: nextStep,
      ),
    );
  }

  @override
  Future<ParticipantProfileResult> updateDisplayName(
    String value, {
    required String idempotencyKey,
  }) async {
    displayName = value;
    updatedNames.add(value);
    updateKeys.add(idempotencyKey);
    return ParticipantProfileResult(
      participant: _profile,
      correlationId: '40000000-0000-4000-8000-000000000004',
    );
  }
}
