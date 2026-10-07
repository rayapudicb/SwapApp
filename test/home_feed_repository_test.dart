import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/home/data/home_feed_repository.dart';
import 'package:swappy_mobile/features/home/domain/discovered_event.dart';

void main() {
  ApiClient apiWith(MockClient client) => ApiClient(
    baseUri: Uri.parse('https://api.example.test'),
    accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
    client: client,
  );

  test(
    'searches a requested event page and maps page/source metadata',
    () async {
      late http.Request captured;
      final repository = HomeFeedRepository(
        apiWith(
          MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'items': [_eventJson(contextRef: 'ticketmaster:event-2')],
                'page': {
                  'number': 2,
                  'size': 10,
                  'totalElements': 35,
                  'totalPages': 4,
                },
                'source': {
                  'provider': 'ticketmaster',
                  'capability': 'discovery_only',
                  'stale': false,
                },
              }),
              200,
            );
          }),
        ),
      );

      final result = await repository.discoverEvents(
        city: ' Hyderabad ',
        stateCode: 'tg',
        countryCode: 'in',
        category: 'Music',
        keyword: ' Live ',
        page: 2,
        size: 10,
      );

      expect(captured.method, 'GET');
      expect(captured.headers['authorization'], 'Bearer token');
      expect(captured.url.path, '/v1/ticketed-experience/events');
      expect(captured.url.queryParameters, {
        'city': 'Hyderabad',
        'stateCode': 'TG',
        'countryCode': 'IN',
        'classificationName': 'Music',
        'keyword': 'Live',
        'page': '2',
        'size': '10',
      });
      expect(result.items.single.contextRef, 'ticketmaster:event-2');
      expect(result.page.number, 2);
      expect(result.page.hasNextPage, isTrue);
      expect(result.source.capability, 'discovery_only');
    },
  );

  test(
    'posts a fresh location observation and maps advisory proximity',
    () async {
      late http.Request captured;
      final repository = HomeFeedRepository(
        apiWith(
          MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'event': _eventJson(),
                    'proximity': {
                      'status': 'proximity_eligible',
                      'distanceMeters': 120,
                      'radiusMeters': 400,
                      'observedAccuracyMeters': 25,
                      'activeFrom': '2026-08-13T07:30:00.000Z',
                      'activeUntil': '2026-08-13T12:00:00.000Z',
                      'policyVersion': 'event-proximity-v1',
                      'source': 'ticketmaster_coordinates_swappy_policy',
                      'disclaimer':
                          'Proximity does not establish ownership or eligibility.',
                    },
                    'swapAvailability': {
                      'publishedPostCount': 3,
                      'requestablePostCount': 2,
                      'hasAvailability': true,
                    },
                    'isFavorite': true,
                    'matchesPreferredSport': true,
                  },
                ],
                'selectedContextRef': 'ticketmaster:event-1',
                'observationExpiresAt': '2026-08-13T08:05:00.000Z',
              }),
              201,
            );
          }),
        ),
        clock: () => DateTime.utc(2026, 8, 13, 8, 2),
      );
      final observedAt = DateTime.utc(2026, 8, 13, 8);

      final result = await repository.evaluateNearbyEvents(
        LocationObservation(
          latitude: 17.385,
          longitude: 78.4867,
          accuracyMeters: 25,
          observedAt: observedAt,
          countryCode: 'in',
        ),
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1/ticketed-experience/nearby-events');
      expect(jsonDecode(captured.body), {
        'latitude': 17.385,
        'longitude': 78.4867,
        'accuracyMeters': 25.0,
        'observedAt': '2026-08-13T08:00:00.000Z',
        'countryCode': 'IN',
      });
      expect(result.selectedContextRef, 'ticketmaster:event-1');
      expect(
        result.candidates.single.proximity.status,
        EventProximityStatus.proximityEligible,
      );
      expect(
        result.candidates.single.proximity.disclaimer,
        contains('does not establish ownership'),
      );
      expect(result.candidates.single.swapAvailability.publishedPostCount, 3);
      expect(result.candidates.single.isFavorite, isTrue);
      expect(result.candidates.single.matchesPreferredSport, isTrue);
      expect(result.observationExpiresAt, DateTime.utc(2026, 8, 13, 8, 5));
    },
  );

  test('loads the authoritative server section layout', () async {
    late http.Request captured;
    const contextRef = 'ticketmaster:event:tm_sf_warriors_celtics_2026';
    final repository = HomeFeedRepository(
      apiWith(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'contextRef': contextRef,
              'eventName': 'NBA Finals',
              'venueName': 'Chase Center',
              'exactSeatCoordinatesAvailable': false,
              'staticSeatMapUrl': null,
              'schematic': {
                'version': 'seeded-section-schematic-v1',
                'centerLabel': 'Court',
                'zones': [
                  {
                    'label': 'North',
                    'sections': ['101', '102'],
                  },
                  {
                    'label': 'South',
                    'sections': ['107', '108'],
                  },
                ],
              },
              'source': {
                'provider': 'ticketmaster',
                'capability': 'discovery_only',
                'observedAt': '2026-08-26T05:00:00.000Z',
              },
              'disclaimer': 'Provider data supplies event context only.',
            }),
            200,
          );
        }),
      ),
    );

    final layout = await repository.getEventLayout(contextRef);

    expect(captured.method, 'GET');
    expect(
      captured.url.path,
      '/v1/ticketed-experience/events/${Uri.encodeComponent(contextRef)}/layout',
    );
    expect(layout.schematic?.centerLabel, 'Court');
    expect(layout.schematic?.zones.first.sections, ['101', '102']);
  });

  test(
    'reverse geocodes a fresh observation without retaining coordinates',
    () async {
      late http.Request captured;
      final repository = HomeFeedRepository(
        apiWith(
          MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'displayLabel': 'Madhapur, Hyderabad',
                'locality': 'Hyderabad',
                'region': 'Telangana',
                'countryCode': 'IN',
                'expiresAt': '2026-08-13T08:10:00.000Z',
              }),
              201,
            );
          }),
        ),
        clock: () => DateTime.utc(2026, 8, 13, 8, 1),
      );

      final result = await repository.reverseGeocode(
        LocationObservation(
          latitude: 17.4483,
          longitude: 78.3915,
          accuracyMeters: 18,
          observedAt: DateTime.utc(2026, 8, 13, 8),
        ),
        locale: 'en-IN',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/v1/me/location/reverse-geocode');
      expect(jsonDecode(captured.body), {
        'latitude': 17.4483,
        'longitude': 78.3915,
        'accuracyMeters': 18.0,
        'observedAt': '2026-08-13T08:00:00.000Z',
        'locale': 'en-IN',
      });
      expect(result.displayLabel, 'Madhapur, Hyderabad');
      expect(result.countryCode, 'IN');
    },
  );

  test(
    'integrates event and sport preferences with preferred events',
    () async {
      final requests = <String>[];
      Map<String, dynamic> preferences({
        List<String> favorites = const [],
        List<Map<String, String>> sports = const [],
        int version = 1,
      }) => {
        'favoriteEventContextRefs': favorites,
        'preferredSports': sports,
        'version': version,
      };
      final repository = HomeFeedRepository(
        apiWith(
          MockClient((request) async {
            requests.add('${request.method} ${request.url}');
            if (request.url.path == '/v1/ticketed-experience/sports') {
              return http.Response(
                jsonEncode({
                  'sports': [
                    {'key': 'basketball', 'displayName': 'Basketball'},
                  ],
                }),
                200,
              );
            }
            if (request.method == 'GET' &&
                request.url.path == '/v1/me/preferences') {
              return http.Response(jsonEncode(preferences()), 200);
            }
            if (request.method == 'PUT' &&
                request.url.pathSegments.contains('events')) {
              return http.Response(
                jsonEncode(
                  preferences(
                    favorites: const ['ticketmaster:event:event-1'],
                    version: 2,
                  ),
                ),
                200,
              );
            }
            if (request.method == 'DELETE' &&
                request.url.pathSegments.contains('sports')) {
              return http.Response(jsonEncode(preferences(version: 3)), 200);
            }
            if (request.url.path == '/v1/me/preferred-events') {
              return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'event': _eventJson(),
                      'swapAvailability': {
                        'publishedPostCount': 1,
                        'requestablePostCount': 1,
                        'hasAvailability': true,
                      },
                      'isFavorite': true,
                      'matchesPreferredSport': false,
                    },
                  ],
                  'total': 1,
                  'limit': 20,
                  'offset': 0,
                }),
                200,
              );
            }
            return http.Response('Not found', 404);
          }),
        ),
      );

      final sports = await repository.getSupportedSports();
      final initial = await repository.getPreferences();
      final favorite = await repository.setFavoriteEvent(
        'ticketmaster:event:event-1',
        favorite: true,
      );
      final removedSport = await repository.setSportPreference(
        'basketball',
        preferred: false,
      );
      final preferred = await repository.getPreferredEvents();

      expect(sports.single.displayName, 'Basketball');
      expect(initial.favoriteEventContextRefs, isEmpty);
      expect(favorite.favoriteEventContextRefs, ['ticketmaster:event:event-1']);
      expect(removedSport.version, 3);
      expect(preferred.items.single.swapAvailability.publishedPostCount, 1);
      expect(preferred.items.single.isFavorite, isTrue);
      expect(requests, hasLength(5));
    },
  );

  test('rejects a stale location observation before transport', () async {
    var transportCalled = false;
    final repository = HomeFeedRepository(
      apiWith(
        MockClient((_) async {
          transportCalled = true;
          return http.Response('{}', 201);
        }),
      ),
      clock: () => DateTime.utc(2026, 8, 13, 8, 11),
    );

    await expectLater(
      repository.evaluateNearbyEvents(
        LocationObservation(
          latitude: 17.385,
          longitude: 78.4867,
          accuracyMeters: 25,
          observedAt: DateTime.utc(2026, 8, 13, 8),
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('stale'),
        ),
      ),
    );
    expect(transportCalled, isFalse);
  });
}

Map<String, dynamic> _eventJson({String contextRef = 'ticketmaster:event-1'}) =>
    {
      'contextRef': contextRef,
      'provider': 'ticketmaster',
      'providerEventId': contextRef.split('-').last,
      'title': 'Provider Event',
      'category': 'Music',
      'startsAt': '2026-08-13T10:00:00.000Z',
      'endsAt': null,
      'timezone': 'Asia/Kolkata',
      'venue': {
        'providerVenueId': 'venue-1',
        'name': 'Provider Venue',
        'city': 'Hyderabad',
        'stateCode': 'TG',
        'countryCode': 'IN',
        'latitude': 17.385,
        'longitude': 78.4867,
      },
      'imageUrl': null,
      'staticSeatMapUrl': null,
      'providerEventUrl': null,
      'sourceObservedAt': '2026-08-13T07:59:00.000Z',
      'disclaimer': 'Provider discovery context only.',
    };
