import 'package:flutter/services.dart';

class VibrationService {
  // Use the same name as defined in AppDelegate
  static const _channel = MethodChannel('com.vkd.brainbooster/vibration');

  /// Triggers the standard vibration (bypasses System Haptics toggle)
  static Future<void> playStandardVibration() async {
    try {
      print("VibrationService: Calling vibrateStandard");
      await _channel.invokeMethod('vibrateStandard');
      print("VibrationService: vibrateStandard called successfully");
    } on PlatformException catch (e) {
      print("VibrationService: Failed to vibrate: ${e.message}");
      print("VibrationService: Error code: ${e.code}, details: ${e.details}");
    } catch (e) {
      print("VibrationService: Unexpected error: $e");
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
