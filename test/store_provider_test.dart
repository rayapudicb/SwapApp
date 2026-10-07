import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swappy_mobile/core/api/api_client.dart';
import 'package:swappy_mobile/features/store/data/store_repository.dart';
import 'package:swappy_mobile/features/store/providers/store_provider.dart';

void main() {
  test('loads server plans and current posting entitlement together', () async {
    final paths = <String>[];
    final api = ApiClient(
      baseUri: Uri.parse('https://api.example.test'),
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/v1/store/products') {
          return http.Response(
            jsonEncode([
              {
                'productId': 'swappy_offerer_plus_monthly',
                'platform': 'all',
                'productType': 'subscription',
                'title': 'Offerer Plus',
                'description': 'Two posting credits each cycle.',
                'creditsGranted': 2,
                'purchaseMode': 'not_configured',
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/v1/me/billing-receipts') {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response(
          jsonEncode({
            'availableCredits': 1,
            'totalCreditsGranted': 1,
            'creditsConsumed': 0,
            'canPublish': true,
            'activeSubscription': null,
          }),
          200,
        );
      }),
    );
    final provider = StoreProvider(repository: StoreRepository(api));

    await provider.load();

    expect(provider.error, isNull);
    expect(provider.products.single.title, 'Offerer Plus');
    expect(provider.products.single.purchaseMode, 'not_configured');
    expect(provider.entitlement?.availableCredits, 1);
    expect(
      paths,
      containsAll(['/v1/store/products', '/v1/me/offering-entitlement']),
    );
  });

  test('session reset clears plan and entitlement data', () async {
    final api = ApiClient(
      baseUri: Uri.parse('https://api.example.test'),
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient(
        (request) async => http.Response(
          request.url.path == '/v1/store/products'
              ? jsonEncode([
                  {
                    'productId': 'credits',
                    'platform': 'all',
                    'productType': 'credit_pack',
                    'title': 'Credits',
                    'description': 'Posting credits.',
                    'creditsGranted': 2,
                    'purchaseMode': 'not_configured',
                  },
                ])
              : jsonEncode({
                  'availableCredits': 1,
                  'totalCreditsGranted': 1,
                  'creditsConsumed': 0,
                  'canPublish': true,
                  'activeSubscription': null,
                }),
          200,
        ),
      ),
    );
    final provider = StoreProvider(repository: StoreRepository(api));
    await provider.load();

    provider.resetForSession();

    expect(provider.products, isEmpty);
    expect(provider.entitlement, isNull);
  });
}
