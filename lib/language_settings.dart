import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSettings {
  static const String _languageCodeKey = 'selected_language_code';
  static const String _isFirstLaunchKey = 'is_first_launch';
  
  static String _selectedLanguageCode = 'en'; // Default to English
  static bool _isFirstLaunch = true;
  static bool _initialized = false;
  
  // Notifier for language changes
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(const Locale('en'));

  // Supported languages
  static const Map<String, Map<String, String>> supportedLanguages = {
    'en': {'name': 'English', 'native': 'English'},
    'af': {'name': 'Afrikaans', 'native': 'Afrikaans'},
    'ar': {'name': 'Arabic', 'native': 'العربية'},
    'fil': {'name': 'Filipino', 'native': 'Filipino'},
    'fr': {'name': 'French', 'native': 'Français'},
    'de': {'name': 'German', 'native': 'Deutsch'},
    'hi': {'name': 'Hindi', 'native': 'हिन्दी'},
    'id': {'name': 'Indonesian', 'native': 'Bahasa Indonesia'},
    'it': {'name': 'Italian', 'native': 'Italiano'},
    'ja': {'name': 'Japanese', 'native': '日本語'},
    'ko': {'name': 'Korean', 'native': '한국어'},
    'pl': {'name': 'Polish', 'native': 'polski'},
    'pt': {'name': 'Portuguese', 'native': 'Português'},
    'ru': {'name': 'Russian', 'native': 'Русские'},
    'es': {'name': 'Spanish', 'native': 'español'},
    'th': {'name': 'Thai', 'native': 'ไทย'},
    'tr': {'name': 'Turkish', 'native': 'Türkçe'},
    'uk': {'name': 'Ukrainian', 'native': 'Українська'},
    'vi': {'name': 'Vietnamese', 'native': 'Tiếng Việt'},
  };

  // Initialize settings from shared preferences
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedLanguageCode = prefs.getString(_languageCodeKey) ?? 'en';
      _isFirstLaunch = prefs.getBool(_isFirstLaunchKey) ?? true;
      _initialized = true;
      // Update notifier with current locale
      _updateLocaleNotifier();
    } catch (e) {
      // If initialization fails, use defaults
      _selectedLanguageCode = 'en';
      _isFirstLaunch = true;
      _initialized = true;
      _updateLocaleNotifier();
    }
  }
  
  // Update locale notifier
  static void _updateLocaleNotifier() {
    if (_selectedLanguageCode == 'fil') {
      localeNotifier.value = const Locale('fil');
    } else {
      localeNotifier.value = Locale(_selectedLanguageCode);
    }
  }

  // Get selected language code
  static String get selectedLanguageCode => _selectedLanguageCode;

  // Get is first launch
  static bool get isFirstLaunch => _isFirstLaunch;

  // Set language
  static Future<void> setLanguage(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      return; // Invalid language code
    }
    
    _selectedLanguageCode = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, languageCode);
    // Update notifier to trigger app rebuild
    _updateLocaleNotifier();
  }

  // Mark first launch as complete
  static Future<void> markFirstLaunchComplete() async {
    _isFirstLaunch = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  // Get language name
  static String getLanguageName(String code) {
    return supportedLanguages[code]?['name'] ?? code;
  }

  // Get native language name
  static String getNativeLanguageName(String code) {
    return supportedLanguages[code]?['native'] ?? code;
  }

  // Get all supported languages
  static List<String> getSupportedLanguageCodes() {
    return supportedLanguages.keys.toList()..sort();
  }
}
