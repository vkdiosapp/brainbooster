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
    setupVibrationChannel()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupVibrationChannel() {
    // Try to set up immediately
    if let controller = window?.rootViewController as? FlutterViewController {
      setupChannel(controller: controller)
    } else {
      // If not ready, try again after a short delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        guard let self = self,
              let controller = self.window?.rootViewController as? FlutterViewController else {
          print("AppDelegate: Window or controller still not ready after delay")
          // Try one more time after another delay
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self,
                  let controller = self.window?.rootViewController as? FlutterViewController else {
              print("AppDelegate: Failed to setup vibration channel")
              return
            }
            self.setupChannel(controller: controller)
          }
          return
        }
        self.setupChannel(controller: controller)
      }
    }
  }
  
  private func setupChannel(controller: FlutterViewController) {
    print("AppDelegate: Setting up vibration channel")
    let vibrationChannel = FlutterMethodChannel(
      name: "com.vkd.brainbooster/vibration",
      binaryMessenger: controller.binaryMessenger
    )
    
    vibrationChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      print("AppDelegate: Received method call: \(call.method)")
      if call.method == "vibrateStandard" {
        print("AppDelegate: Triggering vibration NOW")
        
        // Use the numeric value 4095 (kSystemSoundID_Vibrate) directly
        // This bypasses System Haptics toggle
        let vibrationID: SystemSoundID = 4095
        AudioServicesPlaySystemSound(vibrationID)
        print("AppDelegate: Vibration called with ID 4095")
        
        // Also call on main thread to ensure it executes
        DispatchQueue.main.async {
          AudioServicesPlaySystemSound(vibrationID)
          print("AppDelegate: Vibration also called on main thread")
        }
        
        result(nil)
      } else if call.method == "vibrateAlert" {
        print("AppDelegate: Triggering alert vibration")
        AudioServicesPlaySystemSound(1519)
        result(nil)
      } else {
        print("AppDelegate: Unknown method: \(call.method)")
        result(FlutterMethodNotImplemented)
      }
    }
    print("AppDelegate: Vibration channel setup complete")
  }
}
