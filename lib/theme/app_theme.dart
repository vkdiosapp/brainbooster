import 'package:flutter/material.dart';

/// Centralized theme class for managing all app colors
/// Provides theme-aware colors for both light and dark themes
class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  // ==================== Light Theme Colors ====================

  static const Color _lightCardColor = Colors.white;
  static const Color _lightBorderColor = Color(0xFFE2E8F0);
  static const Color _lightBackgroundColor = Color(0xFFF8FAFC);
  static const Color _lightTextPrimary = Color(0xFF0F172A);
  static const Color _lightTextSecondary = Color(0xFF64748B);
  static const Color _lightTextTertiary = Color(0xFF94A3B8);
  static const Color _lightIconColor = Color(0xFF475569);
  static const Color _lightIconSecondary = Color(0xFF94A3B8);
  static const Color _lightButtonBackground = Color(0xFFF1F5F9);

  // ==================== Dark Theme Colors ====================

  static const Color _darkCardColor = Color(0xFF1E293B);
  static const Color _darkBorderColor = Color(0xFF334155);
  static const Color _darkBackgroundColor = Color(0xFF0F172A);
  static const Color _darkTextPrimary = Color(0xFFF1F5F9);
  static const Color _darkTextSecondary = Color(0xFF94A3B8);
  static const Color _darkTextTertiary = Color(0xFF64748B);
  static const Color _darkIconColor = Color(0xFF94A3B8);
  static const Color _darkIconSecondary = Color(0xFF64748B);
  static const Color _darkButtonBackground = Color(0xFF334155);

  // ==================== Common Colors (Same for both themes) ====================

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF0EA5E9);

  // ==================== Theme-Aware Color Getters ====================

  /// Get card color based on theme brightness
  static Color cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkCardColor
        : _lightCardColor;
  }

  /// Get border color based on theme brightness
  static Color borderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkBorderColor
        : _lightBorderColor;
  }

  /// Get background color based on theme brightness
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkBackgroundColor
        : _lightBackgroundColor;
  }

  /// Get primary text color based on theme brightness
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkTextPrimary
        : _lightTextPrimary;
  }

  /// Get secondary text color based on theme brightness
  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkTextSecondary
        : _lightTextSecondary;
  }

  /// Get tertiary text color based on theme brightness
  static Color textTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkTextTertiary
        : _lightTextTertiary;
  }

  /// Get icon color based on theme brightness
  static Color iconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkIconColor
        : _lightIconColor;
  }

  /// Get secondary icon color based on theme brightness
  static Color iconSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkIconSecondary
        : _lightIconSecondary;
  }

  /// Get button background color based on theme brightness
  static Color buttonBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? _darkButtonBackground
        : _lightButtonBackground;
  }

  /// Get shadow color (always black with opacity)
  static Color shadowColor({double opacity = 0.05}) {
    return Colors.black.withOpacity(opacity);
  }

  /// Get standard box shadow for cards/tiles
  static List<BoxShadow> cardShadow({double opacity = 0.05}) {
    return [
      BoxShadow(
        color: shadowColor(opacity: opacity),
        offset: const Offset(0, 4),
        blurRadius: 0,
      ),
    ];
  }

  /// Get primary color with opacity
  static Color primaryWithOpacity(double opacity) {
    return primaryColor.withOpacity(opacity);
  }

  /// Check if current theme is dark
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Get gradient background colors based on theme
  static List<Color> gradientColors(BuildContext context) {
    if (isDark(context)) {
      return const [
        Color(0xFF1E293B),
        Color(0xFF0F172A),
        Color(0xFF1E293B),
        Color(0xFF334155),
      ];
    } else {
      return const [
        Color(0xFFE2E8F0),
        Color(0xFFF8FAFC),
        Color(0xFFDBEAFE),
        Color(0xFFFCE7F3),
      ];
    }
  }
}
