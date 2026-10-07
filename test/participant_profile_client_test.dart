import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/features/profile/data/participant_profile_client.dart';

void main() {
  group('onboarding policy contract', () {
    final validCases = <({String status, List<String> blockers})>[
      (status: 'not_configured', blockers: <String>[]),
      (status: 'not_configured', blockers: <String>['launch_jurisdiction']),
      (
        status: 'not_configured',
        blockers: <String>[
          'launch_jurisdiction',
          'adult_eligibility_policy',
          'participant_disclosures',
          'profile_data_governance',
        ],
      ),
      (status: 'development_bypass', blockers: <String>[]),
    ];

    for (final policyCase in validCases) {
      test('accepts ${policyCase.status} with '
          '${policyCase.blockers.length} blocker(s)', () async {
        final client = _clientForPolicy(
          status: policyCase.status,
          blockers: policyCase.blockers,
        );

        final onboarding = await client.getOnboarding();

        expect(onboarding.policy.status, policyCase.status);
        expect(onboarding.policy.blockers, policyCase.blockers);
        expect(onboarding.continuation.accountState, 'onboarding');
        expect(onboarding.continuation.nextAction, 'profile_required');
        expect(onboarding.continuation.nextStep, 'profile_basics_required');
      });
    }

    test('development bypass cannot contain policy blockers', () async {
      final client = _clientForPolicy(
        status: 'development_bypass',
        blockers: const ['launch_jurisdiction'],
      );

      expect(
        client.getOnboarding,
        throwsA(
          isA<ParticipantProfileException>().having(
            (error) => error.message,
            'message',
            contains('unsupported policy state'),
          ),
        ),
      );
    });
  });

  test('never retries a profile command under a different session', () async {
    var sessionId = 'session-a';
    var requests = 0;
    final client = ParticipantProfileClient(
      baseUri: Uri.parse('https://api.example.com/'),
      sessionIdentityProvider: () => sessionId,
      accessTokenProvider: ({bool forceRefresh = false}) async =>
          sessionId == 'session-a' ? 'token-a' : 'token-b',
      transport: (method, uri, headers, body) async {
        requests++;
        expect(method, 'PATCH');
        expect(headers['authorization'], 'Bearer token-a');
        sessionId = 'session-b';
        return const ParticipantProfileTransportResponse(401, '');
      },
    );

    await expectLater(
      client.updateDisplayName(
        'Participant A',
        idempotencyKey: 'profile-command-123456',
      ),
      throwsA(
        isA<ParticipantProfileException>().having(
          (error) => error.message,
          'message',
          contains('signed-in account changed'),
        ),
      ),
    );
    expect(requests, 1);
  });

  test('does not expose backend error messages as customer copy', () async {
    final client = ParticipantProfileClient(
      baseUri: Uri.parse('https://api.example.com/'),
      accessTokenProvider: ({bool forceRefresh = false}) async =>
          'access-token',
      transport: (method, uri, headers, body) async =>
          const ParticipantProfileTransportResponse(
            500,
            '{"code":"INTERNAL_FAILURE","message":"database host secret"}',
          ),
    );

    await expectLater(
      client.getOnboarding(),
      throwsA(
        isA<ParticipantProfileException>()
            .having(
              (error) => error.message,
              'message',
              'We could not load your account setup. Try again.',
            )
            .having(
              (error) => error.message,
              'message',
              isNot(contains('database host')),
            ),
      ),
    );
  });
}

ParticipantProfileClient _clientForPolicy({
  required String status,
  required List<String> blockers,
}) => ParticipantProfileClient(
  baseUri: Uri.parse('https://api.example.com/'),
  accessTokenProvider: ({bool forceRefresh = false}) async {
    expect(forceRefresh, isFalse);
    return 'access-token';
  },
  transport: (method, uri, headers, body) async {
    expect(method, 'GET');
    expect(uri, Uri.parse('https://api.example.com/v1/me/onboarding'));
    expect(headers['authorization'], 'Bearer access-token');
    expect(headers['accept'], 'application/json');
    expect(body, isNull);
    return ParticipantProfileTransportResponse(
      200,
      jsonEncode({
        'sourceState': 'durable',
        'participant': {
          'id': '30000000-0000-4000-8000-000000000003',
          'displayName': 'Participant',
          'status': 'onboarding',
          'registrationSource': 'passwordless_phone',
          'createdAt': '2026-08-03T00:00:00.000Z',
          'updatedAt': '2026-08-03T00:00:00.000Z',
        },
        'workflow': {
          'version': 1,
          'status': 'in_progress',
          'currentStep': 'profile_basics_required',
          'startedAt': '2026-08-03T00:00:00.000Z',
          'completedAt': null,
          'completedSteps': <Object>[],
        },
        'policy': {'status': status, 'blockers': blockers},
        'continuation': {
          'accountState': 'onboarding',
          'continuationVersion': 1,
          'nextAction': 'profile_required',
          'nextStep': 'profile_basics_required',
        },
      }),
    );
  },
);
