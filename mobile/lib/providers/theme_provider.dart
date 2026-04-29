import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'light') {
      _mode = ThemeMode.light;
    } else {
      _mode = ThemeMode.dark; // mặc định dark
    }
    notifyListeners();
  }

  Future<void> setDark() async {
    _mode = ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'dark');
    notifyListeners();
  }

  Future<void> setLight() async {
    _mode = ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'light');
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_mode == ThemeMode.dark) {
      await setLight();
    } else {
      await setDark();
    }
  }
}
