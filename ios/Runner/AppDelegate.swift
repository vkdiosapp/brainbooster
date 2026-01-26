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
    
    // Set up vibration method channel after window is created
    if let controller = window?.rootViewController as? FlutterViewController {
      let vibrationChannel = FlutterMethodChannel(
        name: "com.vkd.brainbooster/vibration",
        binaryMessenger: controller.binaryMessenger
      )
      
      vibrationChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "vibrate" {
          if let args = call.arguments as? [String: Any],
             let duration = args["duration"] as? Int {
            self?.startContinuousVibration(duration: duration)
            result(true)
          } else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Duration is required", details: nil))
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private var vibrationTimer: Timer?
  
  private func startContinuousVibration(duration: Int) {
    // Stop any existing vibration
    vibrationTimer?.invalidate()
    
    // Calculate number of vibrations needed (vibrate every 100ms)
    let vibrationCount = duration / 100
    var currentCount = 0
    
    // Use AudioServicesPlaySystemSound which works independently of haptic settings
    vibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
      // Play system sound vibration (kSystemSoundID_Vibrate = 4095)
      // This works even when System Haptics is OFF
      AudioServicesPlaySystemSound(4095)
      
      currentCount += 1
      if currentCount >= vibrationCount {
        timer.invalidate()
        self?.vibrationTimer = nil
      }
    }
  }
}
