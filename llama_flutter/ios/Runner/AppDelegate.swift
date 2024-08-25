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
      guard let strongSelf = self else {
        result(FlutterError(code: "ERROR", message: "Self is nil", details: nil))
        return
      }
      if call.method == "fetchAccessories" {
        // Fetch accessories from HomeManager
        strongSelf.homeManager?.fetchAccessories() { accessories in
          result(accessories)
        }
      } else if call.method == "getAccessoryState" {
          if let args = call.arguments as? [String: Any],
             let name = args["name"] as? String,
             let room = args["room"] as? String {
            strongSelf.homeManager?.getAccessoryState(name: name, room: room) { state, error in
              if let state = state {
                result(state)
              } else {
                result(FlutterError(code: "ERROR", message: "Error fetching state", details: error?.localizedDescription))
              }
            }
          } else {
              result(FlutterError(code: "ERROR", message: "Invalid arguments", details: nil))
          }
        } else if call.method == "toggleAccessory" {
            print("method was called")
            if let args = call.arguments as? [String: Any],
               let name = args["name"] as? String,
               let room = args["room"] as? String {
//              // Ensure case-insensitive and trimmed matching
//              let lowercasedName = name.lowercased().trimmingCharacters(in: .whitespaces)
//              let lowercasedRoom = room.lowercased().trimmingCharacters(in: .whitespaces)
              
              strongSelf.homeManager?.toggleAccessory(name: name, room: room) { success, error in
                  
                   print(name, room)
                if success {
                  result(nil)
                } else {
                  result(FlutterError(code: "ERROR", message: "Error toggling accessory", details: error?.localizedDescription))
                }
              }
            } else {
                result(FlutterError(code: "ERROR", message: "Invalid arguments", details: nil))
            }
          } else {
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
