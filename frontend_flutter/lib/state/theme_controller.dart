import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'aurora_theme_mode';

  ThemeMode _mode;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeController({ThemeMode initial = ThemeMode.dark}) : _mode = initial;

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, isDark ? 'dark' : 'light');
  }

  static Future<ThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == 'light' ? ThemeMode.light : ThemeMode.dark;
  }
}