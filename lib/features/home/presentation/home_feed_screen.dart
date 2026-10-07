import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/swappy_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/foreground_location_source.dart';
import '../domain/discovered_event.dart';
import '../providers/home_feed_provider.dart';
import 'event_seat_layout_screen.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({
    required this.onProfileTap,
    this.locationGateway = const GeolocatorForegroundLocationGateway(),
    super.key,
  });
  final VoidCallback onProfileTap;
  final ForegroundLocationGateway locationGateway;

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final _heroController = PageController(viewportFraction: .92);
  final _search = TextEditingController();
  int _heroPage = 0;
  String _stateCode = '';
  String _city = '';
  String _countryCode = '';
  String _category = 'All';
  LocationAccessException? _locationError;
  bool _acquiringLocation = false;
  bool _restoredFeedState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeFeedProvider>().loadPersonalization();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restoredFeedState) return;
    _restoredFeedState = true;
    final feed = context.read<HomeFeedProvider>();
    final resolved = feed.resolvedLocation;
    _city = feed.activeCity ?? resolved?.locality ?? '';
    _stateCode = feed.activeStateCode ?? '';
    _countryCode = feed.activeCountryCode ?? resolved?.countryCode ?? '';
    _category = feed.activeCategory ?? 'All';
    _search.text = feed.activeKeyword ?? '';
  }

  @override
  void dispose() {
    _heroController.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_city.isEmpty || _countryCode.isEmpty) return;
    final feed = context.read<HomeFeedProvider>();
    await feed.discoverEvents(
      city: _city,
      stateCode: _stateCode.isEmpty ? null : _stateCode,
      countryCode: _countryCode,
      category: _category,
      keyword: _search.text,
    );
  }

  Future<void> _searchEvents() async {
    if (_city.isEmpty || _countryCode.isEmpty) {
      await _showFilters();
      return;
    }
    await _load();
  }

  Future<void> _refresh() async {
    final feed = context.read<HomeFeedProvider>();
    await Future.wait([_load(), feed.loadPersonalization()]);
  }

  Future<void> _checkNearby() async {
    if (_acquiringLocation) return;
    context.read<HomeFeedProvider>().clearNearby();
    setState(() {
      _acquiringLocation = true;
      _locationError = null;
    });
    try {
      final observation = await widget.locationGateway.currentObservation();
      if (!mounted) return;
      final feed = context.read<HomeFeedProvider>();
      // Nearby evaluation accepts a fresh observation without a country code.
      // Start it independently so an address-provider failure cannot suppress
      // otherwise valid nearby results.
      final nearbyFuture = feed.evaluateNearby(observation);
      feed.clearDiscovery();
      setState(() {
        _city = '';
        _stateCode = '';
        _countryCode = '';
        _heroPage = 0;
      });
      final resolvedSuccessfully = await feed.resolveLocation(
        observation,
        locale: Localizations.localeOf(context).toLanguageTag(),
      );
      if (!mounted) return;
      final address = feed.resolvedLocation;
      if (resolvedSuccessfully && address != null) {
        setState(() {
          _city = address.locality;
          _stateCode = '';
          _countryCode = address.countryCode;
          _heroPage = 0;
        });
      }
      await Future.wait([
        nearbyFuture,
        if (resolvedSuccessfully && _city.isNotEmpty && _countryCode.isNotEmpty)
          _load(),
      ]);
    } on LocationAccessException catch (error) {
      if (mounted) setState(() => _locationError = error);
    } finally {
      if (mounted) setState(() => _acquiringLocation = false);
    }
  }

  Future<void> _openLocationSettings() async {
    final error = _locationError;
    if (error == null) return;
    await widget.locationGateway.openSettings(error.issue);
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<HomeFeedProvider>();
    final auth = Provider.of<AuthProvider?>(context);
    final events = feed.events;
    final displayName = auth?.profile?.displayName?.trim();
    final participantName = displayName == null || displayName.isEmpty
        ? 'Swappy participant'
        : displayName;
    final addressLabel = feed.isResolvingLocation
        ? 'Finding your area…'
        : feed.resolvedLocation?.displayLabel ??
              (_city.isEmpty
                  ? 'Use current location or choose a city'
                  : [
                      _city,
                      if (_stateCode.isNotEmpty) _stateCode,
                      if (_countryCode.isNotEmpty) _countryCode,
                    ].join(', '));
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              leadingWidth: 64,
              leading: IconButton(
                tooltip: 'Profile and activity',
                onPressed: widget.onProfileTap,
                icon: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              title: Tooltip(
                message: 'Use current location',
                child: Semantics(
                  button: true,
                  label: '$participantName, current area $addressLabel',
                  hint: 'Use current location and find nearby events',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _acquiringLocation || feed.isLoadingNearby
                        ? null
                        : _checkNearby,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            participantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  addressLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.my_location, size: 12),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Choose an event search city',
                  onPressed: _showFilters,
                  icon: const Icon(Icons.location_city_outlined),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: SearchBar(
                  controller: _search,
                  hintText: 'Search events, artists or venues',
                  leading: const Icon(Icons.search),
                  trailing: [
                    IconButton(
                      tooltip: 'Search',
                      onPressed: _searchEvents,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    IconButton(
                      tooltip: 'Filters',
                      onPressed: _showFilters,
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                  onSubmitted: (_) => _searchEvents(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in const [
                      'All',
                      'Sports',
                      'Music',
                      'Arts & Theatre',
                      'Family',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _category == category,
                          onSelected: (_) {
                            setState(() => _category = category);
                            _searchEvents();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _NearbySection(
                result: feed.nearby,
                serverError: feed.nearbyErrorMessage,
                addressError: feed.resolvedLocationError,
                locationError: _locationError,
                isLoading: _acquiringLocation || feed.isLoadingNearby,
                onCheck: _checkNearby,
                onOpenSettings: _openLocationSettings,
                onEventTap: _openEvent,
                preferencesLoaded: feed.preferences != null,
                isFavorite: feed.isFavorite,
                isFavoriteBusy: feed.isFavoriteCommandRunning,
                onFavorite: feed.toggleFavoriteEvent,
              ),
            ),
            SliverToBoxAdapter(child: _SportsPreferenceSection(feed: feed)),
            SliverToBoxAdapter(
              child: _PreferredEventsSection(
                feed: feed,
                onEventTap: _openEvent,
                onFavorite: feed.toggleFavoriteEvent,
              ),
            ),
            if (_city.isEmpty || _countryCode.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.location_city_outlined,
                  title: 'Choose where to search',
                  message:
                      'Enter a city and country to load real provider event context.',
                  action: 'Choose location',
                  onPressed: _showFilters,
                ),
              )
            else if (feed.isLoading && events.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (feed.errorMessage != null && events.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Events are unavailable',
                  message: feed.errorMessage!,
                  action: 'Try again',
                  onPressed: _load,
                ),
              )
            else if (events.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _MessageState(
                  icon: Icons.event_busy_outlined,
                  title: 'No events found',
                  message: 'Try another location, category, or search.',
                  action: 'Change location',
                  onPressed: _showFilters,
                ),
              )
            else ...[
              if (feed.source?.stale ?? false)
                const SliverToBoxAdapter(child: _StaleSourceNotice()),
              _SectionHeader(title: 'Featured in $_city'),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 246,
                  child: PageView.builder(
                    controller: _heroController,
                    itemCount: events.take(5).length,
                    onPageChanged: (value) => setState(() => _heroPage = value),
                    itemBuilder: (_, index) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _HeroCard(
                        event: events[index],
                        onTap: () => _openEvent(events[index]),
                        isFavorite: feed.isFavorite(events[index].contextRef),
                        favoriteBusy: feed.isFavoriteCommandRunning(
                          events[index].contextRef,
                        ),
                        onFavorite: () =>
                            feed.toggleFavoriteEvent(events[index].contextRef),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      events.take(5).length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == _heroPage ? 22 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _heroPage
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const _SectionHeader(title: 'Upcoming events'),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _EventCard(
                    event: events[index],
                    onTap: () => _openEvent(events[index]),
                    isFavorite: feed.isFavorite(events[index].contextRef),
                    favoriteBusy: feed.isFavoriteCommandRunning(
                      events[index].contextRef,
                    ),
                    onFavorite: () =>
                        feed.toggleFavoriteEvent(events[index].contextRef),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _PaginationControl(
                  isLoading: feed.isLoadingMore,
                  hasMore: feed.hasMoreEvents,
                  errorMessage: feed.loadMoreErrorMessage,
                  onPressed: feed.loadMoreEvents,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
                  child: Text(
                    'Event and venue context is discovery-only provider data. '
                    'Discovery and proximity do not establish ticket ownership, '
                    'eligibility, transferability, provider inventory, or swap availability.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openEvent(DiscoveredEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventSeatLayoutScreen(
          eventTitle: event.title,
          venue: event.venueName ?? 'Venue to be confirmed',
          contextRef: event.contextRef,
          ticketmasterEventId: event.providerEventId,
          ticketmasterSeatMapUrl: event.staticSeatMapUrl,
        ),
      ),
    );
  }

  Future<void> _showFilters() async {
    final formKey = GlobalKey<FormState>();
    var city = _city;
    var stateCode = _stateCode;
    var countryCode = _countryCode;
    final result =
        await showModalBottomSheet<
          ({String stateCode, String city, String countryCode})
        >(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Choose your location',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the city, optional two-letter state code, and two-letter '
                      'country code expected by the discovery provider.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: city,
                      autofocus: _city.isEmpty,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(80)],
                      decoration: const InputDecoration(
                        labelText: 'City',
                        hintText: 'Hyderabad',
                      ),
                      validator: _validateCity,
                      onChanged: (value) => city = value,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: stateCode,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'State code (optional)',
                        hintText: 'TG',
                      ),
                      validator: _validateOptionalCode,
                      onChanged: (value) => stateCode = value,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: countryCode,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                        LengthLimitingTextInputFormatter(2),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Country code',
                        hintText: 'IN',
                      ),
                      validator: _validateRequiredCode,
                      onChanged: (value) => countryCode = value,
                      onFieldSubmitted: (_) {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        Navigator.pop(context, (
                          stateCode: stateCode.trim().toUpperCase(),
                          city: city.trim(),
                          countryCode: countryCode.trim().toUpperCase(),
                        ));
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        Navigator.pop(context, (
                          stateCode: stateCode.trim().toUpperCase(),
                          city: city.trim(),
                          countryCode: countryCode.trim().toUpperCase(),
                        ));
                      },
                      child: const Text('Show events'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    if (result != null && mounted) {
      final feed = context.read<HomeFeedProvider>();
      feed.clearResolvedLocation();
      feed.clearNearby();
      setState(() {
        _stateCode = result.stateCode;
        _city = result.city;
        _countryCode = result.countryCode;
        _heroPage = 0;
      });
      await _load();
    }
  }
}

class _SportsPreferenceSection extends StatelessWidget {
  const _SportsPreferenceSection({required this.feed});

  final HomeFeedProvider feed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your sports & event preferences',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh preferences',
                  onPressed: feed.isLoadingPreferences
                      ? null
                      : feed.loadPersonalization,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose sports to shape your preferred list. Favorites are saved from event cards.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (feed.isLoadingPreferences) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text('Loading saved preferences…'),
            ],
            if (feed.preferencesError != null) ...[
              const SizedBox(height: 10),
              Semantics(liveRegion: true, child: Text(feed.preferencesError!)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: feed.isLoadingPreferences
                    ? null
                    : feed.loadPersonalization,
                child: const Text('Retry preferences'),
              ),
            ],
            if (!feed.isLoadingPreferences &&
                feed.preferencesError == null &&
                feed.supportedSports.isEmpty) ...[
              const SizedBox(height: 10),
              const Text('No preference options are available right now.'),
            ],
            if (feed.supportedSports.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sport in feed.supportedSports)
                    FilterChip(
                      label: Text(sport.displayName),
                      selected: feed.isSportPreferred(sport.key),
                      onSelected: feed.isSportCommandRunning(sport.key)
                          ? null
                          : (_) => feed.toggleSportPreference(sport.key),
                      avatar: feed.isSportCommandRunning(sport.key)
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                ],
              ),
            ],
            if (feed.preferenceCommandError != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feed.preferenceCommandError!)),
                    IconButton(
                      tooltip: 'Dismiss preference error',
                      onPressed: feed.clearPreferenceCommandError,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PreferredEventsSection extends StatelessWidget {
  const _PreferredEventsSection({
    required this.feed,
    required this.onEventTap,
    required this.onFavorite,
  });

  final HomeFeedProvider feed;
  final ValueChanged<DiscoveredEvent> onEventTap;
  final Future<bool> Function(String contextRef) onFavorite;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your preferred events',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh preferred events',
                  onPressed: feed.isLoadingPreferredEvents
                      ? null
                      : () => feed.loadPreferredEvents(force: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (feed.isLoadingPreferredEvents) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text('Loading preferred events…'),
            ] else if (feed.preferredEventsError != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(feed.preferredEventsError!),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => feed.loadPreferredEvents(force: true),
                child: const Text('Retry preferred events'),
              ),
            ] else if (feed.preferredEvents.isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Favorite an event or choose a sport to build this list.',
              ),
            ] else ...[
              const SizedBox(height: 6),
              ...feed.preferredEvents.map((candidate) {
                final reference = candidate.event.contextRef;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    candidate.isFavorite
                        ? Icons.favorite
                        : Icons.sports_outlined,
                  ),
                  title: Text(candidate.event.title),
                  subtitle: Text(
                    '${_eventLine(candidate.event)}\n'
                    '${_publishedPostLabel(candidate.swapAvailability)}; '
                    'requestability is checked when opened.',
                  ),
                  isThreeLine: true,
                  trailing: _FavoriteButton(
                    isFavorite: feed.isFavorite(reference),
                    isBusy: feed.isFavoriteCommandRunning(reference),
                    onPressed: () => onFavorite(reference),
                  ),
                  onTap: () => onEventTap(candidate.event),
                );
              }),
            ],
          ],
        ),
      ),
    ),
  );
}

class _NearbySection extends StatelessWidget {
  const _NearbySection({
    required this.result,
    required this.serverError,
    required this.addressError,
    required this.locationError,
    required this.isLoading,
    required this.onCheck,
    required this.onOpenSettings,
    required this.onEventTap,
    required this.preferencesLoaded,
    required this.isFavorite,
    required this.isFavoriteBusy,
    required this.onFavorite,
  });

  final NearbyEventsResult? result;
  final String? serverError;
  final String? addressError;
  final LocationAccessException? locationError;
  final bool isLoading;
  final VoidCallback onCheck;
  final VoidCallback onOpenSettings;
  final ValueChanged<DiscoveredEvent> onEventTap;
  final bool preferencesLoaded;
  final bool Function(String contextRef) isFavorite;
  final bool Function(String contextRef) isFavoriteBusy;
  final Future<bool> Function(String contextRef) onFavorite;

  @override
  Widget build(BuildContext context) {
    final error = locationError?.message ?? addressError ?? serverError;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.near_me_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nearby event context',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          result == null
                              ? 'Use a one-time fresh foreground location. '
                                    'Swappy resolves only a coarse area label; '
                                    'proximity remains advisory.'
                              : result!.candidates.isEmpty
                              ? 'No nearby events were found for this location.'
                              : '${result!.candidates.length} nearby '
                                    'event(s) found.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 6),
                const Text('Getting your location and finding nearby events…'),
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                Semantics(liveRegion: true, child: Text(error)),
              ],
              if (result != null)
                ...result!.candidates.map((candidate) {
                  final reference = candidate.event.contextRef;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(candidate.event.title),
                    subtitle: Text(
                      '${_proximityLabel(candidate.proximity.status)} · '
                      '${candidate.proximity.distanceMeters == null ? 'Distance unavailable' : '${candidate.proximity.distanceMeters} m'} · '
                      '${_publishedPostLabel(candidate.swapAvailability)}'
                      '${candidate.matchesPreferredSport ? ' · Preferred sport' : ''}',
                    ),
                    trailing: _FavoriteButton(
                      isFavorite: preferencesLoaded
                          ? isFavorite(reference)
                          : candidate.isFavorite,
                      isBusy: isFavoriteBusy(reference),
                      onPressed: () => onFavorite(reference),
                    ),
                    onTap: () => onEventTap(candidate.event),
                  );
                }),
              if (result != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Nearby context is advisory only. It does not prove '
                  'ownership or swap eligibility.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: isLoading ? null : onCheck,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      result == null
                          ? 'Use current location'
                          : 'Refresh nearby',
                    ),
                  ),
                  if (locationError?.canOpenSettings ?? false)
                    TextButton.icon(
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Open settings'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _proximityLabel(EventProximityStatus status) => switch (status) {
  EventProximityStatus.locationUnknown => 'Location unknown',
  EventProximityStatus.outsideEventZone => 'Outside event zone',
  EventProximityStatus.proximityEligible => 'Inside event zone',
  EventProximityStatus.proximityExpired => 'Observation expired',
};

class _StaleSourceNotice extends StatelessWidget {
  const _StaleSourceNotice();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.update_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'The provider marked this discovery page as stale. Pull to '
                'refresh before relying on event details.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PaginationControl extends StatelessWidget {
  const _PaginationControl({
    required this.isLoading,
    required this.hasMore,
    required this.errorMessage,
    required this.onPressed,
  });

  final bool isLoading;
  final bool hasMore;
  final String? errorMessage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          children: [
            Text(errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onPressed, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (!hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: OutlinedButton(
        onPressed: onPressed,
        child: const Text('Load more events'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.event,
    required this.onTap,
    required this.isFavorite,
    required this.favoriteBusy,
    required this.onFavorite,
  });
  final DiscoveredEvent event;
  final VoidCallback onTap;
  final bool isFavorite;
  final bool favoriteBusy;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) {
    final visual = context.swappyVisual;
    final palette = visual.eventPalette(_eventTone(event.category));
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _EventImage(url: event.imageUrl),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: visual.eventHeroScrimGradient,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: visual.eventHeroControl,
                shape: const CircleBorder(),
                child: _FavoriteButton(
                  isFavorite: isFavorite,
                  isBusy: favoriteBusy,
                  onPressed: onFavorite,
                  lightForeground: true,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (event.category ?? 'EVENT').toUpperCase(),
                    style: TextStyle(
                      color: palette.secondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: visual.onEnergy,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _eventLine(event),
                    style: TextStyle(color: visual.onEnergy),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Provider event discovery only',
                    style: TextStyle(
                      color: visual.onEnergy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onTap,
    required this.isFavorite,
    required this.favoriteBusy,
    required this.onFavorite,
  });
  final DiscoveredEvent event;
  final VoidCallback onTap;
  final bool isFavorite;
  final bool favoriteBusy;
  final VoidCallback onFavorite;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            height: 138,
            child: _EventImage(url: event.imageUrl),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _eventLine(event),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Find participant seat Posts',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'View layout and current swap availability',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 2),
            child: Column(
              children: [
                _FavoriteButton(
                  isFavorite: isFavorite,
                  isBusy: favoriteBusy,
                  onPressed: onFavorite,
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Image.asset(
        'assets/images/city_finals_hero.png',
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator()),
            ),
      errorBuilder: (_, __, ___) =>
          Image.asset('assets/images/city_finals_hero.png', fit: BoxFit.cover),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.isBusy,
    required this.onPressed,
    this.lightForeground = false,
  });

  final bool isFavorite;
  final bool isBusy;
  final VoidCallback onPressed;
  final bool lightForeground;

  @override
  Widget build(BuildContext context) {
    final visual = context.swappyVisual;
    return IconButton(
      tooltip: isFavorite
          ? 'Remove from favorite events'
          : 'Save favorite event',
      onPressed: isBusy ? null : onPressed,
      color: lightForeground ? visual.onEnergy : null,
      disabledColor: lightForeground
          ? visual.onEnergy.withValues(alpha: 0.7)
          : null,
      icon: isBusy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
    );
  }
}

SwappyEventTone _eventTone(String? category) {
  final normalized = category?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return SwappyEventTone.neutral;
  }
  if (normalized.contains('sport')) return SwappyEventTone.sports;
  if (normalized.contains('music')) return SwappyEventTone.music;
  if (normalized.contains('art') || normalized.contains('theatre')) {
    return SwappyEventTone.arts;
  }
  if (normalized.contains('family')) return SwappyEventTone.family;
  return SwappyEventTone.neutral;
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onPressed,
  });
  final IconData icon;
  final String title, message, action;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 50),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    ),
  );
}

String _eventLine(DiscoveredEvent event) {
  final date = event.startsAt;
  final dateText = date == null
      ? 'Date to be announced'
      : '${date.month}/${date.day}/${date.year} · '
            '${date.toLocal().hour.toString().padLeft(2, '0')}:'
            '${date.toLocal().minute.toString().padLeft(2, '0')}';
  return '$dateText · ${event.venueName ?? 'Venue to be announced'}';
}

String _publishedPostLabel(EventSwapAvailability availability) {
  final count = availability.publishedPostCount;
  return '$count published ${count == 1 ? 'Post' : 'Posts'}';
}

String? _validateCity(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 2 || length > 80) return 'Enter a city (2–80 characters).';
  return null;
}

String? _validateOptionalCode(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return null;
  if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(normalized)) {
    return 'Use a two-letter state code.';
  }
  return null;
}

String? _validateRequiredCode(String? value) {
  if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(value?.trim() ?? '')) {
    return 'Use a two-letter country code.';
  }
  return null;
}
