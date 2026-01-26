import Flutter
import UIKit
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up vibration method channel
    if let controller = window?.rootViewController as? FlutterViewController {
      let vibrationChannel = FlutterMethodChannel(
        name: "com.vkd.brainbooster/vibration",
        binaryMessenger: controller.binaryMessenger
      )
      
      vibrationChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "vibrateStandard" {
          // Standard vibration that bypasses System Haptics toggle
          AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
          result(nil)
        } else if call.method == "vibrateAlert" {
          // Short "peek" vibration (1519)
          AudioServicesPlaySystemSound(1519)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
