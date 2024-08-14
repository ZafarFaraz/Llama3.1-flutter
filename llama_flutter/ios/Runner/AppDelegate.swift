import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var homeManager: HomeManager?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Initialize HomeManager and set up the method channel
    homeManager = HomeManager()
    
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let dataChannel = FlutterMethodChannel(name: "jarvis_data", binaryMessenger: controller.binaryMessenger)
      
    print("Method channel 'jarvis_data' set up successfully")
      
    dataChannel.setMethodCallHandler {[weak self] (call, result) in
      if call.method == "fetchAccessories" {
        print("fetchAccessories method called from Flutter")
        
        // Fetch accessories from HomeManager
        self?.homeManager?.fetchAccessories() { accessories in
          print("Fetched accessories: \(accessories)")
          result(accessories)
        }
      } else if call.method == "toggleAccessory" {
        if let args = call.arguments as? [String: Any],
           let name = args["name"] as? String,
           let room = args["room"] as? String {
          print("toggleAccessory called with name: \(name), room: \(room)")
          
          // Toggle the accessory state
          self?.homeManager?.toggleAccessory(name: name, room: room) { success, error in
            if success {
              result(nil)
            } else {
              result(FlutterError(code: "ERROR", message: "Error toggling accessory", details: error?.localizedDescription))
            }
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
