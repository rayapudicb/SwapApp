class DiscoveredEvent {
  const DiscoveredEvent({
    required this.contextRef,
    required this.providerEventId,
    required this.title,
    required this.category,
    required this.startsAt,
    required this.timezone,
    required this.venueName,
    required this.city,
    required this.stateCode,
    required this.countryCode,
    required this.imageUrl,
    required this.staticSeatMapUrl,
    required this.providerEventUrl,
    required this.disclaimer,
    this.provider = 'ticketmaster',
    this.endsAt,
    this.sourceObservedAt,
  });

  factory DiscoveredEvent.fromJson(Map<String, dynamic> json) {
    final venue = _object(json['venue']);
    return DiscoveredEvent(
      contextRef: _string(json['contextRef']),
      providerEventId: _string(json['providerEventId']),
      provider: _string(json['provider'], fallback: 'ticketmaster'),
      title: _string(json['title'], fallback: 'Untitled event'),
      category: _optionalString(json['category']),
      startsAt: _optionalDate(json['startsAt']),
      endsAt: _optionalDate(json['endsAt']),
      timezone: _optionalString(json['timezone']),
      venueName: _optionalString(venue['name']),
      city: _optionalString(venue['city']),
      stateCode: _optionalString(venue['stateCode']),
      countryCode: _optionalString(venue['countryCode']),
      imageUrl: _optionalString(json['imageUrl']),
      staticSeatMapUrl: _optionalString(json['staticSeatMapUrl']),
      providerEventUrl: _optionalString(json['providerEventUrl']),
      sourceObservedAt: _optionalDate(json['sourceObservedAt']),
      disclaimer: _string(
        json['disclaimer'],
        fallback: 'Provider data supplies event context only.',
      ),
    );
  }

  final String contextRef;
  final String provider;
  final String providerEventId;
  final String title;
  final String? category;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? timezone;
  final String? venueName;
  final String? city;
  final String? stateCode;
  final String? countryCode;
  final String? imageUrl;
  final String? staticSeatMapUrl;
  final String? providerEventUrl;
  final DateTime? sourceObservedAt;
  final String disclaimer;
}

class EventLayoutProjection {
  const EventLayoutProjection({
    required this.contextRef,
    required this.eventName,
    required this.venueName,
    required this.staticSeatMapUrl,
    required this.schematic,
    required this.disclaimer,
  });

  factory EventLayoutProjection.fromJson(Map<String, dynamic> json) {
    final rawSchematic = json['schematic'];
    if (rawSchematic != null && rawSchematic is! Map) {
      throw const FormatException('Event layout schematic is invalid.');
    }
    return EventLayoutProjection(
      contextRef: _requiredString(json, 'contextRef'),
      eventName: _requiredString(json, 'eventName'),
      venueName: _requiredString(json, 'venueName'),
      staticSeatMapUrl: _optionalString(json['staticSeatMapUrl']),
      schematic: rawSchematic == null
          ? null
          : VenueSectionSchematic.fromJson(
              Map<String, dynamic>.from(rawSchematic),
            ),
      disclaimer: _requiredString(json, 'disclaimer'),
    );
  }

  final String contextRef;
  final String eventName;
  final String venueName;
  final String? staticSeatMapUrl;
  final VenueSectionSchematic? schematic;
  final String disclaimer;
}

class VenueSectionSchematic {
  const VenueSectionSchematic({
    required this.version,
    required this.centerLabel,
    required this.zones,
  });

  factory VenueSectionSchematic.fromJson(Map<String, dynamic> json) {
    final rawZones = json['zones'];
    if (rawZones is! List || rawZones.length < 2 || rawZones.length > 8) {
      throw const FormatException('Event layout zones are invalid.');
    }
    return VenueSectionSchematic(
      version: _requiredString(json, 'version'),
      centerLabel: _requiredString(json, 'centerLabel'),
      zones: rawZones
          .map(
            (value) =>
                VenueSectionZone.fromJson(_requiredMapValue(value, 'zones')),
          )
          .toList(growable: false),
    );
  }

  final String version;
  final String centerLabel;
  final List<VenueSectionZone> zones;
}

class VenueSectionZone {
  const VenueSectionZone({required this.label, required this.sections});

  factory VenueSectionZone.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    if (rawSections is! List ||
        rawSections.isEmpty ||
        rawSections.any((value) => value is! String || value.trim().isEmpty)) {
      throw const FormatException('Event layout sections are invalid.');
    }
    return VenueSectionZone(
      label: _requiredString(json, 'label'),
      sections: rawSections
          .cast<String>()
          .map((value) => value.trim())
          .toList(growable: false),
    );
  }

  final String label;
  final List<String> sections;
}

class EventDiscoveryPage {
  const EventDiscoveryPage({
    required this.items,
    required this.page,
    required this.source,
  });

  factory EventDiscoveryPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException(
        'The event response does not contain an item list.',
      );
    }

    return EventDiscoveryPage(
      items: rawItems
          .whereType<Map>()
          .map((item) => DiscoveredEvent.fromJson(_object(item)))
          .where(
            (event) =>
                event.contextRef.isNotEmpty && event.providerEventId.isNotEmpty,
          )
          .toList(growable: false),
      page: EventPageInfo.fromJson(_requiredObject(json, 'page')),
      source: EventDiscoverySource.fromJson(_requiredObject(json, 'source')),
    );
  }

  final List<DiscoveredEvent> items;
  final EventPageInfo page;
  final EventDiscoverySource source;
}

class EventPageInfo {
  const EventPageInfo({
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory EventPageInfo.fromJson(Map<String, dynamic> json) => EventPageInfo(
    number: _requiredInt(json, 'number'),
    size: _requiredInt(json, 'size'),
    totalElements: _requiredInt(json, 'totalElements'),
    totalPages: _requiredInt(json, 'totalPages'),
  );

  final int number;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get hasNextPage => number + 1 < totalPages && number < 49;
}

class EventDiscoverySource {
  const EventDiscoverySource({
    required this.provider,
    required this.capability,
    required this.stale,
  });

  factory EventDiscoverySource.fromJson(Map<String, dynamic> json) =>
      EventDiscoverySource(
        provider: _requiredString(json, 'provider'),
        capability: _requiredString(json, 'capability'),
        stale: _requiredBool(json, 'stale'),
      );

  final String provider;
  final String capability;
  final bool stale;
}

class LocationObservation {
  const LocationObservation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.observedAt,
    this.countryCode,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime observedAt;
  final String? countryCode;
}

/// A coarse, participant-safe address returned by Swappy's server.
///
/// Device coordinates are deliberately not part of this projection so the
/// provider can retain and render the label without retaining precise location.
class ResolvedLocation {
  const ResolvedLocation({
    required this.displayLabel,
    required this.locality,
    required this.region,
    required this.countryCode,
    required this.expiresAt,
  });

  factory ResolvedLocation.fromJson(Map<String, dynamic> json) {
    final countryCode = _requiredString(json, 'countryCode').toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) {
      throw const FormatException('countryCode is invalid.');
    }
    return ResolvedLocation(
      displayLabel: _requiredString(json, 'displayLabel'),
      locality: _requiredString(json, 'locality'),
      region: _requiredString(json, 'region'),
      countryCode: countryCode,
      expiresAt: _requiredDate(json, 'expiresAt'),
    );
  }

  final String displayLabel;
  final String locality;
  final String region;
  final String countryCode;
  final DateTime expiresAt;
}

class EventSwapAvailability {
  const EventSwapAvailability({
    required this.publishedPostCount,
    required this.requestablePostCount,
    required this.hasAvailability,
  });

  factory EventSwapAvailability.fromJson(Map<String, dynamic> json) {
    final publishedPostCount = _requiredInt(json, 'publishedPostCount');
    final requestablePostCount = _requiredInt(json, 'requestablePostCount');
    if (publishedPostCount < 0 || requestablePostCount < 0) {
      throw const FormatException('Swap availability counts are invalid.');
    }
    return EventSwapAvailability(
      publishedPostCount: publishedPostCount,
      requestablePostCount: requestablePostCount,
      hasAvailability: _requiredBool(json, 'hasAvailability'),
    );
  }

  final int publishedPostCount;
  final int requestablePostCount;
  final bool hasAvailability;
}

class SportPreference {
  const SportPreference({required this.key, required this.displayName});

  factory SportPreference.fromJson(Map<String, dynamic> json) {
    final key = _requiredString(json, 'key').toLowerCase();
    if (!RegExp(r'^[a-z0-9_-]{1,50}$').hasMatch(key)) {
      throw const FormatException('Sport preference key is invalid.');
    }
    return SportPreference(
      key: key,
      displayName: _requiredString(json, 'displayName'),
    );
  }

  final String key;
  final String displayName;
}

class ParticipantEventPreferences {
  const ParticipantEventPreferences({
    required this.favoriteEventContextRefs,
    required this.preferredSports,
    required this.version,
  });

  factory ParticipantEventPreferences.fromJson(Map<String, dynamic> json) {
    final rawFavorites = json['favoriteEventContextRefs'];
    final rawSports = json['preferredSports'];
    if (rawFavorites is! List || rawSports is! List) {
      throw const FormatException('Participant preferences are invalid.');
    }
    final favorites = rawFavorites
        .map((value) => value is String ? value.trim() : '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (favorites.length != rawFavorites.length) {
      throw const FormatException('Favorite event references are invalid.');
    }
    return ParticipantEventPreferences(
      favoriteEventContextRefs: favorites,
      preferredSports: rawSports
          .map(
            (value) => SportPreference.fromJson(
              _requiredMapValue(value, 'preferredSports'),
            ),
          )
          .toList(growable: false),
      version: _requiredPositiveInt(json, 'version'),
    );
  }

  final List<String> favoriteEventContextRefs;
  final List<SportPreference> preferredSports;
  final int version;
}

enum EventProximityStatus {
  locationUnknown,
  outsideEventZone,
  proximityEligible,
  proximityExpired;

  factory EventProximityStatus.fromWireValue(String value) => switch (value) {
    'location_unknown' => EventProximityStatus.locationUnknown,
    'outside_event_zone' => EventProximityStatus.outsideEventZone,
    'proximity_eligible' => EventProximityStatus.proximityEligible,
    'proximity_expired' => EventProximityStatus.proximityExpired,
    _ => throw FormatException('Unknown proximity status: $value'),
  };
}

class NearbyEventCandidate {
  const NearbyEventCandidate({
    required this.event,
    required this.proximity,
    required this.swapAvailability,
    required this.isFavorite,
    required this.matchesPreferredSport,
  });

  factory NearbyEventCandidate.fromJson(Map<String, dynamic> json) =>
      NearbyEventCandidate(
        event: DiscoveredEvent.fromJson(_requiredObject(json, 'event')),
        proximity: EventProximity.fromJson(_requiredObject(json, 'proximity')),
        swapAvailability: EventSwapAvailability.fromJson(
          _requiredObject(json, 'swapAvailability'),
        ),
        isFavorite: _requiredBool(json, 'isFavorite'),
        matchesPreferredSport: _requiredBool(json, 'matchesPreferredSport'),
      );

  final DiscoveredEvent event;
  final EventProximity proximity;
  final EventSwapAvailability swapAvailability;
  final bool isFavorite;
  final bool matchesPreferredSport;
}

class EventProximity {
  const EventProximity({
    required this.status,
    required this.distanceMeters,
    required this.radiusMeters,
    required this.observedAccuracyMeters,
    required this.activeFrom,
    required this.activeUntil,
    required this.policyVersion,
    required this.source,
    required this.disclaimer,
  });

  factory EventProximity.fromJson(Map<String, dynamic> json) => EventProximity(
    status: EventProximityStatus.fromWireValue(_requiredString(json, 'status')),
    distanceMeters: _optionalInt(json['distanceMeters']),
    radiusMeters: _requiredInt(json, 'radiusMeters'),
    observedAccuracyMeters: _requiredDouble(json, 'observedAccuracyMeters'),
    activeFrom: _optionalDate(json['activeFrom']),
    activeUntil: _optionalDate(json['activeUntil']),
    policyVersion: _requiredString(json, 'policyVersion'),
    source: _requiredString(json, 'source'),
    disclaimer: _requiredString(json, 'disclaimer'),
  );

  final EventProximityStatus status;
  final int? distanceMeters;
  final int radiusMeters;
  final double observedAccuracyMeters;
  final DateTime? activeFrom;
  final DateTime? activeUntil;
  final String policyVersion;
  final String source;
  final String disclaimer;
}

class NearbyEventsResult {
  const NearbyEventsResult({
    required this.candidates,
    required this.selectedContextRef,
    required this.observationExpiresAt,
  });

  factory NearbyEventsResult.fromJson(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List) {
      throw const FormatException(
        'The nearby-event response does not contain candidates.',
      );
    }
    return NearbyEventsResult(
      candidates: candidates
          .whereType<Map>()
          .map((candidate) => NearbyEventCandidate.fromJson(_object(candidate)))
          .toList(growable: false),
      selectedContextRef: _optionalString(json['selectedContextRef']),
      observationExpiresAt: _requiredDate(json, 'observationExpiresAt'),
    );
  }

  final List<NearbyEventCandidate> candidates;
  final String? selectedContextRef;
  final DateTime observationExpiresAt;
}

class PreferredEventCandidate {
  const PreferredEventCandidate({
    required this.event,
    required this.swapAvailability,
    required this.isFavorite,
    required this.matchesPreferredSport,
  });

  factory PreferredEventCandidate.fromJson(Map<String, dynamic> json) =>
      PreferredEventCandidate(
        event: DiscoveredEvent.fromJson(_requiredObject(json, 'event')),
        swapAvailability: EventSwapAvailability.fromJson(
          _requiredObject(json, 'swapAvailability'),
        ),
        isFavorite: _requiredBool(json, 'isFavorite'),
        matchesPreferredSport: _requiredBool(json, 'matchesPreferredSport'),
      );

  final DiscoveredEvent event;
  final EventSwapAvailability swapAvailability;
  final bool isFavorite;
  final bool matchesPreferredSport;

  bool get isPreferred => isFavorite || matchesPreferredSport;
}

class PreferredEventsPage {
  const PreferredEventsPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory PreferredEventsPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Preferred events are invalid.');
    }
    final total = _requiredInt(json, 'total');
    final limit = _requiredInt(json, 'limit');
    final offset = _requiredInt(json, 'offset');
    if (total < 0 || limit < 1 || limit > 50 || offset < 0) {
      throw const FormatException('Preferred event page metadata is invalid.');
    }
    return PreferredEventsPage(
      items: rawItems
          .map(
            (value) => PreferredEventCandidate.fromJson(
              _requiredMapValue(value, 'items'),
            ),
          )
          .toList(growable: false),
      total: total,
      limit: limit,
      offset: offset,
    );
  }

  final List<PreferredEventCandidate> items;
  final int total;
  final int limit;
  final int offset;
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
  final result = _object(json[key]);
  if (result.isEmpty) throw FormatException('$key is missing.');
  return result;
}

Map<String, dynamic> _requiredMapValue(Object? value, String label) {
  final result = _object(value);
  if (result.isEmpty) throw FormatException('$label contains an invalid item.');
  return result;
}

String _string(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _string(json[key]);
  if (value.isEmpty) throw FormatException('$key is missing.');
  return value;
}

String? _optionalString(Object? value) {
  final normalized = _string(value);
  return normalized.isEmpty ? null : normalized;
}

DateTime? _optionalDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _optionalDate(json[key]);
  if (value == null) throw FormatException('$key is invalid.');
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key is invalid.');
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = _requiredInt(json, key);
  if (value < 1) throw FormatException('$key is invalid.');
  return value;
}

int? _optionalInt(Object? value) => value is int ? value : null;

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('$key is invalid.');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key is invalid.');
}
