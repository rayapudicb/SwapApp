import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

typedef AccessTokenProvider = Future<String> Function({bool forceRefresh});
typedef SessionRejectedHandler =
    Future<void> Function(ApiRequestException error);
typedef SessionIdentityProvider = String? Function();

class ApiSessionScope {
  const ApiSessionScope._(this.sessionId);

  final String? sessionId;
}

class ApiRequestException implements Exception {
  const ApiRequestException(
    this.message, {
    this.statusCode,
    this.code,
    this.correlationId,
    this.outcomeUnknown = false,
    this.retryAt,
    this.isTransportFailure = false,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final String? correlationId;
  final bool outcomeUnknown;
  final DateTime? retryAt;
  final bool isTransportFailure;

  factory ApiRequestException.fromResponse(
    http.Response response, {
    bool outcomeUnknown = false,
  }) {
    Map<String, dynamic>? payload;
    try {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } on FormatException {
      // An unreadable server body is never surfaced to the participant.
    }
    final message = payload?['message'];
    final code = payload?['code'];
    final retryAt = payload?['retryAfter'] ?? payload?['retryAt'];
    return ApiRequestException(
      message is String && message.trim().isNotEmpty
          ? message
          : response.statusCode == 401
          ? 'Your session is no longer valid. Sign in again.'
          : 'The request failed (${response.statusCode}).',
      statusCode: response.statusCode,
      code: code is String ? code : null,
      correlationId:
          response.headers['x-correlation-id'] ??
          response.headers['x-request-id'],
      outcomeUnknown: outcomeUnknown && response.statusCode >= 500,
      retryAt: retryAt is String ? DateTime.tryParse(retryAt) : null,
    );
  }

  bool get isGeoRestricted => code == 'MARKET_GEO_RESTRICTED';
  bool get isMaintenanceMode => code == 'MAINTENANCE_MODE';

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required this.baseUri,
    required AccessTokenProvider accessTokenProvider,
    SessionRejectedHandler? onSessionRejected,
    SessionIdentityProvider? sessionIdentityProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _accessTokenProvider = accessTokenProvider,
       _onSessionRejected = onSessionRejected,
       _sessionIdentityProvider = sessionIdentityProvider,
       _client = client ?? http.Client();

  final Uri baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final SessionRejectedHandler? _onSessionRejected;
  final SessionIdentityProvider? _sessionIdentityProvider;
  final http.Client _client;
  final Duration timeout;

  Uri _buildUrl(String endpoint) =>
      baseUri.resolve(endpoint.startsWith('/') ? endpoint : '/$endpoint');

  Future<Map<String, String>> _headers({
    bool forceRefresh = false,
    bool jsonContentType = true,
  }) async {
    final token = await _accessTokenProvider(forceRefresh: forceRefresh);
    if (token.trim().isEmpty) {
      throw const ApiRequestException('Sign in to continue.');
    }
    return {
      if (jsonContentType) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String> extraHeaders = const {},
    ApiSessionScope? sessionScope,
  }) => _send(
    'POST',
    endpoint,
    body: body,
    extraHeaders: extraHeaders,
    sessionScope: sessionScope,
  );

  Future<http.Response> get(
    String endpoint, {
    Map<String, String> extraHeaders = const {},
    ApiSessionScope? sessionScope,
  }) => _send(
    'GET',
    endpoint,
    extraHeaders: extraHeaders,
    sessionScope: sessionScope,
  );

  Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String> extraHeaders = const {},
    ApiSessionScope? sessionScope,
  }) => _send(
    'PATCH',
    endpoint,
    body: body,
    extraHeaders: extraHeaders,
    sessionScope: sessionScope,
  );

  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String> extraHeaders = const {},
    ApiSessionScope? sessionScope,
  }) => _send(
    'PUT',
    endpoint,
    body: body,
    extraHeaders: extraHeaders,
    sessionScope: sessionScope,
  );

  /// Uploads one in-memory file without persisting its path or bytes.
  ///
  /// The server-provided upload URL must resolve to the configured API origin;
  /// this prevents bearer credentials and upload tokens being sent elsewhere.
  Future<http.Response> putMultipartFile({
    required String uploadUrl,
    required String fieldName,
    required List<int> bytes,
    required String filename,
    Map<String, String> extraHeaders = const {},
    ApiSessionScope? sessionScope,
    Duration uploadTimeout = const Duration(seconds: 60),
  }) async {
    final boundScope = sessionScope ?? captureSessionScope();
    final url = _trustedUploadUrl(uploadUrl);

    Future<http.Response> perform({required bool forceRefresh}) async {
      _requireSessionScope(boundScope);
      final request = http.MultipartRequest('PUT', url);
      request.headers.addAll({
        ...await _headers(forceRefresh: forceRefresh, jsonContentType: false),
        ...extraHeaders,
      });
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
      );
      _requireSessionScope(boundScope);
      final streamed = await _client.send(request).timeout(uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      _requireSessionScope(boundScope);
      return response;
    }

    return _mapNetworkErrors(() async {
      var response = await perform(forceRefresh: false);
      if (response.statusCode == 401) {
        response = await perform(forceRefresh: true);
      }
      if (response.statusCode == 401) {
        final error = ApiRequestException.fromResponse(response);
        await _onSessionRejected?.call(error);
        throw error;
      }
      return response;
    });
  }

  Future<http.Response> delete(
    String endpoint, {
    Map<String, String> extraHeaders = const {},
    ApiSessionScope? sessionScope,
  }) => _send(
    'DELETE',
    endpoint,
    extraHeaders: extraHeaders,
    sessionScope: sessionScope,
  );

  ApiSessionScope? captureSessionScope() => _sessionIdentityProvider == null
      ? null
      : ApiSessionScope._(_sessionIdentityProvider());

  Future<http.Response> _send(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String> extraHeaders = const {},
    ApiSessionScope? sessionScope,
  }) async {
    final boundScope = sessionScope ?? captureSessionScope();
    final url = _buildUrl(endpoint);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return _mapNetworkErrors(() async {
      _requireSessionScope(boundScope);
      final initialHeaders = await _headers();
      _requireSessionScope(boundScope);
      var response = await _perform(
        method,
        url,
        headers: {...initialHeaders, ...extraHeaders},
        body: encodedBody,
      );
      if (response.statusCode == 401) {
        _requireSessionScope(boundScope);
        final refreshedHeaders = await _headers(forceRefresh: true);
        _requireSessionScope(boundScope);
        response = await _perform(
          method,
          url,
          headers: {...refreshedHeaders, ...extraHeaders},
          body: encodedBody,
        );
      }
      if (response.statusCode == 401) {
        final error = ApiRequestException.fromResponse(response);
        await _onSessionRejected?.call(error);
        throw error;
      }
      return response;
    });
  }

  void _requireSessionScope(ApiSessionScope? scope) {
    if (scope == null || _sessionIdentityProvider == null) return;
    if (_sessionIdentityProvider() != scope.sessionId) {
      throw const ApiRequestException(
        'The signed-in account changed before this request completed. '
        'Start the action again.',
        code: 'PARTICIPANT_SESSION_CHANGED',
      );
    }
  }

  Future<http.Response> _perform(
    String method,
    Uri url, {
    required Map<String, String> headers,
    String? body,
  }) => switch (method) {
    'GET' => _client.get(url, headers: headers).timeout(timeout),
    'POST' => _client.post(url, headers: headers, body: body).timeout(timeout),
    'PATCH' =>
      _client.patch(url, headers: headers, body: body).timeout(timeout),
    'PUT' => _client.put(url, headers: headers, body: body).timeout(timeout),
    'DELETE' => _client.delete(url, headers: headers).timeout(timeout),
    _ => throw ArgumentError.value(method, 'method', 'is unsupported'),
  };

  Uri _trustedUploadUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null || value.trim().isEmpty) {
      throw const ApiRequestException('The upload destination is invalid.');
    }
    final resolved = parsed.hasScheme ? parsed : baseUri.resolveUri(parsed);
    if (resolved.scheme != baseUri.scheme ||
        resolved.host != baseUri.host ||
        resolved.port != baseUri.port) {
      throw const ApiRequestException(
        'The upload destination is not approved for this app.',
      );
    }
    return resolved;
  }

  Future<http.Response> _mapNetworkErrors(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException {
      throw const ApiRequestException(
        'The Swappy service took too long to respond. Try again.',
        isTransportFailure: true,
      );
    } on http.ClientException {
      throw const ApiRequestException(
        'Cannot reach Swappy right now. Check the connection and try again.',
        isTransportFailure: true,
      );
    }
  }

  static void requireSuccess(
    http.Response response, {
    bool outcomeUnknown = false,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiRequestException.fromResponse(
      response,
      outcomeUnknown: outcomeUnknown,
    );
  }
}
