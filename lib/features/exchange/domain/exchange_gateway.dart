import 'exchange_models.dart';
import 'exchange_marketplace_models.dart';
import 'exchange_conversation_models.dart';

/// UI/provider-facing boundary for the participant exchange workflow.
abstract interface class ExchangeGateway {
  Future<EventPresenceGrant> issueEventPresenceGrant(
    EventPresenceGrantRequest request,
  );

  Future<EvidenceProjection> submitEvidence(
    EvidenceSubmissionRequest request, {
    required String idempotencyKey,
  });

  Future<ExchangePage<EvidenceProjection>> listEvidence({
    int limit = 50,
    int offset = 0,
    EvidenceState? state,
  });

  Future<EvidenceProjection> getEvidence(String evidenceId);

  Future<ExchangePage<EntitlementProjection>> listEntitlements({
    int limit = 50,
    int offset = 0,
    EntitlementState? state,
  });

  Future<EntitlementProjection> getEntitlement(String entitlementId);

  Future<SwapIntentProjection> createSwapIntent(
    CreateSwapIntentRequest request, {
    required String idempotencyKey,
  });

  Future<ExchangePage<SwapIntentProjection>> listSwapIntents({
    int limit = 50,
    int offset = 0,
    SwapIntentState? state,
  });

  Future<SwapIntentDetail> getSwapIntent(String intentId);

  Future<SwapIntentProjection> updateSwapIntent(
    String intentId,
    UpdateSwapIntentRequest request, {
    required String idempotencyKey,
  });

  Future<SwapIntentProjection> publishSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<SwapIntentProjection> pauseSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<SwapIntentProjection> resumeSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<SwapIntentProjection> withdrawSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<ExchangePage<SwapPostProjection>> listPublishedSwapPosts({
    String? contextRef,
    int limit = 50,
    int offset = 0,
  });

  Future<SwapPostProjection> getPublishedSwapPost(String postId);

  Future<SwapRequestProjection> createSwapRequest(
    String targetIntentId,
    CreateSwapRequestRequest request, {
    required String idempotencyKey,
  });

  Future<ExchangePage<SwapRequestProjection>> listSwapRequests({
    int limit = 50,
    int offset = 0,
    SwapRequestState? state,
  });

  Future<SwapRequestDetail> getSwapRequest(String requestId);

  Future<SwapRequestProjection> selectSwapRequest(
    String requestId,
    SelectSwapRequestRequest request, {
    required String idempotencyKey,
  });

  Future<SwapRequestProjection> rejectSwapRequest(
    String requestId, {
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<SwapRequestProjection> withdrawSwapRequest(
    String requestId, {
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<SwapAgreement> getAgreement(String agreementId);

  Future<SwapAgreement> recordAgreementConsent(
    String agreementId, {
    required EventPresenceGrant presenceGrant,
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<SwapAgreement> recordAgreementHandoff(
    String agreementId, {
    required EventPresenceGrant presenceGrant,
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<SwapAgreement> recordAgreementCashConfirmation(
    String agreementId, {
    required EventPresenceGrant presenceGrant,
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<SwapAgreement> cancelAgreement(
    String agreementId, {
    required String? reason,
    required String idempotencyKey,
  });

  Future<SwapAgreement> disputeAgreement(
    String agreementId, {
    required String reason,
    required String idempotencyKey,
  });

  Future<SwapConversationProjection> getSwapConversation(String requestId);

  Future<SwapMessageProjection> sendSwapMessage(
    String requestId,
    SendSwapMessageRequest request, {
    required String idempotencyKey,
  });

  Future<SwapConversationReadResult> markSwapConversationRead(
    String requestId, {
    required String idempotencyKey,
  });

  /// Legacy, non-contract method retained until the unreachable agreement UI
  /// migrates to [recordAgreementHandoff]. Implementations must fail closed.
  Future<SwapAgreement> confirmTransfer(
    String agreementId, {
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<RevealedEntitlement> getRevealedEntitlement(String agreementId);
}
