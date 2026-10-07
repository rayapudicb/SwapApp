import 'package:flutter/foundation.dart';
import '../../storage/secure_storage.dart';
import '../data/bootstrap_repository.dart';
import '../domain/platform_bootstrap.dart';

class BootstrapProvider extends ChangeNotifier {
  BootstrapProvider({
    required BootstrapGateway gateway,
    required SecureStorage storage,
  }) : _gateway = gateway,
       _storage = storage;

  final BootstrapGateway _gateway;
  final SecureStorage _storage;

  PlatformBootstrap? _bootstrap;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  String _currentCountryCode = 'US';

  PlatformBootstrap? get bootstrap => _bootstrap;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get hasVerifiedBootstrap => _bootstrap != null && _errorMessage == null;
  String? get errorMessage => _errorMessage;
  String get currentCountryCode => _currentCountryCode;

  bool get isMaintenanceActive => _bootstrap?.maintenanceMode.enabled ?? false;
  String? get maintenanceReason => _bootstrap?.maintenanceMode.reason;

  ActiveCountry? get activeCountryConfig =>
      _bootstrap?.countryForCode(_currentCountryCode);

  bool hasPublishedLegalDocument(String slug) =>
      hasVerifiedBootstrap && _bootstrap?.legalDocumentForSlug(slug) != null;

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final storedCountry = await _storage.read('user_selected_country');
      if (storedCountry != null && storedCountry.isNotEmpty) {
        _currentCountryCode = storedCountry.toUpperCase();
      }

      _bootstrap = await _gateway.fetchBootstrap();
    } on BootstrapException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Bootstrap error: $e';
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setCountryCode(String code) async {
    final upper = code.trim().toUpperCase();
    if (_currentCountryCode == upper) return;
    _currentCountryCode = upper;
    await _storage.write('user_selected_country', upper);
    notifyListeners();
  }

  Future<LegalDocument> getLegalDocument(String slug, {String? locale}) {
    return _gateway.fetchLegalDocument(
      slug,
      locale: locale,
      countryCode: _currentCountryCode,
    );
  }
}
