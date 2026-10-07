import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/tickets/data/ticket_api_client.dart';
import 'package:swappy_mobile/features/tickets/domain/ticket_models.dart';

const importId = '11111111-1111-4111-8111-111111111111';
const candidateId = '22222222-2222-4222-8222-222222222222';
const bundleId = '33333333-3333-4333-8333-333333333333';
const evidenceId = '44444444-4444-4444-8444-444444444444';
const eligibilityId = '55555555-5555-4555-8555-555555555555';
const commandKey = 'ticket_command_1234567890';
const uploadToken = 'upload_token_abcdefghijklmnopqrstuvwxyz_1234567890';
const protectedReference =
    'evidence://ticket-import/abcdefghijklmnopqrstuvwxyz_1234567890';

void main() {
  test('creates, uploads and polls a real protected ticket import', () async {
    final seen = <String>[];
    final client = TicketApiClient(
      apiClient: _apiClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        expect(request.headers['authorization'], 'Bearer access-token');
        if (request.method == 'POST') {
          expect(request.headers['idempotency-key'], commandKey);
          expect(jsonDecode(request.body), {'countryCode': 'IN'});
          return _response({
            'ticketImport': _importJson(),
            'upload': _uploadJson(),
          }, 201);
        }
        if (request.method == 'PUT') {
          expect(request.headers['idempotency-key'], commandKey);
          expect(request.headers['x-upload-token'], uploadToken);
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          final multipartBody = latin1.decode(request.bodyBytes);
          expect(multipartBody, contains('name="ticket"'));
          expect(multipartBody, contains('filename="ticket.png"'));
          return _response({
            'ticketImport': _importJson(state: 'processing', version: 2),
          });
        }
        return _response({
          'ticketImport': _importJson(
            state: 'awaiting_confirmation',
            version: 3,
          ),
        });
      }),
      retryDelay: (_) async {},
    );

    final created = await client.createImport('in', idempotencyKey: commandKey);
    expect(created.ticketImport.state, TicketImportState.awaitingUpload);
    expect(created.upload.toString(), isNot(contains(uploadToken)));

    final uploaded = await client.uploadTicket(
      authorization: created.upload,
      bytes: _pngBytes(),
      filename: 'ticket.png',
      idempotencyKey: commandKey,
    );
    expect(uploaded.state, TicketImportState.processing);

    final polled = await client.getImport(importId);
    expect(polled.state, TicketImportState.awaitingConfirmation);
    expect(polled.eventCandidates.single.contextRef, 'ticketmaster:event:abc');
    expect(seen, [
      'POST /v1/me/ticket-imports',
      'PUT /v1/me/ticket-imports/$importId/content',
      'GET /v1/me/ticket-imports/$importId',
    ]);
  });

  test(
    'confirms and immediately consumes the one-use protected reference',
    () async {
      var calls = 0;
      final client = TicketApiClient(
        apiClient: _apiClient((request) async {
          calls++;
          expect(request.headers['idempotency-key'], commandKey);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (request.url.path.endsWith('/confirm')) {
            expect(body, {
              'contextRef': 'ticketmaster:event:abc',
              'sectionLabel': 'A',
              'rowLabel': '12',
              'seatLabels': ['14', '15'],
            });
            return _response({
              'ticketImport': _importJson(
                state: 'confirmed',
                version: 4,
                confirmedContextRef: 'ticketmaster:event:abc',
              ),
              'protectedObjectRef': protectedReference,
            });
          }
          expect(request.url.path, '/v1/me/entitlement-evidence');
          expect(body['verticalKey'], 'ticketed_experience');
          expect(body['providerKey'], 'ticketmaster_discovery');
          expect(body['evidenceType'], 'ticket_photo');
          expect(body['protectedObjectRef'], protectedReference);
          return _response({
            'evidence': _evidenceJson(),
            'ticketBundle': _bundleJson(),
          }, 201);
        }),
        retryDelay: (_) async {},
      );

      final confirmed = await client.confirmImport(
        importId,
        contextRef: 'ticketmaster:event:abc',
        sectionLabel: 'A',
        rowLabel: '12',
        seatLabels: const ['14', '15'],
        idempotencyKey: commandKey,
      );
      expect(confirmed.toString(), isNot(contains(protectedReference)));

      final result = await client.consumeConfirmedImport(
        confirmed,
        idempotencyKey: commandKey,
      );
      expect(result.ticket.id, bundleId);
      expect(result.ticket.ownershipVerified, isFalse);
      expect(result.ticket.transferabilityVerified, isFalse);
      expect(calls, 2);
    },
  );

  test('refuses to send upload credentials to a different origin', () async {
    var requested = false;
    final client = TicketApiClient(
      apiClient: _apiClient((_) async {
        requested = true;
        return _response({});
      }),
      retryDelay: (_) async {},
    );
    final authorization = TicketUploadAuthorization(
      method: 'PUT',
      url: 'https://attacker.example/upload',
      fieldName: 'ticket',
      uploadToken: uploadToken,
      expiresAt: DateTime.utc(2026, 8, 13, 13),
      acceptedMimeTypes: const ['image/png'],
      maximumBytes: 10485760,
    );

    await expectLater(
      client.uploadTicket(
        authorization: authorization,
        bytes: _pngBytes(),
        filename: 'ticket.png',
        idempotencyKey: commandKey,
      ),
      throwsA(isA<ApiRequestException>()),
    );
    expect(requested, isFalse);
  });
}

ApiClient _apiClient(
  Future<http.Response> Function(http.Request request) handler,
) => ApiClient(
  baseUri: Uri.parse('https://api.example.com/'),
  accessTokenProvider: ({bool forceRefresh = false}) async => 'access-token',
  client: MockClient(handler),
);

http.Response _response(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

Map<String, dynamic> _uploadJson() => {
  'method': 'PUT',
  'url': '/v1/me/ticket-imports/$importId/content',
  'fieldName': 'ticket',
  'uploadToken': uploadToken,
  'expiresAt': '2026-08-13T13:00:00Z',
  'acceptedMimeTypes': ['image/jpeg', 'image/png'],
  'maximumBytes': 10485760,
};

Map<String, dynamic> _importJson({
  String state = 'awaiting_upload',
  int version = 1,
  String? confirmedContextRef,
}) => {
  'id': importId,
  'state': state,
  'version': version,
  'countryCode': 'IN',
  'extracted': {
    'eventName': 'City Finals',
    'startsAt': '2026-08-20T18:00:00Z',
    'venueName': 'Central Arena',
    'sectionLabel': 'A',
    'rowLabel': '12',
    'seatLabels': ['14', '15'],
  },
  'confirmedContextRef': confirmedContextRef,
  'failureCode': null,
  'eventCandidates': [_candidateJson()],
  'retentionUntil': '2026-09-13T12:00:00Z',
  'createdAt': '2026-08-13T12:00:00Z',
  'updatedAt': '2026-08-13T12:01:00Z',
};

Map<String, dynamic> _candidateJson() => {
  'id': candidateId,
  'contextRef': 'ticketmaster:event:abc',
  'title': 'City Finals',
  'startsAt': '2026-08-20T18:00:00Z',
  'timezone': 'Asia/Kolkata',
  'venueName': 'Central Arena',
  'venueCity': 'Hyderabad',
  'venueCountryCode': 'IN',
  'staticSeatMapUrl': 'https://maps.example/seat.png',
  'confidenceBasisPoints': 9500,
  'rank': 1,
  'sourceObservedAt': '2026-08-13T12:00:00Z',
};

Map<String, dynamic> _bundleJson() => {
  'id': bundleId,
  'contextRef': 'ticketmaster:event:abc',
  'eventTitle': 'City Finals',
  'startsAt': '2026-08-20T18:00:00Z',
  'timezone': 'Asia/Kolkata',
  'venueName': 'Central Arena',
  'sectionLabel': 'A',
  'rowLabel': '12',
  'seatLabels': ['14', '15'],
  'quantity': 2,
  'trustLevel': 'photo_checked',
  'ownershipVerified': false,
  'transferabilityVerified': false,
  'verification': {
    'eventMatch': 'confirmed',
    'ownership': 'unverified',
    'validity': 'unverified',
    'unusedStatus': 'unverified',
    'transferability': 'unverified',
    'seat': 'unverified',
    'provider': 'ticketmaster_discovery',
  },
  'state': 'active',
  'version': 1,
  'createdAt': '2026-08-13T12:00:00Z',
  'updatedAt': '2026-08-13T12:00:00Z',
};

Map<String, dynamic> _evidenceJson() => {
  'id': evidenceId,
  'verticalKey': 'ticketed_experience',
  'providerKey': 'ticketmaster_discovery',
  'contextRef': 'ticketmaster:event:abc',
  'evidenceType': 'ticket_photo',
  'state': 'processed',
  'retentionUntil': '2026-09-13T12:00:00Z',
  'createdAt': '2026-08-13T12:00:00Z',
  'latestEligibility': {
    'id': eligibilityId,
    'decision': 'ineligible',
    'mode': 'photo_checked',
    'policyVersion': 'v1',
    'adapterVersion': 'v1',
    'reasonCode': 'photo_checked_not_provider_verified',
    'decidedAt': '2026-08-13T12:00:00Z',
    'validUntil': '2026-09-13T12:00:00Z',
    'revokedAt': null,
  },
};

List<int> _pngBytes() => [
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
];
