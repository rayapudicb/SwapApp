import 'exchange_models.dart';

enum SwapRequestState {
  submitted,
  selected,
  rejected,
  withdrawn,
  expired;

  String get wireValue => name;

  static SwapRequestState fromJson(Object? value, String field) =>
      _enumValue(values, value, field);
}

enum SwapRequestRole {
  requester,
  targetOwner;

  String get wireValue => switch (this) {
    requester => 'requester',
    targetOwner => 'target_owner',
  };

  static SwapRequestRole fromJson(Object? value, String field) {
    for (final role in values) {
      if (role.wireValue == value) return role;
    }
    throw ExchangeContractException('$field has an unsupported value.');
  }
}

enum RequestCashDirection {
  none,
  requesterPaysOwner,
  ownerPaysRequester;

  String get wireValue => switch (this) {
    none => 'none',
    requesterPaysOwner => 'requester_pays_owner',
    ownerPaysRequester => 'owner_pays_requester',
  };

  static RequestCashDirection fromJson(Object? value, String field) {
    for (final direction in values) {
      if (direction.wireValue == value) return direction;
    }
    throw ExchangeContractException('$field has an unsupported value.');
  }
}

class SwapPostProjection {
  const SwapPostProjection({
    required this.post,
    required this.isOwnPost,
    required this.requestable,
  });

  final SwapIntentProjection post;
  final bool isOwnPost;
  final bool requestable;

  factory SwapPostProjection.fromJson(Map<String, dynamic> json) {
    const postKeys = {
      'id',
      'state',
      'version',
      'desiredAssignmentLabels',
      'acceptsAnyAssignment',
      'expiresAt',
      'publishedAt',
      'pausedAt',
      'withdrawnAt',
      'createdAt',
      'updatedAt',
      'offeredSource',
      'offeredEntitlement',
      'offeredTicketBundle',
      'cashDifference',
    };
    _expectKeys(json, {...postKeys, 'isOwnPost', 'requestable'}, 'swap post');
    final postJson = <String, dynamic>{
      for (final key in postKeys) key: json[key],
    };
    final post = SwapIntentProjection.fromJson(postJson);
    if (post.state != SwapIntentState.published) {
      throw ExchangeContractException('A public swap post must be published.');
    }
    return SwapPostProjection(
      post: post,
      isOwnPost: _bool(json, 'isOwnPost'),
      requestable: _bool(json, 'requestable'),
    );
  }
}

class CreateSwapRequestRequest {
  CreateSwapRequestRequest({
    required this.counterpartyIntentId,
    required this.targetIntentVersion,
    required this.counterpartyIntentVersion,
    required this.expiresAt,
    this.cashDirection = RequestCashDirection.none,
    this.cashAmountMinor,
    this.cashCurrency,
  }) {
    _uuid(counterpartyIntentId, 'counterpartyIntentId');
    _positiveVersion(targetIntentVersion, 'targetIntentVersion');
    _positiveVersion(counterpartyIntentVersion, 'counterpartyIntentVersion');
    _validateCash(cashDirection, cashAmountMinor, cashCurrency);
  }

  final String counterpartyIntentId;
  final int targetIntentVersion;
  final int counterpartyIntentVersion;
  final RequestCashDirection cashDirection;
  final int? cashAmountMinor;
  final String? cashCurrency;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
    'counterpartyIntentId': counterpartyIntentId,
    'targetIntentVersion': targetIntentVersion,
    'counterpartyIntentVersion': counterpartyIntentVersion,
    'cashDirection': cashDirection.wireValue,
    if (cashAmountMinor != null) 'cashAmountMinor': cashAmountMinor,
    if (cashCurrency != null) 'cashCurrency': cashCurrency!.toUpperCase(),
    'expiresAt': _wireDate(expiresAt),
  };
}

class SelectSwapRequestRequest {
  SelectSwapRequestRequest({
    required this.expectedVersion,
    required this.targetIntentVersion,
    required this.counterpartyIntentVersion,
  }) {
    _positiveVersion(expectedVersion, 'expectedVersion');
    _positiveVersion(targetIntentVersion, 'targetIntentVersion');
    _positiveVersion(counterpartyIntentVersion, 'counterpartyIntentVersion');
  }

  final int expectedVersion;
  final int targetIntentVersion;
  final int counterpartyIntentVersion;

  Map<String, dynamic> toJson() => {
    'expectedVersion': expectedVersion,
    'targetIntentVersion': targetIntentVersion,
    'counterpartyIntentVersion': counterpartyIntentVersion,
  };
}

class RequestCashDifference {
  const RequestCashDifference({
    required this.direction,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.paymentProtected,
  });

  final RequestCashDirection direction;
  final int? amountMinor;
  final String? currency;
  final String status;
  final bool paymentProtected;

  factory RequestCashDifference.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'direction',
      'amountMinor',
      'currency',
      'status',
      'paymentProtected',
    }, 'request cash difference');
    final direction = RequestCashDirection.fromJson(
      json['direction'],
      'cashDifference.direction',
    );
    final amount = json['amountMinor'];
    final currency = json['currency'];
    if ((amount != null &&
            (amount is! int || amount < 1 || amount > 100000000)) ||
        (currency != null &&
            (currency is! String ||
                !RegExp(r'^[A-Z]{3}$').hasMatch(currency))) ||
        json['status'] != 'proposal_only' ||
        json['paymentProtected'] != false ||
        (direction == RequestCashDirection.none &&
            (amount != null || currency != null)) ||
        (direction != RequestCashDirection.none &&
            (amount == null || currency == null))) {
      throw const ExchangeContractException(
        'request cash difference projection is invalid.',
      );
    }
    return RequestCashDifference(
      direction: direction,
      amountMinor: amount as int?,
      currency: currency as String?,
      status: 'proposal_only',
      paymentProtected: false,
    );
  }
}

class SwapRequestProjection {
  const SwapRequestProjection({
    required this.id,
    required this.state,
    required this.version,
    required this.role,
    required this.targetPostVersionAtSubmission,
    required this.counterpartyPostVersionAtSubmission,
    required this.cashDifference,
    required this.expiresAt,
    required this.selectedAt,
    required this.rejectedAt,
    required this.withdrawnAt,
    required this.createdAt,
    required this.updatedAt,
    required this.targetPost,
    required this.counterpartyPost,
    required this.warning,
    this.agreementId,
  });

  final String id;
  final SwapRequestState state;
  final int version;
  final SwapRequestRole role;
  final int targetPostVersionAtSubmission;
  final int counterpartyPostVersionAtSubmission;
  final RequestCashDifference cashDifference;
  final DateTime expiresAt;
  final DateTime? selectedAt;
  final DateTime? rejectedAt;
  final DateTime? withdrawnAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SwapIntentProjection targetPost;
  final SwapIntentProjection counterpartyPost;
  final String warning;
  final String? agreementId;

  factory SwapRequestProjection.fromJson(Map<String, dynamic> json) {
    _expectKeys(json, const {
      'id',
      'state',
      'version',
      'role',
      'targetPostVersionAtSubmission',
      'counterpartyPostVersionAtSubmission',
      'cashDifference',
      'expiresAt',
      'selectedAt',
      'rejectedAt',
      'withdrawnAt',
      'createdAt',
      'updatedAt',
      'targetPost',
      'counterpartyPost',
      'warning',
      'agreementId',
    }, 'swap request');
    final id = _string(json, 'id');
    _uuid(id, 'swapRequest.id');
    final warning = _string(json, 'warning');
    if (warning.isEmpty) {
      throw const ExchangeContractException('swapRequest.warning is required.');
    }
    final agreementId = _nullableString(json, 'agreementId');
    if (agreementId != null) _uuid(agreementId, 'swapRequest.agreementId');
    return SwapRequestProjection(
      id: id,
      state: SwapRequestState.fromJson(json['state'], 'swapRequest.state'),
      version: _positiveInt(json, 'version'),
      role: SwapRequestRole.fromJson(json['role'], 'swapRequest.role'),
      targetPostVersionAtSubmission: _positiveInt(
        json,
        'targetPostVersionAtSubmission',
      ),
      counterpartyPostVersionAtSubmission: _positiveInt(
        json,
        'counterpartyPostVersionAtSubmission',
      ),
      cashDifference: RequestCashDifference.fromJson(
        _map(json, 'cashDifference'),
      ),
      expiresAt: _date(json, 'expiresAt'),
      selectedAt: _nullableDate(json, 'selectedAt'),
      rejectedAt: _nullableDate(json, 'rejectedAt'),
      withdrawnAt: _nullableDate(json, 'withdrawnAt'),
      createdAt: _date(json, 'createdAt'),
      updatedAt: _date(json, 'updatedAt'),
      targetPost: SwapIntentProjection.fromJson(_map(json, 'targetPost')),
      counterpartyPost: SwapIntentProjection.fromJson(
        _map(json, 'counterpartyPost'),
      ),
      warning: warning,
      agreementId: agreementId,
    );
  }
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw ExchangeContractException('$key must be a string or null.');
  }
  return value;
}

class SwapRequestDetail {
  const SwapRequestDetail({required this.swapRequest, required this.timeline});

  final SwapRequestProjection swapRequest;
  final List<SwapIntentTimelineItem> timeline;
}

void validateSwapRequestExpiry(DateTime expiresAt, {required DateTime now}) {
  final remaining = expiresAt.toUtc().difference(now.toUtc());
  if (remaining < const Duration(minutes: 5) ||
      remaining > const Duration(days: 30)) {
    throw const ExchangeContractException(
      'Request expiry must be between 5 minutes and 30 days from now.',
    );
  }
}

String swapIntentContextRef(SwapIntentProjection intent) =>
    intent.offeredTicketBundle?.contextRef ??
    intent.offeredEntitlement?.contextRef ??
    '';

int swapIntentQuantity(SwapIntentProjection intent) =>
    intent.offeredTicketBundle?.quantity ?? 1;

T _enumValue<T extends Enum>(List<T> values, Object? value, String field) {
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw ExchangeContractException('$field has an unsupported value.');
}

void _expectKeys(
  Map<String, dynamic> json,
  Set<String> keys,
  String objectName,
) {
  if (json.length != keys.length ||
      json.keys.any((key) => !keys.contains(key)) ||
      keys.any((key) => !json.containsKey(key))) {
    throw ExchangeContractException('$objectName has unexpected fields.');
  }
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw ExchangeContractException('$key must be a string.');
  }
  return value;
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw ExchangeContractException('$key must be a boolean.');
  }
  return value;
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 1) {
    throw ExchangeContractException('$key must be a positive integer.');
  }
  return value;
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw ExchangeContractException('$key must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  if (!_rfc3339.hasMatch(value)) {
    throw ExchangeContractException('$key must be an RFC 3339 timestamp.');
  }
  final result = DateTime.tryParse(value);
  if (result == null) {
    throw ExchangeContractException('$key must be an RFC 3339 timestamp.');
  }
  return result;
}

DateTime? _nullableDate(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _date(json, key);

void _uuid(String value, String field) {
  if (!_uuidPattern.hasMatch(value)) {
    throw ExchangeContractException('$field must be a UUID.');
  }
}

void _positiveVersion(int value, String field) {
  if (value < 1) {
    throw ExchangeContractException('$field must be at least 1.');
  }
}

void _validateCash(
  RequestCashDirection direction,
  int? amountMinor,
  String? currency,
) {
  if (direction == RequestCashDirection.none) {
    if (amountMinor != null || currency != null) {
      throw const ExchangeContractException(
        'Cash amount and currency must be empty when direction is none.',
      );
    }
    return;
  }
  if (amountMinor == null ||
      amountMinor < 1 ||
      amountMinor > 100000000 ||
      currency == null ||
      !RegExp(r'^[A-Za-z]{3}$').hasMatch(currency.trim())) {
    throw const ExchangeContractException(
      'Enter a positive cash amount and a three-letter currency.',
    );
  }
}

String _wireDate(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
  value.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _rfc3339 = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
);
