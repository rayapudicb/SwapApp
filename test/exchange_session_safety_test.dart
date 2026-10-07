import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_conversation_models.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_gateway.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_models.dart';
import 'package:swappy_mobile/features/exchange/providers/exchange_provider.dart';

const _agreementId = '11111111-1111-4111-8111-111111111111';
const _requestId = '22222222-2222-4222-8222-222222222222';
const _conversationId = '33333333-3333-4333-8333-333333333333';
const _messageId = '44444444-4444-4444-8444-444444444444';

void main() {
  test('rejects a late agreement response after session reset', () async {
    final gateway = _SafetyGateway()..holdAgreement = true;
    final provider = ExchangeProvider(gateway: gateway);

    final pending = provider.loadAgreement(_agreementId);
    await gateway.agreementStarted.future;
    provider.resetForSession();
    gateway.agreementResult.complete(_agreement());
    await pending;

    expect(provider.activeAgreement, isNull);
    expect(provider.isLoadingAgreement, isFalse);
    expect(provider.agreementError, isNull);
  });

  test(
    'unknown chat outcome blocks resubmission until authoritative refresh',
    () async {
      final gateway = _SafetyGateway()..failMessageUnknownOnce = true;
      final provider = ExchangeProvider(gateway: gateway);
      await provider.loadSwapConversation(_requestId);

      expect(
        await provider.sendSwapConversationMessage(_requestId, 'Meet at A12'),
        isFalse,
      );
      expect(provider.conversationSendOutcomeUnknown, isTrue);
      expect(
        await provider.sendSwapConversationMessage(_requestId, 'Meet at A12'),
        isFalse,
      );
      expect(gateway.sendCalls, 1);

      expect(await provider.loadSwapConversation(_requestId), isTrue);
      expect(provider.conversationSendOutcomeUnknown, isFalse);
      expect(
        await provider.sendSwapConversationMessage(_requestId, 'Meet at A12'),
        isTrue,
      );
      expect(gateway.sendCalls, 2);
    },
  );

  test(
    'a stale conversation refresh cannot erase a newly sent message',
    () async {
      final gateway = _SafetyGateway();
      final provider = ExchangeProvider(gateway: gateway);
      await provider.loadSwapConversation(_requestId);

      gateway.holdConversation = true;
      final staleRefresh = provider.loadSwapConversation(_requestId);
      await gateway.conversationStarted.future;
      expect(
        await provider.sendSwapConversationMessage(_requestId, 'Meet at A12'),
        isTrue,
      );
      gateway.conversationResult.complete(_conversation());
      await staleRefresh;

      expect(provider.conversation?.messages.map((item) => item.id), [
        _messageId,
      ]);
    },
  );

  test(
    'a refresh started before an unknown send cannot unlock resubmission',
    () async {
      final gateway = _SafetyGateway()..failMessageUnknownOnce = true;
      final provider = ExchangeProvider(gateway: gateway);
      await provider.loadSwapConversation(_requestId);

      gateway.holdConversation = true;
      final staleRefresh = provider.loadSwapConversation(_requestId);
      await gateway.conversationStarted.future;
      expect(
        await provider.sendSwapConversationMessage(_requestId, 'Meet at A12'),
        isFalse,
      );
      expect(provider.conversationSendOutcomeUnknown, isTrue);

      gateway.conversationResult.complete(_conversation());
      expect(await staleRefresh, isTrue);
      expect(provider.conversationSendOutcomeUnknown, isTrue);
      expect(
        await provider.sendSwapConversationMessage(_requestId, 'Meet at A12'),
        isFalse,
      );
      expect(gateway.sendCalls, 1);

      expect(await provider.loadSwapConversation(_requestId), isTrue);
      expect(provider.conversationSendOutcomeUnknown, isFalse);
    },
  );
}

class _SafetyGateway implements ExchangeGateway {
  bool holdAgreement = false;
  bool holdConversation = false;
  bool failMessageUnknownOnce = false;
  int sendCalls = 0;
  final agreementStarted = Completer<void>();
  final agreementResult = Completer<SwapAgreement>();
  final conversationStarted = Completer<void>();
  final conversationResult = Completer<SwapConversationProjection>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<SwapAgreement> getAgreement(String agreementId) {
    if (!holdAgreement) return Future.value(_agreement());
    agreementStarted.complete();
    return agreementResult.future;
  }

  @override
  Future<SwapConversationProjection> getSwapConversation(String requestId) {
    if (!holdConversation) return Future.value(_conversation());
    holdConversation = false;
    conversationStarted.complete();
    return conversationResult.future;
  }

  @override
  Future<SwapMessageProjection> sendSwapMessage(
    String requestId,
    SendSwapMessageRequest request, {
    required String idempotencyKey,
  }) async {
    sendCalls++;
    if (failMessageUnknownOnce) {
      failMessageUnknownOnce = false;
      throw const ApiRequestException(
        'Connection lost.',
        outcomeUnknown: true,
        isTransportFailure: true,
      );
    }
    return _message();
  }
}

SwapAgreement _agreement() => SwapAgreement(
  id: _agreementId,
  swapRequestId: _requestId,
  contextRef: 'ticketmaster:event:test-event',
  state: AgreementState.awaitingConsent,
  status: 'awaiting_consent',
  isPartyA: true,
  youConsented: false,
  counterpartyConsented: false,
  youConfirmedHandoff: false,
  counterpartyConfirmedHandoff: false,
  cashSettlement: null,
  holdExpiresAt: DateTime.utc(2026, 8, 24, 20),
  completedAt: null,
  cancelledAt: null,
  disputedAt: null,
  disputeReason: null,
  version: 1,
  createdAt: DateTime.utc(2026, 8, 24, 18),
  updatedAt: DateTime.utc(2026, 8, 24, 18),
);

SwapConversationProjection _conversation() => SwapConversationProjection(
  id: _conversationId,
  swapRequestId: _requestId,
  messages: const [],
  unreadCount: 0,
  createdAt: DateTime.utc(2026, 8, 24, 18),
  updatedAt: DateTime.utc(2026, 8, 24, 18),
);

SwapMessageProjection _message() => SwapMessageProjection(
  id: _messageId,
  conversationId: _conversationId,
  isViewer: true,
  body: 'Meet at A12',
  readAt: null,
  isFlagged: false,
  flagReason: null,
  createdAt: DateTime.utc(2026, 8, 24, 18, 1),
);
