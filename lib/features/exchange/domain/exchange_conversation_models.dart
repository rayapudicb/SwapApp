import 'exchange_models.dart';

class SendSwapMessageRequest {
  SendSwapMessageRequest(String body) : body = body.trim() {
    if (this.body.isEmpty || this.body.length > 2000) {
      throw const ExchangeContractException(
        'Message body must be between 1 and 2000 characters.',
      );
    }
  }

  final String body;

  Map<String, dynamic> toJson() => {'body': body};

  @override
  String toString() => 'SendSwapMessageRequest(body: [REDACTED])';
}

class SwapMessageProjection {
  const SwapMessageProjection({
    required this.id,
    required this.conversationId,
    required this.isViewer,
    required this.body,
    required this.readAt,
    required this.isFlagged,
    required this.flagReason,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final bool isViewer;
  final String body;
  final DateTime? readAt;
  final bool isFlagged;
  final String? flagReason;
  final DateTime createdAt;

  factory SwapMessageProjection.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'id',
      'conversationId',
      'senderId',
      'isViewer',
      'body',
      'readAt',
      'isFlagged',
      'flagReason',
      'createdAt',
    }, 'swap message');
    final id = _requiredString(json, 'id');
    final conversationId = _requiredString(json, 'conversationId');
    final senderId = _requiredString(json, 'senderId');
    _requireUuid(id, 'message.id');
    _requireUuid(conversationId, 'message.conversationId');
    _requireUuid(senderId, 'message.senderId');
    final body = _requiredString(json, 'body');
    if (body.isEmpty || body.length > 2000) {
      throw const ExchangeContractException(
        'message.body has an invalid length.',
      );
    }
    final flagReason = _nullableString(json, 'flagReason');
    if (flagReason != null && flagReason.length > 128) {
      throw const ExchangeContractException(
        'message.flagReason exceeds 128 characters.',
      );
    }
    return SwapMessageProjection(
      id: id,
      conversationId: conversationId,
      isViewer: _requiredBool(json, 'isViewer'),
      body: body,
      readAt: _nullableDateTime(json, 'readAt'),
      isFlagged: _requiredBool(json, 'isFlagged'),
      flagReason: flagReason,
      createdAt: _requiredDateTime(json, 'createdAt'),
    );
  }

  @override
  String toString() =>
      'SwapMessageProjection(id: $id, conversationId: $conversationId, '
      'sender: [REDACTED], body: [REDACTED], isViewer: $isViewer, '
      'isFlagged: $isFlagged, createdAt: $createdAt)';
}

class SwapConversationProjection {
  const SwapConversationProjection({
    required this.id,
    required this.swapRequestId,
    required this.messages,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String swapRequestId;
  final List<SwapMessageProjection> messages;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SwapConversationProjection.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {
      'id',
      'swapRequestId',
      'messages',
      'unreadCount',
      'createdAt',
      'updatedAt',
    }, 'swap conversation');
    final id = _requiredString(json, 'id');
    final requestId = _requiredString(json, 'swapRequestId');
    _requireUuid(id, 'conversation.id');
    _requireUuid(requestId, 'conversation.swapRequestId');
    final rawMessages = json['messages'];
    final unreadCount = json['unreadCount'];
    if (rawMessages is! List || unreadCount is! int || unreadCount < 0) {
      throw const ExchangeContractException(
        'The swap conversation projection is invalid.',
      );
    }
    final messages = List<SwapMessageProjection>.unmodifiable(
      rawMessages.map(
        (value) => SwapMessageProjection.fromJson(
          _requiredObject(value, 'conversation message'),
        ),
      ),
    );
    if (messages.any((message) => message.conversationId != id) ||
        unreadCount > messages.where((message) => !message.isViewer).length) {
      throw const ExchangeContractException(
        'The swap conversation message projection is inconsistent.',
      );
    }
    return SwapConversationProjection(
      id: id,
      swapRequestId: requestId,
      messages: messages,
      unreadCount: unreadCount,
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

class SwapConversationReadResult {
  const SwapConversationReadResult({required this.updatedCount});

  final int updatedCount;

  factory SwapConversationReadResult.fromJson(Map<String, dynamic> json) {
    _expectExactKeys(json, const {'updatedCount'}, 'conversation read result');
    final count = json['updatedCount'];
    if (count is! int || count < 0) {
      throw const ExchangeContractException(
        'conversation read updatedCount must be a non-negative integer.',
      );
    }
    return SwapConversationReadResult(updatedCount: count);
  }
}

void _expectExactKeys(
  Map<String, dynamic> json,
  Set<String> keys,
  String name,
) {
  if (json.length != keys.length ||
      keys.any((key) => !json.containsKey(key)) ||
      json.keys.any((key) => !keys.contains(key))) {
    throw ExchangeContractException('$name has unexpected fields.');
  }
}

Map<String, dynamic> _requiredObject(Object? value, String name) {
  if (value is! Map) {
    throw ExchangeContractException('$name must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw ExchangeContractException('$key must be a string.');
  }
  return value;
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw ExchangeContractException('$key must be a string or null.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw ExchangeContractException('$key must be a boolean.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !_rfc3339.hasMatch(value)) {
    throw ExchangeContractException('$key must be an RFC 3339 timestamp.');
  }
  return parsed;
}

DateTime? _nullableDateTime(Map<String, dynamic> json, String key) =>
    json[key] == null ? null : _requiredDateTime(json, key);

void _requireUuid(String value, String field) {
  if (!_uuid.hasMatch(value)) {
    throw ExchangeContractException('$field must be a UUID.');
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _rfc3339 = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
);
