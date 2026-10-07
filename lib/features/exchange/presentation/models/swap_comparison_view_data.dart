import '../../domain/exchange_marketplace_models.dart';
import '../../domain/exchange_models.dart';

/// Presentation-safe seat details used by the current V1 exchange screens.
///
/// This adapter deliberately drops ticket resource identifiers, provider
/// internals, eligibility records, and event context references. A future V2
/// SeatSummary can map into the same view data without changing the widget.
class SwapSeatViewData {
  const SwapSeatViewData({
    required this.title,
    required this.venue,
    required this.assignment,
    required this.shortAssignment,
    required this.quantity,
    required this.trustLabel,
    required this.trustExplanation,
  });

  factory SwapSeatViewData.fromPost(SwapIntentProjection post) {
    final photoTicket = post.offeredTicketBundle;
    if (photoTicket != null) {
      final assignmentParts = [
        if (photoTicket.sectionLabel != null)
          'Section ${photoTicket.sectionLabel}',
        if (photoTicket.rowLabel != null) 'Row ${photoTicket.rowLabel}',
        'Seats ${photoTicket.seatLabels.join(', ')}',
      ];
      final assignment = assignmentParts.join(' · ');
      return SwapSeatViewData(
        title: photoTicket.eventTitle,
        venue: photoTicket.venueName,
        assignment: assignment,
        shortAssignment: assignment,
        quantity: photoTicket.quantity,
        trustLabel: 'Photo details checked',
        trustExplanation:
            'Ownership, validity and transferability are not verified.',
      );
    }

    final providerSeat = post.offeredEntitlement;
    final assignment = providerSeat?.assignmentLabel.trim();
    return SwapSeatViewData(
      title: 'Provider-connected seat',
      venue: null,
      assignment: assignment == null || assignment.isEmpty
          ? 'Seat assignment unavailable'
          : assignment,
      shortAssignment: assignment == null || assignment.isEmpty
          ? 'Assignment unavailable'
          : assignment,
      // V1 provider entitlements do not expose an authoritative quantity.
      quantity: null,
      trustLabel: 'Provider-connected details',
      trustExplanation:
          'Only the seat assignment supplied by the provider is shown.',
    );
  }

  final String title;
  final String? venue;
  final String assignment;
  final String shortAssignment;
  final int? quantity;
  final String trustLabel;
  final String trustExplanation;

  String get semanticsLabel => [
    title,
    if (venue != null) venue!,
    assignment,
    if (quantity != null) 'Quantity $quantity',
    trustLabel,
    trustExplanation,
  ].join('. ');
}

class SwapComparisonViewData {
  const SwapComparisonViewData({
    required this.youGive,
    required this.youReceive,
    this.cashSummary,
  });

  factory SwapComparisonViewData.fromPosts({
    required SwapIntentProjection youGive,
    required SwapIntentProjection youReceive,
    String? cashSummary,
  }) => SwapComparisonViewData(
    youGive: SwapSeatViewData.fromPost(youGive),
    youReceive: SwapSeatViewData.fromPost(youReceive),
    cashSummary: cashSummary,
  );

  factory SwapComparisonViewData.fromRequest(SwapRequestProjection request) {
    final isRequester = request.role == SwapRequestRole.requester;
    return SwapComparisonViewData.fromPosts(
      youGive: isRequester ? request.counterpartyPost : request.targetPost,
      youReceive: isRequester ? request.targetPost : request.counterpartyPost,
      cashSummary: requestCashSummaryForViewer(
        direction: request.cashDifference.direction,
        amountMinor: request.cashDifference.amountMinor,
        currency: request.cashDifference.currency,
        role: request.role,
      ),
    );
  }

  final SwapSeatViewData youGive;
  final SwapSeatViewData youReceive;
  final String? cashSummary;
}

bool requestPostsChangedSinceSubmission(SwapRequestProjection request) =>
    request.targetPostVersionAtSubmission != request.targetPost.version ||
    request.counterpartyPostVersionAtSubmission !=
        request.counterpartyPost.version;

bool requestAllowsConversationMessages(SwapRequestProjection request) =>
    !requestPostsChangedSinceSubmission(request) &&
    (request.state == SwapRequestState.submitted ||
        request.state == SwapRequestState.selected);

String requestCashSummaryForViewer({
  required RequestCashDirection direction,
  required int? amountMinor,
  required String? currency,
  required SwapRequestRole role,
}) {
  if (direction == RequestCashDirection.none) return 'No cash difference';
  if (amountMinor == null || currency == null) {
    return 'Enter the cash proposal amount below.';
  }

  final amount = _currencyAmount(currency, amountMinor);
  final requesterPays = direction == RequestCashDirection.requesterPaysOwner;
  final viewerPays = role == SwapRequestRole.requester
      ? requesterPays
      : !requesterPays;
  return viewerPays
      ? 'You would pay $amount — payment is not protected.'
      : 'You would receive $amount — payment is not protected.';
}

String _currencyAmount(String currency, int minor) => currency == 'INR'
    ? 'INR ${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}'
    : '$currency $minor minor units';
