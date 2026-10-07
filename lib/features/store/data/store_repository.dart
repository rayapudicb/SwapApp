import 'dart:convert';

import '../../../core/api/api_client.dart';
import '../domain/store_models.dart';

class StoreRepository {
  const StoreRepository(this._api);

  final ApiClient _api;

  Future<List<StoreProduct>> getProducts() async {
    final response = await _api.get('/v1/store/products?platform=all');
    ApiClient.requireSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('The plans response is invalid.');
    }
    return decoded
        .map((value) {
          if (value is! Map) {
            throw const FormatException('A store product is invalid.');
          }
          return StoreProduct.fromJson(Map<String, dynamic>.from(value));
        })
        .toList(growable: false);
  }

  Future<OfferingEntitlement> getOfferingEntitlement() async {
    final response = await _api.get('/v1/me/offering-entitlement');
    ApiClient.requireSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('The posting entitlement is invalid.');
    }
    return OfferingEntitlement.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<BillingReceipt> processCheckout({
    required String productId,
    required String cardNumber,
    required String cardBrand,
    required String expMonth,
    required String expYear,
    required String cvc,
    required String zipCode,
  }) async {
    final response = await _api.post(
      '/v1/me/subscriptions/checkout',
      body: {
        'productId': productId,
        'cardNumber': cardNumber,
        'cardBrand': cardBrand,
        'expMonth': expMonth,
        'expYear': expYear,
        'cvc': cvc,
        'zipCode': zipCode,
        'paymentMethodType': 'credit_card',
      },
    );
    ApiClient.requireSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['receipt'] is! Map) {
      throw const FormatException('Checkout receipt payload is invalid.');
    }
    return BillingReceipt.fromJson(Map<String, dynamic>.from(decoded['receipt'] as Map));
  }

  Future<List<BillingReceipt>> getBillingReceipts() async {
    final response = await _api.get('/v1/me/billing-receipts');
    ApiClient.requireSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('The billing receipts response is invalid.');
    }
    return decoded
        .map((value) {
          if (value is! Map) {
            throw const FormatException('A billing receipt item is invalid.');
          }
          return BillingReceipt.fromJson(Map<String, dynamic>.from(value));
        })
        .toList(growable: false);
  }
}
