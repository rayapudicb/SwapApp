import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../home/domain/discovered_event.dart';
import '../domain/exchange_conversation_models.dart';
import '../domain/exchange_gateway.dart';
import '../domain/exchange_marketplace_models.dart';
import '../domain/exchange_models.dart';

typedef ExchangeProviderClock = DateTime Function();
typedef PresenceObservationLoader = Future<LocationObservation> Function();

/// Session-scoped participant state for the contract-authorized exchange API.
///
/// No response is persisted. [resetForSession] clears every projection and
/// pending retry, and request generations prevent an old session's late
/// response from entering a new participant's state.
class ExchangeProvider extends ChangeNotifier {
  ExchangeProvider({
    required ExchangeGateway gateway,
    ExchangeProviderClock? clock,
  }) : _gateway = gateway,
       _clock = clock ?? DateTime.now;

  final ExchangeGateway _gateway;
  final ExchangeProviderClock _clock;

  List<EvidenceProjection> _evidence = const [];
  List<EntitlementProjection> _entitlements = const [];
  List<SwapIntentProjection> _intents = const [];
  List<SwapPostProjection> _publishedPosts = const [];
  List<SwapRequestProjection> _swapRequests = const [];
  SwapIntentDetail? _detail;
  SwapPostProjection? _publishedPostDetail;
  SwapRequestDetail? _swapRequestDetail;
  EvidenceProjection? _evidenceDetail;
  EntitlementProjection? _entitlementDetail;
  bool _postLoading = false;
  bool _postDataCurrent = false;
  bool _evidenceLoadingMore = false;
  bool _entitlementsLoadingMore = false;
  bool _intentsLoading = false;
  bool _intentsLoadingMore = false;
  bool _detailLoading = false;
  bool _publishedPostsLoading = false;
  bool _publishedPostsLoadingMore = false;
  bool _publishedPostDetailLoading = false;
  bool _swapRequestsLoading = false;
  bool _swapRequestsLoadingMore = false;
  bool _swapRequestDetailLoading = false;
  bool _resourceDetailLoading = false;
  bool _commandRunning = false;
  int _evidenceTotal = 0;
  int _entitlementsTotal = 0;
  int _intentsTotal = 0;
  int _publishedPostsTotal = 0;
  int _swapRequestsTotal = 0;
  String? _postError;
  String? _intentsError;
  String? _detailError;
  String? _publishedPostsError;
  String? _publishedPostDetailError;
  String? _swapRequestsError;
  String? _swapRequestDetailError;
  String? _resourceDetailError;
  SwapAgreement? _activeAgreement;
  bool _agreementLoading = false;
  String? _agreementError;
  final Map<String, EventPresenceGrant> _presenceGrants = {};
  bool _presenceGrantLoading = false;
  String? _presenceGrantError;
  SwapConversationProjection? _conversation;
  String? _conversationRequestId;
  bool _conversationLoading = false;
  bool _conversationSending = false;
  bool _conversationSendOutcomeUnknown = false;
  bool _conversationMarkingRead = false;
  String? _conversationError;
  String? _commandError;
  String? _commandCorrelationId;
  DateTime? _commandRetryAt;
  DateTime? _selectionRetryAt;
  SwapIntentState? _intentFilter;
  String? _publishedPostsContextRef;
  SwapRequestState? _swapRequestFilter;
  _PendingIntentCommand? _pendingIntentCommand;
  _PendingEvidenceCommand? _pendingEvidenceCommand;
  _PendingSwapRequestCommand? _pendingSwapRequestCommand;
  int _sessionGeneration = 0;
  int _detailRequestVersion = 0;
  int _resourceDetailRequestVersion = 0;
  int _postListRequestVersion = 0;
  int _intentListRequestVersion = 0;
  int _publishedPostListRequestVersion = 0;
  int _publishedPostDetailRequestVersion = 0;
  int _swapRequestListRequestVersion = 0;
  int _swapRequestDetailRequestVersion = 0;
  int _agreementRequestVersion = 0;
  int _conversationRequestVersion = 0;

  List<EvidenceProjection> get evidence => List.unmodifiable(_evidence);
  List<EntitlementProjection> get entitlements =>
      List.unmodifiable(_entitlements);
  List<EntitlementProjection> get eligibleEntitlements {
    if (!_postDataCurrent) return const [];
    final now = _clock().toUtc();
    return List.unmodifiable(
      _entitlements.where((item) {
        final eligibility = item.eligibility;
        return item.state == EntitlementState.eligible &&
            eligibility.decision == EligibilityDecision.eligible &&
            eligibility.revokedAt == null &&
            eligibility.validUntil.toUtc().isAfter(now);
      }),
    );
  }

  List<SwapIntentProjection> get intents => List.unmodifiable(_intents);
  List<SwapPostProjection> get publishedPosts =>
      List.unmodifiable(_publishedPosts);
  List<SwapRequestProjection> get swapRequests =>
      List.unmodifiable(_swapRequests);
  List<SwapRequestProjection> get incomingSwapRequests => List.unmodifiable(
    _swapRequests.where((item) => item.role == SwapRequestRole.targetOwner),
  );
  List<SwapRequestProjection> get outgoingSwapRequests => List.unmodifiable(
    _swapRequests.where((item) => item.role == SwapRequestRole.requester),
  );
  SwapIntentDetail? get detail => _detail;
  SwapPostProjection? get publishedPostDetail => _publishedPostDetail;
  SwapRequestDetail? get swapRequestDetail => _swapRequestDetail;
  EvidenceProjection? get evidenceDetail => _evidenceDetail;
  EntitlementProjection? get entitlementDetail => _entitlementDetail;
  bool get postLoading => _postLoading;
  bool get evidenceLoadingMore => _evidenceLoadingMore;
  bool get entitlementsLoadingMore => _entitlementsLoadingMore;
  bool get intentsLoading => _intentsLoading;
  bool get intentsLoadingMore => _intentsLoadingMore;
  bool get detailLoading => _detailLoading;
  bool get publishedPostsLoading => _publishedPostsLoading;
  bool get publishedPostsLoadingMore => _publishedPostsLoadingMore;
  bool get publishedPostDetailLoading => _publishedPostDetailLoading;
  bool get swapRequestsLoading => _swapRequestsLoading;
  bool get swapRequestsLoadingMore => _swapRequestsLoadingMore;
  bool get swapRequestDetailLoading => _swapRequestDetailLoading;
  bool get resourceDetailLoading => _resourceDetailLoading;
  bool get commandRunning => _commandRunning;
  bool get commandBlocked => _commandRunning || canRetryUnknownCommand;
  bool get selectionBlocked =>
      commandBlocked || (_selectionRetryAt?.isAfter(_clock().toUtc()) ?? false);
  bool get hasMoreEvidence => _evidence.length < _evidenceTotal;
  bool get hasMoreEntitlements => _entitlements.length < _entitlementsTotal;
  bool get hasMoreIntents => _intents.length < _intentsTotal;
  bool get hasMorePublishedPosts =>
      _publishedPosts.length < _publishedPostsTotal;
  bool get hasMoreSwapRequests => _swapRequests.length < _swapRequestsTotal;
  int get evidenceTotal => _evidenceTotal;
  int get entitlementTotal => _entitlementsTotal;
  int get intentTotal => _intentsTotal;
  int get publishedPostTotal => _publishedPostsTotal;
  int get swapRequestTotal => _swapRequestsTotal;
  String? get postError => _postError;
  String? get intentsError => _intentsError;
  String? get detailError => _detailError;
  String? get publishedPostsError => _publishedPostsError;
  String? get publishedPostDetailError => _publishedPostDetailError;
  String? get swapRequestsError => _swapRequestsError;
  String? get swapRequestDetailError => _swapRequestDetailError;
  String? get resourceDetailError => _resourceDetailError;
  String? get commandError => _commandError;
  String? get commandCorrelationId => _commandCorrelationId;
  DateTime? get commandRetryAt => _commandRetryAt;
  DateTime? get selectionRetryAt => _selectionRetryAt;
  bool get canRetryUnknownCommand =>
      _pendingIntentCommand != null ||
      _pendingEvidenceCommand != null ||
      _pendingSwapRequestCommand != null;
  SwapAgreement? get activeAgreement => _activeAgreement;
  bool get isLoadingAgreement => _agreementLoading;
  String? get agreementError => _agreementError;
  bool get presenceGrantLoading => _presenceGrantLoading;
  String? get presenceGrantError => _presenceGrantError;
  SwapConversationProjection? get conversation => _conversation;
  String? get conversationRequestId => _conversationRequestId;
  bool get conversationLoading => _conversationLoading;
  bool get conversationSending => _conversationSending;
  bool get conversationSendOutcomeUnknown => _conversationSendOutcomeUnknown;
  bool get conversationMarkingRead => _conversationMarkingRead;
  String? get conversationError => _conversationError;

  Future<void> loadAgreement(String agreementId) async {
    final session = _sessionGeneration;
    final request = ++_agreementRequestVersion;
    _agreementLoading = true;
    _agreementError = null;
    notifyListeners();
    try {
      final loaded = await _gateway.getAgreement(agreementId);
      if (!_agreementRequestIsCurrent(session, request)) return;
      if (loaded.id != agreementId) {
        throw const ExchangeContractException(
          'The agreement could not be verified. Refresh and try again.',
        );
      }
      _activeAgreement = loaded;
    } on ApiRequestException catch (error) {
      if (_agreementRequestIsCurrent(session, request)) {
        _agreementError = error.message;
      }
    } on ExchangeContractException catch (error) {
      if (_agreementRequestIsCurrent(session, request)) {
        _agreementError = error.message;
      }
    } catch (_) {
      if (_agreementRequestIsCurrent(session, request)) {
        _agreementError = 'The swap agreement could not be loaded.';
      }
    } finally {
      if (_agreementRequestIsCurrent(session, request)) {
        _agreementLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> confirmAgreementTransfer({
    required String agreementId,
    required int expectedVersion,
  }) async {
    _agreementError =
        'This action is no longer available. Verify your event presence and '
        'open the latest agreement before continuing.';
    notifyListeners();
  }

  Future<bool> acquireFreshEventPresenceGrant({
    required String contextRef,
    required PresenceObservationLoader loadObservation,
    String? deviceIntegrityToken,
  }) async {
    if (_presenceGrantLoading) return false;
    final session = _sessionGeneration;
    _presenceGrantLoading = true;
    _presenceGrantError = null;
    _presenceGrants.remove(contextRef);
    notifyListeners();
    try {
      final observation = await loadObservation();
      if (!_scopeIsCurrent(session)) return false;
      final request = EventPresenceGrantRequest(
        contextRef: contextRef,
        latitude: observation.latitude,
        longitude: observation.longitude,
        accuracyMeters: observation.accuracyMeters,
        observedAt: observation.observedAt,
        deviceIntegrityToken: deviceIntegrityToken,
      );
      final grant = await _gateway.issueEventPresenceGrant(request);
      if (!_scopeIsCurrent(session)) return false;
      if (grant.contextRef != contextRef ||
          !grant.isUsableAt(_clock().toUtc())) {
        throw const ExchangeContractException(
          'Your event presence could not be verified. Try again.',
        );
      }
      _presenceGrants[contextRef] = grant;
      return true;
    } on ApiRequestException catch (error) {
      if (_scopeIsCurrent(session)) _presenceGrantError = error.message;
      return false;
    } on ExchangeContractException catch (error) {
      if (_scopeIsCurrent(session)) _presenceGrantError = error.message;
      return false;
    } catch (_) {
      if (_scopeIsCurrent(session)) {
        _presenceGrantError =
            'Fresh event presence could not be verified. Try again.';
      }
      return false;
    } finally {
      if (_scopeIsCurrent(session)) {
        _presenceGrantLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> recordAgreementConsent({
    required SwapAgreement agreement,
    required String contextRef,
  }) => _runPresenceAgreementCommand(
    agreement: agreement,
    contextRef: contextRef,
    command: (grant, key) => _gateway.recordAgreementConsent(
      agreement.id,
      presenceGrant: grant,
      expectedVersion: agreement.version,
      idempotencyKey: key,
    ),
  );

  Future<bool> recordAgreementHandoff({
    required SwapAgreement agreement,
    required String contextRef,
  }) => _runPresenceAgreementCommand(
    agreement: agreement,
    contextRef: contextRef,
    command: (grant, key) => _gateway.recordAgreementHandoff(
      agreement.id,
      presenceGrant: grant,
      expectedVersion: agreement.version,
      idempotencyKey: key,
    ),
  );

  Future<bool> recordAgreementCashConfirmation({
    required SwapAgreement agreement,
    required String contextRef,
  }) => _runPresenceAgreementCommand(
    agreement: agreement,
    contextRef: contextRef,
    command: (grant, key) => _gateway.recordAgreementCashConfirmation(
      agreement.id,
      presenceGrant: grant,
      expectedVersion: agreement.version,
      idempotencyKey: key,
    ),
  );

  Future<bool> cancelActiveAgreement({String? reason}) => _runAgreementCommand(
    (agreement, key) => _gateway.cancelAgreement(
      agreement.id,
      reason: reason,
      idempotencyKey: key,
    ),
  );

  Future<bool> disputeActiveAgreement(String reason) => _runAgreementCommand(
    (agreement, key) => _gateway.disputeAgreement(
      agreement.id,
      reason: reason,
      idempotencyKey: key,
    ),
  );

  Future<bool> _runPresenceAgreementCommand({
    required SwapAgreement agreement,
    required String contextRef,
    required Future<SwapAgreement> Function(EventPresenceGrant, String) command,
  }) async {
    final grant = _presenceGrants[contextRef];
    if (grant == null || !grant.isUsableAt(_clock().toUtc())) {
      _presenceGrants.remove(contextRef);
      _agreementError =
          'Refresh your in-event presence immediately before this action.';
      notifyListeners();
      return false;
    }
    return _runAgreementCommand(
      (current, key) => command(grant, key),
      expectedAgreementId: agreement.id,
      consumedPresenceContextRef: contextRef,
    );
  }

  Future<bool> _runAgreementCommand(
    Future<SwapAgreement> Function(SwapAgreement, String) command, {
    String? expectedAgreementId,
    String? consumedPresenceContextRef,
  }) async {
    if (_agreementLoading) return false;
    final agreement = _activeAgreement;
    if (agreement == null ||
        (expectedAgreementId != null && agreement.id != expectedAgreementId)) {
      _agreementError = 'Load the latest swap agreement before continuing.';
      notifyListeners();
      return false;
    }
    final session = _sessionGeneration;
    _agreementLoading = true;
    _agreementError = null;
    notifyListeners();
    try {
      final updated = await command(agreement, newExchangeIdempotencyKey());
      if (!_scopeIsCurrent(session)) return false;
      if (updated.id != agreement.id) {
        throw const ExchangeContractException(
          'The agreement command returned a different agreement.',
        );
      }
      _activeAgreement = updated;
      return true;
    } on ApiRequestException catch (error) {
      if (_scopeIsCurrent(session)) {
        _agreementError = error.outcomeUnknown
            ? 'The agreement action may have completed. Refresh the agreement '
                  'before attempting another action.'
            : error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_scopeIsCurrent(session)) _agreementError = error.message;
      return false;
    } catch (_) {
      if (_scopeIsCurrent(session)) {
        _agreementError = 'The agreement action could not be completed.';
      }
      return false;
    } finally {
      if (_scopeIsCurrent(session)) {
        if (consumedPresenceContextRef != null) {
          _presenceGrants.remove(consumedPresenceContextRef);
        }
        _agreementLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadSwapConversation(String requestId) async {
    final session = _sessionGeneration;
    final request = ++_conversationRequestVersion;
    final canResolveUnknownSend = _conversationSendOutcomeUnknown;
    _conversationLoading = true;
    _conversationError = null;
    _conversationRequestId = requestId;
    notifyListeners();
    try {
      final loaded = await _gateway.getSwapConversation(requestId);
      if (!_conversationRequestIsCurrent(session, request, requestId)) {
        return false;
      }
      if (loaded.swapRequestId != requestId) {
        throw const ExchangeContractException(
          'The conversation belongs to a different Swap Request.',
        );
      }
      _conversation = _mergeConversation(_conversation, loaded);
      if (canResolveUnknownSend) {
        _conversationSendOutcomeUnknown = false;
      }
      return true;
    } on ApiRequestException catch (error) {
      if (_conversationRequestIsCurrent(session, request, requestId)) {
        _conversationError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_conversationRequestIsCurrent(session, request, requestId)) {
        _conversationError = error.message;
      }
      return false;
    } catch (_) {
      if (_conversationRequestIsCurrent(session, request, requestId)) {
        _conversationError = 'The swap conversation could not be loaded.';
      }
      return false;
    } finally {
      if (_conversationRequestIsCurrent(session, request, requestId)) {
        _conversationLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> sendSwapConversationMessage(
    String requestId,
    String body,
  ) async {
    if (_conversationSending || _conversationSendOutcomeUnknown) return false;
    final session = _sessionGeneration;
    _conversationSending = true;
    _conversationError = null;
    notifyListeners();
    try {
      final message = await _gateway.sendSwapMessage(
        requestId,
        SendSwapMessageRequest(body),
        idempotencyKey: newExchangeIdempotencyKey(),
      );
      if (!_scopeIsCurrent(session)) return false;
      _conversationSendOutcomeUnknown = false;
      final current = _conversation;
      if (current != null &&
          current.swapRequestId == requestId &&
          current.id == message.conversationId) {
        _conversation = SwapConversationProjection(
          id: current.id,
          swapRequestId: current.swapRequestId,
          messages: List.unmodifiable([
            ...current.messages.where((item) => item.id != message.id),
            message,
          ]),
          unreadCount: current.unreadCount,
          createdAt: current.createdAt,
          updatedAt: message.createdAt,
        );
      } else {
        await loadSwapConversation(requestId);
      }
      return true;
    } on ApiRequestException catch (error) {
      if (_scopeIsCurrent(session)) {
        _conversationError = error.outcomeUnknown
            ? 'The message may have been sent. Refresh the conversation before '
                  'sending it again.'
            : error.message;
        if (error.outcomeUnknown) _conversationSendOutcomeUnknown = true;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_scopeIsCurrent(session)) _conversationError = error.message;
      return false;
    } catch (_) {
      if (_scopeIsCurrent(session)) {
        _conversationError = 'The message could not be sent.';
      }
      return false;
    } finally {
      if (_scopeIsCurrent(session)) {
        _conversationSending = false;
        notifyListeners();
      }
    }
  }

  Future<bool> markSwapConversationRead(String requestId) async {
    if (_conversationMarkingRead) return false;
    final session = _sessionGeneration;
    _conversationMarkingRead = true;
    _conversationError = null;
    notifyListeners();
    try {
      await _gateway.markSwapConversationRead(
        requestId,
        idempotencyKey: newExchangeIdempotencyKey(),
      );
      if (!_scopeIsCurrent(session)) return false;
      return loadSwapConversation(requestId);
    } on ApiRequestException catch (error) {
      if (_scopeIsCurrent(session)) _conversationError = error.message;
      return false;
    } on ExchangeContractException catch (error) {
      if (_scopeIsCurrent(session)) _conversationError = error.message;
      return false;
    } catch (_) {
      if (_scopeIsCurrent(session)) {
        _conversationError = 'Conversation read status could not be updated.';
      }
      return false;
    } finally {
      if (_scopeIsCurrent(session)) {
        _conversationMarkingRead = false;
        notifyListeners();
      }
    }
  }

  String? get pendingCommandLabel =>
      _pendingIntentCommand?.label ??
      _pendingEvidenceCommand?.label ??
      _pendingSwapRequestCommand?.label;

  /// Must be called whenever the authenticated server session changes.
  void resetForSession() {
    _sessionGeneration++;
    _detailRequestVersion++;
    _resourceDetailRequestVersion++;
    _postListRequestVersion++;
    _intentListRequestVersion++;
    _publishedPostListRequestVersion++;
    _publishedPostDetailRequestVersion++;
    _swapRequestListRequestVersion++;
    _swapRequestDetailRequestVersion++;
    _agreementRequestVersion++;
    _conversationRequestVersion++;
    _evidence = const [];
    _entitlements = const [];
    _intents = const [];
    _publishedPosts = const [];
    _swapRequests = const [];
    _detail = null;
    _publishedPostDetail = null;
    _swapRequestDetail = null;
    _evidenceDetail = null;
    _entitlementDetail = null;
    _activeAgreement = null;
    _agreementLoading = false;
    _agreementError = null;
    _presenceGrants.clear();
    _presenceGrantLoading = false;
    _presenceGrantError = null;
    _conversation = null;
    _conversationRequestId = null;
    _conversationLoading = false;
    _conversationSending = false;
    _conversationSendOutcomeUnknown = false;
    _conversationMarkingRead = false;
    _conversationError = null;
    _postLoading = false;
    _postDataCurrent = false;
    _evidenceLoadingMore = false;
    _entitlementsLoadingMore = false;
    _intentsLoading = false;
    _intentsLoadingMore = false;
    _detailLoading = false;
    _publishedPostsLoading = false;
    _publishedPostsLoadingMore = false;
    _publishedPostDetailLoading = false;
    _swapRequestsLoading = false;
    _swapRequestsLoadingMore = false;
    _swapRequestDetailLoading = false;
    _resourceDetailLoading = false;
    _commandRunning = false;
    _evidenceTotal = 0;
    _entitlementsTotal = 0;
    _intentsTotal = 0;
    _publishedPostsTotal = 0;
    _swapRequestsTotal = 0;
    _postError = null;
    _intentsError = null;
    _detailError = null;
    _publishedPostsError = null;
    _publishedPostDetailError = null;
    _swapRequestsError = null;
    _swapRequestDetailError = null;
    _resourceDetailError = null;
    _commandError = null;
    _commandCorrelationId = null;
    _commandRetryAt = null;
    _selectionRetryAt = null;
    _intentFilter = null;
    _publishedPostsContextRef = null;
    _swapRequestFilter = null;
    _pendingIntentCommand = null;
    _pendingEvidenceCommand = null;
    _pendingSwapRequestCommand = null;
    notifyListeners();
  }

  Future<bool> loadPostData() async {
    if (_postLoading) return false;
    final scope = _sessionGeneration;
    final requestVersion = ++_postListRequestVersion;
    _postLoading = true;
    _evidenceLoadingMore = false;
    _entitlementsLoadingMore = false;
    _postDataCurrent = false;
    _postError = null;
    notifyListeners();
    try {
      final evidenceFuture = _gateway.listEvidence(limit: 100);
      final entitlementFuture = _gateway.listEntitlements(limit: 100);
      final evidencePage = await evidenceFuture;
      final entitlementPage = await entitlementFuture;
      if (!_postRequestIsCurrent(scope, requestVersion)) return false;
      _evidence = evidencePage.items;
      _entitlements = entitlementPage.items;
      _evidenceTotal = evidencePage.total;
      _entitlementsTotal = entitlementPage.total;
      _postDataCurrent = true;
      return true;
    } on ApiRequestException catch (error) {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postError = error.message;
      }
      return false;
    } catch (_) {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postError =
            'Your exchange eligibility could not be loaded. Try again.';
      }
      return false;
    } finally {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadMoreEvidence() async {
    if (_evidenceLoadingMore || !hasMoreEvidence) return false;
    final scope = _sessionGeneration;
    final requestVersion = _postListRequestVersion;
    _evidenceLoadingMore = true;
    _postError = null;
    notifyListeners();
    try {
      final page = await _gateway.listEvidence(
        limit: 100,
        offset: _evidence.length,
      );
      if (!_postRequestIsCurrent(scope, requestVersion)) return false;
      _evidence = _mergeById(_evidence, page.items, (item) => item.id);
      _evidenceTotal = page.total;
      return true;
    } on ApiRequestException catch (error) {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postError = error.message;
      }
      return false;
    } catch (_) {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postError = 'More evidence records could not be loaded.';
      }
      return false;
    } finally {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _evidenceLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadMoreEntitlements() async {
    if (_entitlementsLoadingMore || !hasMoreEntitlements) return false;
    final scope = _sessionGeneration;
    final requestVersion = _postListRequestVersion;
    _entitlementsLoadingMore = true;
    _postError = null;
    notifyListeners();
    try {
      final page = await _gateway.listEntitlements(
        limit: 100,
        offset: _entitlements.length,
      );
      if (!_postRequestIsCurrent(scope, requestVersion)) return false;
      _entitlements = _mergeById(_entitlements, page.items, (item) => item.id);
      _entitlementsTotal = page.total;
      return true;
    } on ApiRequestException catch (error) {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postError = error.message;
      }
      return false;
    } catch (_) {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _postError = 'More entitlements could not be loaded.';
      }
      return false;
    } finally {
      if (_postRequestIsCurrent(scope, requestVersion)) {
        _entitlementsLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadIntents({SwapIntentState? state, bool force = false}) async {
    if (_intentsLoading && !force) return false;
    final scope = _sessionGeneration;
    final requestVersion = ++_intentListRequestVersion;
    _intentFilter = state;
    _intentsLoading = true;
    _intentsLoadingMore = false;
    _intentsError = null;
    notifyListeners();
    try {
      final page = await _gateway.listSwapIntents(limit: 100, state: state);
      if (!_intentListRequestIsCurrent(scope, requestVersion)) return false;
      _intents = page.items;
      _intentsTotal = page.total;
      return true;
    } on ApiRequestException catch (error) {
      if (_intentListRequestIsCurrent(scope, requestVersion)) {
        _intentsError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_intentListRequestIsCurrent(scope, requestVersion)) {
        _intentsError = error.message;
      }
      return false;
    } catch (_) {
      if (_intentListRequestIsCurrent(scope, requestVersion)) {
        _intentsError = 'Your swap intents could not be loaded. Try again.';
      }
      return false;
    } finally {
      if (_intentListRequestIsCurrent(scope, requestVersion)) {
        _intentsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadMoreIntents() async {
    if (_intentsLoadingMore || !hasMoreIntents) return false;
    final scope = _sessionGeneration;
    final requestVersion = _intentListRequestVersion;
    _intentsLoadingMore = true;
    _intentsError = null;
    notifyListeners();
    try {
      final page = await _gateway.listSwapIntents(
        limit: 100,
        offset: _intents.length,
        state: _intentFilter,
      );
      if (!_intentListRequestIsCurrent(scope, requestVersion)) return false;
      _intents = _mergeById(_intents, page.items, (item) => item.id);
      _intentsTotal = page.total;
      return true;
    } on ApiRequestException catch (error) {
      if (_intentListRequestIsCurrent(scope, requestVersion)) {
        _intentsError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_intentListRequestIsCurrent(scope, requestVersion)) {
        _intentsError = error.message;
      }
      return false;
    } catch (_) {
      if (_intentListRequestIsCurrent(scope, requestVersion)) {
        _intentsError = 'More swap intents could not be loaded.';
      }
      return false;
    } finally {
      if (_intentListRequestIsCurrent(scope, requestVersion)) {
        _intentsLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadIntentDetail(String intentId) async {
    final scope = _sessionGeneration;
    final requestVersion = ++_detailRequestVersion;
    _detailLoading = true;
    _detailError = null;
    notifyListeners();
    try {
      final result = await _gateway.getSwapIntent(intentId);
      if (!_detailRequestIsCurrent(scope, requestVersion)) return false;
      _detail = result;
      _upsertIntent(result.intent);
      return true;
    } on ApiRequestException catch (error) {
      if (!_detailRequestIsCurrent(scope, requestVersion)) return false;
      _detailError = error.message;
      if (error.statusCode == 404) {
        _detail = null;
        _intents = _intents.where((item) => item.id != intentId).toList();
        _intentsTotal = (_intentsTotal - 1).clamp(0, 1000000);
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_detailRequestIsCurrent(scope, requestVersion)) {
        _detailError = error.message;
      }
      return false;
    } catch (_) {
      if (_detailRequestIsCurrent(scope, requestVersion)) {
        _detailError = 'This swap intent could not be loaded. Try again.';
      }
      return false;
    } finally {
      if (_detailRequestIsCurrent(scope, requestVersion)) {
        _detailLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadPublishedPosts({
    String? contextRef,
    bool force = false,
  }) async {
    if (_publishedPostsLoading && !force) return false;
    final scope = _sessionGeneration;
    final requestVersion = ++_publishedPostListRequestVersion;
    _publishedPostsContextRef = contextRef?.trim();
    _publishedPostsLoading = true;
    _publishedPostsLoadingMore = false;
    _publishedPostsError = null;
    notifyListeners();
    try {
      final page = await _gateway.listPublishedSwapPosts(
        contextRef: _publishedPostsContextRef,
        limit: 100,
      );
      if (!_publishedPostListIsCurrent(scope, requestVersion)) return false;
      _publishedPosts = page.items;
      _publishedPostsTotal = page.total;
      return true;
    } on ApiRequestException catch (error) {
      if (_publishedPostListIsCurrent(scope, requestVersion)) {
        _publishedPostsError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_publishedPostListIsCurrent(scope, requestVersion)) {
        _publishedPostsError = error.message;
      }
      return false;
    } catch (_) {
      if (_publishedPostListIsCurrent(scope, requestVersion)) {
        _publishedPostsError = 'Published seat Posts could not be loaded.';
      }
      return false;
    } finally {
      if (_publishedPostListIsCurrent(scope, requestVersion)) {
        _publishedPostsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadMorePublishedPosts() async {
    if (_publishedPostsLoadingMore || !hasMorePublishedPosts) return false;
    final scope = _sessionGeneration;
    final requestVersion = _publishedPostListRequestVersion;
    _publishedPostsLoadingMore = true;
    _publishedPostsError = null;
    notifyListeners();
    try {
      final page = await _gateway.listPublishedSwapPosts(
        contextRef: _publishedPostsContextRef,
        limit: 100,
        offset: _publishedPosts.length,
      );
      if (!_publishedPostListIsCurrent(scope, requestVersion)) return false;
      _publishedPosts = _mergeById(
        _publishedPosts,
        page.items,
        (item) => item.post.id,
      );
      _publishedPostsTotal = page.total;
      return true;
    } on ApiRequestException catch (error) {
      if (_publishedPostListIsCurrent(scope, requestVersion)) {
        _publishedPostsError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_publishedPostListIsCurrent(scope, requestVersion)) {
        _publishedPostsError = error.message;
      }
      return false;
    } catch (_) {
      if (_publishedPostListIsCurrent(scope, requestVersion)) {
        _publishedPostsError = 'More published Posts could not be loaded.';
      }
      return false;
    } finally {
      if (_publishedPostListIsCurrent(scope, requestVersion)) {
        _publishedPostsLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadPublishedPostDetail(String postId) async {
    final scope = _sessionGeneration;
    final requestVersion = ++_publishedPostDetailRequestVersion;
    _publishedPostDetailLoading = true;
    _publishedPostDetailError = null;
    notifyListeners();
    try {
      final result = await _gateway.getPublishedSwapPost(postId);
      if (!_publishedPostDetailIsCurrent(scope, requestVersion)) return false;
      _publishedPostDetail = result;
      _upsertPublishedPost(result);
      return true;
    } on ApiRequestException catch (error) {
      if (!_publishedPostDetailIsCurrent(scope, requestVersion)) return false;
      _publishedPostDetailError = error.message;
      if (error.statusCode == 404) {
        _publishedPostDetail = null;
        final removed = _publishedPosts.any((item) => item.post.id == postId);
        _publishedPosts = _publishedPosts
            .where((item) => item.post.id != postId)
            .toList();
        if (removed) {
          _publishedPostsTotal = (_publishedPostsTotal - 1).clamp(0, 1000000);
        }
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_publishedPostDetailIsCurrent(scope, requestVersion)) {
        _publishedPostDetailError = error.message;
      }
      return false;
    } catch (_) {
      if (_publishedPostDetailIsCurrent(scope, requestVersion)) {
        _publishedPostDetailError = 'This published Post could not be loaded.';
      }
      return false;
    } finally {
      if (_publishedPostDetailIsCurrent(scope, requestVersion)) {
        _publishedPostDetailLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadSwapRequests({
    SwapRequestState? state,
    bool force = false,
  }) async {
    if (_swapRequestsLoading && !force) return false;
    final scope = _sessionGeneration;
    final requestVersion = ++_swapRequestListRequestVersion;
    _swapRequestFilter = state;
    _swapRequestsLoading = true;
    _swapRequestsLoadingMore = false;
    _swapRequestsError = null;
    notifyListeners();
    try {
      final page = await _gateway.listSwapRequests(limit: 100, state: state);
      if (!_swapRequestListIsCurrent(scope, requestVersion)) return false;
      _swapRequests = page.items;
      _swapRequestsTotal = page.total;
      return true;
    } on ApiRequestException catch (error) {
      if (_swapRequestListIsCurrent(scope, requestVersion)) {
        _swapRequestsError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_swapRequestListIsCurrent(scope, requestVersion)) {
        _swapRequestsError = error.message;
      }
      return false;
    } catch (_) {
      if (_swapRequestListIsCurrent(scope, requestVersion)) {
        _swapRequestsError = 'Your Swap Requests could not be loaded.';
      }
      return false;
    } finally {
      if (_swapRequestListIsCurrent(scope, requestVersion)) {
        _swapRequestsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadMoreSwapRequests() async {
    if (_swapRequestsLoadingMore || !hasMoreSwapRequests) return false;
    final scope = _sessionGeneration;
    final requestVersion = _swapRequestListRequestVersion;
    _swapRequestsLoadingMore = true;
    _swapRequestsError = null;
    notifyListeners();
    try {
      final page = await _gateway.listSwapRequests(
        limit: 100,
        offset: _swapRequests.length,
        state: _swapRequestFilter,
      );
      if (!_swapRequestListIsCurrent(scope, requestVersion)) return false;
      _swapRequests = _mergeById(_swapRequests, page.items, (item) => item.id);
      _swapRequestsTotal = page.total;
      return true;
    } on ApiRequestException catch (error) {
      if (_swapRequestListIsCurrent(scope, requestVersion)) {
        _swapRequestsError = error.message;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_swapRequestListIsCurrent(scope, requestVersion)) {
        _swapRequestsError = error.message;
      }
      return false;
    } catch (_) {
      if (_swapRequestListIsCurrent(scope, requestVersion)) {
        _swapRequestsError = 'More Swap Requests could not be loaded.';
      }
      return false;
    } finally {
      if (_swapRequestListIsCurrent(scope, requestVersion)) {
        _swapRequestsLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadSwapRequestDetail(String requestId) async {
    final scope = _sessionGeneration;
    final requestVersion = ++_swapRequestDetailRequestVersion;
    _swapRequestDetailLoading = true;
    _swapRequestDetailError = null;
    notifyListeners();
    try {
      final result = await _gateway.getSwapRequest(requestId);
      if (!_swapRequestDetailIsCurrent(scope, requestVersion)) return false;
      _swapRequestDetail = result;
      _upsertSwapRequest(result.swapRequest);
      return true;
    } on ApiRequestException catch (error) {
      if (!_swapRequestDetailIsCurrent(scope, requestVersion)) return false;
      _swapRequestDetailError = error.message;
      if (error.statusCode == 404) {
        _swapRequestDetail = null;
        final removed = _swapRequests.any((item) => item.id == requestId);
        _swapRequests = _swapRequests
            .where((item) => item.id != requestId)
            .toList();
        if (removed) {
          _swapRequestsTotal = (_swapRequestsTotal - 1).clamp(0, 1000000);
        }
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_swapRequestDetailIsCurrent(scope, requestVersion)) {
        _swapRequestDetailError = error.message;
      }
      return false;
    } catch (_) {
      if (_swapRequestDetailIsCurrent(scope, requestVersion)) {
        _swapRequestDetailError = 'This Swap Request could not be loaded.';
      }
      return false;
    } finally {
      if (_swapRequestDetailIsCurrent(scope, requestVersion)) {
        _swapRequestDetailLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadEvidenceDetail(String evidenceId) =>
      _loadResourceDetail(evidenceId, evidence: true);

  Future<bool> loadEntitlementDetail(String entitlementId) =>
      _loadResourceDetail(entitlementId, evidence: false);

  Future<bool> _loadResourceDetail(
    String resourceId, {
    required bool evidence,
  }) async {
    final scope = _sessionGeneration;
    final requestVersion = ++_resourceDetailRequestVersion;
    _resourceDetailLoading = true;
    _resourceDetailError = null;
    if (evidence) {
      _evidenceDetail = null;
    } else {
      _entitlementDetail = null;
    }
    notifyListeners();
    try {
      if (evidence) {
        final result = await _gateway.getEvidence(resourceId);
        if (!_resourceRequestIsCurrent(scope, requestVersion)) return false;
        _evidenceDetail = result;
        _evidence = [
          result,
          ..._evidence.where((item) => item.id != result.id),
        ];
      } else {
        final result = await _gateway.getEntitlement(resourceId);
        if (!_resourceRequestIsCurrent(scope, requestVersion)) return false;
        _entitlementDetail = result;
        _entitlements = [
          result,
          ..._entitlements.where((item) => item.id != result.id),
        ];
      }
      return true;
    } on ApiRequestException catch (error) {
      if (!_resourceRequestIsCurrent(scope, requestVersion)) return false;
      _resourceDetailError = error.message;
      if (error.statusCode == 404) {
        if (evidence) {
          _evidence = _evidence.where((item) => item.id != resourceId).toList();
          _evidenceTotal = (_evidenceTotal - 1).clamp(0, 1000000);
        } else {
          _entitlements = _entitlements
              .where((item) => item.id != resourceId)
              .toList();
          _entitlementsTotal = (_entitlementsTotal - 1).clamp(0, 1000000);
        }
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_resourceRequestIsCurrent(scope, requestVersion)) {
        _resourceDetailError = error.message;
      }
      return false;
    } catch (_) {
      if (_resourceRequestIsCurrent(scope, requestVersion)) {
        _resourceDetailError = evidence
            ? 'This evidence record could not be loaded.'
            : 'This entitlement could not be loaded.';
      }
      return false;
    } finally {
      if (_resourceRequestIsCurrent(scope, requestVersion)) {
        _resourceDetailLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> submitEvidence(EvidenceSubmissionRequest request) {
    final key = newExchangeIdempotencyKey();
    return _runEvidenceCommand(
      _PendingEvidenceCommand(
        label: 'evidence submission',
        run: () => _gateway.submitEvidence(request, idempotencyKey: key),
      ),
    );
  }

  Future<bool> createIntent(CreateSwapIntentRequest request) {
    final offeredEntitlementId = request.offeredEntitlementId;
    if (offeredEntitlementId != null &&
        !eligibleEntitlements.any((item) => item.id == offeredEntitlementId)) {
      _commandError =
          'Refresh eligibility and choose a current, unrevoked entitlement.';
      notifyListeners();
      return Future.value(false);
    }
    final key = newExchangeIdempotencyKey();
    return _runIntentCommand(
      _PendingIntentCommand(
        label: 'create draft',
        run: () => _gateway.createSwapIntent(request, idempotencyKey: key),
      ),
    );
  }

  Future<bool> updateIntent(String intentId, UpdateSwapIntentRequest request) {
    final key = newExchangeIdempotencyKey();
    return _runIntentCommand(
      _PendingIntentCommand(
        label: 'save changes',
        intentId: intentId,
        run: () =>
            _gateway.updateSwapIntent(intentId, request, idempotencyKey: key),
      ),
    );
  }

  Future<bool> publishIntent(SwapIntentProjection intent) =>
      _lifecycleCommand(intent, 'publish');

  Future<bool> pauseIntent(SwapIntentProjection intent) =>
      _lifecycleCommand(intent, 'pause');

  Future<bool> resumeIntent(SwapIntentProjection intent) =>
      _lifecycleCommand(intent, 'resume');

  Future<bool> withdrawIntent(SwapIntentProjection intent) =>
      _lifecycleCommand(intent, 'withdraw');

  Future<bool> _lifecycleCommand(SwapIntentProjection intent, String command) {
    final key = newExchangeIdempotencyKey();
    Future<SwapIntentProjection> run() => switch (command) {
      'publish' => _gateway.publishSwapIntent(
        intent.id,
        expectedVersion: intent.version,
        idempotencyKey: key,
      ),
      'pause' => _gateway.pauseSwapIntent(
        intent.id,
        expectedVersion: intent.version,
        idempotencyKey: key,
      ),
      'resume' => _gateway.resumeSwapIntent(
        intent.id,
        expectedVersion: intent.version,
        idempotencyKey: key,
      ),
      'withdraw' => _gateway.withdrawSwapIntent(
        intent.id,
        expectedVersion: intent.version,
        idempotencyKey: key,
      ),
      _ => throw StateError('Unsupported lifecycle command.'),
    };
    return _runIntentCommand(
      _PendingIntentCommand(
        label: '$command intent',
        intentId: intent.id,
        run: run,
      ),
    );
  }

  Future<bool> createSwapRequest(
    SwapPostProjection target,
    SwapIntentProjection ownPost,
    CreateSwapRequestRequest request,
  ) {
    if (target.isOwnPost || !target.requestable) {
      _commandError = 'This Post is not available for a Swap Request.';
      notifyListeners();
      return Future.value(false);
    }
    if (ownPost.state != SwapIntentState.published ||
        swapIntentContextRef(ownPost) != swapIntentContextRef(target.post) ||
        swapIntentQuantity(ownPost) != swapIntentQuantity(target.post) ||
        request.counterpartyIntentId != ownPost.id ||
        request.targetIntentVersion != target.post.version ||
        request.counterpartyIntentVersion != ownPost.version) {
      _commandError =
          'Choose a current published Post for the same event and ticket quantity.';
      notifyListeners();
      return Future.value(false);
    }
    final requestExpiry = request.expiresAt.toUtc();
    if (requestExpiry.isAfter(target.post.expiresAt.toUtc()) ||
        requestExpiry.isAfter(ownPost.expiresAt.toUtc())) {
      _commandError = 'The request cannot expire after either Post.';
      notifyListeners();
      return Future.value(false);
    }
    final key = newExchangeIdempotencyKey();
    return _runSwapRequestCommand(
      _PendingSwapRequestCommand(
        label: 'submit Swap Request',
        contextRef: swapIntentContextRef(target.post),
        targetIntentId: target.post.id,
        counterpartyIntentId: ownPost.id,
        createExpiresAt: request.expiresAt.toUtc(),
        run: () => _gateway.createSwapRequest(
          target.post.id,
          request,
          idempotencyKey: key,
        ),
      ),
    );
  }

  Future<bool> selectSwapRequest(SwapRequestProjection request) async {
    if (_selectionRetryAt?.isAfter(_clock().toUtc()) ?? false) {
      _commandError =
          'The daily selection limit is still active. Try again after the '
          'time shown below.';
      notifyListeners();
      return false;
    }
    _selectionRetryAt = null;
    if (request.role != SwapRequestRole.targetOwner ||
        request.state != SwapRequestState.submitted) {
      _commandError = 'Only an incoming submitted request can be selected.';
      notifyListeners();
      return false;
    }
    final loaded = await loadSwapRequestDetail(request.id);
    if (!loaded) return false;
    final latest = _swapRequestDetail!.swapRequest;
    if (latest.role != SwapRequestRole.targetOwner ||
        latest.state != SwapRequestState.submitted) {
      _commandError = 'This request is no longer available to select.';
      notifyListeners();
      return false;
    }
    final key = newExchangeIdempotencyKey();
    final input = SelectSwapRequestRequest(
      expectedVersion: latest.version,
      targetIntentVersion: latest.targetPost.version,
      counterpartyIntentVersion: latest.counterpartyPost.version,
    );
    return _runSwapRequestCommand(
      _PendingSwapRequestCommand(
        label: 'select Swap Request',
        requestId: latest.id,
        contextRef: swapIntentContextRef(latest.targetPost),
        run: () =>
            _gateway.selectSwapRequest(latest.id, input, idempotencyKey: key),
      ),
    );
  }

  Future<bool> rejectSwapRequest(SwapRequestProjection request) =>
      _requestLifecycleCommand(request, 'reject');

  Future<bool> withdrawSwapRequest(SwapRequestProjection request) =>
      _requestLifecycleCommand(request, 'withdraw');

  Future<bool> _requestLifecycleCommand(
    SwapRequestProjection request,
    String command,
  ) {
    final allowed =
        request.state == SwapRequestState.submitted &&
        ((command == 'reject' && request.role == SwapRequestRole.targetOwner) ||
            (command == 'withdraw' &&
                request.role == SwapRequestRole.requester));
    if (!allowed) {
      _commandError = 'This Swap Request action is no longer available.';
      notifyListeners();
      return Future.value(false);
    }
    final key = newExchangeIdempotencyKey();
    Future<SwapRequestProjection> run() => switch (command) {
      'reject' => _gateway.rejectSwapRequest(
        request.id,
        expectedVersion: request.version,
        idempotencyKey: key,
      ),
      'withdraw' => _gateway.withdrawSwapRequest(
        request.id,
        expectedVersion: request.version,
        idempotencyKey: key,
      ),
      _ => throw StateError('Unsupported Swap Request command.'),
    };
    return _runSwapRequestCommand(
      _PendingSwapRequestCommand(
        label: '$command Swap Request',
        requestId: request.id,
        contextRef: swapIntentContextRef(request.targetPost),
        run: run,
      ),
    );
  }

  Future<bool> retryUnknownCommand() {
    final intentCommand = _pendingIntentCommand;
    if (intentCommand != null) {
      return _runIntentCommand(intentCommand, isRetry: true);
    }
    final evidenceCommand = _pendingEvidenceCommand;
    if (evidenceCommand != null) {
      return _runEvidenceCommand(evidenceCommand, isRetry: true);
    }
    final requestCommand = _pendingSwapRequestCommand;
    if (requestCommand != null) {
      final createExpiresAt = requestCommand.createExpiresAt;
      if (requestCommand.requestId == null &&
          createExpiresAt != null &&
          createExpiresAt.difference(_clock().toUtc()) <
              const Duration(minutes: 5)) {
        return _reconcileExpiredUnknownRequestCreate(requestCommand);
      }
      return _runSwapRequestCommand(requestCommand, isRetry: true);
    }
    return Future.value(false);
  }

  Future<bool> _runEvidenceCommand(
    _PendingEvidenceCommand command, {
    bool isRetry = false,
  }) async {
    if (!_prepareCommand(isRetry: isRetry)) return false;
    final scope = _sessionGeneration;
    try {
      final result = await command.run();
      if (!_scopeIsCurrent(scope)) return false;
      _pendingEvidenceCommand = null;
      _evidence = [result, ..._evidence.where((item) => item.id != result.id)];
      _evidenceTotal = _evidenceTotal < _evidence.length
          ? _evidence.length
          : _evidenceTotal;
      return true;
    } on ApiRequestException catch (error) {
      if (!_scopeIsCurrent(scope)) return false;
      _recordCommandError(error);
      _pendingEvidenceCommand = error.outcomeUnknown ? command : null;
      return false;
    } on ExchangeContractException catch (error) {
      if (_scopeIsCurrent(scope)) {
        _pendingEvidenceCommand = null;
        _commandError = error.message;
      }
      return false;
    } catch (_) {
      if (_scopeIsCurrent(scope)) {
        _pendingEvidenceCommand = null;
        _commandError = 'The evidence submission could not be completed.';
      }
      return false;
    } finally {
      if (_scopeIsCurrent(scope)) {
        _commandRunning = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _runIntentCommand(
    _PendingIntentCommand command, {
    bool isRetry = false,
  }) async {
    if (!_prepareCommand(isRetry: isRetry)) return false;
    final scope = _sessionGeneration;
    try {
      final result = await command.run();
      if (!_scopeIsCurrent(scope)) return false;
      _pendingIntentCommand = null;
      _upsertIntent(result);
      if (_detail?.intent.id == result.id) {
        _detail = SwapIntentDetail(intent: result, timeline: _detail!.timeline);
        await loadIntentDetail(result.id);
      }
      await loadIntents(state: _intentFilter, force: true);
      return true;
    } on ApiRequestException catch (error) {
      if (!_scopeIsCurrent(scope)) return false;
      _recordCommandError(error);
      _pendingIntentCommand = error.outcomeUnknown ? command : null;
      if (!error.outcomeUnknown && error.statusCode == 409) {
        await _reconcileConflict(command.intentId);
      } else if (!error.outcomeUnknown && error.statusCode == 404) {
        await loadIntents(state: _intentFilter);
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_scopeIsCurrent(scope)) {
        _pendingIntentCommand = null;
        _commandError = error.message;
      }
      return false;
    } catch (_) {
      if (_scopeIsCurrent(scope)) {
        _pendingIntentCommand = null;
        _commandError = 'The swap command could not be completed. Try again.';
      }
      return false;
    } finally {
      if (_scopeIsCurrent(scope)) {
        _commandRunning = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _runSwapRequestCommand(
    _PendingSwapRequestCommand command, {
    bool isRetry = false,
  }) async {
    if (!_prepareCommand(isRetry: isRetry)) return false;
    final scope = _sessionGeneration;
    try {
      final result = await command.run();
      if (!_scopeIsCurrent(scope)) return false;
      _pendingSwapRequestCommand = null;
      _upsertSwapRequest(result);
      if (_swapRequestDetail?.swapRequest.id == result.id) {
        _swapRequestDetail = SwapRequestDetail(
          swapRequest: result,
          timeline: _swapRequestDetail!.timeline,
        );
        await loadSwapRequestDetail(result.id);
      }
      await Future.wait([
        loadIntents(state: _intentFilter, force: true),
        loadPublishedPosts(contextRef: command.contextRef, force: true),
        loadSwapRequests(state: _swapRequestFilter, force: true),
      ]);
      return true;
    } on ApiRequestException catch (error) {
      if (!_scopeIsCurrent(scope)) return false;
      _recordCommandError(error);
      _pendingSwapRequestCommand = error.outcomeUnknown ? command : null;
      if (!error.outcomeUnknown && error.statusCode == 409) {
        await _reconcileSwapRequestConflict(command, error.code);
        if (error.code == 'DAILY_SWAP_SELECTION_LIMIT_REACHED') {
          _commandError = error.message;
          _commandRetryAt = error.retryAt;
          _selectionRetryAt = error.retryAt;
        }
      } else if (!error.outcomeUnknown && error.statusCode == 404) {
        await Future.wait([
          loadPublishedPosts(contextRef: command.contextRef),
          loadSwapRequests(state: _swapRequestFilter),
          loadIntents(state: _intentFilter),
        ]);
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_scopeIsCurrent(scope)) {
        _pendingSwapRequestCommand = null;
        _commandError = error.message;
      }
      return false;
    } catch (_) {
      if (_scopeIsCurrent(scope)) {
        _pendingSwapRequestCommand = null;
        _commandError = 'The Swap Request action could not be completed.';
      }
      return false;
    } finally {
      if (_scopeIsCurrent(scope)) {
        _commandRunning = false;
        notifyListeners();
      }
    }
  }

  Future<void> _reconcileSwapRequestConflict(
    _PendingSwapRequestCommand command,
    String? code,
  ) async {
    final detailLoaded = command.requestId == null
        ? true
        : await loadSwapRequestDetail(command.requestId!);
    final results = await Future.wait([
      loadPublishedPosts(contextRef: command.contextRef),
      loadSwapRequests(state: _swapRequestFilter),
      loadIntents(state: _intentFilter),
    ]);
    if (detailLoaded && results.every((loaded) => loaded)) {
      _commandError = switch (code) {
        'SWAP_POST_CONTEXT_MISMATCH' =>
          'The two Posts no longer belong to the same event. The latest '
              'Posts are shown.',
        'SWAP_POST_QUANTITY_MISMATCH' =>
          'The two Posts no longer offer the same ticket quantity. The '
              'latest Posts are shown.',
        'SWAP_REQUEST_ALREADY_EXISTS' =>
          'A request between these Posts already exists. The latest request '
              'is shown.',
        'SWAP_POST_VERSION_CONFLICT' =>
          'One of the Posts changed. Review both latest Posts before trying '
              'again.',
        'SWAP_REQUEST_VERSION_CONFLICT' =>
          'This request changed. Review its latest state before trying again.',
        'SWAP_REQUEST_TRANSITION_INVALID' || 'SWAP_REQUEST_EXPIRED' =>
          'This request is no longer in a state that allows that action. The '
              'latest state is shown.',
        'SWAP_REQUEST_SELECTION_FORBIDDEN' =>
          'Only the owner of the target Post can select this request.',
        'SWAP_REQUEST_REJECTION_FORBIDDEN' =>
          'Only the owner of the target Post can reject this request.',
        'SWAP_REQUEST_WITHDRAWAL_FORBIDDEN' =>
          'Only the requester can withdraw this request.',
        _ =>
          'The request or a Post changed. The latest versions are shown; '
              'review them before trying a new action.',
      };
    } else {
      _commandError =
          'The request changed, but the latest state could not be loaded. '
          'Refresh before trying again.';
    }
  }

  Future<bool> _reconcileExpiredUnknownRequestCreate(
    _PendingSwapRequestCommand command,
  ) async {
    if (!_prepareCommand(isRetry: true)) return false;
    final scope = _sessionGeneration;
    try {
      var offset = 0;
      while (true) {
        final page = await _gateway.listSwapRequests(
          limit: 100,
          offset: offset,
        );
        if (!_scopeIsCurrent(scope)) return false;
        for (final request in page.items) {
          if (request.targetPost.id == command.targetIntentId &&
              request.counterpartyPost.id == command.counterpartyIntentId) {
            _pendingSwapRequestCommand = null;
            _upsertSwapRequest(request);
            _commandError =
                'Your original Swap Request was accepted. Its latest '
                'status is now shown.';
            return true;
          }
        }
        offset += page.items.length;
        if (page.items.isEmpty || offset >= page.total) break;
      }
      _pendingSwapRequestCommand = null;
      _commandError =
          'The original request is no longer available. Review the '
          'preserved form and submit it again with a new expiry.';
      return false;
    } on ApiRequestException catch (error) {
      if (_scopeIsCurrent(scope)) {
        _recordCommandError(error);
        _pendingSwapRequestCommand = command;
      }
      return false;
    } on ExchangeContractException catch (error) {
      if (_scopeIsCurrent(scope)) {
        _commandError = error.message;
        _pendingSwapRequestCommand = command;
      }
      return false;
    } catch (_) {
      if (_scopeIsCurrent(scope)) {
        _commandError =
            'The original request outcome is still unknown. Refresh and try '
            'the safe resolution again.';
        _pendingSwapRequestCommand = command;
      }
      return false;
    } finally {
      if (_scopeIsCurrent(scope)) {
        _commandRunning = false;
        notifyListeners();
      }
    }
  }

  Future<void> _reconcileConflict(String? intentId) async {
    final detailLoaded = intentId == null
        ? true
        : await loadIntentDetail(intentId);
    final results = await Future.wait([
      loadIntents(state: _intentFilter),
      loadPostData(),
    ]);
    if (detailLoaded && results.every((loaded) => loaded)) {
      _commandError =
          'This item changed. The latest version is shown; review it '
          'before trying a new action.';
    } else {
      _commandError =
          'This item changed, but the latest status could not be '
          'loaded. Refresh before trying another action.';
    }
  }

  bool _prepareCommand({required bool isRetry}) {
    if (_commandRunning) return false;
    if (!isRetry && canRetryUnknownCommand) {
      _commandError =
          'Resolve the request with an unknown outcome before starting a new '
          'exchange action.';
      notifyListeners();
      return false;
    }
    _commandRunning = true;
    _commandError = null;
    _commandCorrelationId = null;
    _commandRetryAt = null;
    notifyListeners();
    return true;
  }

  void _recordCommandError(ApiRequestException error) {
    _commandError = error.outcomeUnknown
        ? 'This request may have been accepted. Retry only with the '
              'safe retry action below.'
        : error.message;
    _commandCorrelationId = error.correlationId;
    _commandRetryAt = error.retryAt;
  }

  void _upsertIntent(SwapIntentProjection intent) {
    if (_intentFilter != null && intent.state != _intentFilter) {
      final removed = _intents.any((item) => item.id == intent.id);
      _intents = _intents.where((item) => item.id != intent.id).toList();
      if (removed) _intentsTotal = (_intentsTotal - 1).clamp(0, 1000000);
      return;
    }
    final existed = _intents.any((item) => item.id == intent.id);
    _intents = [intent, ..._intents.where((item) => item.id != intent.id)];
    if (!existed) _intentsTotal++;
  }

  void _upsertPublishedPost(SwapPostProjection post) {
    final existed = _publishedPosts.any((item) => item.post.id == post.post.id);
    _publishedPosts = [
      post,
      ..._publishedPosts.where((item) => item.post.id != post.post.id),
    ];
    if (!existed) _publishedPostsTotal++;
  }

  void _upsertSwapRequest(SwapRequestProjection request) {
    if (_swapRequestFilter != null && request.state != _swapRequestFilter) {
      final removed = _swapRequests.any((item) => item.id == request.id);
      _swapRequests = _swapRequests
          .where((item) => item.id != request.id)
          .toList();
      if (removed) {
        _swapRequestsTotal = (_swapRequestsTotal - 1).clamp(0, 1000000);
      }
      return;
    }
    final existed = _swapRequests.any((item) => item.id == request.id);
    _swapRequests = [
      request,
      ..._swapRequests.where((item) => item.id != request.id),
    ];
    if (!existed) _swapRequestsTotal++;
  }

  bool _scopeIsCurrent(int scope) => scope == _sessionGeneration;

  bool _agreementRequestIsCurrent(int scope, int request) =>
      _scopeIsCurrent(scope) && request == _agreementRequestVersion;

  bool _conversationRequestIsCurrent(
    int scope,
    int request,
    String requestId,
  ) =>
      _scopeIsCurrent(scope) &&
      request == _conversationRequestVersion &&
      _conversationRequestId == requestId;

  bool _detailRequestIsCurrent(int scope, int version) =>
      _scopeIsCurrent(scope) && version == _detailRequestVersion;

  bool _resourceRequestIsCurrent(int scope, int version) =>
      _scopeIsCurrent(scope) && version == _resourceDetailRequestVersion;

  bool _postRequestIsCurrent(int scope, int version) =>
      _scopeIsCurrent(scope) && version == _postListRequestVersion;

  bool _intentListRequestIsCurrent(int scope, int version) =>
      _scopeIsCurrent(scope) && version == _intentListRequestVersion;

  bool _publishedPostListIsCurrent(int scope, int version) =>
      _scopeIsCurrent(scope) && version == _publishedPostListRequestVersion;

  bool _publishedPostDetailIsCurrent(int scope, int version) =>
      _scopeIsCurrent(scope) && version == _publishedPostDetailRequestVersion;

  bool _swapRequestListIsCurrent(int scope, int version) =>
      _scopeIsCurrent(scope) && version == _swapRequestListRequestVersion;

  bool _swapRequestDetailIsCurrent(int scope, int version) =>
      _scopeIsCurrent(scope) && version == _swapRequestDetailRequestVersion;

  void clearCommandError() {
    if (_commandRunning) return;
    _commandError = null;
    _commandCorrelationId = null;
    _commandRetryAt = null;
    notifyListeners();
  }
}

class _PendingIntentCommand {
  const _PendingIntentCommand({
    required this.label,
    required this.run,
    this.intentId,
  });

  final String label;
  final String? intentId;
  final Future<SwapIntentProjection> Function() run;
}

class _PendingEvidenceCommand {
  const _PendingEvidenceCommand({required this.label, required this.run});

  final String label;
  final Future<EvidenceProjection> Function() run;
}

class _PendingSwapRequestCommand {
  const _PendingSwapRequestCommand({
    required this.label,
    required this.contextRef,
    required this.run,
    this.requestId,
    this.targetIntentId,
    this.counterpartyIntentId,
    this.createExpiresAt,
  });

  final String label;
  final String contextRef;
  final String? requestId;
  final String? targetIntentId;
  final String? counterpartyIntentId;
  final DateTime? createExpiresAt;
  final Future<SwapRequestProjection> Function() run;
}

List<T> _mergeById<T>(
  List<T> current,
  List<T> incoming,
  String Function(T item) idOf,
) {
  final seen = current.map(idOf).toSet();
  return [...current, ...incoming.where((item) => seen.add(idOf(item)))];
}

SwapConversationProjection _mergeConversation(
  SwapConversationProjection? current,
  SwapConversationProjection loaded,
) {
  if (current == null || current.id != loaded.id) return loaded;
  final messages = <String, SwapMessageProjection>{
    for (final message in loaded.messages) message.id: message,
  };
  for (final message in current.messages) {
    messages.putIfAbsent(message.id, () => message);
  }
  final ordered = messages.values.toList()
    ..sort((left, right) {
      final time = left.createdAt.compareTo(right.createdAt);
      return time != 0 ? time : left.id.compareTo(right.id);
    });
  return SwapConversationProjection(
    id: loaded.id,
    swapRequestId: loaded.swapRequestId,
    messages: List.unmodifiable(ordered),
    unreadCount: loaded.unreadCount,
    createdAt: loaded.createdAt,
    updatedAt: loaded.updatedAt.isAfter(current.updatedAt)
        ? loaded.updatedAt
        : current.updatedAt,
  );
}
