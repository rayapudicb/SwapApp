import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._({this.apiBaseUri, this.configurationError});

  final Uri? apiBaseUri;
  final String? configurationError;

  bool get isConfigured => apiBaseUri != null && configurationError == null;

  factory AppConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment('SWAPPY_API_BASE_URL');
    return AppConfig.fromApiBaseUrl(apiBaseUrl, requireHttps: kReleaseMode);
  }

  factory AppConfig.fromApiBaseUrl(String value, {bool requireHttps = false}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const AppConfig._(
        configurationError:
            'SWAPPY_API_BASE_URL is required to connect this client.',
      );
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        !parsed.hasAuthority ||
        parsed.host.trim().isEmpty ||
        parsed.userInfo.isNotEmpty ||
        !{'http', 'https'}.contains(parsed.scheme) ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      return const AppConfig._(
        configurationError:
            'SWAPPY_API_BASE_URL must be an absolute HTTP(S) URL without a query or fragment.',
      );
    }

    if (requireHttps && parsed.scheme != 'https') {
      return const AppConfig._(
        configurationError:
            'SWAPPY_API_BASE_URL must use HTTPS in release builds.',
      );
    }

    final normalizedPath = parsed.path.endsWith('/')
        ? parsed.path
        : '${parsed.path}/';
    return AppConfig._(apiBaseUri: parsed.replace(path: normalizedPath));
  }
}
