import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_gateway.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_marketplace_models.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_models.dart';
import 'package:swappy_mobile/features/exchange/providers/exchange_provider.dart';

const targetId = '11111111-1111-4111-8111-111111111111';
const ownId = '22222222-2222-4222-8222-222222222222';
const requestId = '33333333-3333-4333-8333-333333333333';
const otherRequestId = '66666666-6666-4666-8666-666666666666';
const targetBundleId = '44444444-4444-4444-8444-444444444444';
const ownBundleId = '55555555-5555-4555-8555-555555555555';

void main() {
  test(
    'loads published Posts and separates incoming/outgoing requests',
    () async {
      final gateway = _MarketplaceGateway();
      final provider = ExchangeProvider(
        gateway: gateway,
        clock: () => DateTime.utc(2026, 8, 14),
      );

      await provider.loadPublishedPosts(contextRef: 'event:one');
      await provider.loadSwapRequests();

      expect(gateway.loadedContextRef, 'event:one');
      expect(provider.publishedPosts.single.post.id, targetId);
      expect(provider.incomingSwapRequests, hasLength(1));
      expect(provider.outgoingSwapRequests, hasLength(1));
    },
  );

  test('submits only a compatible version-bound published Post', () async {
    final gateway = _MarketplaceGateway();
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 14),
    );
    await provider.loadIntents(state: SwapIntentState.published);
    await provider.loadPublishedPosts();
    final target = provider.publishedPosts.single;
    final own = provider.intents.single;
    final input = CreateSwapRequestRequest(
      counterpartyIntentId: own.id,
      targetIntentVersion: target.post.version,
      counterpartyIntentVersion: own.version,
      expiresAt: DateTime.utc(2026, 8, 15),
    );

    expect(await provider.createSwapRequest(target, own, input), isTrue);

    expect(gateway.createCalls, 1);
    expect(gateway.createdInput, same(input));
    expect(gateway.createdKey, hasLength(greaterThanOrEqualTo(16)));
    expect(provider.outgoingSwapRequests, isNotEmpty);
  });

  test('blocks an incompatible own Post before transport', () async {
    final gateway = _MarketplaceGateway();
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 14),
    );
    final target = gateway.target;
    final incompatible = _intent(
      ownId,
      ownBundleId,
      contextRef: 'event:other',
      version: 2,
    );

    final result = await provider.createSwapRequest(
      target,
      incompatible,
      CreateSwapRequestRequest(
        counterpartyIntentId: ownId,
        targetIntentVersion: target.post.version,
        counterpartyIntentVersion: incompatible.version,
        expiresAt: DateTime.utc(2026, 8, 15),
      ),
    );

    expect(result, isFalse);
    expect(gateway.createCalls, 0);
    expect(provider.commandError, contains('same event'));
  });

  test('refetches detail and selects using all latest versions', () async {
    final gateway = _MarketplaceGateway();
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 14),
    );
    final stale = _request(
      role: SwapRequestRole.targetOwner,
      version: 1,
      targetVersion: 1,
      ownVersion: 1,
    );
    gateway.currentRequest = _request(
      role: SwapRequestRole.targetOwner,
      version: 5,
      targetVersion: 7,
      ownVersion: 8,
    );

    expect(await provider.selectSwapRequest(stale), isTrue);

    expect(gateway.detailReads, greaterThanOrEqualTo(1));
    expect(gateway.selectedInput?.expectedVersion, 5);
    expect(gateway.selectedInput?.targetIntentVersion, 7);
    expect(gateway.selectedInput?.counterpartyIntentVersion, 8);
    expect(
      provider.swapRequests.any(
        (request) => request.state == SwapRequestState.selected,
      ),
      isTrue,
    );
  });

  test('preserves the rolling-limit retry time after reconciliation', () async {
    final gateway = _MarketplaceGateway()..failSelectionForDailyLimit = true;
    final provider = ExchangeProvider(
      gateway: gateway,
      clock: () => DateTime.utc(2026, 8, 14),
    );
    gateway.currentRequest = _request(role: SwapRequestRole.targetOwner);

    expect(await provider.selectSwapRequest(gateway.currentRequest), isFalse);

    expect(provider.commandError, 'Daily selection limit reached.');
    expect(provider.commandRetryAt, DateTime.utc(2026, 8, 15, 10, 30));
    expect(provider.selectionBlocked, isTrue);
    provider.clearCommandError();
    expect(provider.selectionBlocked, isTrue);
  });

  test('session reset clears marketplace and request state', () async {
    final gateway = _MarketplaceGateway();
    final provider = ExchangeProvider(gateway: gateway);
    await provider.loadPublishedPosts();
    await provider.loadSwapRequests();

    provider.resetForSession();

    expect(provider.publishedPosts, isEmpty);
    expect(provider.swapRequests, isEmpty);
    expect(provider.publishedPostDetail, isNull);
    expect(provider.swapRequestDetail, isNull);
  });
}

class _MarketplaceGateway implements ExchangeGateway {
  late SwapPostProjection target = SwapPostProjection(
    post: _intent(targetId, targetBundleId, version: 4),
    isOwnPost: false,
    requestable: true,
  );
  late SwapIntentProjection own = _intent(ownId, ownBundleId, version: 2);
  late SwapRequestProjection currentRequest = _request(
    role: SwapRequestRole.requester,
  );
  String? loadedContextRef;
  int createCalls = 0;
  int detailReads = 0;
  String? createdKey;
  CreateSwapRequestRequest? createdInput;
  SelectSwapRequestRequest? selectedInput;
  bool failSelectionForDailyLimit = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ExchangePage<SwapPostProjection>> listPublishedSwapPosts({
    String? contextRef,
    int limit = 50,
    int offset = 0,
  }) async {
    loadedContextRef = contextRef;
    return ExchangePage(items: [target], total: 1);
  }

  @override
  Future<SwapPostProjection> getPublishedSwapPost(String postId) async =>
      target;

  @override
  Future<ExchangePage<SwapIntentProjection>> listSwapIntents({
    int limit = 50,
    int offset = 0,
    SwapIntentState? state,
  }) async => ExchangePage(items: [own], total: 1);

  @override
  Future<ExchangePage<SwapRequestProjection>> listSwapRequests({
    int limit = 50,
    int offset = 0,
    SwapRequestState? state,
  }) async {
    final other = _request(
      id: otherRequestId,
      role: currentRequest.role == SwapRequestRole.requester
          ? SwapRequestRole.targetOwner
          : SwapRequestRole.requester,
    );
    return ExchangePage(items: [currentRequest, other], total: 2);
  }

  @override
  Future<SwapRequestProjection> createSwapRequest(
    String targetIntentId,
    CreateSwapRequestRequest request, {
    required String idempotencyKey,
  }) async {
    createCalls++;
    createdKey = idempotencyKey;
    createdInput = request;
    currentRequest = _request(role: SwapRequestRole.requester);
    return currentRequest;
  }

  @override
  Future<SwapRequestDetail> getSwapRequest(String requestId) async {
    detailReads++;
    return SwapRequestDetail(swapRequest: currentRequest, timeline: const []);
  }

  @override
  Future<SwapRequestProjection> selectSwapRequest(
    String requestId,
    SelectSwapRequestRequest request, {
    required String idempotencyKey,
  }) async {
    selectedInput = request;
    if (failSelectionForDailyLimit) {
      throw ApiRequestException(
        'Daily selection limit reached.',
        statusCode: 409,
        code: 'DAILY_SWAP_SELECTION_LIMIT_REACHED',
        retryAt: DateTime.utc(2026, 8, 15, 10, 30),
      );
    }
    currentRequest = _request(
      role: SwapRequestRole.targetOwner,
      state: SwapRequestState.selected,
      version: request.expectedVersion + 1,
      targetVersion: request.targetIntentVersion,
      ownVersion: request.counterpartyIntentVersion,
    );
    return currentRequest;
  }
}

SwapRequestProjection _request({
  String id = requestId,
  required SwapRequestRole role,
  SwapRequestState state = SwapRequestState.submitted,
  int version = 1,
  int targetVersion = 4,
  int ownVersion = 2,
}) => SwapRequestProjection(
  id: id,
  state: state,
  version: version,
  role: role,
  targetPostVersionAtSubmission: targetVersion,
  counterpartyPostVersionAtSubmission: ownVersion,
  cashDifference: const RequestCashDifference(
    direction: RequestCashDirection.none,
    amountMinor: null,
    currency: null,
    status: 'proposal_only',
    paymentProtected: false,
  ),
  expiresAt: DateTime.utc(2026, 8, 15),
  selectedAt: state == SwapRequestState.selected
      ? DateTime.utc(2026, 8, 14, 1)
      : null,
  rejectedAt: null,
  withdrawnAt: null,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
  targetPost: _intent(targetId, targetBundleId, version: targetVersion),
  counterpartyPost: _intent(ownId, ownBundleId, version: ownVersion),
  warning: 'Interest only. No ticket or money is transferred.',
);

SwapIntentProjection _intent(
  String id,
  String bundleId, {
  String contextRef = 'event:one',
  int version = 1,
}) => SwapIntentProjection(
  id: id,
  state: SwapIntentState.published,
  version: version,
  desiredAssignmentLabels: const ['Section B'],
  acceptsAnyAssignment: false,
  expiresAt: DateTime.utc(2026, 8, 20),
  publishedAt: DateTime.utc(2026, 8, 13),
  pausedAt: null,
  withdrawnAt: null,
  createdAt: DateTime.utc(2026, 8, 13),
  updatedAt: DateTime.utc(2026, 8, 13),
  offeredSource: SwapIntentOfferedSource.photoChecked,
  offeredEntitlement: null,
  offeredTicketBundle: PhotoTicketBundleProjection(
    id: bundleId,
    contextRef: contextRef,
    eventTitle: 'City Finals',
    startsAt: DateTime.utc(2026, 9, 1),
    timezone: 'Asia/Kolkata',
    venueName: 'City Arena',
    sectionLabel: 'A',
    rowLabel: '4',
    seatLabels: const ['14'],
    quantity: 1,
    state: 'active',
    version: 1,
  ),
);
