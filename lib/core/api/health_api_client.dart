import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiHealth {
  const ApiHealth({
    required this.status,
    required this.service,
    required this.version,
  });

  final String status;
  final String service;
  final String version;
}

abstract interface class ApiHealthGateway {
  Future<ApiHealth> fetchHealth();
}

class HealthContractException implements Exception {
  const HealthContractException();
}

class HealthRequestException implements Exception {
  const HealthRequestException();
}

class HealthApiClient implements ApiHealthGateway {
  HealthApiClient({
    required this.apiBaseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client;

  final Uri apiBaseUri;
  final http.Client? _client;
  final Duration timeout;

  @override
  Future<ApiHealth> fetchHealth() async {
    final client = _client ?? http.Client();

    try {
      final response = await client
          .get(
            apiBaseUri.resolve('health'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw const HealthRequestException();
      }

      final payload = _decodePayload(response.body);
      return ApiHealth(
        status: payload['status']! as String,
        service: payload['service']! as String,
        version: payload['version']! as String,
      );
    } on TimeoutException {
      throw const HealthRequestException();
    } on http.ClientException {
      throw const HealthRequestException();
    } finally {
      if (_client == null) client.close();
    }
  }

  Map<String, Object?> _decodePayload(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const HealthContractException();
    }

    if (decoded is! Map<String, dynamic> ||
        decoded.length != 3 ||
        decoded['status'] != 'ok' ||
        decoded['service'] != 'swappy-api' ||
        decoded['version'] is! String ||
        (decoded['version']! as String).trim().isEmpty) {
      throw const HealthContractException();
    }

    return decoded;
  }
}
