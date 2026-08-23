import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_color.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const _accentKey = 'accentTheme';
  static const _modeKey = 'themeMode';

  AppAccentColor accent = AppAccentColor.blue;
  ThemeMode mode = ThemeMode.light;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    accent = AppAccentColor.values.firstWhere(
      (value) => value.name == preferences.getString(_accentKey),
      orElse: () => AppAccentColor.blue,
    );
    final storedMode = preferences.getString(_modeKey);
    mode = storedMode == ThemeMode.dark.name ? ThemeMode.dark : ThemeMode.light;
    if (storedMode != mode.name) {
      await preferences.setString(_modeKey, mode.name);
    }
  }

  Future<void> setAccent(AppAccentColor value) async {
    if (accent == value) return;
    accent = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_accentKey, value.name);
  }

  Future<void> setMode(ThemeMode value) async {
    final normalized = value == ThemeMode.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    if (mode == normalized) return;
    mode = normalized;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_modeKey, normalized.name);
  }
}
