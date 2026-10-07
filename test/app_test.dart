import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/core/theme/widgets/swappy_floating_dock.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_gateway.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_marketplace_models.dart';
import 'package:swappy_mobile/features/exchange/domain/exchange_models.dart';
import 'package:swappy_mobile/features/exchange/providers/exchange_provider.dart';
import 'package:swappy_mobile/features/foundation/presentation/participant_foundation_screen.dart';
import 'package:swappy_mobile/features/home/data/home_feed_repository.dart';
import 'package:swappy_mobile/features/home/data/foreground_location_source.dart';
import 'package:swappy_mobile/features/home/domain/discovered_event.dart';
import 'package:swappy_mobile/features/home/presentation/home_feed_screen.dart';
import 'package:swappy_mobile/features/home/providers/home_feed_provider.dart';
import 'package:swappy_mobile/features/tickets/domain/ticket_gateway.dart';
import 'package:swappy_mobile/features/tickets/domain/ticket_models.dart';
import 'package:swappy_mobile/features/tickets/providers/ticket_provider.dart';

class _FakeHomeRepository extends HomeFeedRepository {
  _FakeHomeRepository()
    : super(
        ApiClient(
          baseUri: Uri.parse('https://api.example.com/'),
          accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
        ),
      );

  ParticipantEventPreferences _preferences = const ParticipantEventPreferences(
    favoriteEventContextRefs: [],
    preferredSports: [],
    version: 1,
  );

  @override
  Future<EventDiscoveryPage> discoverEvents({
    required String city,
    String? stateCode,
    required String countryCode,
    String? category,
    String? keyword,
    int page = 0,
    int size = 20,
  }) async => EventDiscoveryPage(
    items: [
      DiscoveredEvent(
        contextRef: 'ticketmaster:event:event-1',
        providerEventId: 'event-1',
        title: 'City Basketball Finals',
        category: 'Sports',
        startsAt: DateTime.utc(2026, 8, 8, 19, 30),
        timezone: 'Asia/Kolkata',
        venueName: 'Central Arena',
        city: city,
        stateCode: stateCode,
        countryCode: countryCode,
        imageUrl: null,
        staticSeatMapUrl: null,
        providerEventUrl: null,
        disclaimer: 'Discovery only.',
      ),
    ],
    page: const EventPageInfo(
      number: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
    ),
    source: const EventDiscoverySource(
      provider: 'ticketmaster',
      capability: 'discovery_only',
      stale: false,
    ),
  );

  @override
  Future<NearbyEventsResult> evaluateNearbyEvents(
    LocationObservation observation,
  ) async => NearbyEventsResult(
    candidates: [
      NearbyEventCandidate(
        event: DiscoveredEvent(
          contextRef: 'ticketmaster:event:nearby-1',
          providerEventId: 'nearby-1',
          title: 'Nearby Provider Event',
          category: 'Music',
          startsAt: DateTime.utc(2026, 8, 14, 18),
          timezone: 'Asia/Kolkata',
          venueName: 'Nearby Arena',
          city: 'Hyderabad',
          stateCode: 'TG',
          countryCode: 'IN',
          imageUrl: null,
          staticSeatMapUrl: null,
          providerEventUrl: null,
          disclaimer: 'Discovery only.',
        ),
        proximity: EventProximity(
          status: EventProximityStatus.proximityEligible,
          distanceMeters: 120,
          radiusMeters: 400,
          observedAccuracyMeters: observation.accuracyMeters,
          activeFrom: null,
          activeUntil: null,
          policyVersion: 'v1',
          source: 'server',
          disclaimer: 'Advisory only.',
        ),
        swapAvailability: const EventSwapAvailability(
          publishedPostCount: 2,
          requestablePostCount: 2,
          hasAvailability: true,
        ),
        isFavorite: false,
        matchesPreferredSport: false,
      ),
    ],
    selectedContextRef: 'ticketmaster:event:nearby-1',
    observationExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
  );

  @override
  Future<ResolvedLocation> reverseGeocode(
    LocationObservation observation, {
    String? locale,
  }) async => ResolvedLocation(
    displayLabel: 'Madhapur, Hyderabad',
    locality: 'Hyderabad',
    region: 'Telangana',
    countryCode: 'IN',
    expiresAt: DateTime.now().add(const Duration(minutes: 10)),
  );

  @override
  Future<List<SportPreference>> getSupportedSports() async => const [
    SportPreference(key: 'basketball', displayName: 'Basketball'),
    SportPreference(key: 'football', displayName: 'American Football'),
  ];

  @override
  Future<ParticipantEventPreferences> getPreferences() async => _preferences;

  @override
  Future<ParticipantEventPreferences> setFavoriteEvent(
    String contextRef, {
    required bool favorite,
  }) async {
    final favorites = _preferences.favoriteEventContextRefs.toSet();
    favorite ? favorites.add(contextRef) : favorites.remove(contextRef);
    _preferences = ParticipantEventPreferences(
      favoriteEventContextRefs: favorites.toList(growable: false),
      preferredSports: _preferences.preferredSports,
      version: _preferences.version + 1,
    );
    return _preferences;
  }

  @override
  Future<ParticipantEventPreferences> setSportPreference(
    String sportKey, {
    required bool preferred,
  }) async {
    final sports = [..._preferences.preferredSports];
    sports.removeWhere((sport) => sport.key == sportKey);
    if (preferred) {
      sports.add(
        SportPreference(
          key: sportKey,
          displayName: sportKey == 'basketball'
              ? 'Basketball'
              : 'American Football',
        ),
      );
    }
    _preferences = ParticipantEventPreferences(
      favoriteEventContextRefs: _preferences.favoriteEventContextRefs,
      preferredSports: sports,
      version: _preferences.version + 1,
    );
    return _preferences;
  }

  @override
  Future<PreferredEventsPage> getPreferredEvents({
    int limit = 20,
    int offset = 0,
  }) async => PreferredEventsPage(
    items: const [],
    total: 0,
    limit: limit,
    offset: offset,
  );
}

class _ReverseGeocodeFailingHomeRepository extends _FakeHomeRepository {
  @override
  Future<ResolvedLocation> reverseGeocode(
    LocationObservation observation, {
    String? locale,
  }) => throw const ApiRequestException(
    'Your area could not be resolved. Try again or search by city.',
  );
}

class _ReverseGeocodeFailsAfterSuccessHomeRepository
    extends _FakeHomeRepository {
  int reverseGeocodeCalls = 0;
  int discoveryCalls = 0;

  @override
  Future<ResolvedLocation> reverseGeocode(
    LocationObservation observation, {
    String? locale,
  }) {
    reverseGeocodeCalls++;
    if (reverseGeocodeCalls > 1) {
      throw const ApiRequestException(
        'Your area could not be resolved. Try again or search by city.',
      );
    }
    return super.reverseGeocode(observation, locale: locale);
  }

  @override
  Future<EventDiscoveryPage> discoverEvents({
    required String city,
    String? stateCode,
    required String countryCode,
    String? category,
    String? keyword,
    int page = 0,
    int size = 20,
  }) {
    discoveryCalls++;
    return super.discoverEvents(
      city: city,
      stateCode: stateCode,
      countryCode: countryCode,
      category: category,
      keyword: keyword,
      page: page,
      size: size,
    );
  }
}

class _FakeLocationGateway implements ForegroundLocationGateway {
  String? requestedCountryCode;

  @override
  Future<LocationObservation> currentObservation({String? countryCode}) async {
    requestedCountryCode = countryCode;
    return LocationObservation(
      latitude: 17.385,
      longitude: 78.4867,
      accuracyMeters: 25,
      observedAt: DateTime.now(),
      countryCode: countryCode,
    );
  }

  @override
  Future<bool> openSettings(LocationAccessIssue issue) async => false;
}

Widget _withFeed(
  Widget child, {
  HomeFeedRepository? homeRepository,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) =>
          HomeFeedProvider(repository: homeRepository ?? _FakeHomeRepository()),
    ),
    ChangeNotifierProvider(
      create: (_) => ExchangeProvider(gateway: _FakeExchangeGateway()),
    ),
    ChangeNotifierProvider(
      create: (_) => TicketProvider(gateway: _FakeTicketGateway()),
    ),
  ],
  child: MaterialApp(theme: ThemeData.light(useMaterial3: true), home: child),
);

Widget _withExistingFeed(Widget child, HomeFeedProvider feed) =>
    ChangeNotifierProvider<HomeFeedProvider>.value(
      value: feed,
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: child,
      ),
    );

class _FakeTicketGateway implements TicketGateway {
  @override
  Future<TicketPage<TicketImportProjection>> listImports({
    TicketImportState? state,
  }) async => const TicketPage(items: [], total: 0);

  @override
  Future<TicketPage<TicketBundleProjection>> listTickets() async =>
      const TicketPage(items: [], total: 0);

  @override
  Future<CreatedTicketImport> createImport(
    String countryCode, {
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<TicketImportProjection> getImport(String ticketImportId) =>
      throw UnimplementedError();

  @override
  Future<TicketBundleProjection> getTicket(String ticketBundleId) =>
      throw UnimplementedError();

  @override
  Future<TicketImportProjection> uploadTicket({
    required TicketUploadAuthorization authorization,
    required List<int> bytes,
    required String filename,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<CreatedTicketImport> refreshUploadAuthorization(
    String ticketImportId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ConfirmedTicketImport> confirmImport(
    String ticketImportId, {
    required String contextRef,
    required String? sectionLabel,
    required String? rowLabel,
    required List<String> seatLabels,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<TicketEvidenceResult> consumeConfirmedImport(
    ConfirmedTicketImport confirmed, {
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

class _FakeExchangeGateway implements ExchangeGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ExchangePage<EvidenceProjection>> listEvidence({
    int limit = 50,
    int offset = 0,
    EvidenceState? state,
  }) async => const ExchangePage(items: [], total: 0);

  @override
  Future<ExchangePage<EntitlementProjection>> listEntitlements({
    int limit = 50,
    int offset = 0,
    EntitlementState? state,
  }) async => const ExchangePage(items: [], total: 0);

  @override
  Future<ExchangePage<SwapIntentProjection>> listSwapIntents({
    int limit = 50,
    int offset = 0,
    SwapIntentState? state,
  }) async => const ExchangePage(items: [], total: 0);

  @override
  Future<ExchangePage<SwapPostProjection>> listPublishedSwapPosts({
    String? contextRef,
    int limit = 50,
    int offset = 0,
  }) async => const ExchangePage(items: [], total: 0);

  @override
  Future<ExchangePage<SwapRequestProjection>> listSwapRequests({
    int limit = 50,
    int offset = 0,
    SwapRequestState? state,
  }) async => const ExchangePage(items: [], total: 0);

  @override
  Future<EvidenceProjection> getEvidence(String evidenceId) =>
      throw UnimplementedError();

  @override
  Future<EntitlementProjection> getEntitlement(String entitlementId) =>
      throw UnimplementedError();

  @override
  Future<SwapIntentDetail> getSwapIntent(String intentId) =>
      throw UnimplementedError();

  @override
  Future<EvidenceProjection> submitEvidence(
    EvidenceSubmissionRequest request, {
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<SwapIntentProjection> createSwapIntent(
    CreateSwapIntentRequest request, {
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<SwapIntentProjection> updateSwapIntent(
    String intentId,
    UpdateSwapIntentRequest request, {
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<SwapIntentProjection> publishSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<SwapIntentProjection> pauseSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<SwapIntentProjection> resumeSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<SwapIntentProjection> withdrawSwapIntent(
    String intentId, {
    required int expectedVersion,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets('home is event-first and does not expose buying capsules', (
    tester,
  ) async {
    await tester.pumpWidget(_withFeed(HomeFeedScreen(onProfileTap: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Swappy participant'), findsOneWidget);
    expect(find.text('Use current location or choose a city'), findsOneWidget);
    expect(find.text('City Basketball Finals'), findsNothing);

    await tester.tap(find.byTooltip('Choose an event search city'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'City'),
      'Hyderabad',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'State code (optional)'),
      'TG',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Country code'),
      'IN',
    );
    await tester.tap(find.text('Show events'));
    await tester.pumpAndSettle();

    expect(find.text('Hyderabad, TG, IN'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Featured in Hyderabad'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Featured in Hyderabad'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('City Basketball Finals'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('City Basketball Finals'), findsWidgets);
    expect(find.textContaining('Provider event discovery only'), findsWidgets);
    expect(find.textContaining('swaps available'), findsNothing);
    expect(find.text('Events near you'), findsNothing);
    expect(find.text('Buying'), findsNothing);
    expect(find.text('Selling'), findsNothing);
  });

  testWidgets('home saves sport and event preferences through the provider', (
    tester,
  ) async {
    await tester.pumpWidget(_withFeed(HomeFeedScreen(onProfileTap: () {})));
    await tester.pumpAndSettle();

    final basketball = find.widgetWithText(FilterChip, 'Basketball');
    expect(tester.widget<FilterChip>(basketball).selected, isFalse);
    await tester.tap(basketball);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(basketball).selected, isTrue);

    await tester.tap(find.byTooltip('Choose an event search city'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'City'),
      'Hyderabad',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Country code'),
      'IN',
    );
    await tester.tap(find.text('Show events'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('City Basketball Finals'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final saveFavorite = find.byTooltip('Save favorite event');
    expect(saveFavorite, findsWidgets);
    await tester.tap(saveFavorite.first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favorite events'), findsWidgets);
  });

  testWidgets('participant foundation has exactly three dock destinations', (
    tester,
  ) async {
    await tester.pumpWidget(_withFeed(const ParticipantFoundationScreen()));
    await tester.pump();

    expect(find.byType(SwappyFloatingDock), findsOneWidget);
    expect(
      find.byKey(const ValueKey('swappy-dock-destination-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('swappy-dock-destination-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('swappy-dock-destination-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('swappy-dock-selected-icon-stroke-0')),
      findsOneWidget,
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Swaps'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNothing);
    expect(find.textContaining('LOCAL DEVELOPMENT'), findsNothing);

    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('swappy-dock-selected-icon-stroke-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('swappy-dock-selected-icon-stroke-0')),
      findsNothing,
    );
  });

  testWidgets('nearby uses one foreground observation and server result', (
    tester,
  ) async {
    final location = _FakeLocationGateway();
    await tester.pumpWidget(
      _withFeed(HomeFeedScreen(onProfileTap: () {}, locationGateway: location)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Choose an event search city'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'City'),
      'Hyderabad',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Country code'),
      'IN',
    );
    await tester.tap(find.text('Show events'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use current location'));
    await tester.pumpAndSettle();

    expect(find.text('Nearby Provider Event'), findsOneWidget);
    expect(find.text('Madhapur, Hyderabad'), findsOneWidget);
    expect(find.textContaining('nearby event(s) found'), findsOneWidget);
    expect(find.textContaining('Inside event zone'), findsOneWidget);
    expect(find.textContaining('2 published Posts'), findsOneWidget);
    expect(location.requestedCountryCode, isNull);
    expect(
      find.textContaining('ownership or swap eligibility'),
      findsOneWidget,
    );
  });

  testWidgets(
    'header location action still evaluates nearby when address lookup fails',
    (tester) async {
      final location = _FakeLocationGateway();
      await tester.pumpWidget(
        _withFeed(
          HomeFeedScreen(onProfileTap: () {}, locationGateway: location),
          homeRepository: _ReverseGeocodeFailingHomeRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Use current location'), findsOneWidget);
      await tester.tap(find.byTooltip('Use current location'));
      await tester.pumpAndSettle();

      expect(find.text('Nearby Provider Event'), findsOneWidget);
      expect(
        find.text(
          'Your area could not be resolved. Try again or search by city.',
        ),
        findsOneWidget,
      );
      expect(location.requestedCountryCode, isNull);
    },
  );

  testWidgets('failed location refresh never reuses the previous city', (
    tester,
  ) async {
    final repository = _ReverseGeocodeFailsAfterSuccessHomeRepository();
    final feed = HomeFeedProvider(repository: repository);
    await tester.pumpWidget(
      _withExistingFeed(
        HomeFeedScreen(
          key: const ValueKey('initial-home'),
          onProfileTap: () {},
          locationGateway: _FakeLocationGateway(),
        ),
        feed,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Use current location'));
    await tester.pumpAndSettle();
    expect(find.text('Madhapur, Hyderabad'), findsOneWidget);
    expect(repository.discoveryCalls, 1);

    await tester.tap(find.byTooltip('Use current location'));
    await tester.pumpAndSettle();

    expect(find.text('Madhapur, Hyderabad'), findsNothing);
    expect(find.text('Nearby Provider Event'), findsOneWidget);
    expect(repository.discoveryCalls, 1);
    expect(feed.activeCity, isNull);

    await tester.pumpWidget(
      _withExistingFeed(
        HomeFeedScreen(
          key: const ValueKey('recreated-home'),
          onProfileTap: () {},
          locationGateway: _FakeLocationGateway(),
        ),
        feed,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Madhapur, Hyderabad'), findsNothing);
    expect(find.text('City Basketball Finals'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    feed.dispose();
  });

  testWidgets('foundation uses real exchange empty states without mock data', (
    tester,
  ) async {
    await tester.pumpWidget(_withFeed(const ParticipantFoundationScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to do?'), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-seats')), findsOneWidget);
    expect(find.text('Add seats to offer'), findsOneWidget);
    expect(find.text('Find seats'), findsOneWidget);
    expect(find.text('Protected ticket upload'), findsOneWidget);
    await tester.tap(find.text('Find seats'));
    await tester.pumpAndSettle();
    expect(find.text('Find a seat to swap'), findsOneWidget);
    expect(find.text('No seat offers yet'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No tickets yet'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('No tickets yet'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.textContaining('does not verify ownership'), findsOneWidget);

    await tester.tap(find.text('Swaps'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swap-filter-all')), findsOneWidget);
    expect(
      find.byType(FilterChip),
      findsNWidgets(SwapIntentState.values.length + 1),
    );
    expect(find.text('No swap intents returned'), findsOneWidget);
    expect(
      find.textContaining('No sample swaps are displayed'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('swap-requests')));
    await tester.pumpAndSettle();
    expect(find.text('Incoming'), findsOneWidget);
    expect(find.text('Outgoing'), findsOneWidget);
    expect(find.text('No incoming requests'), findsOneWidget);
  });
}
