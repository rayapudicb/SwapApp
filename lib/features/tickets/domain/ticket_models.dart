import '../../exchange/domain/exchange_models.dart';

class TicketContractException implements Exception {
  const TicketContractException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum TicketImportState {
  awaitingUpload('awaiting_upload'),
  uploaded('uploaded'),
  processing('processing'),
  awaitingConfirmation('awaiting_confirmation'),
  confirmed('confirmed'),
  evidenceSubmitted('evidence_submitted'),
  failedRetryable('failed_retryable'),
  rejected('rejected'),
  quarantined('quarantined'),
  expired('expired');

  const TicketImportState(this.wireValue);

  final String wireValue;

  static TicketImportState parse(Object? value) {
    for (final state in values) {
      if (state.wireValue == value) return state;
    }
    throw const TicketContractException(
      'The ticket import has an unsupported state.',
    );
  }

  bool get shouldPoll =>
      this == uploaded || this == processing || this == failedRetryable;
}

enum TicketBundleState {
  active,
  revoked,
  expired;

  static TicketBundleState parse(Object? value) {
    for (final state in values) {
      if (state.name == value) return state;
    }
    throw const TicketContractException('The ticket has an unsupported state.');
  }
}

enum TicketVerificationStatus {
  confirmed,
  unverified;

  static TicketVerificationStatus parse(Object? value, String field) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    throw TicketContractException('$field has an unsupported value.');
  }
}

class TicketVerificationCapabilities {
  const TicketVerificationCapabilities({
    required this.eventMatch,
    required this.ownership,
    required this.validity,
    required this.unusedStatus,
    required this.transferability,
    required this.seat,
    required this.provider,
  });

  final TicketVerificationStatus eventMatch;
  final TicketVerificationStatus ownership;
  final TicketVerificationStatus validity;
  final TicketVerificationStatus unusedStatus;
  final TicketVerificationStatus transferability;
  final TicketVerificationStatus seat;
  final String provider;

  factory TicketVerificationCapabilities.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'eventMatch',
      'ownership',
      'validity',
      'unusedStatus',
      'transferability',
      'seat',
      'provider',
    }, 'ticket verification capabilities');
    final provider = _string(json, 'provider', maximum: 128);
    if (!RegExp(r'^[a-z][a-z0-9_-]{0,127}$').hasMatch(provider)) {
      throw const TicketContractException(
        'The ticket verification provider is invalid.',
      );
    }
    return TicketVerificationCapabilities(
      eventMatch: TicketVerificationStatus.parse(
        json['eventMatch'],
        'verification.eventMatch',
      ),
      ownership: TicketVerificationStatus.parse(
        json['ownership'],
        'verification.ownership',
      ),
      validity: TicketVerificationStatus.parse(
        json['validity'],
        'verification.validity',
      ),
      unusedStatus: TicketVerificationStatus.parse(
        json['unusedStatus'],
        'verification.unusedStatus',
      ),
      transferability: TicketVerificationStatus.parse(
        json['transferability'],
        'verification.transferability',
      ),
      seat: TicketVerificationStatus.parse(json['seat'], 'verification.seat'),
      provider: provider,
    );
  }
}

class TicketImportExtracted {
  const TicketImportExtracted({
    required this.eventName,
    required this.startsAt,
    required this.venueName,
    required this.sectionLabel,
    required this.rowLabel,
    required this.seatLabels,
  });

  final String? eventName;
  final DateTime? startsAt;
  final String? venueName;
  final String? sectionLabel;
  final String? rowLabel;
  final List<String> seatLabels;

  factory TicketImportExtracted.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'eventName',
      'startsAt',
      'venueName',
      'sectionLabel',
      'rowLabel',
      'seatLabels',
    }, 'ticket extraction');
    final seats = _stringList(json, 'seatLabels', maximum: 3);
    return TicketImportExtracted(
      eventName: _nullableString(json, 'eventName', maximum: 255),
      startsAt: _nullableDateTime(json, 'startsAt'),
      venueName: _nullableString(json, 'venueName', maximum: 255),
      sectionLabel: _nullableString(json, 'sectionLabel', maximum: 64),
      rowLabel: _nullableString(json, 'rowLabel', maximum: 64),
      seatLabels: seats,
    );
  }
}

class TicketEventCandidate {
  const TicketEventCandidate({
    required this.id,
    required this.contextRef,
    required this.title,
    required this.startsAt,
    required this.timezone,
    required this.venueName,
    required this.venueCity,
    required this.venueCountryCode,
    required this.staticSeatMapUrl,
    required this.confidenceBasisPoints,
    required this.rank,
    required this.sourceObservedAt,
  });

  final String id;
  final String contextRef;
  final String title;
  final DateTime? startsAt;
  final String? timezone;
  final String? venueName;
  final String? venueCity;
  final String? venueCountryCode;
  final Uri? staticSeatMapUrl;
  final int confidenceBasisPoints;
  final int rank;
  final DateTime sourceObservedAt;

  factory TicketEventCandidate.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'id',
      'contextRef',
      'title',
      'startsAt',
      'timezone',
      'venueName',
      'venueCity',
      'venueCountryCode',
      'staticSeatMapUrl',
      'confidenceBasisPoints',
      'rank',
      'sourceObservedAt',
    }, 'ticket event candidate');
    final id = _string(json, 'id');
    _requireUuid(id, 'ticket event candidate id');
    final contextRef = _string(json, 'contextRef');
    if (!_contextRefPattern.hasMatch(contextRef)) {
      throw const TicketContractException(
        'The ticket event reference is invalid.',
      );
    }
    final confidence = _integer(json, 'confidenceBasisPoints');
    final rank = _integer(json, 'rank');
    if (confidence < 0 || confidence > 10000 || rank < 1 || rank > 5) {
      throw const TicketContractException(
        'The ticket event candidate ranking is invalid.',
      );
    }
    final rawSeatMap = _nullableString(json, 'staticSeatMapUrl');
    final seatMap = rawSeatMap == null ? null : Uri.tryParse(rawSeatMap);
    if (rawSeatMap != null &&
        (seatMap == null ||
            (!seatMap.isScheme('https') && !seatMap.isScheme('http')))) {
      throw const TicketContractException(
        'The ticket event seat-map address is invalid.',
      );
    }
    return TicketEventCandidate(
      id: id,
      contextRef: contextRef,
      title: _string(json, 'title', maximum: 255),
      startsAt: _nullableDateTime(json, 'startsAt'),
      timezone: _nullableString(json, 'timezone', maximum: 64),
      venueName: _nullableString(json, 'venueName', maximum: 255),
      venueCity: _nullableString(json, 'venueCity', maximum: 120),
      venueCountryCode: _nullableString(json, 'venueCountryCode', maximum: 2),
      staticSeatMapUrl: seatMap,
      confidenceBasisPoints: confidence,
      rank: rank,
      sourceObservedAt: _dateTime(json, 'sourceObservedAt'),
    );
  }
}

class TicketImportProjection {
  const TicketImportProjection({
    required this.id,
    required this.state,
    required this.version,
    required this.countryCode,
    required this.extracted,
    required this.confirmedContextRef,
    required this.failureCode,
    required this.eventCandidates,
    required this.retentionUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final TicketImportState state;
  final int version;
  final String countryCode;
  final TicketImportExtracted extracted;
  final String? confirmedContextRef;
  final String? failureCode;
  final List<TicketEventCandidate> eventCandidates;
  final DateTime retentionUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TicketImportProjection.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'id',
      'state',
      'version',
      'countryCode',
      'extracted',
      'confirmedContextRef',
      'failureCode',
      'eventCandidates',
      'retentionUntil',
      'createdAt',
      'updatedAt',
    }, 'ticket import');
    final id = _string(json, 'id');
    _requireUuid(id, 'ticket import id');
    final version = _integer(json, 'version');
    if (version < 1) {
      throw const TicketContractException(
        'The ticket import version is invalid.',
      );
    }
    final countryCode = _string(json, 'countryCode');
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)) {
      throw const TicketContractException(
        'The ticket import country is invalid.',
      );
    }
    final rawCandidates = json['eventCandidates'];
    if (rawCandidates is! List || rawCandidates.length > 5) {
      throw const TicketContractException(
        'The ticket import event candidates are invalid.',
      );
    }
    return TicketImportProjection(
      id: id,
      state: TicketImportState.parse(json['state']),
      version: version,
      countryCode: countryCode,
      extracted: TicketImportExtracted.fromJson(_map(json, 'extracted')),
      confirmedContextRef: _nullableString(json, 'confirmedContextRef'),
      failureCode: _nullableString(json, 'failureCode', maximum: 128),
      eventCandidates: List.unmodifiable(
        rawCandidates.map(
          (item) => TicketEventCandidate.fromJson(
            _object(item, 'ticket event candidate'),
          ),
        ),
      ),
      retentionUntil: _dateTime(json, 'retentionUntil'),
      createdAt: _dateTime(json, 'createdAt'),
      updatedAt: _dateTime(json, 'updatedAt'),
    );
  }
}

class TicketUploadAuthorization {
  TicketUploadAuthorization({
    required this.method,
    required this.url,
    required this.fieldName,
    required String uploadToken,
    required this.expiresAt,
    required this.acceptedMimeTypes,
    required this.maximumBytes,
  }) : _uploadToken = uploadToken;

  final String method;
  final String url;
  final String fieldName;
  final String _uploadToken;
  final DateTime expiresAt;
  final List<String> acceptedMimeTypes;
  final int maximumBytes;

  String get tokenForImmediateUpload => _uploadToken;

  factory TicketUploadAuthorization.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'method',
      'url',
      'fieldName',
      'uploadToken',
      'expiresAt',
      'acceptedMimeTypes',
      'maximumBytes',
    }, 'ticket upload authorization');
    final token = _string(json, 'uploadToken');
    final mimeTypes = _stringList(json, 'acceptedMimeTypes');
    final maximumBytes = _integer(json, 'maximumBytes');
    if (json['method'] != 'PUT' ||
        json['fieldName'] != 'ticket' ||
        token.length < 32 ||
        token.length > 128 ||
        maximumBytes != 10485760 ||
        mimeTypes.any(
          (value) => value != 'image/jpeg' && value != 'image/png',
        )) {
      throw const TicketContractException(
        'The ticket upload authorization is invalid.',
      );
    }
    return TicketUploadAuthorization(
      method: 'PUT',
      url: _string(json, 'url'),
      fieldName: 'ticket',
      uploadToken: token,
      expiresAt: _dateTime(json, 'expiresAt'),
      acceptedMimeTypes: mimeTypes,
      maximumBytes: maximumBytes,
    );
  }

  @override
  String toString() =>
      'TicketUploadAuthorization(method: PUT, credentials: [REDACTED])';
}

class CreatedTicketImport {
  const CreatedTicketImport({required this.ticketImport, required this.upload});

  final TicketImportProjection ticketImport;
  final TicketUploadAuthorization upload;

  factory CreatedTicketImport.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {'ticketImport', 'upload'}, 'create import');
    return CreatedTicketImport(
      ticketImport: TicketImportProjection.fromJson(_map(json, 'ticketImport')),
      upload: TicketUploadAuthorization.fromJson(_map(json, 'upload')),
    );
  }
}

class ConfirmedTicketImport {
  ConfirmedTicketImport({
    required this.ticketImport,
    required String protectedObjectRef,
  }) : _protectedObjectRef = protectedObjectRef;

  final TicketImportProjection ticketImport;
  final String _protectedObjectRef;

  String get referenceForImmediateConsumption => _protectedObjectRef;

  factory ConfirmedTicketImport.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'ticketImport',
      'protectedObjectRef',
    }, 'confirm import');
    final reference = _string(json, 'protectedObjectRef');
    if (!RegExp(
      r'^evidence://ticket-import/[A-Za-z0-9_-]{32,128}$',
    ).hasMatch(reference)) {
      throw const TicketContractException(
        'The confirmed ticket reference is invalid.',
      );
    }
    return ConfirmedTicketImport(
      ticketImport: TicketImportProjection.fromJson(_map(json, 'ticketImport')),
      protectedObjectRef: reference,
    );
  }

  @override
  String toString() =>
      'ConfirmedTicketImport(id: ${ticketImport.id}, reference: [REDACTED])';
}

class TicketBundleProjection {
  const TicketBundleProjection({
    required this.id,
    required this.contextRef,
    required this.eventTitle,
    required this.startsAt,
    required this.timezone,
    required this.venueName,
    required this.sectionLabel,
    required this.rowLabel,
    required this.seatLabels,
    required this.quantity,
    required this.trustLevel,
    required this.ownershipVerified,
    required this.transferabilityVerified,
    required this.verification,
    required this.state,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String contextRef;
  final String eventTitle;
  final DateTime? startsAt;
  final String? timezone;
  final String? venueName;
  final String? sectionLabel;
  final String? rowLabel;
  final List<String> seatLabels;
  final int quantity;
  final String trustLevel;
  final bool ownershipVerified;
  final bool transferabilityVerified;
  final TicketVerificationCapabilities verification;
  final TicketBundleState state;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TicketBundleProjection.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'id',
      'contextRef',
      'eventTitle',
      'startsAt',
      'timezone',
      'venueName',
      'sectionLabel',
      'rowLabel',
      'seatLabels',
      'quantity',
      'trustLevel',
      'ownershipVerified',
      'transferabilityVerified',
      'verification',
      'state',
      'version',
      'createdAt',
      'updatedAt',
    }, 'ticket bundle');
    final id = _string(json, 'id');
    _requireUuid(id, 'ticket id');
    final seats = _stringList(json, 'seatLabels', minimum: 1, maximum: 3);
    final quantity = _integer(json, 'quantity');
    final version = _integer(json, 'version');
    if (quantity != seats.length ||
        version < 1 ||
        json['trustLevel'] != 'photo_checked') {
      throw const TicketContractException('The ticket projection is invalid.');
    }
    final ownershipVerified = _boolean(json, 'ownershipVerified');
    final transferabilityVerified = _boolean(json, 'transferabilityVerified');
    final verification = TicketVerificationCapabilities.fromJson(
      _map(json, 'verification'),
    );
    if (ownershipVerified || transferabilityVerified) {
      throw const TicketContractException(
        'The photo ticket trust projection is invalid.',
      );
    }
    if (verification.ownership != TicketVerificationStatus.unverified ||
        verification.validity != TicketVerificationStatus.unverified ||
        verification.unusedStatus != TicketVerificationStatus.unverified ||
        verification.transferability != TicketVerificationStatus.unverified ||
        verification.seat != TicketVerificationStatus.unverified) {
      throw const TicketContractException(
        'The photo ticket verification capabilities are inconsistent.',
      );
    }
    return TicketBundleProjection(
      id: id,
      contextRef: _string(json, 'contextRef'),
      eventTitle: _string(json, 'eventTitle', maximum: 255),
      startsAt: _nullableDateTime(json, 'startsAt'),
      timezone: _nullableString(json, 'timezone', maximum: 64),
      venueName: _nullableString(json, 'venueName', maximum: 255),
      sectionLabel: _nullableString(json, 'sectionLabel', maximum: 64),
      rowLabel: _nullableString(json, 'rowLabel', maximum: 64),
      seatLabels: seats,
      quantity: quantity,
      trustLevel: 'photo_checked',
      ownershipVerified: false,
      transferabilityVerified: false,
      verification: verification,
      state: TicketBundleState.parse(json['state']),
      version: version,
      createdAt: _dateTime(json, 'createdAt'),
      updatedAt: _dateTime(json, 'updatedAt'),
    );
  }
}

class TicketPage<T> {
  const TicketPage({required this.items, required this.total});

  final List<T> items;
  final int total;
}

class TicketEvidenceResult {
  const TicketEvidenceResult({required this.evidence, required this.ticket});

  final EvidenceProjection evidence;
  final TicketBundleProjection ticket;

  factory TicketEvidenceResult.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'evidence',
      'ticketBundle',
    }, 'photo ticket evidence response');
    return TicketEvidenceResult(
      evidence: EvidenceProjection.fromJson(_map(json, 'evidence')),
      ticket: TicketBundleProjection.fromJson(_map(json, 'ticketBundle')),
    );
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _contextRefPattern = RegExp(r'^ticketmaster:event:[A-Za-z0-9_-]{1,200}$');

void _expectExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String name,
) {
  if (json.length != expected.length ||
      expected.any((key) => !json.containsKey(key)) ||
      json.keys.any((key) => !expected.contains(key))) {
    throw TicketContractException('$name has unexpected fields.');
  }
}

Map<String, dynamic> _object(Object? value, String name) {
  if (value is! Map) {
    throw TicketContractException('$name must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) =>
    _object(json[key], key);

String _string(Map<String, dynamic> json, String key, {int? maximum}) {
  final value = json[key];
  if (value is! String ||
      value.isEmpty ||
      (maximum != null && value.length > maximum)) {
    throw TicketContractException('$key must be a valid string.');
  }
  return value;
}

String? _nullableString(Map<String, dynamic> json, String key, {int? maximum}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || (maximum != null && value.length > maximum)) {
    throw TicketContractException('$key must be a string or null.');
  }
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw TicketContractException('$key must be an integer.');
  }
  return value;
}

bool _boolean(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw TicketContractException('$key must be a boolean.');
  }
  return value;
}

List<String> _stringList(
  Map<String, dynamic> json,
  String key, {
  int minimum = 0,
  int? maximum,
}) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw TicketContractException('$key must be a string array.');
  }
  final result = List<String>.unmodifiable(value.cast<String>());
  if (result.length < minimum ||
      (maximum != null && result.length > maximum) ||
      result.toSet().length != result.length) {
    throw TicketContractException('$key has an invalid number of values.');
  }
  return result;
}

DateTime _dateTime(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw TicketContractException('$key must be a timestamp.');
  }
  return parsed;
}

DateTime? _nullableDateTime(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _dateTime(json, key);

void _requireUuid(String value, String name) {
  if (!_uuidPattern.hasMatch(value)) {
    throw TicketContractException('$name must be a UUID.');
  }
}
