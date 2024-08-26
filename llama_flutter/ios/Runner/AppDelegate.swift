import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var homeManager: HomeManager?
  private var eventManager: EventManager?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Initialize HomeManager and EventManager
    homeManager = HomeManager()
    eventManager = EventManager()
    
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let dataChannel = FlutterMethodChannel(name: "jarvis_data", binaryMessenger: controller.binaryMessenger)
      
    print("Method channel 'jarvis_data' set up successfully")
      
    dataChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let strongSelf = self else {
        result(FlutterError(code: "ERROR", message: "Self is nil", details: nil))
        return
      }
      
      switch call.method {
      case "fetchAccessories":
        strongSelf.homeManager?.fetchAccessories() { accessories in
          result(accessories)
        }
      
      case "getAccessoryState":
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
      
      case "toggleAccessory":
        if let args = call.arguments as? [String: Any],
           let name = args["name"] as? String,
           let room = args["room"] as? String {
          strongSelf.homeManager?.toggleAccessory(name: name, room: room) { success, error in
            if success {
              result(nil)
            } else {
              result(FlutterError(code: "ERROR", message: "Error toggling accessory", details: error?.localizedDescription))
            }
          }
        } else {
          result(FlutterError(code: "ERROR", message: "Invalid arguments", details: nil))
        }

      case "loadReminders":
        // No arguments required for loadReminders
        strongSelf.eventManager?.loadReminders(result: result)


      case "loadUpcomingEvents":
        // No arguments required for loadReminders
        strongSelf.eventManager?.loadUpcomingEvents(result: result)
      
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
