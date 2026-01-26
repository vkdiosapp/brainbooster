import 'package:flutter/services.dart';

class VibrationService {
  /// Triggers a single vibration using Flutter's built-in HapticFeedback
  static Future<void> playStandardVibration() async {
    HapticFeedback.mediumImpact();
  }

  /// Triggers a light vibration
  static Future<void> playAlertVibration() async {
    HapticFeedback.lightImpact();
  }
}
