import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/exchange/data/exchange_api_client.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_models.dart';

const evidenceId = '11111111-1111-4111-8111-111111111111';
const eligibilityId = '22222222-2222-4222-8222-222222222222';
const entitlementId = '33333333-3333-4333-8333-333333333333';
const intentId = '44444444-4444-4444-8444-444444444444';
const timelineId = '55555555-5555-4555-8555-555555555555';
const correlationId = '66666666-6666-4666-8666-666666666666';
const commandKey = 'command_key_1234567890';
final now = DateTime.utc(2026, 8, 13, 12);

void main() {
  group('exchange models', () {
    test('generates valid secure URL-safe idempotency keys', () {
      final first = newExchangeIdempotencyKey();
      final second = newExchangeIdempotencyKey();

      expect(first, isNot(second));
      expect(first.length, inInclusiveRange(16, 255));
      expect(first, matches(RegExp(r'^[A-Za-z0-9._~-]+$')));
      expect(() => validateExchangeIdempotencyKey(first), returnsNormally);
    });

    test('validates assignment choice, expiry, versions, and page bounds', () {
      expect(
        () => CreateSwapIntentRequest(
          offeredEntitlementId: entitlementId,
          desiredAssignmentLabels: const [],
          acceptsAnyAssignment: false,
          expiresAt: now.add(const Duration(days: 1)),
        ),
        throwsA(isA<ExchangeContractException>()),
      );
      expect(
        () => validateSwapIntentExpiry(
          now.add(const Duration(minutes: 4)),
          now: now,
        ),
        throwsA(isA<ExchangeContractException>()),
      );
      expect(
        () => UpdateSwapIntentRequest(
          desiredAssignmentLabels: const ['A'],
          acceptsAnyAssignment: false,
          expiresAt: now.add(const Duration(days: 1)),
          expectedVersion: 0,
        ),
        throwsA(isA<ExchangeContractException>()),
      );
      expect(
        () => validateExchangePage(limit: 101, offset: 0),
        throwsA(isA<ExchangeContractException>()),
      );
    });

    test('keeps protectedObjectRef write-only and redacted', () {
      const protectedRef = 'evidence://opaque-reference-1234';
      final request = EvidenceSubmissionRequest(
        verticalKey: 'ticketed_experience',
        providerKey: 'provider_one',
        contextRef: 'event-1',
        evidenceType: 'ticket',
        protectedObjectRef: protectedRef,
      );

      expect(request.toJson()['protectedObjectRef'], protectedRef);
      expect(request.toString(), isNot(contains(protectedRef)));

      final leakedResponse = evidenceJson()
        ..['protectedObjectRef'] = protectedRef;
      expect(
        () => EvidenceProjection.fromJson(leakedResponse),
        throwsA(isA<ExchangeContractException>()),
      );
    });
  });

  group('ExchangeApiClient', () {
    test(
      'calls all evidence and entitlement endpoints with typed filters',
      () async {
        final seen = <String>[];
        final gateway = gatewayWith((request) async {
          seen.add(
            '${request.method} ${request.url.path}?${request.url.query}',
          );
          expect(request.headers['authorization'], 'Bearer access-token');
          if (request.method == 'POST') {
            expect(request.headers['idempotency-key'], commandKey);
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(
              body['protectedObjectRef'],
              'evidence://opaque-reference-1234',
            );
            return response({'evidence': evidenceJson()}, 201);
          }
          if (request.url.path == '/v1/me/entitlement-evidence') {
            return response({
              'items': [evidenceJson()],
              'total': 1,
            });
          }
          if (request.url.path == '/v1/me/entitlement-evidence/$evidenceId') {
            return response({'evidence': evidenceJson()});
          }
          if (request.url.path == '/v1/me/entitlements') {
            return response({
              'items': [entitlementJson()],
              'total': 1,
            });
          }
          if (request.url.path == '/v1/me/entitlements/$entitlementId') {
            return response({'entitlement': entitlementJson()});
          }
          return http.Response('', 404);
        });

        final submitted = await gateway.submitEvidence(
          EvidenceSubmissionRequest(
            verticalKey: 'ticketed_experience',
            providerKey: 'provider_one',
            contextRef: 'event-1',
            evidenceType: 'ticket',
            protectedObjectRef: 'evidence://opaque-reference-1234',
          ),
          idempotencyKey: commandKey,
        );
        final evidence = await gateway.listEvidence(
          limit: 25,
          offset: 50,
          state: EvidenceState.processing,
        );
        await gateway.getEvidence(evidenceId);
        final entitlements = await gateway.listEntitlements(
          state: EntitlementState.eligible,
        );
        await gateway.getEntitlement(entitlementId);

        expect(submitted.id, evidenceId);
        expect(evidence.items.single.state, EvidenceState.processing);
        expect(
          entitlements.items.single.eligibility.decision,
          EligibilityDecision.eligible,
        );
        expect(
          seen,
          contains(
            'GET /v1/me/entitlement-evidence?limit=25&offset=50&state=processing',
          ),
        );
        expect(
          seen,
          contains('GET /v1/me/entitlements?limit=50&offset=0&state=eligible'),
        );
      },
    );

    test(
      'calls all eight swap-intent endpoints with expectedVersion',
      () async {
        final calls = <http.Request>[];
        final gateway = gatewayWith((request) async {
          calls.add(request);
          if (request.method == 'GET' &&
              request.url.path == '/v1/me/swap-intents') {
            return response({
              'items': [intentJson()],
              'total': 1,
            });
          }
          if (request.method == 'GET') {
            return response({
              'intent': intentJson(),
              'timeline': [timelineJson()],
            });
          }
          return response(
            {'intent': intentJson()},
            request.method == 'POST' &&
                    request.url.path == '/v1/me/swap-intents'
                ? 201
                : 200,
          );
        }, clock: () => now);

        final create = CreateSwapIntentRequest(
          offeredEntitlementId: entitlementId,
          desiredAssignmentLabels: const ['B12'],
          acceptsAnyAssignment: false,
          expiresAt: now.add(const Duration(days: 1)),
        );
        final update = UpdateSwapIntentRequest(
          desiredAssignmentLabels: const ['C10'],
          acceptsAnyAssignment: false,
          expiresAt: now.add(const Duration(days: 2)),
          expectedVersion: 3,
        );
        await gateway.createSwapIntent(create, idempotencyKey: commandKey);
        await gateway.listSwapIntents(state: SwapIntentState.published);
        final detail = await gateway.getSwapIntent(intentId);
        await gateway.updateSwapIntent(
          intentId,
          update,
          idempotencyKey: commandKey,
        );
        await gateway.publishSwapIntent(
          intentId,
          expectedVersion: 3,
          idempotencyKey: commandKey,
        );
        await gateway.pauseSwapIntent(
          intentId,
          expectedVersion: 4,
          idempotencyKey: commandKey,
        );
        await gateway.resumeSwapIntent(
          intentId,
          expectedVersion: 5,
          idempotencyKey: commandKey,
        );
        await gateway.withdrawSwapIntent(
          intentId,
          expectedVersion: 6,
          idempotencyKey: commandKey,
        );

        expect(
          detail.timeline.single.actorType,
          SwapIntentActorType.participant,
        );
        expect(
          calls.map((request) => '${request.method} ${request.url.path}'),
          [
            'POST /v1/me/swap-intents',
            'GET /v1/me/swap-intents',
            'GET /v1/me/swap-intents/$intentId',
            'PATCH /v1/me/swap-intents/$intentId',
            'POST /v1/me/swap-intents/$intentId/publish',
            'POST /v1/me/swap-intents/$intentId/pause',
            'POST /v1/me/swap-intents/$intentId/resume',
            'POST /v1/me/swap-intents/$intentId/withdraw',
          ],
        );
        expect(jsonDecode(calls[3].body)['expectedVersion'], 3);
        expect(jsonDecode(calls[4].body), {'expectedVersion': 3});
        expect(jsonDecode(calls[5].body), {'expectedVersion': 4});
        expect(jsonDecode(calls[6].body), {'expectedVersion': 5});
        expect(jsonDecode(calls[7].body), {'expectedVersion': 6});
        for (final request in calls.where(
          (request) => request.method == 'POST' || request.method == 'PATCH',
        )) {
          expect(request.headers['idempotency-key'], commandKey);
        }
      },
    );

    test('retries 503 with the exact same immutable body and key', () async {
      final bodies = <String>[];
      final keys = <String?>[];
      var attempts = 0;
      final gateway = gatewayWith((request) async {
        attempts++;
        bodies.add(request.body);
        keys.add(request.headers['idempotency-key']);
        if (attempts < 3) {
          return response(
            {'code': 'EXCHANGE_STORAGE_UNAVAILABLE', 'message': 'Try later.'},
            503,
            {'x-correlation-id': correlationId},
          );
        }
        return response({'intent': intentJson()}, 201);
      }, clock: () => now);

      await gateway.createSwapIntent(
        CreateSwapIntentRequest(
          offeredEntitlementId: entitlementId,
          desiredAssignmentLabels: const ['B12'],
          acceptsAnyAssignment: false,
          expiresAt: now.add(const Duration(days: 1)),
        ),
        idempotencyKey: commandKey,
      );

      expect(attempts, 3);
      expect(bodies.toSet(), hasLength(1));
      expect(keys.toSet(), {commandKey});
    });

    test('retries a transport failure without changing the command', () async {
      final bodies = <String>[];
      var attempts = 0;
      final gateway = gatewayWith((request) async {
        attempts++;
        bodies.add(request.body);
        if (attempts == 1) {
          throw http.ClientException('private transport details');
        }
        return response({'intent': intentJson()}, 200);
      });

      await gateway.publishSwapIntent(
        intentId,
        expectedVersion: 3,
        idempotencyKey: commandKey,
      );

      expect(attempts, 2);
      expect(bodies.toSet(), hasLength(1));
    });

    test('aborts a 503 retry when the participant session changes', () async {
      var sessionId = 'session-a';
      var attempts = 0;
      final apiClient = ApiClient(
        baseUri: Uri.parse('https://api.example.com/'),
        sessionIdentityProvider: () => sessionId,
        accessTokenProvider: ({bool forceRefresh = false}) async =>
            sessionId == 'session-a' ? 'token-a' : 'token-b',
        client: MockClient((request) async {
          attempts++;
          expect(request.headers['authorization'], 'Bearer token-a');
          sessionId = 'session-b';
          return response({
            'code': 'DURABLE_EXCHANGE_STORAGE_REQUIRED',
            'message': 'Wait.',
          }, 503);
        }),
      );
      final gateway = ExchangeApiClient(
        apiClient: apiClient,
        retryPolicy: ExchangeRetryPolicy(
          maxAttempts: 3,
          initialDelay: Duration.zero,
        ),
        retryDelay: (_) async {},
      );

      await expectLater(
        gateway.publishSwapIntent(
          intentId,
          expectedVersion: 3,
          idempotencyKey: commandKey,
        ),
        throwsA(
          isA<ApiRequestException>().having(
            (error) => error.code,
            'code',
            'PARTICIPANT_SESSION_CHANGED',
          ),
        ),
      );
      expect(attempts, 1);
    });

    test(
      'does not retry conflicts and preserves structured error context',
      () async {
        var attempts = 0;
        final gateway = gatewayWith((_) async {
          attempts++;
          return response(
            {
              'code': 'INTENT_VERSION_CONFLICT',
              'message': 'Refresh the intent.',
            },
            409,
            {'x-correlation-id': correlationId},
          );
        });

        await expectLater(
          gateway.publishSwapIntent(
            intentId,
            expectedVersion: 4,
            idempotencyKey: commandKey,
          ),
          throwsA(
            isA<ApiRequestException>()
                .having((error) => error.statusCode, 'status', 409)
                .having(
                  (error) => error.code,
                  'code',
                  'INTENT_VERSION_CONFLICT',
                )
                .having(
                  (error) => error.correlationId,
                  'correlation',
                  correlationId,
                )
                .having((error) => error.outcomeUnknown, 'outcome', isFalse),
          ),
        );
        expect(attempts, 1);
      },
    );

    test('marks an exhausted 503 mutation outcome unknown', () async {
      final gateway = gatewayWith(
        (_) async => response(
          {'code': 'EXCHANGE_STORAGE_UNAVAILABLE', 'message': 'Try later.'},
          503,
          {'x-correlation-id': correlationId},
        ),
      );

      await expectLater(
        gateway.pauseSwapIntent(
          intentId,
          expectedVersion: 4,
          idempotencyKey: commandKey,
        ),
        throwsA(
          isA<ApiRequestException>()
              .having((error) => error.statusCode, 'status', 503)
              .having((error) => error.outcomeUnknown, 'outcome', isTrue)
              .having(
                (error) => error.correlationId,
                'correlation',
                correlationId,
              ),
        ),
      );
    });

    test('rejects malformed response fields and timestamps', () async {
      final malformed = evidenceJson()
        ..['createdAt'] = '2026-08-13'
        ..['unknown'] = true;
      final gateway = gatewayWith(
        (_) async => response({'evidence': malformed}),
      );

      await expectLater(
        gateway.getEvidence(evidenceId),
        throwsA(isA<ExchangeContractException>()),
      );
    });
  });
}

ExchangeApiClient gatewayWith(
  Future<http.Response> Function(http.Request request) handler, {
  DateTime Function()? clock,
}) {
  final apiClient = ApiClient(
    baseUri: Uri.parse('https://api.example.com/'),
    accessTokenProvider: ({bool forceRefresh = false}) async => 'access-token',
    client: MockClient(handler),
  );
  return ExchangeApiClient(
    apiClient: apiClient,
    retryPolicy: ExchangeRetryPolicy(
      maxAttempts: 3,
      initialDelay: Duration.zero,
    ),
    retryDelay: (_) async {},
    clock: clock,
  );
}

http.Response response(
  Map<String, dynamic> body, [
  int status = 200,
  Map<String, String> headers = const {},
]) => http.Response(jsonEncode(body), status, headers: headers);

Map<String, dynamic> eligibilityJson() => {
  'id': eligibilityId,
  'decision': 'eligible',
  'mode': 'provider',
  'policyVersion': 'v1',
  'adapterVersion': 'v1',
  'reasonCode': 'provider_confirmed',
  'decidedAt': '2026-08-13T10:00:00Z',
  'validUntil': '2026-09-13T10:00:00Z',
  'revokedAt': null,
};

Map<String, dynamic> evidenceJson() => {
  'id': evidenceId,
  'verticalKey': 'ticketed_experience',
  'providerKey': 'provider_one',
  'contextRef': 'event-1',
  'evidenceType': 'ticket',
  'state': 'processing',
  'retentionUntil': null,
  'createdAt': '2026-08-13T10:00:00Z',
  'latestEligibility': eligibilityJson(),
};

Map<String, dynamic> entitlementJson() => {
  'id': entitlementId,
  'verticalKey': 'ticketed_experience',
  'providerKey': 'provider_one',
  'contextRef': 'event-1',
  'assignmentLabel': 'A12',
  'state': 'eligible',
  'version': 2,
  'createdAt': '2026-08-13T10:00:00Z',
  'updatedAt': '2026-08-13T11:00:00Z',
  'eligibility': eligibilityJson(),
};

Map<String, dynamic> intentJson() => {
  'id': intentId,
  'state': 'draft',
  'version': 3,
  'desiredAssignmentLabels': ['B12'],
  'acceptsAnyAssignment': false,
  'expiresAt': '2026-08-14T12:00:00Z',
  'publishedAt': null,
  'pausedAt': null,
  'withdrawnAt': null,
  'createdAt': '2026-08-13T10:00:00Z',
  'updatedAt': '2026-08-13T11:00:00Z',
  'offeredSource': 'provider_verified',
  'offeredEntitlement': entitlementJson(),
  'offeredTicketBundle': null,
  'cashDifference': {
    'direction': 'none',
    'amountMinor': null,
    'currency': null,
    'status': 'proposal_only',
    'paymentProtected': false,
  },
};

Map<String, dynamic> timelineJson() => {
  'id': timelineId,
  'fromState': null,
  'toState': 'draft',
  'actorType': 'participant',
  'reasonCode': 'created',
  'correlationId': correlationId,
  'occurredAt': '2026-08-13T10:00:00Z',
};
