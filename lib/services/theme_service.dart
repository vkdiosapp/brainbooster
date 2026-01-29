import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeModeKey = 'theme_mode';

  static ThemeMode _themeMode = ThemeMode.light; // Default to light
  static bool _initialized = false;

  // Notifier for theme changes
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  // Initialize theme from shared preferences
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeModeKey);

      if (savedTheme != null) {
        switch (savedTheme) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
            _themeMode = ThemeMode.system;
            break;
          default:
            _themeMode = ThemeMode.light;
        }
      }

      _initialized = true;
      themeModeNotifier.value = _themeMode;
    } catch (e) {
      // If initialization fails, use defaults
      _themeMode = ThemeMode.light;
      _initialized = true;
      themeModeNotifier.value = ThemeMode.light;
    }
  }

  // Get current theme mode
  static ThemeMode get themeMode => _themeMode;

  // Set theme mode
  static Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();

    String themeString;
    switch (mode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }

    await prefs.setString(_themeModeKey, themeString);
    themeModeNotifier.value = mode;
  }

  // Toggle between light and dark (ignoring system mode)
  static Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await setThemeMode(newMode);
  }

  // Check if dark mode is currently active
  static bool isDarkMode(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark;
  }
}
