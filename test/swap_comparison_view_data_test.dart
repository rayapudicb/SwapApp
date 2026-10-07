import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_marketplace_models.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_models.dart';
import 'package:swappy_mobile/features/exchange/presentation/models/swap_comparison_view_data.dart';

void main() {
  group('SwapComparisonViewData', () {
    test(
      'maps the requester to give their Post and receive the target Post',
      () {
        final comparison = SwapComparisonViewData.fromRequest(
          _request(role: SwapRequestRole.requester),
        );

        expect(comparison.youGive.assignment, contains('Section 305'));
        expect(comparison.youGive.assignment, contains('Seats 22'));
        expect(comparison.youReceive.assignment, contains('Section 101'));
        expect(comparison.youReceive.assignment, contains('Seats 12'));
      },
    );

    test('reverses the same pair for the target owner', () {
      final comparison = SwapComparisonViewData.fromRequest(
        _request(role: SwapRequestRole.targetOwner),
      );

      expect(comparison.youGive.assignment, contains('Section 101'));
      expect(comparison.youGive.assignment, contains('Seats 12'));
      expect(comparison.youReceive.assignment, contains('Section 305'));
      expect(comparison.youReceive.assignment, contains('Seats 22'));
    });

    test('makes requester-pays-owner cash wording viewer relative', () {
      final requester = SwapComparisonViewData.fromRequest(
        _request(
          role: SwapRequestRole.requester,
          cashDirection: RequestCashDirection.requesterPaysOwner,
        ),
      );
      final owner = SwapComparisonViewData.fromRequest(
        _request(
          role: SwapRequestRole.targetOwner,
          cashDirection: RequestCashDirection.requesterPaysOwner,
        ),
      );

      expect(requester.cashSummary, contains('You would pay INR 2000.00'));
      expect(owner.cashSummary, contains('You would receive INR 2000.00'));
      expect(requester.cashSummary, contains('not protected'));
    });

    test('makes owner-pays-requester cash wording viewer relative', () {
      final requester = SwapComparisonViewData.fromRequest(
        _request(
          role: SwapRequestRole.requester,
          cashDirection: RequestCashDirection.ownerPaysRequester,
        ),
      );
      final owner = SwapComparisonViewData.fromRequest(
        _request(
          role: SwapRequestRole.targetOwner,
          cashDirection: RequestCashDirection.ownerPaysRequester,
        ),
      );

      expect(requester.cashSummary, contains('You would receive INR 2000.00'));
      expect(owner.cashSummary, contains('You would pay INR 2000.00'));
    });

    test(
      'uses conservative trust copy and omits provider quantity guesses',
      () {
        final providerSeat = SwapSeatViewData.fromPost(_providerIntent());
        final photoSeat = SwapSeatViewData.fromPost(
          _photoIntent(
            id: _targetPostId,
            bundleId: _targetBundleId,
            section: '101',
            row: 'B',
            seats: const ['12'],
          ),
        );

        expect(providerSeat.assignment, 'Section 401 Row Z Seat 9');
        expect(providerSeat.quantity, isNull);
        expect(providerSeat.trustLabel, 'Provider-connected details');
        expect(photoSeat.trustLabel, 'Photo details checked');
        expect(photoSeat.trustExplanation, contains('not verified'));
        expect(providerSeat.semanticsLabel, isNot(contains(_entitlementId)));
        expect(photoSeat.semanticsLabel, isNot(contains(_targetBundleId)));
        expect(photoSeat.semanticsLabel, isNot(contains('ticketmaster:event')));
      },
    );

    test('detects a Post changed after request submission', () {
      final unchanged = _request(role: SwapRequestRole.targetOwner);
      final changed = _request(
        role: SwapRequestRole.targetOwner,
        targetVersionAtSubmission: 3,
      );

      expect(requestPostsChangedSinceSubmission(unchanged), isFalse);
      expect(requestPostsChangedSinceSubmission(changed), isTrue);
    });

    test('allows messages only for current active requests', () {
      final submitted = _request(role: SwapRequestRole.requester);
      final selected = _request(
        role: SwapRequestRole.requester,
        state: SwapRequestState.selected,
      );
      final rejected = _request(
        role: SwapRequestRole.requester,
        state: SwapRequestState.rejected,
      );
      final changed = _request(
        role: SwapRequestRole.requester,
        targetVersionAtSubmission: 3,
      );

      expect(requestAllowsConversationMessages(submitted), isTrue);
      expect(requestAllowsConversationMessages(selected), isTrue);
      expect(requestAllowsConversationMessages(rejected), isFalse);
      expect(requestAllowsConversationMessages(changed), isFalse);
    });
  });
}

const _targetPostId = '11111111-1111-4111-8111-111111111111';
const _requesterPostId = '22222222-2222-4222-8222-222222222222';
const _requestId = '33333333-3333-4333-8333-333333333333';
const _targetBundleId = '44444444-4444-4444-8444-444444444444';
const _requesterBundleId = '55555555-5555-4555-8555-555555555555';
const _entitlementId = '66666666-6666-4666-8666-666666666666';

SwapRequestProjection _request({
  required SwapRequestRole role,
  RequestCashDirection cashDirection = RequestCashDirection.none,
  int targetVersionAtSubmission = 4,
  SwapRequestState state = SwapRequestState.submitted,
}) => SwapRequestProjection(
  id: _requestId,
  state: state,
  version: 1,
  role: role,
  targetPostVersionAtSubmission: targetVersionAtSubmission,
  counterpartyPostVersionAtSubmission: 2,
  cashDifference: RequestCashDifference(
    direction: cashDirection,
    amountMinor: cashDirection == RequestCashDirection.none ? null : 200000,
    currency: cashDirection == RequestCashDirection.none ? null : 'INR',
    status: 'proposal_only',
    paymentProtected: false,
  ),
  expiresAt: DateTime.utc(2026, 9, 1, 14),
  selectedAt: state == SwapRequestState.selected
      ? DateTime.utc(2026, 9, 1, 13, 5)
      : null,
  rejectedAt: state == SwapRequestState.rejected
      ? DateTime.utc(2026, 9, 1, 13, 5)
      : null,
  withdrawnAt: null,
  createdAt: DateTime.utc(2026, 9, 1, 13),
  updatedAt: DateTime.utc(2026, 9, 1, 13),
  targetPost: _photoIntent(
    id: _targetPostId,
    bundleId: _targetBundleId,
    section: '101',
    row: 'B',
    seats: const ['12'],
    version: 4,
  ),
  counterpartyPost: _photoIntent(
    id: _requesterPostId,
    bundleId: _requesterBundleId,
    section: '305',
    row: 'F',
    seats: const ['22'],
    version: 2,
  ),
  warning: 'No ticket or money is transferred.',
);

SwapIntentProjection _photoIntent({
  required String id,
  required String bundleId,
  required String section,
  required String row,
  required List<String> seats,
  int version = 1,
}) => SwapIntentProjection(
  id: id,
  state: SwapIntentState.published,
  version: version,
  desiredAssignmentLabels: const ['Any seat'],
  acceptsAnyAssignment: true,
  expiresAt: DateTime.utc(2026, 9, 1, 15),
  publishedAt: DateTime.utc(2026, 9, 1, 12),
  pausedAt: null,
  withdrawnAt: null,
  createdAt: DateTime.utc(2026, 9, 1, 12),
  updatedAt: DateTime.utc(2026, 9, 1, 12),
  offeredSource: SwapIntentOfferedSource.photoChecked,
  offeredEntitlement: null,
  offeredTicketBundle: PhotoTicketBundleProjection(
    id: bundleId,
    contextRef: 'ticketmaster:event:city-finals',
    eventTitle: 'City Finals',
    startsAt: DateTime.utc(2026, 9, 1, 13),
    timezone: 'Asia/Kolkata',
    venueName: 'City Arena',
    sectionLabel: section,
    rowLabel: row,
    seatLabels: seats,
    quantity: seats.length,
    state: 'active',
    version: 1,
  ),
);

SwapIntentProjection _providerIntent() => SwapIntentProjection(
  id: '77777777-7777-4777-8777-777777777777',
  state: SwapIntentState.published,
  version: 1,
  desiredAssignmentLabels: const ['Any seat'],
  acceptsAnyAssignment: true,
  expiresAt: DateTime.utc(2026, 9, 1, 15),
  publishedAt: DateTime.utc(2026, 9, 1, 12),
  pausedAt: null,
  withdrawnAt: null,
  createdAt: DateTime.utc(2026, 9, 1, 12),
  updatedAt: DateTime.utc(2026, 9, 1, 12),
  offeredSource: SwapIntentOfferedSource.providerVerified,
  offeredEntitlement: EntitlementProjection(
    id: _entitlementId,
    verticalKey: 'ticketed_experience',
    providerKey: 'ticketmaster',
    contextRef: 'ticketmaster:event:city-finals',
    assignmentLabel: 'Section 401 Row Z Seat 9',
    state: EntitlementState.eligible,
    version: 1,
    createdAt: DateTime.utc(2026, 9, 1, 12),
    updatedAt: DateTime.utc(2026, 9, 1, 12),
    eligibility: EligibilityProjection(
      id: '88888888-8888-4888-8888-888888888888',
      decision: EligibilityDecision.eligible,
      mode: 'provider',
      policyVersion: '1',
      adapterVersion: '1',
      reasonCode: 'eligible',
      decidedAt: DateTime.utc(2026, 9, 1, 12),
      validUntil: DateTime.utc(2026, 9, 1, 15),
      revokedAt: null,
    ),
  ),
  offeredTicketBundle: null,
);
