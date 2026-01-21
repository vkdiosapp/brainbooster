import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'language_settings.dart';

/// Helper class to access AppLocalizations easily
class AppLocalizationsHelper {
  /// Get AppLocalizations from context
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations.of(context)!;
  }

  /// Get current locale from LanguageSettings
  static Locale getCurrentLocale() {
    final languageCode = LanguageSettings.selectedLanguageCode;
    // Handle special cases
    if (languageCode == 'fil') {
      return const Locale('fil');
    }
    return Locale(languageCode);
  }

  /// Get all supported locales
  static List<Locale> getSupportedLocales() {
    return LanguageSettings.getSupportedLanguageCodes()
        .map((code) {
          if (code == 'fil') {
            return const Locale('fil');
          }
          return Locale(code);
        })
        .toList();
  }
}
