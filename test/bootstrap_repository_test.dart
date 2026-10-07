import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swappy_mobile/core/bootstrap/data/bootstrap_repository.dart';

void main() {
  const sampleBootstrapJson = '''
{
  "maintenanceMode": { "enabled": false, "reason": null },
  "minAppVersion": "1.0.0",
  "activeCountries": [
    { "code": "US", "name": "United States", "currency": "USD", "status": "PILOT", "defaultRadiusKm": 50, "ocrAutoApprove": true },
    { "code": "GB", "name": "United Kingdom", "currency": "GBP", "status": "PILOT", "defaultRadiusKm": 40, "ocrAutoApprove": true },
    { "code": "IN", "name": "India", "currency": "INR", "status": "PILOT", "defaultRadiusKm": 30, "ocrAutoApprove": false }
  ],
  "supportedCurrencies": [
    { "code": "USD", "symbol": "\$", "name": "US Dollar", "enabled": true }
  ],
  "supportedLocales": [
    { "code": "en-US", "name": "English (United States)", "direction": "ltr", "isDefault": true }
  ],
  "exchangePolicy": {
    "holdDurationMinutes": 15,
    "maxActiveIntentsPerUser": 5,
    "ocrConfidenceThresholdPercent": 85
  },
  "legalDocuments": [
    { "slug": "terms-of-service", "title": "Terms of Service", "version": 1, "contentDigest": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "publishedAt": "2026-08-24T00:00:00.000Z" },
    { "slug": "privacy-policy", "title": "Privacy Policy", "version": 1, "contentDigest": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "publishedAt": "2026-08-24T00:00:00.000Z" },
    { "slug": "eula", "title": "EULA", "version": 1, "contentDigest": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "publishedAt": "2026-08-24T00:00:00.000Z" }
  ],
  "serverTime": "2026-08-24T00:00:00.000Z"
}
''';

  test(
    'parses bootstrap payload and country configurations successfully',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url,
          Uri.parse('https://api.example.com/v1/platform/bootstrap'),
        );
        return http.Response(sampleBootstrapJson, 200);
      });

      final repo = BootstrapRepository(
        baseUri: Uri.parse('https://api.example.com/'),
        client: client,
      );

      final bootstrap = await repo.fetchBootstrap();

      expect(bootstrap.maintenanceMode.enabled, isFalse);
      expect(bootstrap.activeCountries.length, 3);
      expect(bootstrap.countryForCode('US')?.currency, 'USD');
      expect(bootstrap.countryForCode('US')?.defaultRadiusKm, 50);
      expect(bootstrap.countryForCode('US')?.ocrAutoApprove, isTrue);
      expect(bootstrap.exchangePolicy.holdDurationMinutes, 15);
      expect(bootstrap.legalDocumentForSlug('terms-of-service')?.version, 1);
    },
  );

  test('loads the participant-facing published legal document route', () async {
    final client = MockClient((request) async {
      expect(
        request.url,
        Uri.parse(
          'https://api.example.com/v1/legal/documents/terms-of-service?locale=en-US&countryCode=US',
        ),
      );
      return http.Response('''
{
  "slug": "terms-of-service",
  "title": "Terms of Service",
  "version": 2,
  "contentMarkdown": "Approved terms.",
  "contentDigest": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
  "locale": "en-US",
  "jurisdiction": "US",
  "effectiveAt": "2026-08-24T00:00:00.000Z",
  "status": "published"
}
''', 200);
    });

    final repo = BootstrapRepository(
      baseUri: Uri.parse('https://api.example.com/'),
      client: client,
    );

    final document = await repo.fetchLegalDocument(
      'terms-of-service',
      locale: 'en-US',
      countryCode: 'us',
    );

    expect(document.slug, 'terms-of-service');
    expect(document.version, 2);
    expect(document.jurisdiction, 'US');
  });

  test('rejects missing legal document summaries', () async {
    final client = MockClient(
      (_) async => http.Response(
        sampleBootstrapJson.replaceFirst('"legalDocuments": [', '"missing": ['),
        200,
      ),
    );
    final repo = BootstrapRepository(
      baseUri: Uri.parse('https://api.example.com/'),
      client: client,
    );

    await expectLater(
      repo.fetchBootstrap(),
      throwsA(isA<BootstrapException>()),
    );
  });

  test('rejects non-integer legal document versions', () async {
    final client = MockClient(
      (_) async => http.Response(
        sampleBootstrapJson.replaceFirst('"version": 1,', '"version": 1.5,'),
        200,
      ),
    );
    final repo = BootstrapRepository(
      baseUri: Uri.parse('https://api.example.com/'),
      client: client,
    );

    await expectLater(
      repo.fetchBootstrap(),
      throwsA(isA<BootstrapException>()),
    );
  });

  test('throws BootstrapException on non-200 response', () async {
    final client = MockClient((_) async => http.Response('Error', 500));
    final repo = BootstrapRepository(
      baseUri: Uri.parse('https://api.example.com/'),
      client: client,
    );

    expect(repo.fetchBootstrap(), throwsA(isA<BootstrapException>()));
  });
}
