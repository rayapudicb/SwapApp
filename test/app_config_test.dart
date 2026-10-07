import 'package:flutter_test/flutter_test.dart';
import 'package:swappy_mobile/core/config/app_config.dart';

void main() {
  test('requires an explicit API base URL', () {
    final config = AppConfig.fromApiBaseUrl('');

    expect(config.isConfigured, isFalse);
    expect(config.apiBaseUri, isNull);
    expect(config.configurationError, contains('SWAPPY_API_BASE_URL'));
  });

  test('normalizes a valid API base URL', () {
    final config = AppConfig.fromApiBaseUrl('https://api.example.com/v1');

    expect(config.isConfigured, isTrue);
    expect(config.apiBaseUri.toString(), 'https://api.example.com/v1/');
  });

  test('rejects non-HTTP and ambiguous API URLs', () {
    expect(AppConfig.fromApiBaseUrl('file:///tmp/api').isConfigured, isFalse);
    expect(
      AppConfig.fromApiBaseUrl(
        'https://user:secret@api.example.com',
      ).isConfigured,
      isFalse,
    );
    expect(
      AppConfig.fromApiBaseUrl('https://api.example.com?token=x').isConfigured,
      isFalse,
    );
  });
}
