import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/platform_bootstrap.dart';

class BootstrapException implements Exception {
  const BootstrapException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

abstract interface class BootstrapGateway {
  Future<PlatformBootstrap> fetchBootstrap();
  Future<LegalDocument> fetchLegalDocument(
    String slug, {
    String? locale,
    String? countryCode,
  });
}

class BootstrapRepository implements BootstrapGateway {
  BootstrapRepository({
    required this.baseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<PlatformBootstrap> fetchBootstrap() async {
    final url = baseUri.resolve('/v1/platform/bootstrap');
    try {
      final response = await _client
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw BootstrapException(
          'Failed to load platform configuration (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const BootstrapException('Invalid platform bootstrap payload.');
      }

      return PlatformBootstrap.fromJson(decoded);
    } catch (e) {
      if (e is BootstrapException) rethrow;
      throw BootstrapException('Unable to reach Swappy services: $e');
    }
  }

  @override
  Future<LegalDocument> fetchLegalDocument(
    String slug, {
    String? locale,
    String? countryCode,
  }) async {
    final normalizedSlug = slug.trim();
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(normalizedSlug)) {
      throw const BootstrapException('Invalid legal document identifier.');
    }
    final query = <String, String>{
      if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
      if (countryCode != null && countryCode.trim().isNotEmpty)
        'countryCode': countryCode.trim().toUpperCase(),
    };
    final url = baseUri
        .resolve('/v1/legal/documents/${Uri.encodeComponent(normalizedSlug)}')
        .replace(queryParameters: query.isEmpty ? null : query);
    try {
      final response = await _client
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw BootstrapException(
          'Published legal document is unavailable (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const BootstrapException('Invalid legal document payload.');
      }
      return LegalDocument.fromJson(decoded);
    } catch (e) {
      if (e is BootstrapException) rethrow;
      throw const BootstrapException(
        'Published legal document could not be verified.',
      );
    }
  }
}
