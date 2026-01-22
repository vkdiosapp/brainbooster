import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameSettings {
  static const String _numberOfRepetitionsKey = 'number_of_repetitions';
  
  static int _numberOfRepetitions = 5; // Default value
  static bool _initialized = false;
  
  // Notifier for repetitions changes
  static final ValueNotifier<int> repetitionsNotifier = ValueNotifier<int>(5);

  // Initialize settings from shared preferences
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _numberOfRepetitions = prefs.getInt(_numberOfRepetitionsKey) ?? 5;
      _initialized = true;
      repetitionsNotifier.value = _numberOfRepetitions;
    } catch (e) {
      // If initialization fails, use defaults
      _numberOfRepetitions = 5;
      _initialized = true;
      repetitionsNotifier.value = 5;
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
}
