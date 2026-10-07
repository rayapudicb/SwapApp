import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swappy_mobile/core/api/health_api_client.dart';

void main() {
  test('accepts the exact Swappy health contract', () async {
    final client = MockClient((request) async {
      expect(request.url, Uri.parse('https://api.example.com/health'));
      expect(request.headers['Accept'], 'application/json');
      return http.Response(
        '{"status":"ok","service":"swappy-api","version":"0.1.0"}',
        200,
      );
    });
    final gateway = HealthApiClient(
      apiBaseUri: Uri.parse('https://api.example.com/'),
      client: client,
    );

    final health = await gateway.fetchHealth();

    expect(health.status, 'ok');
    expect(health.service, 'swappy-api');
    expect(health.version, '0.1.0');
  });

  test('rejects a successful response with the wrong contract', () async {
    final gateway = HealthApiClient(
      apiBaseUri: Uri.parse('https://api.example.com/'),
      client: MockClient((_) async => http.Response('{"status":"ok"}', 200)),
    );

    expect(gateway.fetchHealth(), throwsA(isA<HealthContractException>()));
  });

  test('maps a non-success response to a request failure', () async {
    final gateway = HealthApiClient(
      apiBaseUri: Uri.parse('https://api.example.com/'),
      client: MockClient((_) async => http.Response('', 503)),
    );

    expect(gateway.fetchHealth(), throwsA(isA<HealthRequestException>()));
  });
}
