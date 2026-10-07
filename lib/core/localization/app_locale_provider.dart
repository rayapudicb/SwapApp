import 'package:flutter/material.dart';

import '../bootstrap/domain/platform_bootstrap.dart';
import '../storage/secure_storage.dart';
import '../../l10n/generated/app_localizations.dart';

enum LocalePreferenceFailure { restore, save, unavailable }

class AppLocaleProvider extends ChangeNotifier {
  AppLocaleProvider(this._storage);

  static const fallbackLocale = Locale('en', 'US');
  static const fallbackSupportedLocales = <Locale>[fallbackLocale];

  final SecureStorage _storage;

  Locale? _locale;
  bool _isLoading = true;
  String? _errorMessage;
  LocalePreferenceFailure? _failure;

  Locale? get locale => _locale;
  bool get followsSystem => _locale == null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LocalePreferenceFailure? get failure => _failure;

  Future<void> initialize({bool force = false}) async {
    if (!_isLoading && !force) return;
    if (force) {
      _isLoading = true;
      _errorMessage = null;
      _failure = null;
      notifyListeners();
    }
    try {
      final saved = await _storage.getPreferredLocale();
      final restored = saved == null ? null : parseLanguageTag(saved);
      _locale = restored != null && _isCompiledLanguage(restored.languageCode)
          ? restored
          : null;
      if (saved != null && _locale == null) {
        await _storage.clearPreferredLocale();
      }
    } catch (_) {
      _errorMessage = 'Language preference could not be restored.';
      _failure = LocalePreferenceFailure.restore;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> useSystemLocale() async {
    if (_locale == null && !_isLoading) return;
    final previous = _locale;
    _isLoading = true;
    _errorMessage = null;
    _failure = null;
    notifyListeners();
    try {
      await _storage.clearPreferredLocale();
      _locale = null;
    } catch (_) {
      _locale = previous;
      _errorMessage = 'Language preference could not be saved.';
      _failure = LocalePreferenceFailure.save;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectLocale(Locale locale) async {
    if (!_isCompiledLanguage(locale.languageCode)) {
      _errorMessage = 'This language is not available in this app version.';
      _failure = LocalePreferenceFailure.unavailable;
      _isLoading = false;
      notifyListeners();
      return;
    }
    if (_locale == locale && !_isLoading) return;
    final previous = _locale;
    _isLoading = true;
    _errorMessage = null;
    _failure = null;
    notifyListeners();
    try {
      await _storage.savePreferredLocale(toLanguageTag(locale));
      _locale = locale;
    } catch (_) {
      _locale = previous;
      _errorMessage = 'Language preference could not be saved.';
      _failure = LocalePreferenceFailure.save;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _failure = null;
    notifyListeners();
  }

  Future<void> reconcileSupportedLocales(Iterable<Locale> supported) async {
    final selected = _locale;
    if (selected == null || effectiveLocale(selected, supported) != null) {
      return;
    }
    await useSystemLocale();
  }

  static List<Locale> supportedLocalesFrom(
    Iterable<SupportedLocale>? configured,
  ) {
    final locales = <Locale>[];
    for (final item in configured ?? const <SupportedLocale>[]) {
      final locale = parseLanguageTag(item.code);
      if (locale != null &&
          _isCompiledLanguage(locale.languageCode) &&
          !locales.contains(locale)) {
        locales.add(locale);
      }
    }
    return locales.isEmpty
        ? fallbackSupportedLocales
        : List.unmodifiable(locales);
  }

  static Locale? effectiveLocale(Locale? selected, Iterable<Locale> supported) {
    if (selected == null) return null;
    for (final locale in supported) {
      if (_sameLocale(selected, locale) ||
          (selected.languageCode.toLowerCase() ==
                  locale.languageCode.toLowerCase() &&
              (locale.countryCode == null || locale.countryCode!.isEmpty))) {
        return selected;
      }
    }
    return null;
  }

  static Locale? parseLanguageTag(String value) {
    final normalized = value.trim().replaceAll('_', '-');
    if (normalized.isEmpty) return null;
    final parts = normalized.split('-');
    final language = parts.first.toLowerCase();
    if (!RegExp(r'^[a-z]{2,3}$').hasMatch(language)) return null;

    String? script;
    String? country;
    for (final part in parts.skip(1)) {
      if (script == null && RegExp(r'^[A-Za-z]{4}$').hasMatch(part)) {
        script = '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      } else if (country == null &&
          RegExp(r'^([A-Za-z]{2}|[0-9]{3})$').hasMatch(part)) {
        country = part.toUpperCase();
      } else {
        return null;
      }
    }

    return Locale.fromSubtags(
      languageCode: language,
      scriptCode: script,
      countryCode: country,
    );
  }

  static String toLanguageTag(Locale locale) {
    final parts = <String>[locale.languageCode.toLowerCase()];
    final script = locale.scriptCode;
    final country = locale.countryCode;
    if (script != null && script.isNotEmpty) parts.add(script);
    if (country != null && country.isNotEmpty) parts.add(country.toUpperCase());
    return parts.join('-');
  }

  static bool _sameLocale(Locale left, Locale right) =>
      left.languageCode.toLowerCase() == right.languageCode.toLowerCase() &&
      (left.scriptCode ?? '').toLowerCase() ==
          (right.scriptCode ?? '').toLowerCase() &&
      (left.countryCode ?? '').toUpperCase() ==
          (right.countryCode ?? '').toUpperCase();

  static bool _isCompiledLanguage(String languageCode) =>
      AppLocalizations.supportedLocales.any(
        (locale) =>
            locale.languageCode.toLowerCase() == languageCode.toLowerCase(),
      );
}
