import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/home/data/home_feed_repository.dart';
import 'package:swappy_mobile/features/home/domain/discovered_event.dart';
import 'package:swappy_mobile/features/home/providers/home_feed_provider.dart';

void main() {
  test(
    'appends the next real page without duplicating event contexts',
    () async {
      final repository = _PagedHomeRepository();
      final provider = HomeFeedProvider(repository: repository);

      await provider.discoverEvents(
        city: 'Hyderabad',
        stateCode: 'TG',
        countryCode: 'IN',
        category: 'Music',
        keyword: 'live',
      );

      expect(provider.events.map((event) => event.contextRef), ['event-1']);
      expect(provider.hasMoreEvents, isTrue);
      await provider.loadMoreEvents();

      expect(provider.events.map((event) => event.contextRef), [
        'event-1',
        'event-2',
      ]);
      expect(provider.hasMoreEvents, isFalse);
      expect(repository.requestedPages, [0, 1]);
      expect(repository.lastCountryCode, 'IN');
      expect(repository.lastKeyword, 'live');
    },
  );

  test('keeps loaded events when loading the next page fails', () async {
    final repository = _PagedHomeRepository(failSecondPage: true);
    final provider = HomeFeedProvider(repository: repository);
    await provider.discoverEvents(city: 'Pune', countryCode: 'IN');

    await provider.loadMoreEvents();

    expect(provider.events.single.contextRef, 'event-1');
    expect(provider.loadMoreErrorMessage, contains('next page failed'));
    expect(provider.errorMessage, isNull);
    expect(provider.isLoadingMore, isFalse);
  });

  test(
    'stores only the server nearby result, not device coordinates',
    () async {
      final repository = _PagedHomeRepository();
      final provider = HomeFeedProvider(repository: repository);

      await provider.evaluateNearby(
        LocationObservation(
          latitude: 17.385,
          longitude: 78.4867,
          accuracyMeters: 25,
          observedAt: DateTime.now(),
          countryCode: 'IN',
        ),
      );

      expect(repository.nearbyCalls, 1);
      expect(provider.nearby?.candidates, isEmpty);
      expect(provider.nearbyErrorMessage, isNull);
    },
  );

  test('clears nearby candidates when a refresh fails', () async {
    final repository = _PagedHomeRepository();
    final provider = HomeFeedProvider(repository: repository);
    final observation = LocationObservation(
      latitude: 17.385,
      longitude: 78.4867,
      accuracyMeters: 25,
      observedAt: DateTime.now(),
      countryCode: 'IN',
    );
    await provider.evaluateNearby(observation);
    expect(provider.nearby, isNotNull);

    repository.failNearby = true;
    await provider.evaluateNearby(observation);

    expect(provider.nearby, isNull);
    expect(provider.nearbyErrorMessage, contains('nearby failed'));
  });

  test('clears a prior resolved address when a new lookup fails', () async {
    final repository = _PagedHomeRepository();
    final provider = HomeFeedProvider(repository: repository);
    final observation = LocationObservation(
      latitude: 17.385,
      longitude: 78.4867,
      accuracyMeters: 25,
      observedAt: DateTime.now(),
      countryCode: 'IN',
    );

    expect(await provider.resolveLocation(observation), isTrue);
    expect(provider.resolvedLocation?.displayLabel, 'Madhapur, Hyderabad');

    repository.failLocation = true;
    expect(await provider.resolveLocation(observation), isFalse);

    expect(provider.resolvedLocation, isNull);
    expect(provider.resolvedLocationError, contains('area could not'));
  });
}

class _PagedHomeRepository extends HomeFeedRepository {
  _PagedHomeRepository({this.failSecondPage = false})
    : super(
        ApiClient(
          baseUri: Uri.parse('https://api.example.test'),
          accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
        ),
      );

  final bool failSecondPage;
  final List<int> requestedPages = [];
  String? lastCountryCode;
  String? lastKeyword;
  int nearbyCalls = 0;
  bool failNearby = false;
  bool failLocation = false;

  @override
  Future<EventDiscoveryPage> discoverEvents({
    required String city,
    String? stateCode,
    required String countryCode,
    String? category,
    String? keyword,
    int page = 0,
    int size = 20,
  }) async {
    requestedPages.add(page);
    lastCountryCode = countryCode;
    lastKeyword = keyword;
    if (page == 1 && failSecondPage) {
      throw const ApiRequestException('The next page failed.');
    }
    return EventDiscoveryPage(
      items: [
        _event(page == 0 ? 'event-1' : 'event-1'),
        if (page == 1) _event('event-2'),
      ],
      page: EventPageInfo(
        number: page,
        size: size,
        totalElements: 2,
        totalPages: 2,
      ),
      source: const EventDiscoverySource(
        provider: 'ticketmaster',
        capability: 'discovery_only',
        stale: false,
      ),
    );
  }

  @override
  Future<NearbyEventsResult> evaluateNearbyEvents(
    LocationObservation observation,
  ) async {
    nearbyCalls++;
    if (failNearby) {
      throw const ApiRequestException('The nearby failed.');
    }
    return NearbyEventsResult(
      candidates: const [],
      selectedContextRef: null,
      observationExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<ResolvedLocation> reverseGeocode(
    LocationObservation observation, {
    String? locale,
  }) async {
    if (failLocation) {
      throw const ApiRequestException(
        'Your area could not be resolved. Try again or search by city.',
      );
    }
    return ResolvedLocation(
      displayLabel: 'Madhapur, Hyderabad',
      locality: 'Hyderabad',
      region: 'Telangana',
      countryCode: 'IN',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }
}

DiscoveredEvent _event(String contextRef) => DiscoveredEvent(
  contextRef: contextRef,
  providerEventId: contextRef,
  title: contextRef,
  category: null,
  startsAt: null,
  timezone: null,
  venueName: null,
  city: null,
  stateCode: null,
  countryCode: null,
  imageUrl: null,
  staticSeatMapUrl: null,
  providerEventUrl: null,
  disclaimer: 'Discovery only.',
);
