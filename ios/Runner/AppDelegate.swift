import Flutter
import UIKit
import CoreHaptics
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var hapticEngine: CHHapticEngine?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize haptic engine
    createHapticEngine()
    
    // Set up vibration method channel after window is created
    if let controller = window?.rootViewController as? FlutterViewController {
      let vibrationChannel = FlutterMethodChannel(
        name: "com.vkd.brainbooster/vibration",
        binaryMessenger: controller.binaryMessenger
      )
      
      vibrationChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "vibrate" {
          self?.startContinuousVibration()
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func createHapticEngine() {
    do {
      hapticEngine = try CHHapticEngine()
      
      hapticEngine?.stoppedHandler = { [weak self] reason in
        print("Haptic engine stopped: \(reason)")
        self?.hapticEngine = nil
      }
      
      hapticEngine?.resetHandler = { [weak self] in
        print("Haptic engine reset")
        self?.createHapticEngine()
      }
      
      try hapticEngine?.start()
    } catch {
      print("Failed to create haptic engine: \(error)")
    }
  }
  
  private func startContinuousVibration() {
    // Ensure haptic engine exists and is started
    if hapticEngine == nil {
      createHapticEngine()
    }
    
    guard let engine = hapticEngine else {
      // If haptic engine is not available, fallback to system vibration
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
      return
    }
    
    do {
      // Ensure engine is started
      try engine.start()
      
      // Create a continuous haptic event for 2 seconds
      let hapticEvent = CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        ],
        relativeTime: 0,
        duration: 2.0
      )
      
      let pattern = try CHHapticPattern(events: [hapticEvent], parameters: [])
      let player = try engine.makePlayer(with: pattern)
      
      try player.start(atTime: 0)
    } catch {
      print("Failed to play haptic: \(error)")
      // Fallback to system vibration
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
  }
}
