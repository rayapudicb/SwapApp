import 'package:flutter/foundation.dart';

import 'app_config.dart';

/// Capability issued only to the protected local-development entrypoint.
///
/// This is a UI safety boundary, not an authorization control. The API must
/// still enforce every participant policy and exchange command.
class LocalDevelopmentAccess {
  const LocalDevelopmentAccess._(this._apiBaseUri);

  static const _inspectionEnabled = bool.fromEnvironment(
    'SWAPPY_INTERNAL_OTP_INSPECTION_ENABLED',
    defaultValue: false,
  );

  final Uri _apiBaseUri;

  static LocalDevelopmentAccess? authorize(AppConfig config) {
    final uri = config.apiBaseUri;
    if (kReleaseMode ||
        !_inspectionEnabled ||
        uri == null ||
        !_isExactLoopback(uri)) {
      return null;
    }
    return LocalDevelopmentAccess._(uri);
  }

  @visibleForTesting
  static LocalDevelopmentAccess testOnly(AppConfig config) {
    final uri = config.apiBaseUri;
    LocalDevelopmentAccess? access;
    assert(() {
      if (!kReleaseMode && uri != null && _isExactLoopback(uri)) {
        access = LocalDevelopmentAccess._(uri);
      }
      return true;
    }());
    if (access == null) {
      throw StateError(
        'Test development access requires a debug loopback URL.',
      );
    }
    return access!;
  }

  bool permits(AppConfig config) {
    final candidate = config.apiBaseUri;
    return !kReleaseMode &&
        candidate != null &&
        _isExactLoopback(candidate) &&
        candidate == _apiBaseUri;
  }

  static bool _isExactLoopback(Uri uri) =>
      const {'127.0.0.1', 'localhost', '::1'}.contains(uri.host);
}
