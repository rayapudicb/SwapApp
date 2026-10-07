import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_gateway.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_models.dart';
import 'package:swappy_mobile/features/exchange/providers/exchange_provider.dart';

const _entitlementId = '33333333-3333-4333-8333-333333333333';
const _intentId = '44444444-4444-4444-8444-444444444444';

void main() {
  test('loads real evidence and eligible entitlements', () async {
    final gateway = _FakeExchangeGateway();
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 13),
    );

    await provider.loadPostData();

    expect(provider.postError, isNull);
    expect(provider.evidence, hasLength(1));
    expect(provider.eligibleEntitlements, hasLength(1));

    await provider.loadEvidenceDetail(provider.evidence.single.id);
    await provider.loadEntitlementDetail(provider.entitlements.single.id);
    expect(provider.evidenceDetail?.state, EvidenceState.processed);
    expect(provider.entitlementDetail?.state, EntitlementState.eligible);
  });

  test('uses the latest returned version for lifecycle commands', () async {
    final gateway = _FakeExchangeGateway();
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 13),
    );
    await provider.loadIntents();

    final published = await provider.publishIntent(provider.intents.single);
    final paused = await provider.pauseIntent(provider.intents.single);

    expect(published, isTrue);
    expect(paused, isTrue);
    expect(gateway.commandVersions, [1, 2]);
    expect(provider.intents.single.state, SwapIntentState.paused);
    expect(provider.intents.single.version, 3);
  });

  test('retries an unknown outcome with the same key and request', () async {
    final gateway = _FakeExchangeGateway()..failCreateUnknownOnce = true;
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 13),
    );
    await provider.loadPostData();
    final request = CreateSwapIntentRequest(
      offeredEntitlementId: _entitlementId,
      desiredAssignmentLabels: const ['B12'],
      acceptsAnyAssignment: false,
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    );

    expect(await provider.createIntent(request), isFalse);
    expect(provider.canRetryUnknownCommand, isTrue);
    expect(await provider.retryUnknownCommand(), isTrue);

    expect(gateway.createKeys, hasLength(2));
    expect(gateway.createKeys.toSet(), hasLength(1));
    expect(gateway.createRequests[0], same(gateway.createRequests[1]));
    expect(provider.canRetryUnknownCommand, isFalse);
  });

  test('refetches authoritative detail after a version conflict', () async {
    final gateway = _FakeExchangeGateway()..failPublishConflictOnce = true;
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 13),
    );
    await provider.loadIntents();

    expect(await provider.publishIntent(provider.intents.single), isFalse);

    expect(gateway.detailReads, 1);
    expect(gateway.intentListReads, 2);
    expect(provider.commandError, contains('latest version is shown'));
  });

  test('reset clears participant state and rejects late responses', () async {
    final gateway = _FakeExchangeGateway()..holdNextIntentList = true;
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 13),
    );
    await provider.loadPostData();
    final lateLoad = provider.loadIntents();

    provider.resetForSession();
    gateway.completeHeldIntentList();
    await lateLoad;

    expect(provider.evidence, isEmpty);
    expect(provider.entitlements, isEmpty);
    expect(provider.intents, isEmpty);
    expect(provider.canRetryUnknownCommand, isFalse);
  });

  test('blocks a new command until unknown outcome is resolved', () async {
    final gateway = _FakeExchangeGateway()..failCreateUnknownOnce = true;
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 13),
    );
    await provider.loadPostData();
    final request = CreateSwapIntentRequest(
      offeredEntitlementId: _entitlementId,
      desiredAssignmentLabels: const ['B12'],
      acceptsAnyAssignment: false,
      expiresAt: DateTime.utc(2026, 8, 14),
    );
    expect(await provider.createIntent(request), isFalse);

    expect(await provider.createIntent(request), isFalse);
    expect(gateway.createRequests, hasLength(1));
    expect(provider.commandError, contains('Resolve the request'));
  });

  test('does not expose a revoked or expired eligibility decision', () async {
    final gateway = _FakeExchangeGateway()..returnExpiredEntitlement = true;
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 13),
    );

    await provider.loadPostData();

    expect(provider.entitlements, hasLength(1));
    expect(provider.eligibleEntitlements, isEmpty);
  });
}

class _FakeExchangeGateway implements ExchangeGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  SwapIntentProjection currentIntent = _intent(
    state: SwapIntentState.draft,
    version: 1,
  );
  bool failCreateUnknownOnce = false;
  bool failPublishConflictOnce = false;
  bool returnExpiredEntitlement = false;
  bool holdNextIntentList = false;
  Completer<ExchangePage<SwapIntentProjection>>? _heldIntentList;
  int detailReads = 0;
  int intentListReads = 0;
  final List<int> commandVersions = [];
  final List<String> createKeys = [];
  final List<CreateSwapIntentRequest> createRequests = [];

  @override
  Future<ExchangePage<EvidenceProjection>> listEvidence({
    int limit = 50,
    int offset = 0,
    EvidenceState? state,
  }) async => ExchangePage(items: [_evidence()], total: 1);

  @override
  Future<ExchangePage<EntitlementProjection>> listEntitlements({
    int limit = 50,
    int offset = 0,
    EntitlementState? state,
  }) async => ExchangePage(
    items: [
      _entitlement(
        validUntil: returnExpiredEntitlement ? DateTime.utc(2026, 8, 12) : null,
      ),
    ],
    total: 1,
  );

  @override
  Future<ExchangePage<SwapIntentProjection>> listSwapIntents({
    int limit = 50,
    int offset = 0,
    SwapIntentState? state,
  }) async {
    intentListReads++;
    if (holdNextIntentList) {
      holdNextIntentList = false;
      _heldIntentList = Completer<ExchangePage<SwapIntentProjection>>();
      return _heldIntentList!.future;
    }
    return ExchangePage(items: [currentIntent], total: 1);
  }

  void completeHeldIntentList() {
    _heldIntentList?.complete(ExchangePage(items: [currentIntent], total: 1));
  }

  @override
  Future<SwapIntentDetail> getSwapIntent(String intentId) async {
    detailReads++;
    return SwapIntentDetail(intent: currentIntent, timeline: const []);
  }

  @override
  Future<SwapIntentProjection> createSwapIntent(
    CreateSwapIntentRequest request, {
    required String idempotencyKey,
  }) async {
    createKeys.add(idempotencyKey);
    createRequests.add(request);
    if (failCreateUnknownOnce) {
      failCreateUnknownOnce = false;
      throw const ApiRequestException(
        'Unavailable',
        statusCode: 503,
        outcomeUnknown: true,
      );
    }
    currentIntent = _intent(state: SwapIntentState.draft, version: 1);
    return currentIntent;
  }

  @override
  Future<SwapIntentProjection> publishSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    commandVersions.add(expectedVersion);
    if (failPublishConflictOnce) {
      failPublishConflictOnce = false;
      throw const ApiRequestException(
        'Version conflict',
        statusCode: 409,
        code: 'SWAP_INTENT_VERSION_CONFLICT',
      );
    }
    currentIntent = _intent(
      state: SwapIntentState.published,
      version: expectedVersion + 1,
    );
    return currentIntent;
  }

  @override
  Future<SwapIntentProjection> pauseSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    commandVersions.add(expectedVersion);
    currentIntent = _intent(
      state: SwapIntentState.paused,
      version: expectedVersion + 1,
    );
    return currentIntent;
  }

  @override
  Future<SwapIntentProjection> resumeSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    commandVersions.add(expectedVersion);
    currentIntent = _intent(
      state: SwapIntentState.published,
      version: expectedVersion + 1,
    );
    return currentIntent;
  }

  @override
  Future<SwapIntentProjection> withdrawSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    commandVersions.add(expectedVersion);
    currentIntent = _intent(
      state: SwapIntentState.withdrawn,
      version: expectedVersion + 1,
    );
    return currentIntent;
  }

  @override
  Future<SwapIntentProjection> updateSwapIntent(
    String intentId,
    UpdateSwapIntentRequest request, {
    required String idempotencyKey,
  }) async {
    commandVersions.add(request.expectedVersion);
    currentIntent = _intent(
      state: currentIntent.state,
      version: request.expectedVersion + 1,
    );
    return currentIntent;
  }

  @override
  Future<EvidenceProjection> getEvidence(String evidenceId) async =>
      _evidence();

  @override
  Future<EntitlementProjection> getEntitlement(String entitlementId) async =>
      _entitlement();

  @override
  Future<EvidenceProjection> submitEvidence(
    EvidenceSubmissionRequest request, {
    required String idempotencyKey,
  }) async => _evidence();
}

EligibilityProjection _eligibility() => EligibilityProjection(
  id: '22222222-2222-4222-8222-222222222222',
  decision: EligibilityDecision.eligible,
  mode: 'provider',
  policyVersion: 'v1',
  adapterVersion: 'v1',
  reasonCode: 'provider_confirmed',
  decidedAt: DateTime.utc(2026, 8, 13),
  validUntil: DateTime.utc(2026, 9, 13),
  revokedAt: null,
);

EvidenceProjection _evidence() => EvidenceProjection(
  id: '11111111-1111-4111-8111-111111111111',
  verticalKey: 'ticketed_experience',
  providerKey: 'provider_one',
  contextRef: 'event-1',
  evidenceType: 'provider_connection',
  state: EvidenceState.processed,
  retentionUntil: null,
  createdAt: DateTime.utc(2026, 8, 13),
  latestEligibility: _eligibility(),
);

EntitlementProjection _entitlement({DateTime? validUntil}) =>
    EntitlementProjection(
      id: _entitlementId,
      verticalKey: 'ticketed_experience',
      providerKey: 'provider_one',
      contextRef: 'event-1',
      assignmentLabel: 'A12',
      state: EntitlementState.eligible,
      version: 1,
      createdAt: DateTime.utc(2026, 8, 13),
      updatedAt: DateTime.utc(2026, 8, 13),
      eligibility: validUntil == null
          ? _eligibility()
          : EligibilityProjection(
              id: '22222222-2222-4222-8222-222222222222',
              decision: EligibilityDecision.eligible,
              mode: 'provider',
              policyVersion: 'v1',
              adapterVersion: 'v1',
              reasonCode: 'provider_confirmed',
              decidedAt: DateTime.utc(2026, 8, 1),
              validUntil: validUntil,
              revokedAt: null,
            ),
    );

SwapIntentProjection _intent({
  required SwapIntentState state,
  required int version,
}) => SwapIntentProjection(
  id: _intentId,
  state: state,
  version: version,
  desiredAssignmentLabels: const ['B12'],
  acceptsAnyAssignment: false,
  expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
  publishedAt: state == SwapIntentState.published ? DateTime.now() : null,
  pausedAt: state == SwapIntentState.paused ? DateTime.now() : null,
  withdrawnAt: state == SwapIntentState.withdrawn ? DateTime.now() : null,
  createdAt: DateTime.utc(2026, 8, 13),
  updatedAt: DateTime.utc(2026, 8, 13),
  offeredEntitlement: _entitlement(),
);
