import 'package:flutter/material.dart';

import '../storage/secure_storage.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._storage) {
    _load();
  }

  final SecureStorage _storage;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> setDark(bool enabled) async {
    _mode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _storage.saveThemeMode(enabled ? 'dark' : 'light');
  }

  Future<void> _load() async {
    final saved = await _storage.getThemeMode();
    _mode = switch (saved) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }
}
