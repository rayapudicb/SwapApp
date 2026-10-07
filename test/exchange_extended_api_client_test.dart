import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/exchange/data/exchange_api_client.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_conversation_models.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_models.dart';
import 'package:swappy_mobile/features/exchange/providers/exchange_provider.dart';
import 'package:swappy_mobile/features/home/domain/discovered_event.dart';

const agreementId = '11111111-1111-4111-8111-111111111111';
const requestId = '22222222-2222-4222-8222-222222222222';
const participantA = '33333333-3333-4333-8333-333333333333';
const participantB = '44444444-4444-4444-8444-444444444444';
const conversationId = '55555555-5555-4555-8555-555555555555';
const messageId = '66666666-6666-4666-8666-666666666666';
const contextRef = 'ticketmaster:event:city-finals';
const presenceRef =
    'presence://0123456789abcdef0123456789abcdef0123456789abcdef';
const commandKey = 'extended-command-key-1234567890';

void main() {
  test('issues a strict redacted one-use event presence grant', () async {
    final client = _gateway((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/v1/me/event-presence-grants');
      expect(jsonDecode(request.body), {
        'contextRef': contextRef,
        'latitude': 12.9716,
        'longitude': 77.5946,
        'accuracyMeters': 18.0,
        'observedAt': '2026-08-24T10:00:00.000Z',
        'deviceIntegrityToken': 'integrity-token',
      });
      return _response(_presenceJson(), 201);
    });

    final request = EventPresenceGrantRequest(
      contextRef: contextRef,
      latitude: 12.9716,
      longitude: 77.5946,
      accuracyMeters: 18,
      observedAt: DateTime.utc(2026, 8, 24, 10),
      deviceIntegrityToken: 'integrity-token',
    );
    final grant = await client.issueEventPresenceGrant(request);

    expect(grant.contextRef, contextRef);
    expect(grant.toString(), isNot(contains(presenceRef)));
    expect(request.toString(), isNot(contains('12.9716')));
    expect(request.toString(), isNot(contains('integrity-token')));
  });

  test('uses direct conversation projections for get, send and read', () async {
    final seen = <String>[];
    final client = _gateway((request) async {
      seen.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/messages')) {
        expect(request.headers['idempotency-key'], commandKey);
        expect(jsonDecode(request.body), {'body': 'Meet by gate 3.'});
        return _response(_messageJson(body: 'Meet by gate 3.'), 201);
      }
      if (request.url.path.endsWith('/read')) {
        expect(request.headers['idempotency-key'], commandKey);
        return _response({'updatedCount': 1});
      }
      return _response(_conversationJson());
    });

    final conversation = await client.getSwapConversation(requestId);
    final message = await client.sendSwapMessage(
      requestId,
      SendSwapMessageRequest(' Meet by gate 3. '),
      idempotencyKey: commandKey,
    );
    final read = await client.markSwapConversationRead(
      requestId,
      idempotencyKey: commandKey,
    );

    expect(conversation.messages.single.body, 'Ready when you are.');
    expect(message.body, 'Meet by gate 3.');
    expect(message.toString(), isNot(contains('Meet by gate 3.')));
    expect(read.updatedCount, 1);
    expect(seen, [
      'GET /v1/me/swap-requests/$requestId/conversation',
      'POST /v1/me/swap-requests/$requestId/conversation/messages',
      'POST /v1/me/swap-requests/$requestId/conversation/read',
    ]);
  });

  test('message send is one-shot when the server returns 503', () async {
    var attemptCount = 0;
    final client = _gateway((request) async {
      attemptCount += 1;
      return _response({
        'code': 'temporarily_unavailable',
        'message': 'Try again later.',
      }, 503);
    });

    await expectLater(
      client.sendSwapMessage(
        requestId,
        SendSwapMessageRequest('Do not duplicate this message.'),
        idempotencyKey: commandKey,
      ),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.outcomeUnknown,
          'outcomeUnknown',
          isTrue,
        ),
      ),
    );
    expect(attemptCount, 1);
  });

  test(
    'uses presence and versions on agreement consent, handoff, and cash commands',
    () async {
      final bodies = <String, Object?>{};
      final client = _gateway((request) async {
        if (request.url.path == '/v1/me/event-presence-grants') {
          return _response(_presenceJson(), 201);
        }
        bodies[request.url.path] = request.body.isEmpty
            ? null
            : jsonDecode(request.body);
        return _response(_agreementJson());
      });
      final grant = await client.issueEventPresenceGrant(
        EventPresenceGrantRequest(
          contextRef: contextRef,
          latitude: 12,
          longitude: 77,
          accuracyMeters: 10,
          observedAt: DateTime.utc(2026, 8, 24, 10),
        ),
      );

      final agreement = await client.getAgreement(agreementId);
      await client.recordAgreementConsent(
        agreementId,
        presenceGrant: grant,
        expectedVersion: agreement.version,
        idempotencyKey: commandKey,
      );
      await client.recordAgreementHandoff(
        agreementId,
        presenceGrant: grant,
        expectedVersion: agreement.version,
        idempotencyKey: commandKey,
      );
      await client.recordAgreementCashConfirmation(
        agreementId,
        presenceGrant: grant,
        expectedVersion: agreement.version,
        idempotencyKey: commandKey,
      );

      expect(agreement.state, AgreementState.readyForHandoff);
      expect(bodies['/v1/me/swap-agreements/$agreementId/consents'], {
        'presenceGrantRef': presenceRef,
        'expectedVersion': 1,
      });
      expect(
        bodies['/v1/me/swap-agreements/$agreementId/handoff-confirmations'],
        {'presenceGrantRef': presenceRef, 'expectedVersion': 1},
      );
      expect(bodies['/v1/me/swap-agreements/$agreementId/cash-confirmations'], {
        'presenceGrantRef': presenceRef,
        'expectedVersion': 1,
      });
    },
  );

  test('conversation and agreement parsing reject unknown fields', () async {
    final malformedConversation = _conversationJson()..['nextCursor'] = 'x';
    final malformedAgreement = _agreementJson()..remove('isPartyA');

    expect(
      () => SwapConversationProjection.fromJson(malformedConversation),
      throwsA(isA<ExchangeContractException>()),
    );
    expect(
      () => SwapAgreement.fromJson(malformedAgreement),
      throwsA(isA<ExchangeContractException>()),
    );
  });

  test('provider acquires fresh presence before agreement consent', () async {
    final client = _gateway((request) async {
      if (request.url.path == '/v1/me/event-presence-grants') {
        return _response(_presenceJson(), 201);
      }
      if (request.method == 'GET') {
        return _response(_agreementJson(state: 'agreed'));
      }
      expect(jsonDecode(request.body), {
        'presenceGrantRef': presenceRef,
        'expectedVersion': 1,
      });
      return _response(_agreementJson());
    });
    final provider = ExchangeProvider(
      gateway: client,
      clock: () => DateTime.utc(2026, 8, 24, 10, 0, 30),
    );

    await provider.loadAgreement(agreementId);
    final acquired = await provider.acquireFreshEventPresenceGrant(
      contextRef: contextRef,
      loadObservation: () async => LocationObservation(
        latitude: 12.9716,
        longitude: 77.5946,
        accuracyMeters: 18,
        observedAt: DateTime.utc(2026, 8, 24, 10),
      ),
    );
    final consented = await provider.recordAgreementConsent(
      agreement: provider.activeAgreement!,
      contextRef: contextRef,
    );

    expect(acquired, isTrue);
    expect(consented, isTrue);
    expect(provider.activeAgreement?.state, AgreementState.readyForHandoff);
    expect(provider.agreementError, isNull);
  });
}

ExchangeApiClient _gateway(
  Future<http.Response> Function(http.Request request) handler,
) => ExchangeApiClient(
  apiClient: ApiClient(
    baseUri: Uri.parse('https://api.example.com/'),
    accessTokenProvider: ({bool forceRefresh = false}) async => 'access-token',
    client: MockClient(handler),
  ),
  retryDelay: (_) async {},
);

http.Response _response(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> _presenceJson() => {
  'presenceGrantRef': presenceRef,
  'contextRef': contextRef,
  'status': 'eligible',
  'issuedAt': '2026-08-24T10:00:00.000Z',
  'expiresAt': '2026-08-24T10:02:00.000Z',
  'policyVersion': 'stadium-presence-v2',
};

Map<String, dynamic> _messageJson({String body = 'Ready when you are.'}) => {
  'id': messageId,
  'conversationId': conversationId,
  'senderId': participantB,
  'isViewer': false,
  'body': body,
  'readAt': null,
  'isFlagged': false,
  'flagReason': null,
  'createdAt': '2026-08-24T10:01:00.000Z',
};

Map<String, dynamic> _conversationJson() => {
  'id': conversationId,
  'swapRequestId': requestId,
  'messages': [_messageJson()],
  'unreadCount': 1,
  'createdAt': '2026-08-24T10:00:00.000Z',
  'updatedAt': '2026-08-24T10:01:00.000Z',
};

Map<String, dynamic> _agreementJson({String state = 'ready_for_handoff'}) => {
  'id': agreementId,
  'swapRequestId': requestId,
  'contextRef': contextRef,
  'state': state,
  'status': state,
  'participantAId': participantA,
  'participantBId': participantB,
  'isPartyA': true,
  'consents': {'participantA': true, 'participantB': true},
  'handoffConfirmations': {'participantA': false, 'participantB': false},
  'cashSettlement': null,
  'holdExpiresAt': '2026-08-24T10:15:00.000Z',
  'completedAt': null,
  'cancelledAt': null,
  'disputedAt': null,
  'disputeReason': null,
  'version': 1,
  'createdAt': '2026-08-24T10:00:00.000Z',
  'updatedAt': '2026-08-24T10:01:00.000Z',
};
