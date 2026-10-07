import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/exchange/data/exchange_api_client.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_marketplace_models.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_models.dart';

const targetId = '11111111-1111-4111-8111-111111111111';
const ownId = '22222222-2222-4222-8222-222222222222';
const requestId = '33333333-3333-4333-8333-333333333333';
const timelineId = '44444444-4444-4444-8444-444444444444';
const correlationId = '55555555-5555-4555-8555-555555555555';
const bundleOne = '66666666-6666-4666-8666-666666666666';
const bundleTwo = '77777777-7777-4777-8777-777777777777';
const commandKey = 'marketplace-command-key-12345';

void main() {
  group('public Posts', () {
    test('lists and gets authenticated published Posts', () async {
      final paths = <String>[];
      final gateway = _gateway((request) async {
        paths.add(request.url.toString());
        expect(request.headers['authorization'], 'Bearer access-token');
        if (request.url.path.endsWith(targetId)) {
          return _response({'post': _postJson(targetId, bundleOne)});
        }
        return _response({
          'items': [_postJson(targetId, bundleOne)],
          'total': 1,
        });
      });

      final page = await gateway.listPublishedSwapPosts(
        contextRef: 'ticketmaster:event:one',
        limit: 20,
        offset: 5,
      );
      final detail = await gateway.getPublishedSwapPost(targetId);

      expect(page.items.single.post.id, targetId);
      expect(page.items.single.requestable, isTrue);
      expect(detail.post.offeredTicketBundle?.seatLabels, ['14']);
      expect(
        paths.first,
        'https://api.example.com/v1/swap-posts?contextRef=ticketmaster%3Aevent%3Aone&limit=20&offset=5',
      );
      expect(paths.last, 'https://api.example.com/v1/swap-posts/$targetId');
    });

    test('rejects extra public Post fields', () async {
      final malformed = _postJson(targetId, bundleOne)
        ..['participantName'] = 'x';
      final gateway = _gateway(
        (_) async => _response({
          'items': [malformed],
          'total': 1,
        }),
      );

      await expectLater(
        gateway.listPublishedSwapPosts(),
        throwsA(isA<ExchangeContractException>()),
      );
    });

    test('rejects non-published items from the public Post feed', () async {
      final malformed = _postJson(targetId, bundleOne)..['state'] = 'paused';
      final gateway = _gateway(
        (_) async => _response({
          'items': [malformed],
          'total': 1,
        }),
      );

      await expectLater(
        gateway.listPublishedSwapPosts(),
        throwsA(isA<ExchangeContractException>()),
      );
    });

    test('rejects an unsupported event context before transport', () async {
      var called = false;
      final gateway = _gateway((_) async {
        called = true;
        return _response({'items': [], 'total': 0});
      });

      await expectLater(
        gateway.listPublishedSwapPosts(contextRef: 'event:one'),
        throwsA(isA<ExchangeContractException>()),
      );
      expect(called, isFalse);
    });

    test('rejects cash proposals above the server maximum', () async {
      final malformed = _postJson(targetId, bundleOne)
        ..['cashDifference'] = {
          'direction': 'will_pay',
          'amountMinor': 100000001,
          'currency': 'INR',
          'status': 'proposal_only',
          'paymentProtected': false,
        };
      final gateway = _gateway(
        (_) async => _response({
          'items': [malformed],
          'total': 1,
        }),
      );

      await expectLater(
        gateway.listPublishedSwapPosts(),
        throwsA(isA<ExchangeContractException>()),
      );
    });
  });

  group('Swap Requests', () {
    test('creates with both Post versions and one idempotency key', () async {
      late http.Request sent;
      final gateway = _gateway((request) async {
        sent = request;
        return _response({'swapRequest': _requestJson()}, 201);
      }, clock: () => DateTime.utc(2026, 8, 14));
      final input = CreateSwapRequestRequest(
        counterpartyIntentId: ownId,
        targetIntentVersion: 4,
        counterpartyIntentVersion: 2,
        expiresAt: DateTime.utc(2026, 8, 15),
      );

      final result = await gateway.createSwapRequest(
        targetId,
        input,
        idempotencyKey: commandKey,
      );

      expect(sent.method, 'POST');
      expect(sent.url.path, '/v1/me/swap-intents/$targetId/requests');
      expect(sent.headers['idempotency-key'], commandKey);
      expect(jsonDecode(sent.body), {
        'counterpartyIntentId': ownId,
        'targetIntentVersion': 4,
        'counterpartyIntentVersion': 2,
        'cashDirection': 'none',
        'expiresAt': '2026-08-15T00:00:00.000Z',
      });
      expect(result.role, SwapRequestRole.requester);
      expect(result.state, SwapRequestState.submitted);
    });

    test('lists and gets role-aware request details', () async {
      final gateway = _gateway((request) async {
        if (request.url.path.endsWith(requestId)) {
          return _response({
            'swapRequest': _requestJson(),
            'timeline': [_timelineJson()],
          });
        }
        expect(request.url.queryParameters['state'], 'submitted');
        return _response({
          'items': [_requestJson()],
          'total': 1,
        });
      });

      final page = await gateway.listSwapRequests(
        state: SwapRequestState.submitted,
      );
      final detail = await gateway.getSwapRequest(requestId);

      expect(page.items.single.targetPost.id, targetId);
      expect(detail.timeline.single.reasonCode, 'participant_submitted');
      expect(detail.swapRequest.cashDifference.paymentProtected, isFalse);
    });

    test('sends current versions for select, reject, and withdraw', () async {
      final calls = <http.Request>[];
      final gateway = _gateway((request) async {
        calls.add(request);
        return _response({'swapRequest': _requestJson()});
      });

      await gateway.selectSwapRequest(
        requestId,
        SelectSwapRequestRequest(
          expectedVersion: 6,
          targetIntentVersion: 7,
          counterpartyIntentVersion: 8,
        ),
        idempotencyKey: commandKey,
      );
      await gateway.rejectSwapRequest(
        requestId,
        expectedVersion: 9,
        idempotencyKey: commandKey,
      );
      await gateway.withdrawSwapRequest(
        requestId,
        expectedVersion: 10,
        idempotencyKey: commandKey,
      );

      expect(calls.map((call) => call.url.path), [
        '/v1/me/swap-requests/$requestId/select',
        '/v1/me/swap-requests/$requestId/reject',
        '/v1/me/swap-requests/$requestId/withdraw',
      ]);
      expect(jsonDecode(calls[0].body), {
        'expectedVersion': 6,
        'targetIntentVersion': 7,
        'counterpartyIntentVersion': 8,
      });
      expect(jsonDecode(calls[1].body), {'expectedVersion': 9});
      expect(jsonDecode(calls[2].body), {'expectedVersion': 10});
    });

    test('validates request expiry before transport', () async {
      var calls = 0;
      final gateway = _gateway((_) async {
        calls++;
        return _response({'swapRequest': _requestJson()}, 201);
      }, clock: () => DateTime.utc(2026, 8, 14));

      expect(
        () => gateway.createSwapRequest(
          targetId,
          CreateSwapRequestRequest(
            counterpartyIntentId: ownId,
            targetIntentVersion: 1,
            counterpartyIntentVersion: 1,
            expiresAt: DateTime.utc(2026, 9, 14),
          ),
          idempotencyKey: commandKey,
        ),
        throwsA(isA<ExchangeContractException>()),
      );
      expect(calls, 0);
    });
  });
}

ExchangeApiClient _gateway(
  Future<http.Response> Function(http.Request request) handler, {
  DateTime Function()? clock,
}) => ExchangeApiClient(
  apiClient: ApiClient(
    baseUri: Uri.parse('https://api.example.com/'),
    accessTokenProvider: ({bool forceRefresh = false}) async => 'access-token',
    client: MockClient(handler),
  ),
  retryPolicy: ExchangeRetryPolicy(maxAttempts: 1, initialDelay: Duration.zero),
  retryDelay: (_) async {},
  clock: clock,
);

http.Response _response(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> _postJson(String id, String bundleId) => {
  'id': id,
  'state': 'published',
  'version': id == targetId ? 4 : 2,
  'desiredAssignmentLabels': ['Section B'],
  'acceptsAnyAssignment': false,
  'expiresAt': '2026-08-20T12:00:00.000Z',
  'publishedAt': '2026-08-13T12:00:00.000Z',
  'pausedAt': null,
  'withdrawnAt': null,
  'createdAt': '2026-08-13T10:00:00.000Z',
  'updatedAt': '2026-08-13T12:00:00.000Z',
  'offeredSource': 'photo_checked',
  'offeredEntitlement': null,
  'offeredTicketBundle': _bundleJson(bundleId),
  'cashDifference': {
    'direction': 'none',
    'amountMinor': null,
    'currency': null,
    'status': 'proposal_only',
    'paymentProtected': false,
  },
  'isOwnPost': id == ownId,
  'requestable': id != ownId,
};

Map<String, dynamic> _intentJson(String id, String bundleId) {
  final value = _postJson(id, bundleId);
  value.remove('isOwnPost');
  value.remove('requestable');
  return value;
}

Map<String, dynamic> _bundleJson(String id) => {
  'id': id,
  'contextRef': 'ticketmaster:event:one',
  'eventTitle': 'City Finals',
  'startsAt': '2026-09-01T12:00:00.000Z',
  'timezone': 'Asia/Kolkata',
  'venueName': 'City Arena',
  'sectionLabel': 'A',
  'rowLabel': '4',
  'seatLabels': ['14'],
  'quantity': 1,
  'trustLevel': 'photo_checked',
  'ownershipVerified': false,
  'transferabilityVerified': false,
  'state': 'active',
  'version': 1,
  'createdAt': '2026-08-13T10:00:00.000Z',
  'updatedAt': '2026-08-13T10:00:00.000Z',
};

Map<String, dynamic> _requestJson() => {
  'id': requestId,
  'agreementId': null,
  'state': 'submitted',
  'version': 1,
  'role': 'requester',
  'targetPostVersionAtSubmission': 4,
  'counterpartyPostVersionAtSubmission': 2,
  'cashDifference': {
    'direction': 'none',
    'amountMinor': null,
    'currency': null,
    'status': 'proposal_only',
    'paymentProtected': false,
  },
  'expiresAt': '2026-08-15T00:00:00.000Z',
  'selectedAt': null,
  'rejectedAt': null,
  'withdrawnAt': null,
  'createdAt': '2026-08-14T00:00:00.000Z',
  'updatedAt': '2026-08-14T00:00:00.000Z',
  'targetPost': _intentJson(targetId, bundleOne),
  'counterpartyPost': _intentJson(ownId, bundleTwo),
  'warning':
      'Selection records mutual interest only. No transfer or payment occurs.',
};

Map<String, dynamic> _timelineJson() => {
  'id': timelineId,
  'fromState': null,
  'toState': 'submitted',
  'actorType': 'participant',
  'reasonCode': 'participant_submitted',
  'correlationId': correlationId,
  'occurredAt': '2026-08-14T00:00:00.000Z',
};
