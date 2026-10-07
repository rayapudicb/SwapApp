import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../data/home_feed_repository.dart';
import '../domain/discovered_event.dart';

class HomeFeedProvider extends ChangeNotifier {
  HomeFeedProvider({required HomeFeedRepository repository})
    : _repository = repository;

  final HomeFeedRepository _repository;
  List<DiscoveredEvent> _events = [];
  NearbyEventsResult? _nearby;
  ResolvedLocation? _resolvedLocation;
  List<SportPreference> _supportedSports = const [];
  ParticipantEventPreferences? _preferences;
  List<PreferredEventCandidate> _preferredEvents = const [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String? _loadMoreErrorMessage;
  String? _nearbyErrorMessage;
  bool _isLoadingNearby = false;
  bool _isResolvingLocation = false;
  String? _resolvedLocationError;
  bool _isLoadingPreferences = false;
  String? _preferencesError;
  bool _isLoadingPreferredEvents = false;
  String? _preferredEventsError;
  String? _preferenceCommandError;
  final Set<String> _favoriteCommands = <String>{};
  final Set<String> _sportCommands = <String>{};
  EventPageInfo? _page;
  EventDiscoverySource? _source;
  int _requestVersion = 0;
  int _nearbyRequestVersion = 0;
  int _locationRequestVersion = 0;
  int _preferencesRequestVersion = 0;
  int _preferredEventsRequestVersion = 0;
  int _sessionScope = 0;
  Timer? _nearbyExpiryTimer;
  Timer? _resolvedLocationExpiryTimer;
  ({
    String city,
    String? stateCode,
    String countryCode,
    String category,
    String? keyword,
  })?
  _activeQuery;

  List<DiscoveredEvent> get events => _events;
  NearbyEventsResult? get nearby {
    final value = _nearby;
    if (value == null || !DateTime.now().isBefore(value.observationExpiresAt)) {
      return null;
    }
    return value;
  }

  ResolvedLocation? get resolvedLocation {
    final value = _resolvedLocation;
    if (value == null || !DateTime.now().isBefore(value.expiresAt)) return null;
    return value;
  }

  List<SportPreference> get supportedSports => _supportedSports;
  ParticipantEventPreferences? get preferences => _preferences;
  List<PreferredEventCandidate> get preferredEvents => _preferredEvents;
  bool get isResolvingLocation => _isResolvingLocation;
  String? get resolvedLocationError => _resolvedLocationError;
  bool get isLoadingPreferences => _isLoadingPreferences;
  String? get preferencesError => _preferencesError;
  bool get isLoadingPreferredEvents => _isLoadingPreferredEvents;
  String? get preferredEventsError => _preferredEventsError;
  String? get preferenceCommandError => _preferenceCommandError;
  String? get activeCity => _activeQuery?.city;
  String? get activeStateCode => _activeQuery?.stateCode;
  String? get activeCountryCode => _activeQuery?.countryCode;
  String? get activeCategory => _activeQuery?.category;
  String? get activeKeyword => _activeQuery?.keyword;

  bool isFavorite(String contextRef) =>
      _preferences?.favoriteEventContextRefs.contains(contextRef) ?? false;

  bool isSportPreferred(String sportKey) =>
      _preferences?.preferredSports.any((sport) => sport.key == sportKey) ??
      false;

  bool isFavoriteCommandRunning(String contextRef) =>
      _favoriteCommands.contains(contextRef);

  bool isSportCommandRunning(String sportKey) =>
      _sportCommands.contains(sportKey);

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingNearby => _isLoadingNearby;
  String? get errorMessage => _errorMessage;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  String? get nearbyErrorMessage => _nearbyErrorMessage;
  EventDiscoverySource? get source => _source;
  bool get hasMoreEvents => _page?.hasNextPage ?? false;
  int? get totalEventCount => _page?.totalElements;

  Future<EventLayoutProjection> getEventLayout(String contextRef) =>
      _repository.getEventLayout(contextRef);

  Future<void> discoverEvents({
    required String city,
    String? stateCode,
    required String countryCode,
    String category = 'All',
    String? keyword,
  }) async {
    final requestVersion = ++_requestVersion;
    _activeQuery = (
      city: city,
      stateCode: stateCode,
      countryCode: countryCode,
      category: category,
      keyword: keyword,
    );
    _events = [];
    _page = null;
    _source = null;
    _errorMessage = null;
    _loadMoreErrorMessage = null;
    _isLoading = true;
    _isLoadingMore = false;
    notifyListeners();
    try {
      final result = await _repository.discoverEvents(
        city: city,
        stateCode: stateCode,
        countryCode: countryCode,
        category: category,
        keyword: keyword,
      );
      if (requestVersion != _requestVersion) return;
      _events = result.items;
      _page = result.page;
      _source = result.source;
      _errorMessage = null;
    } on ApiRequestException catch (error) {
      if (requestVersion != _requestVersion) return;
      _errorMessage = error.message;
    } on FormatException catch (error) {
      if (requestVersion != _requestVersion) return;
      _errorMessage = error.message;
    } catch (_) {
      if (requestVersion != _requestVersion) return;
      _errorMessage = 'Events are temporarily unavailable. Try again.';
    } finally {
      if (requestVersion == _requestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> resolveLocation(
    LocationObservation observation, {
    String? locale,
  }) async {
    if (_isResolvingLocation) return false;
    final requestVersion = ++_locationRequestVersion;
    _isResolvingLocation = true;
    _resolvedLocationExpiryTimer?.cancel();
    _resolvedLocation = null;
    _resolvedLocationError = null;
    notifyListeners();
    try {
      final result = await _repository.reverseGeocode(
        observation,
        locale: locale,
      );
      if (requestVersion != _locationRequestVersion) return false;
      if (!DateTime.now().isBefore(result.expiresAt)) {
        throw const FormatException(
          'The resolved location expired. Request a fresh location.',
        );
      }
      _resolvedLocation = result;
      _resolvedLocationExpiryTimer?.cancel();
      final delay = result.expiresAt.difference(DateTime.now());
      _resolvedLocationExpiryTimer = Timer(delay, () {
        if (requestVersion != _locationRequestVersion) return;
        _resolvedLocation = null;
        notifyListeners();
      });
      return true;
    } on ApiRequestException catch (error) {
      if (requestVersion != _locationRequestVersion) return false;
      _resolvedLocationError = error.message;
      return false;
    } on FormatException catch (error) {
      if (requestVersion != _locationRequestVersion) return false;
      _resolvedLocationError = error.message;
      return false;
    } catch (_) {
      if (requestVersion != _locationRequestVersion) return false;
      _resolvedLocationError =
          'Your area could not be resolved. Try again or search by city.';
      return false;
    } finally {
      if (requestVersion == _locationRequestVersion) {
        _isResolvingLocation = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadPersonalization() async {
    if (_isLoadingPreferences) return;
    final requestVersion = ++_preferencesRequestVersion;
    _isLoadingPreferences = true;
    _preferencesError = null;
    notifyListeners();
    var succeeded = false;
    try {
      final results = await Future.wait<Object>([
        _repository.getSupportedSports(),
        _repository.getPreferences(),
      ]);
      if (requestVersion != _preferencesRequestVersion) return;
      _supportedSports = results[0] as List<SportPreference>;
      _preferences = results[1] as ParticipantEventPreferences;
      succeeded = true;
    } on ApiRequestException catch (error) {
      if (requestVersion != _preferencesRequestVersion) return;
      _preferencesError = error.message;
    } on FormatException catch (error) {
      if (requestVersion != _preferencesRequestVersion) return;
      _preferencesError = error.message;
    } catch (_) {
      if (requestVersion != _preferencesRequestVersion) return;
      _preferencesError = 'Preferences are temporarily unavailable. Try again.';
    } finally {
      if (requestVersion == _preferencesRequestVersion) {
        _isLoadingPreferences = false;
        notifyListeners();
      }
    }
    if (succeeded) await loadPreferredEvents();
  }

  Future<void> loadPreferredEvents({bool force = false}) async {
    if (_isLoadingPreferredEvents && !force) return;
    final requestVersion = ++_preferredEventsRequestVersion;
    _isLoadingPreferredEvents = true;
    _preferredEventsError = null;
    notifyListeners();
    try {
      final result = await _repository.getPreferredEvents();
      if (requestVersion != _preferredEventsRequestVersion) return;
      // The controller returns match flags for every provider result. Render
      // only actual participant preferences in the preferred surface.
      _preferredEvents = result.items
          .where((candidate) => candidate.isPreferred)
          .toList(growable: false);
    } on ApiRequestException catch (error) {
      if (requestVersion != _preferredEventsRequestVersion) return;
      _preferredEventsError = error.message;
    } on FormatException catch (error) {
      if (requestVersion != _preferredEventsRequestVersion) return;
      _preferredEventsError = error.message;
    } catch (_) {
      if (requestVersion != _preferredEventsRequestVersion) return;
      _preferredEventsError =
          'Preferred events are temporarily unavailable. Try again.';
    } finally {
      if (requestVersion == _preferredEventsRequestVersion) {
        _isLoadingPreferredEvents = false;
        notifyListeners();
      }
    }
  }

  Future<bool> toggleFavoriteEvent(String contextRef) async {
    if (_favoriteCommands.contains(contextRef)) return false;
    final scope = _sessionScope;
    final favorite = !isFavorite(contextRef);
    _favoriteCommands.add(contextRef);
    _preferenceCommandError = null;
    notifyListeners();
    var succeeded = false;
    try {
      final result = await _repository.setFavoriteEvent(
        contextRef,
        favorite: favorite,
      );
      if (scope != _sessionScope) return false;
      _preferences = result;
      succeeded = true;
    } on ApiRequestException catch (error) {
      if (scope == _sessionScope) _preferenceCommandError = error.message;
    } on FormatException catch (error) {
      if (scope == _sessionScope) _preferenceCommandError = error.message;
    } catch (_) {
      if (scope == _sessionScope) {
        _preferenceCommandError =
            'The favorite could not be updated. Try again.';
      }
    } finally {
      if (scope == _sessionScope) {
        _favoriteCommands.remove(contextRef);
        notifyListeners();
      }
    }
    if (succeeded) await loadPreferredEvents(force: true);
    return succeeded;
  }

  Future<bool> toggleSportPreference(String sportKey) async {
    if (_sportCommands.contains(sportKey)) return false;
    final scope = _sessionScope;
    final preferred = !isSportPreferred(sportKey);
    _sportCommands.add(sportKey);
    _preferenceCommandError = null;
    notifyListeners();
    var succeeded = false;
    try {
      final result = await _repository.setSportPreference(
        sportKey,
        preferred: preferred,
      );
      if (scope != _sessionScope) return false;
      _preferences = result;
      succeeded = true;
    } on ApiRequestException catch (error) {
      if (scope == _sessionScope) _preferenceCommandError = error.message;
    } on FormatException catch (error) {
      if (scope == _sessionScope) _preferenceCommandError = error.message;
    } catch (_) {
      if (scope == _sessionScope) {
        _preferenceCommandError =
            'The sport preference could not be updated. Try again.';
      }
    } finally {
      if (scope == _sessionScope) {
        _sportCommands.remove(sportKey);
        notifyListeners();
      }
    }
    if (succeeded) await loadPreferredEvents(force: true);
    return succeeded;
  }

  void clearPreferenceCommandError() {
    _preferenceCommandError = null;
    notifyListeners();
  }

  Future<void> loadMoreEvents() async {
    final query = _activeQuery;
    final currentPage = _page;
    if (query == null ||
        currentPage == null ||
        !currentPage.hasNextPage ||
        _isLoading ||
        _isLoadingMore) {
      return;
    }

    final requestVersion = _requestVersion;
    _isLoadingMore = true;
    _loadMoreErrorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.discoverEvents(
        city: query.city,
        stateCode: query.stateCode,
        countryCode: query.countryCode,
        category: query.category,
        keyword: query.keyword,
        page: currentPage.number + 1,
        size: currentPage.size,
      );
      if (requestVersion != _requestVersion) return;
      final knownContextRefs = _events.map((event) => event.contextRef).toSet();
      _events = [
        ..._events,
        ...result.items.where(
          (event) => knownContextRefs.add(event.contextRef),
        ),
      ];
      _page = result.page;
      _source = result.source;
    } on ApiRequestException catch (error) {
      if (requestVersion != _requestVersion) return;
      _loadMoreErrorMessage = error.message;
    } on FormatException catch (error) {
      if (requestVersion != _requestVersion) return;
      _loadMoreErrorMessage = error.message;
    } catch (_) {
      if (requestVersion != _requestVersion) return;
      _loadMoreErrorMessage =
          'More events could not be loaded. Check the connection and retry.';
    } finally {
      if (requestVersion == _requestVersion) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> evaluateNearby(LocationObservation observation) async {
    if (_isLoadingNearby) return;
    final requestVersion = ++_nearbyRequestVersion;
    _isLoadingNearby = true;
    _nearby = null;
    _nearbyExpiryTimer?.cancel();
    _nearbyErrorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.evaluateNearbyEvents(observation);
      if (requestVersion != _nearbyRequestVersion) return;
      _nearby = result;
      final delay = result.observationExpiresAt.difference(DateTime.now());
      if (!delay.isNegative) {
        _nearbyExpiryTimer = Timer(delay, () {
          if (requestVersion != _nearbyRequestVersion) return;
          _nearby = null;
          notifyListeners();
        });
      }
    } on ApiRequestException catch (error) {
      if (requestVersion != _nearbyRequestVersion) return;
      _nearbyErrorMessage = error.message;
    } on FormatException catch (error) {
      if (requestVersion != _nearbyRequestVersion) return;
      _nearbyErrorMessage = error.message;
    } catch (_) {
      if (requestVersion != _nearbyRequestVersion) return;
      _nearbyErrorMessage =
          'Nearby events could not be evaluated. Check the connection and retry.';
    } finally {
      if (requestVersion == _nearbyRequestVersion) {
        _isLoadingNearby = false;
        notifyListeners();
      }
    }
  }

  void clearNearby() {
    _clearNearby();
    notifyListeners();
  }

  void clearResolvedLocation() {
    _locationRequestVersion++;
    _resolvedLocationExpiryTimer?.cancel();
    _resolvedLocation = null;
    _resolvedLocationError = null;
    _isResolvingLocation = false;
    notifyListeners();
  }

  void clearDiscovery() {
    _requestVersion++;
    _events = const [];
    _page = null;
    _source = null;
    _activeQuery = null;
    _errorMessage = null;
    _loadMoreErrorMessage = null;
    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  void _clearNearby() {
    _nearbyRequestVersion++;
    _nearbyExpiryTimer?.cancel();
    _nearby = null;
    _nearbyErrorMessage = null;
    _isLoadingNearby = false;
  }

  void resetForSession() {
    _sessionScope++;
    _requestVersion++;
    _nearbyRequestVersion++;
    _locationRequestVersion++;
    _preferencesRequestVersion++;
    _preferredEventsRequestVersion++;
    _nearbyExpiryTimer?.cancel();
    _resolvedLocationExpiryTimer?.cancel();
    _events = const [];
    _nearby = null;
    _resolvedLocation = null;
    _supportedSports = const [];
    _preferences = null;
    _preferredEvents = const [];
    _isLoading = false;
    _isLoadingMore = false;
    _isLoadingNearby = false;
    _isResolvingLocation = false;
    _isLoadingPreferences = false;
    _isLoadingPreferredEvents = false;
    _errorMessage = null;
    _loadMoreErrorMessage = null;
    _nearbyErrorMessage = null;
    _resolvedLocationError = null;
    _preferencesError = null;
    _preferredEventsError = null;
    _preferenceCommandError = null;
    _favoriteCommands.clear();
    _sportCommands.clear();
    _page = null;
    _source = null;
    _activeQuery = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _loadMoreErrorMessage = null;
    _nearbyErrorMessage = null;
    _resolvedLocationError = null;
    _preferencesError = null;
    _preferredEventsError = null;
    _preferenceCommandError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _nearbyExpiryTimer?.cancel();
    _resolvedLocationExpiryTimer?.cancel();
    super.dispose();
  }
}
