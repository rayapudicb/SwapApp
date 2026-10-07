import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_models.dart';
import 'auth_repository.dart';
import 'session_store.dart';

class PasswordlessAuthCoordinator extends ChangeNotifier {
  PasswordlessAuthCoordinator({
    required PasswordlessAuthRepository repository,
    required AuthSessionStore sessionStore,
    DateTime Function()? clock,
  })  : _repository = repository,
        _sessionStore = sessionStore,
        _clock = clock ?? DateTime.now;

  final PasswordlessAuthRepository _repository;
  final AuthSessionStore _sessionStore;
  final DateTime Function() _clock;

  AuthCoordinatorPhase _phase = AuthCoordinatorPhase.booting;
  AuthChallenge? _challenge;
  AuthSession? _session;
  AuthException? _error;
  String? _phoneNumber;
  String? _requestOtpKey;
  String? _verifyOtpKey;
  String? _resendOtpKey;
  String? _resendChallengeId;
  String? _installationId;
  String? _refreshOperationKey;
  String? _deletionChallengeKey;
  String? _deletionVerificationKey;
  String? _deletionVerificationChallengeId;
  _PendingDeletionCommand? _pendingDeletionCommand;
  Future<String>? _refreshInFlight;
  Future<void>? _continuationRefreshInFlight;

  // Orders secure-store mutations so a late clear cannot erase a newer write.
  Future<void> _pendingChallengeStorageTail = Future<void>.value();

  // Incremented when a user leaves the phone flow; asynchronous results must
  // match the epoch that started them before changing coordinator state.
  int _authFlowEpoch = 0;

  AuthCoordinatorPhase get phase => _phase;
  AuthChallenge? get challenge => _challenge;
  AuthSession? get session => _session;
  AuthException? get error => _error;
  bool get isAuthenticated => _session != null;

  Future<void> bootstrap() async {
    _setPhase(AuthCoordinatorPhase.booting);
    try {
      _installationId = await _sessionStore.getOrCreateInstallationId();
      final storedSession = await _sessionStore.readRefreshSession();
      if (storedSession == null) {
        _refreshOperationKey = null;
        if (await _restorePendingChallenge()) return;
        _setSignedOut();
        return;
      }
      _refreshOperationKey = storedSession.pendingRefreshIdempotencyKey;
      _setPhase(AuthCoordinatorPhase.refreshing);
      final restored = await _rotateRefreshToken(storedSession.refreshToken);
      await _acceptSession(restored);
      await refreshServerContinuation();
    } on AuthException catch (error) {
      if (error.sessionInvalid) {
        await _clearStoredIdentityState();
        _refreshOperationKey = null;
        _setSignedOut(error: error);
      } else {
        _error = error;
        _setPhase(AuthCoordinatorPhase.recoverableFailure);
      }
    } catch (_) {
      _error = const AuthException(
        code: 'SESSION_RESTORE_FAILED',
        message:
            'Your session could not be restored. Check the connection and retry.',
        outcomeUnknown: true,
      );
      _setPhase(AuthCoordinatorPhase.recoverableFailure);
    }
  }

  Future<void> requestOtp(String phoneNumber) async {
    if (_otpOperationBusy) return;
    final operationEpoch = _authFlowEpoch;
    final normalized = phoneNumber.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(normalized)) {
      _error = const AuthException(
        code: 'PHONE_NUMBER_INVALID',
        message:
            'Enter a phone number in international format, such as +12025550123.',
      );
      _setPhase(AuthCoordinatorPhase.signedOut);
      return;
    }

    final reusePending = _phoneNumber == normalized && _requestOtpKey != null;
    _phoneNumber = normalized;
    _requestOtpKey = reusePending ? _requestOtpKey : newIdentityOperationId();
    _error = null;
    _setPhase(AuthCoordinatorPhase.requestingOtp);
    try {
      try {
        _installationId ??= await _sessionStore.getOrCreateInstallationId();
      } catch (_) {
        if (!_isCurrentAuthFlow(operationEpoch)) return;
        _error = _identityStorageError();
        _setPhase(AuthCoordinatorPhase.signedOut);
        return;
      }
      if (!_isCurrentAuthFlow(operationEpoch)) return;
      final requested = await _repository.requestOtp(
        phoneNumber: normalized,
        installationId: _installationId!,
        idempotencyKey: _requestOtpKey!,
      );
      if (!_isCurrentAuthFlow(operationEpoch)) return;
      _challenge = requested;
      _requestOtpKey = null;
      _verifyOtpKey = null;
      _clearResendOperation();
      try {
        await _storePendingChallenge(requested);
        if (!_isCurrentAuthFlow(operationEpoch)) return;
        _error = null;
      } catch (_) {
        if (!_isCurrentAuthFlow(operationEpoch)) return;
        _error = _challengePersistenceError();
      }
      _setPhase(AuthCoordinatorPhase.awaitingOtp);
    } on AuthException catch (error) {
      if (!_isCurrentAuthFlow(operationEpoch)) return;
      _error = error;
      if (!error.outcomeUnknown) _requestOtpKey = null;
      _setPhase(AuthCoordinatorPhase.signedOut);
    }
  }

  Future<void> verifyOtp(String code) async {
    if (_otpOperationBusy) return;
    final operationEpoch = _authFlowEpoch;
    final challenge = _challenge;
    if (challenge == null) {
      _error = const AuthException(
        code: 'OTP_CHALLENGE_REQUIRED',
        message: 'Request a new verification code.',
      );
      _setPhase(AuthCoordinatorPhase.signedOut);
      return;
    }
    final normalized = code.trim();
    if (!RegExp(r'^(?:[0-9]{4}|[0-9]{6})$').hasMatch(normalized)) {
      _error = const AuthException(
        code: 'OTP_CODE_INVALID',
        message: 'Enter the four- or six-digit verification code.',
      );
      _setPhase(AuthCoordinatorPhase.awaitingOtp);
      return;
    }

    _verifyOtpKey ??= newIdentityOperationId();
    _error = null;
    _setPhase(AuthCoordinatorPhase.verifyingOtp);
    try {
      final authenticated = await _repository.verifyOtp(
        challengeId: challenge.id,
        code: normalized,
        installationId: _installationId!,
        idempotencyKey: _verifyOtpKey!,
      );
      if (!_isCurrentAuthFlow(operationEpoch)) {
        await _discardStaleAuthenticatedSession(authenticated);
        return;
      }
      final accepted = await _acceptSession(
        authenticated,
        expectedAuthFlowEpoch: operationEpoch,
        clearAuthChallenge: true,
      );
      if (!accepted) {
        await _discardStaleAuthenticatedSession(authenticated);
      }
    } on AuthException catch (error) {
      if (!_isCurrentAuthFlow(operationEpoch)) return;
      _error = error;
      if (!error.outcomeUnknown) _verifyOtpKey = null;
      _setPhase(AuthCoordinatorPhase.awaitingOtp);
    }
  }

  Future<void> resendOtp() async {
    if (_otpOperationBusy) return;
    final operationEpoch = _authFlowEpoch;
    final challenge = _challenge;
    if (challenge == null) return;
    if (_clock().isBefore(challenge.resendAvailableAt)) {
      _error = AuthException(
        code: 'OTP_RESEND_COOLDOWN',
        message: 'Wait before requesting another code.',
        retryAt: challenge.resendAvailableAt,
      );
      notifyListeners();
      return;
    }

    _error = null;
    final reusePending =
        _resendChallengeId == challenge.id && _resendOtpKey != null;
    _resendChallengeId = challenge.id;
    _resendOtpKey = reusePending ? _resendOtpKey : newIdentityOperationId();
    _setPhase(AuthCoordinatorPhase.requestingOtp);
    try {
      final resent = await _repository.resendOtp(
        challengeId: challenge.id,
        installationId: _installationId!,
        idempotencyKey: _resendOtpKey!,
      );
      if (!_isCurrentAuthFlow(operationEpoch)) return;
      _challenge = resent;
      _clearResendOperation();
      _verifyOtpKey = null;
      try {
        await _storePendingChallenge(resent);
        if (!_isCurrentAuthFlow(operationEpoch)) return;
        _error = null;
      } catch (_) {
        if (!_isCurrentAuthFlow(operationEpoch)) return;
        _error = _challengePersistenceError();
      }
      _setPhase(AuthCoordinatorPhase.awaitingOtp);
    } on AuthException catch (error) {
      if (!_isCurrentAuthFlow(operationEpoch)) return;
      _error = error;
      if (!error.outcomeUnknown) _clearResendOperation();
      _setPhase(AuthCoordinatorPhase.awaitingOtp);
    }
  }

  Future<String> validAccessToken({bool forceRefresh = false}) async {
    final current = _session;
    if (current == null) {
      throw const AuthException(
        code: 'PARTICIPANT_AUTH_REQUIRED',
        message: 'Sign in to continue.',
        sessionInvalid: true,
      );
    }
    if (!forceRefresh &&
        current.accessTokenExpiresAt.isAfter(
          _clock().add(const Duration(seconds: 30)),
        )) {
      return current.accessToken;
    }
    return _refreshInFlight ??= _refreshAccessToken().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String> _refreshAccessToken() async {
    final current = _session;
    if (current == null) {
      throw const AuthException(
        code: 'PARTICIPANT_AUTH_REQUIRED',
        message: 'Sign in to continue.',
        sessionInvalid: true,
      );
    }
    try {
      final refreshed = await _rotateRefreshToken(current.refreshToken);
      await _acceptSession(refreshed);
      return refreshed.accessToken;
    } on AuthException catch (error) {
      if (error.sessionInvalid) {
        await _clearStoredIdentityState();
        _refreshOperationKey = null;
        _session = null;
        _error = error;
        _setPhase(AuthCoordinatorPhase.signedOut);
      }
      rethrow;
    }
  }

  Future<void> refreshServerContinuation() {
    return _continuationRefreshInFlight ??=
        _refreshServerContinuation().whenComplete(() {
      _continuationRefreshInFlight = null;
    });
  }

  Future<void> _refreshServerContinuation() async {
    final expectedSession = _session;
    if (expectedSession == null) {
      throw const AuthException(
        code: 'PARTICIPANT_AUTH_REQUIRED',
        message: 'Sign in to continue.',
        sessionInvalid: true,
      );
    }

    try {
      var accessToken = await validAccessToken();
      late AuthSessionState state;
      try {
        state = await _repository.getSessionState(accessToken: accessToken);
      } on AuthException catch (error) {
        if (!error.sessionInvalid) rethrow;
        accessToken = await validAccessToken(forceRefresh: true);
        state = await _repository.getSessionState(accessToken: accessToken);
      }

      final current = _session;
      if (current == null || current.sessionId != expectedSession.sessionId) {
        throw const AuthException(
          code: 'PARTICIPANT_AUTH_REQUIRED',
          message: 'Sign in to continue.',
          sessionInvalid: true,
        );
      }
      if (state.sessionId != current.sessionId ||
          !state.expiresAt.isAfter(_clock())) {
        throw const AuthException(
          code: 'AUTH_CONTRACT_INVALID',
          message: 'The identity service returned an invalid session state.',
          sessionInvalid: true,
        );
      }

      _session = AuthSession(
        accessToken: current.accessToken,
        refreshToken: current.refreshToken,
        accessTokenExpiresAt: current.accessTokenExpiresAt,
        refreshTokenExpiresAt: current.refreshTokenExpiresAt,
        sessionId: current.sessionId,
        accountState: state.accountState,
        continuation: state.continuation,
      );
      _error = null;
      _setPhase(AuthCoordinatorPhase.authenticated);
    } on AuthException catch (error) {
      if (error.sessionInvalid && _session != null) {
        await _clearStoredIdentityState();
        _refreshOperationKey = null;
        _session = null;
        _error = error;
        _setPhase(AuthCoordinatorPhase.signedOut);
      }
      rethrow;
    }
  }

  Future<void> logout() => _logout(allSessions: false);

  Future<void> logoutAll() => _logout(allSessions: true);

  /// Clears local credentials after a protected API rejects a refreshed
  /// session. The server response remains authoritative; no revocation request
  /// is attempted because the session has already been rejected.
  Future<void> invalidateSession(AuthException error) async {
    _authFlowEpoch++;
    final storageFailure = await _clearStoredIdentityState();
    _refreshOperationKey = null;
    _requestOtpKey = null;
    _verifyOtpKey = null;
    _clearResendOperation();
    _deletionChallengeKey = null;
    _clearDeletionVerificationOperation();
    _pendingDeletionCommand = null;
    _session = null;
    _challenge = null;
    _setSignedOut(error: storageFailure ?? error);
  }

  Future<void> _logout({required bool allSessions}) async {
    _authFlowEpoch++;
    final current = _session;
    AuthException? revocationFailure;
    try {
      if (current != null) {
        final operationKey = newIdentityOperationId();
        var accessToken = await validAccessToken();
        try {
          await _revokeSession(
            allSessions: allSessions,
            accessToken: accessToken,
            idempotencyKey: operationKey,
          );
        } on AuthException catch (error) {
          if (!error.sessionInvalid) rethrow;
          accessToken = await validAccessToken(forceRefresh: true);
          await _revokeSession(
            allSessions: allSessions,
            accessToken: accessToken,
            idempotencyKey: operationKey,
          );
        }
      }
    } on AuthException catch (error) {
      revocationFailure = AuthException(
        code: error.code,
        message: allSessions
            ? 'This device is signed out, but the server could not confirm '
                'revocation on other devices. Sign in again and retry.'
            : 'This device is signed out, but the server could not confirm '
                'session revocation. Sign in again to retry.',
        outcomeUnknown: true,
      );
    } catch (_) {
      revocationFailure = AuthException(
        code: 'SESSION_REVOCATION_UNCONFIRMED',
        message: allSessions
            ? 'This device is signed out, but the server could not confirm '
                'revocation on other devices. Sign in again and retry.'
            : 'This device is signed out, but the server could not confirm '
                'session revocation. Sign in again to retry.',
        outcomeUnknown: true,
      );
    } finally {
      final storageFailure = await _clearStoredIdentityState();
      _refreshOperationKey = null;
      _requestOtpKey = null;
      _verifyOtpKey = null;
      _clearResendOperation();
      _deletionChallengeKey = null;
      _clearDeletionVerificationOperation();
      _pendingDeletionCommand = null;
      _session = null;
      _challenge = null;
      _setSignedOut(error: revocationFailure ?? storageFailure);
    }
  }

  Future<AuthChallenge> requestDeletionChallenge() async {
    _pendingDeletionCommand = null;
    _clearDeletionVerificationOperation();
    final accessToken = await validAccessToken();
    _deletionChallengeKey ??= newIdentityOperationId();
    try {
      late AuthChallenge challenge;
      try {
        challenge = await _repository.requestDeletionChallenge(
          accessToken: accessToken,
          idempotencyKey: _deletionChallengeKey!,
        );
      } on AuthException catch (error) {
        if (!error.sessionInvalid) rethrow;
        challenge = await _repository.requestDeletionChallenge(
          accessToken: await validAccessToken(forceRefresh: true),
          idempotencyKey: _deletionChallengeKey!,
        );
      }
      _deletionChallengeKey = null;
      return challenge;
    } on AuthException catch (error) {
      if (!error.outcomeUnknown) _deletionChallengeKey = null;
      rethrow;
    }
  }

  Future<void> deleteAccount({
    required AuthChallenge challenge,
    required String code,
  }) async {
    final normalizedCode = code.trim();
    if (!RegExp(r'^(?:[0-9]{4}|[0-9]{6})$').hasMatch(normalizedCode)) {
      throw const AuthException(
        code: 'OTP_CODE_INVALID',
        message: 'Enter the four- or six-digit verification code.',
      );
    }
    _error = null;
    _setPhase(AuthCoordinatorPhase.deletingAccount);
    try {
      var command = _pendingDeletionCommand;
      if (command == null || command.challengeId != challenge.id) {
        var accessToken = await validAccessToken();
        final reusePending = _deletionVerificationChallengeId == challenge.id &&
            _deletionVerificationKey != null;
        _deletionVerificationChallengeId = challenge.id;
        _deletionVerificationKey =
            reusePending ? _deletionVerificationKey : newIdentityOperationId();
        late final ReauthenticationGrant grant;
        try {
          try {
            grant = await _repository.verifyDeletionChallenge(
              accessToken: accessToken,
              challengeId: challenge.id,
              code: normalizedCode,
              idempotencyKey: _deletionVerificationKey!,
            );
          } on AuthException catch (error) {
            if (!error.sessionInvalid) rethrow;
            accessToken = await validAccessToken(forceRefresh: true);
            grant = await _repository.verifyDeletionChallenge(
              accessToken: accessToken,
              challengeId: challenge.id,
              code: normalizedCode,
              idempotencyKey: _deletionVerificationKey!,
            );
          }
        } on AuthException catch (error) {
          if (!error.outcomeUnknown) _clearDeletionVerificationOperation();
          rethrow;
        }
        accessToken = await validAccessToken(forceRefresh: true);
        final expectedSession = _session;
        if (expectedSession == null) {
          throw const AuthException(
            code: 'PARTICIPANT_AUTH_REQUIRED',
            message: 'Sign in to continue.',
            sessionInvalid: true,
          );
        }
        command = _PendingDeletionCommand(
          challengeId: challenge.id,
          accessToken: accessToken,
          grantToken: grant.token,
          expectedAccountState: expectedSession.accountState,
          expectedContinuationVersion: expectedSession.continuation.version,
          idempotencyKey: newIdentityOperationId(),
        );
        _pendingDeletionCommand = command;
        _clearDeletionVerificationOperation();
      }
      try {
        await _requestAccountDeletion(command, command.accessToken);
      } on AuthException catch (error) {
        if (!error.sessionInvalid) rethrow;
        await _requestAccountDeletion(
          command,
          await validAccessToken(forceRefresh: true),
        );
      }
      final storageFailure = await _clearStoredIdentityState();
      _refreshOperationKey = null;
      _deletionChallengeKey = null;
      _clearDeletionVerificationOperation();
      _pendingDeletionCommand = null;
      _session = null;
      _challenge = null;
      _setSignedOut(error: storageFailure);
    } on AuthException catch (error) {
      _error = error;
      _setPhase(
        _session == null
            ? AuthCoordinatorPhase.signedOut
            : AuthCoordinatorPhase.authenticated,
      );
      rethrow;
    }
  }

  void cancelChallenge() {
    _authFlowEpoch++;
    _challenge = null;
    _phoneNumber = null;
    _requestOtpKey = null;
    _verifyOtpKey = null;
    _clearResendOperation();
    _error = null;
    unawaited(
      _clearPendingChallenge().catchError((Object _) {
        _error = _challengePersistenceError();
        notifyListeners();
      }),
    );
    _setPhase(AuthCoordinatorPhase.signedOut);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _acceptSession(
    AuthSession accepted, {
    int? expectedAuthFlowEpoch,
    bool clearAuthChallenge = false,
  }) async {
    AuthException? persistenceWarning;
    try {
      await _sessionStore.writeRefreshSession(
        RefreshSessionState(refreshToken: accepted.refreshToken),
      );
    } catch (_) {
      persistenceWarning = _sessionPersistenceError();
      try {
        await _sessionStore.clearRefreshSession();
      } catch (_) {
        // Server-side session controls remain authoritative.
      }
    }
    if (!_isExpectedAuthFlow(expectedAuthFlowEpoch)) {
      await _clearStaleAcceptedSession(accepted);
      return false;
    }
    try {
      await _clearPendingChallenge();
    } catch (_) {
      persistenceWarning ??= _sessionPersistenceError();
    }
    if (!_isExpectedAuthFlow(expectedAuthFlowEpoch)) {
      await _clearStaleAcceptedSession(accepted);
      return false;
    }
    if (clearAuthChallenge) {
      _verifyOtpKey = null;
      _challenge = null;
      _phoneNumber = null;
      _clearResendOperation();
    }
    _refreshOperationKey = null;
    _session = accepted;
    _error = persistenceWarning;
    _setPhase(AuthCoordinatorPhase.authenticated);
    return true;
  }

  void _setSignedOut({AuthException? error}) {
    _session = null;
    _challenge = null;
    _error = error;
    _setPhase(AuthCoordinatorPhase.signedOut);
  }

  void _setPhase(AuthCoordinatorPhase value) {
    _phase = value;
    notifyListeners();
  }

  bool get _otpOperationBusy =>
      _phase == AuthCoordinatorPhase.requestingOtp ||
      _phase == AuthCoordinatorPhase.verifyingOtp;

  bool _isCurrentAuthFlow(int expectedEpoch) => expectedEpoch == _authFlowEpoch;

  bool _isExpectedAuthFlow(int? expectedEpoch) =>
      expectedEpoch == null || _isCurrentAuthFlow(expectedEpoch);

  Future<void> _clearStaleAcceptedSession(AuthSession staleSession) async {
    try {
      final stored = await _sessionStore.readRefreshSession();
      if (stored?.refreshToken == staleSession.refreshToken) {
        await _sessionStore.clearRefreshSession();
      }
    } catch (_) {
      // Server revocation below remains the authority if local cleanup fails.
    }
    try {
      await _clearPendingChallenge();
    } catch (_) {
      // The pending challenge remains non-authoritative and expires server-side.
    }
    _refreshOperationKey = null;
    if (_session?.sessionId == staleSession.sessionId) _session = null;
  }

  Future<void> _discardStaleAuthenticatedSession(
    AuthSession authenticated,
  ) async {
    try {
      await _repository.revokeCurrentSession(
        accessToken: authenticated.accessToken,
        idempotencyKey: newIdentityOperationId(),
      );
    } catch (_) {
      // Credentials from a cancelled flow are never exposed by the coordinator.
    }
  }

  Future<void> _revokeSession({
    required bool allSessions,
    required String accessToken,
    required String idempotencyKey,
  }) =>
      allSessions
          ? _repository.revokeAllSessions(
              accessToken: accessToken,
              idempotencyKey: idempotencyKey,
            )
          : _repository.revokeCurrentSession(
              accessToken: accessToken,
              idempotencyKey: idempotencyKey,
            );

  Future<void> _requestAccountDeletion(
    _PendingDeletionCommand command,
    String accessToken,
  ) =>
      _repository.requestAccountDeletion(
        accessToken: accessToken,
        reauthenticationToken: command.grantToken,
        expectedAccountState: command.expectedAccountState,
        expectedContinuationVersion: command.expectedContinuationVersion,
        idempotencyKey: command.idempotencyKey,
      );

  void _clearResendOperation() {
    _resendOtpKey = null;
    _resendChallengeId = null;
  }

  void _clearDeletionVerificationOperation() {
    _deletionVerificationKey = null;
    _deletionVerificationChallengeId = null;
  }

  PendingAuthChallengeStore? get _pendingChallengeStore =>
      _sessionStore is PendingAuthChallengeStore
          ? _sessionStore as PendingAuthChallengeStore
          : null;

  Future<bool> _restorePendingChallenge() async {
    final store = _pendingChallengeStore;
    if (store == null) return false;
    await _pendingChallengeStorageTail;
    final pending = await store.readPendingAuthChallenge();
    if (pending == null) return false;
    if (!pending.expiresAt.isAfter(_clock())) {
      await store.clearPendingAuthChallenge();
      return false;
    }
    _challenge = AuthChallenge(
      id: pending.challengeId,
      destinationMasked: pending.destinationMasked,
      expiresAt: pending.expiresAt,
      resendAvailableAt: pending.resendAvailableAt,
    );
    _phoneNumber = null;
    _requestOtpKey = null;
    _verifyOtpKey = null;
    _clearResendOperation();
    _error = null;
    _setPhase(AuthCoordinatorPhase.awaitingOtp);
    return true;
  }

  Future<void> _storePendingChallenge(AuthChallenge challenge) async {
    await _runPendingChallengeStorageOperation(
      (store) => store.writePendingAuthChallenge(
        PendingAuthChallengeState(
          challengeId: challenge.id,
          destinationMasked: challenge.destinationMasked,
          expiresAt: challenge.expiresAt,
          resendAvailableAt: challenge.resendAvailableAt,
        ),
      ),
    );
  }

  Future<void> _clearPendingChallenge() => _runPendingChallengeStorageOperation(
        (store) => store.clearPendingAuthChallenge(),
      );

  Future<AuthException?> _clearStoredIdentityState() async {
    var failed = false;
    try {
      await _sessionStore.clearRefreshSession();
    } catch (_) {
      failed = true;
    }
    try {
      await _clearPendingChallenge();
    } catch (_) {
      failed = true;
    }
    return failed ? _identityStorageError() : null;
  }

  Future<void> _runPendingChallengeStorageOperation(
    Future<void> Function(PendingAuthChallengeStore store) operation,
  ) {
    final store = _pendingChallengeStore;
    if (store == null) return Future<void>.value();
    final scheduled = _pendingChallengeStorageTail.then(
      (_) => operation(store),
    );
    _pendingChallengeStorageTail = scheduled.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return scheduled;
  }

  Future<AuthSession> _rotateRefreshToken(String refreshToken) async {
    final operationKey = _refreshOperationKey ?? newIdentityOperationId();
    _refreshOperationKey = operationKey;
    try {
      await _sessionStore.writeRefreshSession(
        RefreshSessionState(
          refreshToken: refreshToken,
          pendingRefreshIdempotencyKey: operationKey,
        ),
      );
    } catch (_) {
      throw _identityStorageError();
    }
    return _repository.refreshSession(
      refreshToken: refreshToken,
      installationId: _installationId!,
      idempotencyKey: operationKey,
    );
  }
}

AuthException _challengePersistenceError() => const AuthException(
      code: 'AUTH_STATE_PERSISTENCE_FAILED',
      message:
          'The code was received, but this step cannot be restored after closing '
          'the app. Keep this screen open or request a new code.',
    );

AuthException _identityStorageError() => const AuthException(
      code: 'AUTH_STATE_PERSISTENCE_FAILED',
      message:
          'Secure identity storage is unavailable. Check the device settings and '
          'try again.',
    );

AuthException _sessionPersistenceError() => const AuthException(
      code: 'AUTH_STATE_PERSISTENCE_FAILED',
      message:
          'You are signed in for this app session, but the secure session could '
          'not be saved. Sign in again after closing the app.',
    );

class _PendingDeletionCommand {
  const _PendingDeletionCommand({
    required this.challengeId,
    required this.accessToken,
    required this.grantToken,
    required this.expectedAccountState,
    required this.expectedContinuationVersion,
    required this.idempotencyKey,
  });

  final String challengeId;
  final String accessToken;
  final String grantToken;
  final String expectedAccountState;
  final int expectedContinuationVersion;
  final String idempotencyKey;
}
