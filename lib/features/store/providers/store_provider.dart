import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';

class StoreProvider extends ChangeNotifier {
  StoreProvider({required StoreRepository repository})
    : _repository = repository;

  final StoreRepository _repository;
  List<StoreProduct> _products = const [];
  OfferingEntitlement? _entitlement;
  List<BillingReceipt> _receipts = const [];
  bool _loading = false;
  bool _checkoutProcessing = false;
  String? _error;
  int _sessionScope = 0;
  int _requestVersion = 0;

  List<StoreProduct> get products => _products;
  OfferingEntitlement? get entitlement => _entitlement;
  List<BillingReceipt> get receipts => _receipts;
  bool get loading => _loading;
  bool get checkoutProcessing => _checkoutProcessing;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_loading && !force) return;
    final scope = _sessionScope;
    final request = ++_requestVersion;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.getProducts(),
        _repository.getOfferingEntitlement(),
        _repository.getBillingReceipts(),
      ]);
      if (scope != _sessionScope || request != _requestVersion) return;
      _products = results[0] as List<StoreProduct>;
      _entitlement = results[1] as OfferingEntitlement;
      _receipts = results[2] as List<BillingReceipt>;
    } on ApiRequestException catch (error) {
      if (scope == _sessionScope && request == _requestVersion) {
        _error = error.message;
      }
    } on FormatException catch (error) {
      if (scope == _sessionScope && request == _requestVersion) {
        _error = error.message;
      }
    } catch (_) {
      if (scope == _sessionScope && request == _requestVersion) {
        _error = 'Plans and posting credits are temporarily unavailable.';
      }
    } finally {
      if (scope == _sessionScope && request == _requestVersion) {
        _loading = false;
        notifyListeners();
      }
    }
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
    _checkoutProcessing = true;
    _error = null;
    notifyListeners();
    try {
      final receipt = await _repository.processCheckout(
        productId: productId,
        cardNumber: cardNumber,
        cardBrand: cardBrand,
        expMonth: expMonth,
        expYear: expYear,
        cvc: cvc,
        zipCode: zipCode,
      );
      await load(force: true);
      return receipt;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _checkoutProcessing = false;
      notifyListeners();
    }
  }

  void resetForSession() {
    _sessionScope++;
    _requestVersion++;
    _products = const [];
    _entitlement = null;
    _receipts = const [];
    _loading = false;
    _checkoutProcessing = false;
    _error = null;
    notifyListeners();
  }
}
