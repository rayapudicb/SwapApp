import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swappy_mobile/core/api/api_client.dart';

void main() {
  test('adds an in-memory bearer token and refreshes once after 401', () async {
    final forceRefreshValues = <bool>[];
    var requests = 0;
    final client = ApiClient(
      baseUri: Uri.parse('https://api.example.com/'),
      accessTokenProvider: ({bool forceRefresh = false}) async {
        forceRefreshValues.add(forceRefresh);
        return forceRefresh ? 'new-token' : 'old-token';
      },
      client: MockClient((request) async {
        requests++;
        expect(
          request.url,
          Uri.parse(
            'https://api.example.com/v1/ticketed-experience/events?city=LA',
          ),
        );
        if (requests == 1) {
          expect(request.headers['Authorization'], 'Bearer old-token');
          return http.Response('', 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-token');
        return http.Response('{"items":[]}', 200);
      }),
    );

    final response = await client.get('/v1/ticketed-experience/events?city=LA');

    expect(response.statusCode, 200);
    expect(forceRefreshValues, [false, true]);
    expect(requests, 2);
  });

  test('maps transport details to a safe connection message', () async {
    final client = ApiClient(
      baseUri: Uri.parse('https://api.example.com/'),
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((_) async {
        throw http.ClientException('socket failed at secret.example');
      }),
    );

    expect(
      () => client.get('/v1/ticketed-experience/events?city=LA'),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.message,
          'message',
          isNot(contains('secret.example')),
        ),
      ),
    );
  });

  test('PATCH preserves command headers and exact JSON body', () async {
    final client = ApiClient(
      baseUri: Uri.parse('https://api.example.com/'),
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(
          request.url,
          Uri.parse('https://api.example.com/v1/me/swap-intents/intent-1'),
        );
        expect(request.headers['Idempotency-Key'], 'command-key-123456');
        expect(request.body, '{"expectedVersion":1}');
        return http.Response('{"intent":{}}', 200);
      }),
    );

    await client.patch(
      '/v1/me/swap-intents/intent-1',
      body: const {'expectedVersion': 1},
      extraHeaders: const {'Idempotency-Key': 'command-key-123456'},
    );
  });

  test(
    'second 401 invalidates the session and preserves error metadata',
    () async {
      var requests = 0;
      ApiRequestException? rejected;
      final client = ApiClient(
        baseUri: Uri.parse('https://api.example.com/'),
        accessTokenProvider: ({bool forceRefresh = false}) async =>
            forceRefresh ? 'new-token' : 'old-token',
        onSessionRejected: (error) async => rejected = error,
        client: MockClient((_) async {
          requests++;
          return http.Response(
            '{"code":"PARTICIPANT_AUTH_REQUIRED","message":"Sign in."}',
            401,
            headers: const {'x-correlation-id': 'correlation-1'},
          );
        }),
      );

      await expectLater(
        client.get('/v1/me/entitlements'),
        throwsA(
          isA<ApiRequestException>()
              .having((error) => error.statusCode, 'status', 401)
              .having(
                (error) => error.code,
                'code',
                'PARTICIPANT_AUTH_REQUIRED',
              )
              .having(
                (error) => error.correlationId,
                'correlation',
                'correlation-1',
              ),
        ),
      );
      expect(requests, 2);
      expect(rejected?.code, 'PARTICIPANT_AUTH_REQUIRED');
    },
  );

  test('requireSuccess parses structured conflict details', () {
    final response = http.Response(
      '{"code":"SWAP_INTENT_VERSION_CONFLICT","message":"Refetch."}',
      409,
      headers: const {'x-correlation-id': 'correlation-2'},
    );

    expect(
      () => ApiClient.requireSuccess(response, outcomeUnknown: true),
      throwsA(
        isA<ApiRequestException>()
            .having((error) => error.statusCode, 'status', 409)
            .having(
              (error) => error.code,
              'code',
              'SWAP_INTENT_VERSION_CONFLICT',
            )
            .having((error) => error.outcomeUnknown, 'outcome', isFalse),
      ),
    );
  });

  test('requireSuccess preserves the server retryAfter time', () {
    final response = http.Response(
      '{"code":"DAILY_SWAP_SELECTION_LIMIT_REACHED",'
      '"message":"Try later.",'
      '"retryAfter":"2026-08-15T10:30:00.000Z"}',
      409,
    );

    expect(
      () => ApiClient.requireSuccess(response),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.retryAt,
          'retry time',
          DateTime.utc(2026, 8, 15, 10, 30),
        ),
      ),
    );
  });

  test('never retries a 401 under a different participant session', () async {
    var sessionId = 'session-a';
    var requests = 0;
    final client = ApiClient(
      baseUri: Uri.parse('https://api.example.com/'),
      sessionIdentityProvider: () => sessionId,
      accessTokenProvider: ({bool forceRefresh = false}) async =>
          sessionId == 'session-a' ? 'token-a' : 'token-b',
      client: MockClient((request) async {
        requests++;
        expect(request.headers['Authorization'], 'Bearer token-a');
        sessionId = 'session-b';
        return http.Response('', 401);
      }),
    );

    await expectLater(
      client.post('/v1/me/swap-intents', body: const {'value': 'a'}),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.code,
          'code',
          'PARTICIPANT_SESSION_CHANGED',
        ),
      ),
    );
    expect(requests, 1);
  });
}
