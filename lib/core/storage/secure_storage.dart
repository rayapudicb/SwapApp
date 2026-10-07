import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  // These keys belong to the removed token implementation. They are deleted
  // during startup and are never migrated into the passwordless session store.
  static const String _legacyAccessToken = 'access_token';
  static const String _legacyRefreshToken = 'refresh_token';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyHasSeenWelcome = 'has_seen_welcome';
  static const String _keyPreferredLocale = 'preferred_locale';

  Future<void> clearLegacyAuthTokens() async {
    await _storage.delete(key: _legacyAccessToken);
    await _storage.delete(key: _legacyRefreshToken);
  }

  Future<void> saveThemeMode(String value) async {
    await _storage.write(key: _keyThemeMode, value: value);
  }

  Future<String?> getThemeMode() => _storage.read(key: _keyThemeMode);

  Future<void> saveHasSeenWelcome(bool value) async {
    await _storage.write(key: _keyHasSeenWelcome, value: value.toString());
  }

  Future<bool> getHasSeenWelcome() async {
    final value = await _storage.read(key: _keyHasSeenWelcome);
    return value == 'true';
  }

  Future<void> savePreferredLocale(String value) async {
    await _storage.write(key: _keyPreferredLocale, value: value);
  }

  Future<String?> getPreferredLocale() =>
      _storage.read(key: _keyPreferredLocale);

  Future<void> clearPreferredLocale() =>
      _storage.delete(key: _keyPreferredLocale);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);
}
