import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

typedef ParticipantProfileTransport =
    Future<ParticipantProfileTransportResponse> Function(
      String method,
      Uri uri,
      Map<String, String> headers,
      Object? body,
    );

typedef ParticipantAccessTokenProvider =
    Future<String> Function({bool forceRefresh});
typedef ParticipantSessionRejectedHandler = Future<void> Function();
typedef ParticipantSessionIdentityProvider = String? Function();

class _ParticipantSessionScope {
  const _ParticipantSessionScope(this.sessionId);

  final String? sessionId;
}

abstract interface class ParticipantProfileGateway {
  Future<ParticipantProfileResult> getProfile();

  Future<ParticipantOnboardingResult> getOnboarding();

  Future<ParticipantProfileResult> updateDisplayName(
    String displayName, {
    required String idempotencyKey,
  });
}

class ParticipantProfileTransportResponse {
  const ParticipantProfileTransportResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

class ParticipantProfile {
  const ParticipantProfile({
    required this.id,
    required this.displayName,
    required this.status,
    required this.registrationSource,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? displayName;
  final String status;
  final String? registrationSource;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class ParticipantProfileResult {
  const ParticipantProfileResult({
    required this.participant,
    required this.correlationId,
  });

  final ParticipantProfile participant;
  final String? correlationId;
}

class ParticipantOnboardingStepCompletion {
  const ParticipantOnboardingStepCompletion({
    required this.stepKey,
    required this.completedAt,
  });

  final String stepKey;
  final DateTime completedAt;
}

class ParticipantOnboardingWorkflow {
  const ParticipantOnboardingWorkflow({
    required this.version,
    required this.status,
    required this.currentStep,
    required this.startedAt,
    required this.completedAt,
    required this.completedSteps,
  });

  final int version;
  final String status;
  final String currentStep;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<ParticipantOnboardingStepCompletion> completedSteps;
}

class ParticipantOnboardingPolicy {
  const ParticipantOnboardingPolicy({
    required this.status,
    required this.blockers,
  });

  final String status;
  final List<String> blockers;
}

class ParticipantOnboardingContinuation {
  const ParticipantOnboardingContinuation({
    required this.accountState,
    required this.version,
    required this.nextAction,
    required this.nextStep,
  });

  final String accountState;
  final int version;
  final String nextAction;
  final String? nextStep;
}

class ParticipantOnboardingResult {
  const ParticipantOnboardingResult({
    required this.participant,
    required this.workflow,
    required this.policy,
    required this.continuation,
  });

  final ParticipantProfile participant;
  final ParticipantOnboardingWorkflow? workflow;
  final ParticipantOnboardingPolicy policy;
  final ParticipantOnboardingContinuation continuation;
}

class ParticipantProfileClient implements ParticipantProfileGateway {
  ParticipantProfileClient({
    required this.baseUri,
    required this.accessTokenProvider,
    ParticipantSessionRejectedHandler? onSessionRejected,
    ParticipantSessionIdentityProvider? sessionIdentityProvider,
    ParticipantProfileTransport? transport,
  }) : _onSessionRejected = onSessionRejected,
       _sessionIdentityProvider = sessionIdentityProvider,
       _transport = transport ?? _ioTransport;

  final Uri baseUri;
  final ParticipantAccessTokenProvider accessTokenProvider;
  final ParticipantSessionRejectedHandler? _onSessionRejected;
  final ParticipantSessionIdentityProvider? _sessionIdentityProvider;
  final ParticipantProfileTransport _transport;

  @override
  Future<ParticipantProfileResult> getProfile() => _request('GET');

  @override
  Future<ParticipantOnboardingResult> getOnboarding() async {
    final sessionScope = _captureSessionScope();
    ParticipantProfileTransportResponse response;
    try {
      response = await _send(
        'GET',
        path: '/v1/me/onboarding',
        sessionScope: sessionScope,
      );
      if (response.statusCode == HttpStatus.unauthorized) {
        response = await _send(
          'GET',
          path: '/v1/me/onboarding',
          forceRefresh: true,
          sessionScope: sessionScope,
        );
      }
      _requireSessionScope(sessionScope);
      await _rejectInvalidSessionIfNeeded(response);
    } on IOException {
      throw const ParticipantProfileException(
        'Swappy could not connect. Your saved setup is unchanged.',
      );
    } on TimeoutException {
      throw const ParticipantProfileException(
        'The onboarding request timed out. Your saved state is unchanged.',
      );
    } on ParticipantProfileException {
      rethrow;
    } catch (_) {
      throw const ParticipantProfileException(
        'The onboarding request failed unexpectedly.',
      );
    }

    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw const ParticipantProfileException(
        'Swappy returned an unexpected response. Try again.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ParticipantProfileException(
        _participantRequestError(response.statusCode, loadingOnboarding: true),
      );
    }
    if (decoded is! Map) {
      throw const ParticipantProfileException(
        'Swappy returned an unexpected response. Try again.',
      );
    }
    _requireExactKeys(decoded, const {
      'sourceState',
      'participant',
      'workflow',
      'policy',
      'continuation',
    }, 'onboarding response');
    if (decoded['sourceState'] != 'durable' ||
        decoded['participant'] is! Map ||
        decoded['policy'] is! Map ||
        decoded['continuation'] is! Map) {
      throw const ParticipantProfileException(
        'Swappy returned an unexpected response. Try again.',
      );
    }

    return ParticipantOnboardingResult(
      participant: _participantFromMap(decoded['participant'] as Map),
      workflow: _onboardingWorkflow(decoded['workflow']),
      policy: _onboardingPolicy(decoded['policy'] as Map),
      continuation: _onboardingContinuation(decoded['continuation'] as Map),
    );
  }

  @override
  Future<ParticipantProfileResult> updateDisplayName(
    String displayName, {
    required String idempotencyKey,
  }) {
    final key = idempotencyKey.trim();
    if (key.isEmpty || key.length > 128) {
      throw const ParticipantProfileException(
        'A valid idempotency key is required for profile updates.',
      );
    }
    return _request(
      'PATCH',
      body: {'displayName': displayName},
      idempotencyKey: key,
    );
  }

  Future<ParticipantProfileResult> _request(
    String method, {
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    final sessionScope = _captureSessionScope();
    ParticipantProfileTransportResponse response;
    try {
      response = await _send(
        method,
        body: body,
        idempotencyKey: idempotencyKey,
        sessionScope: sessionScope,
      );
      if (response.statusCode == HttpStatus.unauthorized) {
        response = await _send(
          method,
          body: body,
          idempotencyKey: idempotencyKey,
          forceRefresh: true,
          sessionScope: sessionScope,
        );
      }
      _requireSessionScope(sessionScope);
      await _rejectInvalidSessionIfNeeded(response);
    } on IOException {
      throw ParticipantProfileException(
        'Swappy could not connect. You can safely try again.',
        outcomeUnknown: method == 'PATCH',
      );
    } on TimeoutException {
      throw ParticipantProfileException(
        'The profile update timed out. You can safely try again.',
        outcomeUnknown: method == 'PATCH',
      );
    } on ParticipantProfileException {
      rethrow;
    } catch (_) {
      throw ParticipantProfileException(
        'The profile request failed unexpectedly.',
        outcomeUnknown: method == 'PATCH',
      );
    }

    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw ParticipantProfileException(
        'Swappy returned an unexpected response. Try again.',
        outcomeUnknown: method == 'PATCH' && response.statusCode >= 200,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ParticipantProfileException(
        _participantRequestError(response.statusCode),
        outcomeUnknown: method == 'PATCH' && response.statusCode >= 500,
      );
    }

    if (decoded is! Map ||
        decoded['sourceState'] != 'durable' ||
        decoded['participant'] is! Map) {
      throw ParticipantProfileException(
        'Swappy returned an unexpected response. Try again.',
        outcomeUnknown: method == 'PATCH',
      );
    }

    final participant = decoded['participant'] as Map;
    return ParticipantProfileResult(
      participant: _participantFromMap(participant),
      correlationId: method == 'PATCH'
          ? _requiredString(decoded, 'correlationId')
          : _nullableString(decoded['correlationId'], 'correlationId'),
    );
  }

  Future<ParticipantProfileTransportResponse> _send(
    String method, {
    String path = '/v1/me',
    Map<String, Object?>? body,
    String? idempotencyKey,
    bool forceRefresh = false,
    _ParticipantSessionScope? sessionScope,
  }) async {
    _requireSessionScope(sessionScope);
    final accessToken = await accessTokenProvider(forceRefresh: forceRefresh);
    _requireSessionScope(sessionScope);
    if (accessToken.trim().isEmpty) {
      throw const ParticipantProfileException(
        'An authenticated participant session is required.',
      );
    }
    return _transport(method, baseUri.resolve(path), {
      HttpHeaders.authorizationHeader: 'Bearer $accessToken',
      HttpHeaders.acceptHeader: 'application/json',
      if (body != null) HttpHeaders.contentTypeHeader: 'application/json',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    }, body);
  }

  _ParticipantSessionScope? _captureSessionScope() =>
      _sessionIdentityProvider == null
      ? null
      : _ParticipantSessionScope(_sessionIdentityProvider());

  void _requireSessionScope(_ParticipantSessionScope? scope) {
    if (scope == null || _sessionIdentityProvider == null) return;
    if (_sessionIdentityProvider() != scope.sessionId) {
      throw const ParticipantProfileException(
        'The signed-in account changed before this request completed. '
        'Start the action again.',
      );
    }
  }

  Future<void> _rejectInvalidSessionIfNeeded(
    ParticipantProfileTransportResponse response,
  ) async {
    if (response.statusCode != HttpStatus.unauthorized) return;
    await _onSessionRejected?.call();
    throw const ParticipantProfileException(
      'Your participant session is no longer valid. Sign in again.',
    );
  }

  static Future<ParticipantProfileTransportResponse> _ioTransport(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 5));
      headers.forEach(request.headers.set);
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      return ParticipantProfileTransportResponse(
        response.statusCode,
        await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 10)),
      );
    } finally {
      client.close(force: true);
    }
  }
}

ParticipantProfile _participantFromMap(Map<dynamic, dynamic> participant) {
  _requireExactKeys(participant, const {
    'id',
    'displayName',
    'status',
    'registrationSource',
    'createdAt',
    'updatedAt',
  }, 'participant profile');
  final id = _requiredString(participant, 'id');
  final displayName = _nullableString(
    participant['displayName'],
    'displayName',
  );
  final status = _requiredString(participant, 'status');
  final registrationSource = _nullableString(
    participant['registrationSource'],
    'registrationSource',
  );
  if (!RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(id) ||
      (displayName != null && displayName.length > 120) ||
      !const {
        'onboarding',
        'active',
        'deletion_pending',
        'deactivated',
        'suspended',
      }.contains(status) ||
      (registrationSource != null && registrationSource.length > 64)) {
    throw const ParticipantProfileException(
      'Swappy returned an unexpected profile response. Try again.',
    );
  }
  return ParticipantProfile(
    id: id.toLowerCase(),
    displayName: displayName,
    status: status,
    registrationSource: registrationSource,
    createdAt: _requiredDate(participant, 'createdAt'),
    updatedAt: _requiredDate(participant, 'updatedAt'),
  );
}

ParticipantOnboardingWorkflow? _onboardingWorkflow(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) {
    throw const ParticipantProfileException(
      'The onboarding response contains an invalid workflow.',
    );
  }
  _requireExactKeys(raw, const {
    'version',
    'status',
    'currentStep',
    'startedAt',
    'completedAt',
    'completedSteps',
  }, 'onboarding workflow');
  final version = raw['version'];
  final status = raw['status'];
  final completedSteps = raw['completedSteps'];
  final startedAt = _nullableDate(raw['startedAt'], 'startedAt');
  final completedAt = _nullableDate(raw['completedAt'], 'completedAt');
  if (version is! int ||
      version < 1 ||
      status is! String ||
      !const {'not_started', 'in_progress', 'completed'}.contains(status) ||
      completedSteps is! List) {
    throw const ParticipantProfileException(
      'The onboarding response contains an invalid workflow.',
    );
  }
  final currentStep = _requiredString(raw, 'currentStep');
  if (currentStep.length > 64) {
    throw const ParticipantProfileException(
      'The onboarding response contains an invalid workflow step.',
    );
  }
  final timestampsMatchStatus = switch (status) {
    'not_started' => startedAt == null && completedAt == null,
    'in_progress' => startedAt != null && completedAt == null,
    'completed' => startedAt != null && completedAt != null,
    _ => false,
  };
  if (!timestampsMatchStatus) {
    throw const ParticipantProfileException(
      'The onboarding workflow timestamps do not match its status.',
    );
  }
  final parsedSteps = completedSteps
      .map((rawStep) {
        if (rawStep is! Map) {
          throw const ParticipantProfileException(
            'The onboarding response contains an invalid completed step.',
          );
        }
        _requireExactKeys(rawStep, const {
          'stepKey',
          'completedAt',
        }, 'onboarding completed step');
        final stepKey = _requiredString(rawStep, 'stepKey');
        if (stepKey.length > 64) {
          throw const ParticipantProfileException(
            'The onboarding response contains an invalid completed step.',
          );
        }
        return ParticipantOnboardingStepCompletion(
          stepKey: stepKey,
          completedAt: _requiredDate(rawStep, 'completedAt'),
        );
      })
      .toList(growable: false);
  if (parsedSteps.map((step) => step.stepKey).toSet().length !=
      parsedSteps.length) {
    throw const ParticipantProfileException(
      'The onboarding response contains duplicate completed steps.',
    );
  }
  return ParticipantOnboardingWorkflow(
    version: version,
    status: status,
    currentStep: currentStep,
    startedAt: startedAt,
    completedAt: completedAt,
    completedSteps: List.unmodifiable(parsedSteps),
  );
}

ParticipantOnboardingPolicy _onboardingPolicy(Map<dynamic, dynamic> policy) {
  _requireExactKeys(policy, const {'status', 'blockers'}, 'onboarding policy');
  final status = policy['status'];
  final blockers = policy['blockers'];
  const allowedBlockers = {
    'launch_jurisdiction',
    'adult_eligibility_policy',
    'participant_disclosures',
    'profile_data_governance',
  };
  if (status is! String ||
      !const {'not_configured', 'development_bypass'}.contains(status) ||
      blockers is! List ||
      blockers.any((blocker) => blocker is! String) ||
      blockers.any((blocker) => !allowedBlockers.contains(blocker)) ||
      blockers.length > allowedBlockers.length ||
      blockers.toSet().length != blockers.length ||
      (status == 'development_bypass' && blockers.isNotEmpty)) {
    throw const ParticipantProfileException(
      'The onboarding response contains an unsupported policy state.',
    );
  }
  return ParticipantOnboardingPolicy(
    status: status,
    blockers: List<String>.unmodifiable(blockers.cast<String>()),
  );
}

ParticipantOnboardingContinuation _onboardingContinuation(
  Map<dynamic, dynamic> continuation,
) {
  _requireExactKeys(continuation, const {
    'accountState',
    'continuationVersion',
    'nextAction',
    'nextStep',
  }, 'onboarding continuation');
  final accountState = continuation['accountState'];
  final version = continuation['continuationVersion'];
  final nextAction = continuation['nextAction'];
  final nextStep = _nullableString(continuation['nextStep'], 'nextStep');
  if (accountState is! String ||
      !const {
        'onboarding',
        'active',
        'deletion_pending',
        'deactivated',
        'suspended',
      }.contains(accountState) ||
      version is! int ||
      version < 1 ||
      nextAction is! String ||
      (nextStep != null && nextStep.length > 64) ||
      !const {
        'profile_required',
        'profile_in_progress',
        'home',
        'account_ineligible',
        'account_deletion_pending',
        'account_deleted',
      }.contains(nextAction)) {
    throw const ParticipantProfileException(
      'The onboarding response contains an invalid continuation.',
    );
  }
  return ParticipantOnboardingContinuation(
    accountState: accountState,
    version: version,
    nextAction: nextAction,
    nextStep: nextStep,
  );
}

void _requireExactKeys(
  Map<dynamic, dynamic> value,
  Set<String> expected,
  String label,
) {
  final keys = value.keys.whereType<String>().toSet();
  if (keys.length != value.length ||
      keys.length != expected.length ||
      !keys.containsAll(expected)) {
    throw ParticipantProfileException(
      'Swappy returned an unexpected response. Try again.',
    );
  }
}

String _participantRequestError(
  int statusCode, {
  bool loadingOnboarding = false,
}) => switch (statusCode) {
  HttpStatus.unauthorized => 'Your session expired. Sign in again to continue.',
  HttpStatus.tooManyRequests =>
    'Too many attempts. Please wait a moment and try again.',
  HttpStatus.conflict =>
    'Your account changed. Refresh and review the latest details.',
  HttpStatus.serviceUnavailable =>
    'Profile service is temporarily unavailable. Try again shortly.',
  _ =>
    loadingOnboarding
        ? 'We could not load your account setup. Try again.'
        : 'We could not update your profile. Try again.',
};

String newProfileIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

String _requiredString(Map<dynamic, dynamic> value, String key) {
  final field = value[key];
  if (field is! String || field.isEmpty) {
    throw ParticipantProfileException(
      'The profile response is missing $key.',
      outcomeUnknown: true,
    );
  }
  return field;
}

String? _nullableString(Object? value, String key) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return value;
  throw ParticipantProfileException(
    'The profile response contains an invalid $key.',
    outcomeUnknown: true,
  );
}

DateTime _requiredDate(Map<dynamic, dynamic> value, String key) {
  final raw = _requiredString(value, key);
  final date = DateTime.tryParse(raw);
  if (date == null) {
    throw ParticipantProfileException(
      'The profile response contains an invalid $key.',
      outcomeUnknown: true,
    );
  }
  return date;
}

DateTime? _nullableDate(Object? value, String key) {
  if (value == null) return null;
  if (value is String) {
    final date = DateTime.tryParse(value);
    if (date != null) return date;
  }
  throw ParticipantProfileException(
    'The onboarding response contains an invalid $key.',
  );
}

class ParticipantProfileException implements Exception {
  const ParticipantProfileException(
    this.message, {
    this.outcomeUnknown = false,
  });

  final String message;
  final bool outcomeUnknown;
}
