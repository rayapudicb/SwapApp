import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:passwordless_identity/passwordless_identity.dart';

import '../../../core/storage/secure_storage.dart';
import '../../profile/data/participant_profile_client.dart';

enum ParticipantRouteState {
  booting,
  welcome,
  signedOut,
  recoverable,
  awaitingOtp,
  profileBasics,
  home,
  restricted,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required PasswordlessAuthCoordinator coordinator,
    required ParticipantProfileGateway profileGateway,
    required SecureStorage legacyStorage,
    bool autoInitialize = true,
  }) : _coordinator = coordinator,
       _profileGateway = profileGateway,
       _legacyStorage = legacyStorage {
    _coordinator.addListener(_onCoordinatorChanged);
    if (autoInitialize) unawaited(initialize());
  }

  static const supportedContinuationVersion = 1;
  static const profileBasicsStep = 'profile_basics_required';

  final PasswordlessAuthCoordinator _coordinator;
  final ParticipantProfileGateway _profileGateway;
  final SecureStorage _legacyStorage;

  bool _initializing = true;
  bool _profileBusy = false;
  bool _profileCommitConfirmed = false;
  bool _hasSeenWelcome = false;
  String? _profileError;
  String? _pendingDisplayName;
  String? _profileIdempotencyKey;
  ParticipantProfile? _profile;
  ParticipantOnboardingResult? _onboarding;

  PasswordlessAuthCoordinator get coordinator => _coordinator;
  AuthChallenge? get challenge => _coordinator.challenge;
  ParticipantProfile? get profile => _profile ?? _onboarding?.participant;
  ParticipantOnboardingResult? get onboarding => _onboarding;
  String? get pendingDisplayName => _pendingDisplayName;
  bool get isAuthenticated => _coordinator.isAuthenticated;
  String? get authenticatedSessionId => _coordinator.session?.sessionId;
  bool get isProfileBusy => _profileBusy;
  bool get hasSeenWelcome => _hasSeenWelcome;
  bool get isDeletingAccount =>
      _coordinator.phase == AuthCoordinatorPhase.deletingAccount;

  bool get isAuthOperationBusy =>
      _initializing ||
      _coordinator.phase == AuthCoordinatorPhase.requestingOtp ||
      _coordinator.phase == AuthCoordinatorPhase.verifyingOtp ||
      _coordinator.phase == AuthCoordinatorPhase.refreshing;

  bool get isLoading => isAuthOperationBusy || _profileBusy;

  String? get errorMessage {
    if (_profileError != null) return _profileError;
    final error = _coordinator.error;
    if (error == null) return null;
    if (error.sessionInvalid || error.code == 'SESSION_NOT_AVAILABLE') {
      return 'Your session expired. Sign in again to continue.';
    }
    return _authErrorMessage(error);
  }

  ParticipantRouteState get routeState {
    if (_initializing ||
        _coordinator.phase == AuthCoordinatorPhase.booting ||
        _coordinator.phase == AuthCoordinatorPhase.refreshing) {
      return ParticipantRouteState.booting;
    }

    if (_coordinator.phase == AuthCoordinatorPhase.recoverableFailure) {
      return ParticipantRouteState.recoverable;
    }

    if (!_coordinator.isAuthenticated) {
      if (_coordinator.challenge != null &&
          (_coordinator.phase == AuthCoordinatorPhase.awaitingOtp ||
              _coordinator.phase == AuthCoordinatorPhase.requestingOtp ||
              _coordinator.phase == AuthCoordinatorPhase.verifyingOtp)) {
        return ParticipantRouteState.awaitingOtp;
      }
      return _hasSeenWelcome
          ? ParticipantRouteState.signedOut
          : ParticipantRouteState.welcome;
    }

    final session = _coordinator.session!;
    final onboardingContinuation = _onboarding?.continuation;
    if (onboardingContinuation != null &&
        (onboardingContinuation.accountState != session.accountState ||
            onboardingContinuation.version != session.continuation.version ||
            onboardingContinuation.nextAction !=
                session.continuation.nextAction ||
            onboardingContinuation.nextStep != session.continuation.nextStep)) {
      return ParticipantRouteState.restricted;
    }
    final accountState = session.accountState;
    final continuationVersion = session.continuation.version;
    final nextAction = session.continuation.nextAction;
    final nextStep = session.continuation.nextStep;
    if (continuationVersion != supportedContinuationVersion) {
      return ParticipantRouteState.restricted;
    }

    if (accountState == 'onboarding' &&
        (nextAction == 'profile_required' ||
            nextAction == 'profile_in_progress') &&
        nextStep == profileBasicsStep) {
      return ParticipantRouteState.profileBasics;
    }

    if (accountState == 'active' && nextAction == 'home' && nextStep == null) {
      return ParticipantRouteState.home;
    }

    return ParticipantRouteState.restricted;
  }

  Future<void> initialize() async {
    _initializing = true;
    notifyListeners();
    try {
      // Legacy preferences must never prevent secure identity bootstrap.
      try {
        await _legacyStorage.clearLegacyAuthTokens();
      } catch (_) {}
      try {
        _hasSeenWelcome = await _legacyStorage.getHasSeenWelcome();
      } catch (_) {
        _hasSeenWelcome = false;
      }
      await _coordinator.bootstrap();
      if (!_coordinator.isAuthenticated &&
          _coordinator.phase == AuthCoordinatorPhase.signedOut &&
          (_coordinator.error?.sessionInvalid ?? false)) {
        // An invalid saved refresh token has already been removed by the
        // coordinator. Start the signed-out journey cleanly instead of
        // carrying a stale-session error onto login and signup.
        _coordinator.clearError();
      }
      if (_coordinator.isAuthenticated) await _loadOnboarding();
    } catch (_) {
      // The coordinator and profile client expose privacy-safe user messages.
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> setHasSeenWelcome(bool value) async {
    _hasSeenWelcome = value;
    notifyListeners();
    try {
      await _legacyStorage.saveHasSeenWelcome(value);
    } catch (_) {
      // This preference is best-effort and must not block authentication.
    }
  }

  Future<bool> requestLoginOtp(String phone) =>
      _requestOtp(phone: phone, displayName: null);

  Future<bool> requestSignupOtp({
    required String displayName,
    required String phone,
  }) => _requestOtp(phone: phone, displayName: displayName.trim());

  Future<bool> _requestOtp({
    required String phone,
    required String? displayName,
  }) async {
    clearError();
    _pendingDisplayName = displayName;
    _profileIdempotencyKey = displayName == null
        ? null
        : newProfileIdempotencyKey();
    _profileCommitConfirmed = false;
    await _coordinator.requestOtp(phone);
    return _coordinator.challenge != null &&
        _coordinator.phase == AuthCoordinatorPhase.awaitingOtp;
  }

  Future<bool> verifyOtp(String code) async {
    clearError();
    await _coordinator.verifyOtp(code);
    if (!_coordinator.isAuthenticated) return false;

    if (_pendingDisplayName != null) {
      final requestedProfileSetup =
          routeState == ParticipantRouteState.profileBasics;
      try {
        await _loadOnboarding(notify: false, throwOnError: true);
      } on ParticipantProfileException {
        notifyListeners();
        return false;
      }
      final existingName = profile?.displayName?.trim();
      final needsProfileName =
          requestedProfileSetup &&
          (existingName == null || existingName.isEmpty);
      if (needsProfileName) return _completePendingProfile();
      _clearPendingProfile();
      notifyListeners();
      return true;
    }

    await _loadOnboarding();
    return true;
  }

  Future<void> resendOtp() async {
    clearError();
    await _coordinator.resendOtp();
  }

  void cancelOtp() {
    _coordinator.cancelChallenge();
    _clearPendingProfile();
    notifyListeners();
  }

  Future<bool> completeProfile(String displayName) async {
    final normalized = displayName.trim();
    if (normalized.isEmpty || normalized.length > 120) {
      _profileError = 'Enter a name between 1 and 120 characters.';
      notifyListeners();
      return false;
    }

    if (_pendingDisplayName != normalized || _profileIdempotencyKey == null) {
      _pendingDisplayName = normalized;
      _profileIdempotencyKey = newProfileIdempotencyKey();
      _profileCommitConfirmed = false;
    }
    clearError();
    return _completePendingProfile();
  }

  Future<bool> _completePendingProfile() async {
    final displayName = _pendingDisplayName;
    final operationKey = _profileIdempotencyKey;
    if (displayName == null || operationKey == null) return false;

    _profileBusy = true;
    notifyListeners();
    try {
      if (!_profileCommitConfirmed) {
        final result = await _profileGateway.updateDisplayName(
          displayName,
          idempotencyKey: operationKey,
        );
        _profile = result.participant;
        _profileCommitConfirmed = true;
      }

      try {
        await _coordinator.refreshServerContinuation();
        await _loadOnboarding(notify: false, throwOnError: true);
      } on AuthException catch (error) {
        _profileError =
            'Your profile was saved, but the next account step could not be '
            'loaded. ${_authErrorMessage(error)}';
        return false;
      } on ParticipantProfileException catch (error) {
        _profileError =
            'Your profile was saved, but account status could not be loaded. '
            '${error.message}';
        return false;
      }

      _clearPendingProfile();
      _profileError = null;
      return true;
    } on ParticipantProfileException catch (error) {
      _profileError = error.message;
      if (!error.outcomeUnknown) {
        _profileIdempotencyKey = newProfileIdempotencyKey();
      }
      return false;
    } finally {
      _profileBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (!_coordinator.isAuthenticated || _profileBusy) return;
    final expectedSessionId = _coordinator.session?.sessionId;
    _profileBusy = true;
    _profileError = null;
    notifyListeners();
    try {
      final result = await _profileGateway.getProfile();
      if (_coordinator.isAuthenticated &&
          _coordinator.session?.sessionId == expectedSessionId) {
        _profile = result.participant;
      }
    } on ParticipantProfileException catch (error) {
      _profileError = error.message;
    } finally {
      _profileBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshAccountStatus() async {
    if (!_coordinator.isAuthenticated || _profileBusy) return;
    _profileBusy = true;
    _profileError = null;
    notifyListeners();
    try {
      await _coordinator.refreshServerContinuation();
      await _loadOnboarding(notify: false);
    } on AuthException catch (error) {
      _profileError = _authErrorMessage(error);
    } on ParticipantProfileException catch (error) {
      _profileError = error.message;
    } finally {
      _profileBusy = false;
      notifyListeners();
    }
  }

  Future<void> _loadOnboarding({
    bool notify = true,
    bool throwOnError = false,
  }) async {
    try {
      _onboarding = await _profileGateway.getOnboarding();
      _profile = _onboarding!.participant;
      _profileError = null;
    } on ParticipantProfileException catch (error) {
      // Never retain an older authorization projection after a failed refresh.
      // Routing falls back to the latest server session continuation.
      _onboarding = null;
      _profileError = error.message;
      if (throwOnError) rethrow;
    }
    if (notify) notifyListeners();
  }

  Future<String> accessToken({bool forceRefresh = false}) =>
      _coordinator.validAccessToken(forceRefresh: forceRefresh);

  Future<void> logout() async {
    await _logout(allSessions: false);
  }

  Future<void> logoutAll() async {
    await _logout(allSessions: true);
  }

  Future<void> _logout({required bool allSessions}) async {
    _profileBusy = true;
    notifyListeners();
    try {
      if (allSessions) {
        await _coordinator.logoutAll();
      } else {
        await _coordinator.logout();
      }
    } finally {
      _profile = null;
      _onboarding = null;
      final error = _coordinator.error;
      _profileError = error == null ? null : _authErrorMessage(error);
      _clearPendingProfile();
      _profileBusy = false;
      notifyListeners();
    }
  }

  Future<AuthChallenge> requestDeletionChallenge() async {
    _profileBusy = true;
    _profileError = null;
    _coordinator.clearError();
    notifyListeners();
    try {
      return await _coordinator.requestDeletionChallenge();
    } on AuthException catch (error) {
      _profileError = _authErrorMessage(error);
      rethrow;
    } finally {
      _profileBusy = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount({
    required AuthChallenge challenge,
    required String code,
  }) async {
    _profileBusy = true;
    _profileError = null;
    _coordinator.clearError();
    notifyListeners();
    try {
      await _coordinator.deleteAccount(challenge: challenge, code: code);
      _profile = null;
      _onboarding = null;
      _clearPendingProfile();
    } on AuthException catch (error) {
      _profileError = _authErrorMessage(error);
      rethrow;
    } finally {
      _profileBusy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _profileError = null;
    _coordinator.clearError();
    notifyListeners();
  }

  void _clearPendingProfile() {
    _pendingDisplayName = null;
    _profileIdempotencyKey = null;
    _profileCommitConfirmed = false;
  }

  void _onCoordinatorChanged() {
    final session = _coordinator.session;
    final onboardingContinuation = _onboarding?.continuation;
    if (session != null &&
        onboardingContinuation != null &&
        (onboardingContinuation.accountState != session.accountState ||
            onboardingContinuation.version != session.continuation.version ||
            onboardingContinuation.nextAction !=
                session.continuation.nextAction ||
            onboardingContinuation.nextStep != session.continuation.nextStep)) {
      _onboarding = null;
    }
    if (!_coordinator.isAuthenticated &&
        _coordinator.phase == AuthCoordinatorPhase.signedOut) {
      _profile = null;
      _onboarding = null;
      _clearPendingProfile();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _coordinator.removeListener(_onCoordinatorChanged);
    super.dispose();
  }
}

String _authErrorMessage(AuthException error) {
  final attempts = error.attemptsRemaining;
  return switch (error.code) {
    'PHONE_NUMBER_INVALID' =>
      'Enter a valid phone number including the country code.',
    'OTP_CHALLENGE_REQUIRED' ||
    'OTP_CHALLENGE_EXPIRED' ||
    'OTP_EXPIRED' => 'This verification code has expired. Request a new code.',
    'OTP_CODE_INVALID' || 'OTP_INVALID' =>
      attempts == null
          ? 'That verification code is not correct. Try again.'
          : 'That verification code is not correct. $attempts attempt${attempts == 1 ? '' : 's'} remaining.',
    'INVALID_OTP_CODE' => 'Enter the complete verification code and try again.',
    'OTP_ATTEMPTS_EXHAUSTED' ||
    'OTP_TOO_MANY_ATTEMPTS' ||
    'OTP_CHALLENGE_LOCKED' =>
      'Too many incorrect attempts. Request a new code.',
    'OTP_CHALLENGE_NOT_AVAILABLE' =>
      'This verification request is no longer available. Request a new code.',
    'OTP_RESEND_COOLDOWN' || 'OTP_RESEND_NOT_READY' =>
      'Please wait before requesting another verification code.',
    'TOO_MANY_REQUESTS' || 'RATE_LIMITED' || 'OTP_RATE_LIMITED' =>
      'Too many attempts. Please wait a moment and try again.',
    'AUTH_TIMEOUT' => 'The request timed out. Check your connection and retry.',
    'AUTH_UNREACHABLE' =>
      'Swappy could not connect. Check your connection and try again.',
    'AUTH_REQUEST_FAILED' ||
    'AUTH_REQUEST_REJECTED' ||
    'AUTH_RESPONSE_UNREADABLE' ||
    'AUTH_CONTRACT_INVALID' ||
    'INTERNAL_SERVER_ERROR' ||
    'SERVICE_UNAVAILABLE' =>
      'Verification is temporarily unavailable. Try again in a moment.',
    'AUTH_STATE_PERSISTENCE_FAILED' =>
      'Swappy could not securely save your sign-in. Try again.',
    _ => 'We could not complete that request. Try again.',
  };
}
