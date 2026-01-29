import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameSettings {
  // Common ball color for Ball Rush, Ball Track, and Catch The Ball games
  static const Color ballColor = Colors.black;
  static const String _numberOfRepetitionsKey = 'number_of_repetitions';
  static const String _soundEnabledKey = 'sound_enabled';

  static int _numberOfRepetitions = 5; // Default value
  static bool _soundEnabled = true; // Default value (sound ON by default)
  static bool _initialized = false;

  // Notifier for repetitions changes
  static final ValueNotifier<int> repetitionsNotifier = ValueNotifier<int>(5);

  // Notifier for sound enabled changes
  static final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(
    true,
  );

  // Initialize settings from shared preferences
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _numberOfRepetitions = prefs.getInt(_numberOfRepetitionsKey) ?? 5;
      _soundEnabled =
          prefs.getBool(_soundEnabledKey) ?? true; // Default to true (ON)
      _initialized = true;
      repetitionsNotifier.value = _numberOfRepetitions;
      soundEnabledNotifier.value = _soundEnabled;
    } catch (e) {
      // If initialization fails, use defaults
      _numberOfRepetitions = 5;
      _soundEnabled = true;
      _initialized = true;
      repetitionsNotifier.value = 5;
      soundEnabledNotifier.value = true;
    }
  }

  // Get number of repetitions
  static int get numberOfRepetitions => _numberOfRepetitions;

  // Set number of repetitions
  static Future<void> setNumberOfRepetitions(int repetitions) async {
    if (repetitions < 1) return; // Minimum value is 1

    _numberOfRepetitions = repetitions;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_numberOfRepetitionsKey, repetitions);
    repetitionsNotifier.value = repetitions;
  }

  // Get sound enabled status
  static bool get soundEnabled => _soundEnabled;

  // Set sound enabled status
  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
    soundEnabledNotifier.value = enabled;
  }
}
