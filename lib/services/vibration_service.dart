import 'dart:async';
import 'package:flutter/services.dart';

class VibrationService {
  static Timer? _vibrationTimer;

  /// Triggers vibration for 1 second using Flutter's built-in HapticFeedback
  static Future<void> playStandardVibration() async {
    // Cancel any existing vibration timer
    _vibrationTimer?.cancel();

    // Start time
    final startTime = DateTime.now();
    const duration = Duration(seconds: 1);
    const interval = Duration(milliseconds: 50); // Vibrate every 50ms for continuous feel

    // Trigger initial vibration
    HapticFeedback.mediumImpact();

    // Continue vibrating for 1 second
    _vibrationTimer = Timer.periodic(interval, (timer) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= duration) {
        timer.cancel();
        _vibrationTimer = null;
      } else {
        HapticFeedback.mediumImpact();
      }
    });
  }

  /// Triggers a light vibration
  static Future<void> playAlertVibration() async {
    HapticFeedback.lightImpact();
  }

  /// Cancels any ongoing vibration
  static void cancel() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }
}
