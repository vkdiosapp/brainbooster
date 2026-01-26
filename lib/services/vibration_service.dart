import 'package:flutter/services.dart';

class VibrationService {
  // Use the same name as defined in AppDelegate
  static const _channel = MethodChannel('com.vkd.brainbooster/vibration');

  /// Triggers the standard vibration (bypasses System Haptics toggle)
  static Future<void> playStandardVibration() async {
    try {
      await _channel.invokeMethod('vibrateStandard');
    } on PlatformException catch (e) {
      print("Failed to vibrate: ${e.message}");
    }
  }

  /// Triggers the short "peek" vibration
  static Future<void> playAlertVibration() async {
    try {
      await _channel.invokeMethod('vibrateAlert');
    } on PlatformException catch (e) {
      print("Failed to vibrate: ${e.message}");
    }
  }
}
