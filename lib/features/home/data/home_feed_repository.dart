import 'dart:convert';

import '../../../core/api/api_client.dart';
import '../domain/discovered_event.dart';

typedef DiscoveryClock = DateTime Function();

class HomeFeedRepository {
  HomeFeedRepository(this._api, {DiscoveryClock? clock})
    : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final DiscoveryClock _clock;

  Future<EventDiscoveryPage> discoverEvents({
    required String city,
    String? stateCode,
    required String countryCode,
    String? category,
    String? keyword,
    int page = 0,
    int size = 20,
  }) async {
    final normalizedCity = _boundedText(city, 'City', 2, 80);
    final normalizedStateCode = _optionalCode(stateCode, 'State code');
    final normalizedCountryCode = _requiredCode(countryCode, 'Country code');
    final normalizedCategory = category == null || category == 'All'
        ? null
        : _boundedText(category, 'Category', 1, 50);
    final normalizedKeyword = keyword == null || keyword.trim().isEmpty
        ? null
        : _boundedText(keyword, 'Keyword', 1, 100);
    if (page < 0 || page > 49) {
      throw const FormatException('Page must be between 0 and 49.');
    }
    if (size < 1 || size > 50) {
      throw const FormatException('Page size must be between 1 and 50.');
    }

    final endpoint = Uri(
      path: '/v1/ticketed-experience/events',
      queryParameters: {
        'city': normalizedCity,
        if (normalizedStateCode != null) 'stateCode': normalizedStateCode,
        'countryCode': normalizedCountryCode,
        if (normalizedCategory != null)
          'classificationName': normalizedCategory,
        if (normalizedKeyword != null) 'keyword': normalizedKeyword,
        'page': '$page',
        'size': '$size',
      },
    ).toString();
    final response = await _api.get(endpoint);
    ApiClient.requireSuccess(response);
    return EventDiscoveryPage.fromJson(_decodeObject(response.body));
  }

  Future<NearbyEventsResult> evaluateNearbyEvents(
    LocationObservation observation,
  ) async {
    _validateObservation(observation);
    final countryCode = observation.countryCode == null
        ? null
        : _requiredCode(observation.countryCode!, 'Country code');
    final response = await _api.post(
      '/v1/ticketed-experience/nearby-events',
      body: {
        'latitude': observation.latitude,
        'longitude': observation.longitude,
        'accuracyMeters': observation.accuracyMeters,
        'observedAt': observation.observedAt.toUtc().toIso8601String(),
        if (countryCode != null) 'countryCode': countryCode,
      },
    );
    ApiClient.requireSuccess(response);
    return NearbyEventsResult.fromJson(_decodeObject(response.body));
  }

  Future<EventLayoutProjection> getEventLayout(String contextRef) async {
    final segment = _encodedPathSegment(contextRef, 'Event reference', 300);
    final response = await _api.get(
      '/v1/ticketed-experience/events/$segment/layout',
    );
    ApiClient.requireSuccess(response);
    final layout = EventLayoutProjection.fromJson(_decodeObject(response.body));
    if (layout.contextRef != contextRef) {
      throw const FormatException('The event layout reference does not match.');
    }
    return layout;
  }

  Future<ResolvedLocation> reverseGeocode(
    LocationObservation observation, {
    String? locale,
  }) async {
    _validateObservation(observation);
    final normalizedLocale = locale == null || locale.trim().isEmpty
        ? null
        : _boundedText(locale, 'Locale', 2, 35);
    final response = await _api.post(
      '/v1/me/location/reverse-geocode',
      body: {
        'latitude': observation.latitude,
        'longitude': observation.longitude,
        'accuracyMeters': observation.accuracyMeters,
        'observedAt': observation.observedAt.toUtc().toIso8601String(),
        if (normalizedLocale != null) 'locale': normalizedLocale,
      },
    );
    ApiClient.requireSuccess(response);
    return ResolvedLocation.fromJson(_decodeObject(response.body));
  }

  Future<List<SportPreference>> getSupportedSports() async {
    final response = await _api.get('/v1/ticketed-experience/sports');
    ApiClient.requireSuccess(response);
    final json = _decodeObject(response.body);
    final rawSports = json['sports'];
    if (rawSports is! List) {
      throw const FormatException('The sports response is invalid.');
    }
    return rawSports
        .map(
          (value) => SportPreference.fromJson(
            _requiredResponseObject(value, 'sports'),
          ),
        )
        .toList(growable: false);
  }

  Future<ParticipantEventPreferences> getPreferences() async {
    final response = await _api.get('/v1/me/preferences');
    ApiClient.requireSuccess(response);
    return ParticipantEventPreferences.fromJson(_decodeObject(response.body));
  }

  Future<ParticipantEventPreferences> setFavoriteEvent(
    String contextRef, {
    required bool favorite,
  }) async {
    final segment = _encodedPathSegment(contextRef, 'Event reference', 300);
    final endpoint = '/v1/me/preferences/events/$segment';
    final response = favorite
        ? await _api.put(endpoint)
        : await _api.delete(endpoint);
    ApiClient.requireSuccess(response);
    return ParticipantEventPreferences.fromJson(_decodeObject(response.body));
  }

  Future<ParticipantEventPreferences> setSportPreference(
    String sportKey, {
    required bool preferred,
  }) async {
    final normalizedKey = sportKey.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_-]{1,50}$').hasMatch(normalizedKey)) {
      throw const FormatException('Sport preference key is invalid.');
    }
    final segment = Uri.encodeComponent(normalizedKey);
    final endpoint = '/v1/me/preferences/sports/$segment';
    final response = preferred
        ? await _api.put(endpoint)
        : await _api.delete(endpoint);
    ApiClient.requireSuccess(response);
    return ParticipantEventPreferences.fromJson(_decodeObject(response.body));
  }

  Future<PreferredEventsPage> getPreferredEvents({
    int limit = 20,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 50 || offset < 0) {
      throw const FormatException('Preferred event page is invalid.');
    }
    final endpoint = Uri(
      path: '/v1/me/preferred-events',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    ).toString();
    final response = await _api.get(endpoint);
    ApiClient.requireSuccess(response);
    return PreferredEventsPage.fromJson(_decodeObject(response.body));
  }

  void _validateObservation(LocationObservation observation) {
    if (!observation.latitude.isFinite ||
        observation.latitude < -90 ||
        observation.latitude > 90) {
      throw const FormatException('Latitude is invalid.');
    }
    if (!observation.longitude.isFinite ||
        observation.longitude < -180 ||
        observation.longitude > 180) {
      throw const FormatException('Longitude is invalid.');
    }
    if (!observation.accuracyMeters.isFinite ||
        observation.accuracyMeters < 0 ||
        observation.accuracyMeters > 5000) {
      throw const FormatException('Location accuracy is invalid.');
    }

    final now = _clock().toUtc();
    final observedAt = observation.observedAt.toUtc();
    if (now.difference(observedAt) > const Duration(minutes: 2)) {
      throw const FormatException(
        'The location observation is stale. Request a fresh foreground location.',
      );
    }
    if (observedAt.difference(now) > const Duration(seconds: 15)) {
      throw const FormatException('The location observation is in the future.');
    }
  }
}

Map<String, dynamic> _requiredResponseObject(Object? value, String label) {
  if (value is! Map) throw FormatException('$label contains an invalid item.');
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _decodeObject(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('The event API returned an invalid response.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _boundedText(String value, String label, int minimum, int maximum) {
  final normalized = value.trim();
  if (normalized.length < minimum || normalized.length > maximum) {
    throw FormatException('$label must be $minimum–$maximum characters.');
  }
  return normalized;
}

String _requiredCode(String value, String label) {
  final normalized = value.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) {
    throw FormatException('$label must contain two letters.');
  }
  return normalized;
}

String? _optionalCode(String? value, String label) {
  if (value == null || value.trim().isEmpty) return null;
  return _requiredCode(value, label);
}

String _encodedPathSegment(String value, String label, int maximum) {
  final normalized = _boundedText(value, label, 1, maximum);
  return Uri.encodeComponent(normalized);
}
