import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scorvoai/theme/app_theme.dart';

/// Globally-shared theme controller. Listen via [ValueListenableBuilder]
/// in MaterialApp; toggle via [ThemeController.toggle] / [.setMode].
class ThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);
  static const _key = 'theme_mode';

  /// Load persisted preference on app startup.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    final m = switch (s) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    AppColors.setDark(m == ThemeMode.dark);
    mode.value = m;
  }

  static Future<void> setMode(ThemeMode m, [BuildContext? context]) async {
    AppColors.setDark(
      m == ThemeMode.dark ||
          (m == ThemeMode.system &&
              context != null &&
              MediaQuery.platformBrightnessOf(context) == Brightness.dark),
    );
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, m.name);
  }

  static Future<void> toggle() async {
    final next = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    AppColors.setDark(next == ThemeMode.dark);
    mode.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next.name);
  }
}
