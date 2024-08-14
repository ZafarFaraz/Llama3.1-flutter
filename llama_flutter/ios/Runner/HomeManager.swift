import Foundation
import HomeKit

class HomeManager: NSObject, HMHomeManagerDelegate {
    private let homeManager = HMHomeManager()
    private var accessoriesCompletion: (([[String: String]]) -> Void)?

    override init() {
        super.init()
        homeManager.delegate = self
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        // This method is called when the HomeKit data has been loaded
        if let completion = accessoriesCompletion {
            fetchAccessories(completion: completion)
        }
    }

    func fetchAccessories(completion: @escaping ([[String: String]]) -> Void) {
        // Check if homes are already available
        if homeManager.homes.isEmpty {
            print("No homes available yet, waiting for HomeKit data to load...")
            accessoriesCompletion = completion
            return
        }

        var accessoriesList: [[String: String]] = []
        for home in homeManager.homes {
            for accessory in home.accessories {
                if let room = accessory.room?.name {
                    let accessoryInfo = [
                        "name": accessory.name,
                        "room": room,
                        "home": home.name // Include the home name
                    ]
                    accessoriesList.append(accessoryInfo)
                }
            }
        }

        print("Fetched accessories: ", accessoriesList)
        completion(accessoriesList)
    }

    func toggleAccessory(name: String, room: String, completion: @escaping (Bool, Error?) -> Void) {
        for home in homeManager.homes {
            for accessory in home.accessories {
                if accessory.name == name && accessory.room?.name == room {
                    for service in accessory.services {
                        if service.serviceType == HMServiceTypeLightbulb {
                            for characteristic in service.characteristics {
                                if characteristic.characteristicType == HMCharacteristicTypePowerState {
                                    // Toggle the power state
                                    characteristic.readValue { error in
                                        if let error = error {
                                            completion(false, error)
                                        } else if let currentValue = characteristic.value as? Bool {
                                            let newValue = !currentValue
                                            characteristic.writeValue(newValue) { error in
                                                if let error = error {
                                                    completion(false, error)
                                                } else {
                                                    completion(true, nil)
                                                }
                                            }
                                        } else {
                                            completion(false, NSError(domain: "HomeManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unable to read power state"]))
                                        }
                                    }
                                    return
                                }
                            }
                        }
                    }
                }
            }
        }
        completion(false, NSError(domain: "HomeManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Accessory not found"]))
    }

    func setLightColor(name: String, room: String, hue: CGFloat, saturation: CGFloat, brightness: CGFloat, completion: @escaping (Bool, Error?) -> Void) {
        for home in homeManager.homes {
            for accessory in home.accessories {
                if accessory.name == name && accessory.room?.name == room {
                    for service in accessory.services {
                        if service.serviceType == HMServiceTypeLightbulb {
                            var hueSet = false
                            var saturationSet = false
                            var brightnessSet = false
                            var lastError: Error?

                            for characteristic in service.characteristics {
                                switch characteristic.characteristicType {
                                case HMCharacteristicTypeHue:
                                    characteristic.writeValue(hue) { error in
                                        if let error = error {
                                            lastError = error
                                        } else {
                                            hueSet = true
                                        }
                                        if hueSet && saturationSet && brightnessSet {
                                            completion(true, nil)
                                        } else if lastError != nil {
                                            completion(false, lastError)
                                        }
                                    }
                                case HMCharacteristicTypeSaturation:
                                    characteristic.writeValue(saturation) { error in
                                        if let error = error {
                                            lastError = error
                                        } else {
                                            saturationSet = true
                                        }
                                        if hueSet && saturationSet && brightnessSet {
                                            completion(true, nil)
                                        } else if lastError != nil {
                                            completion(false, lastError)
                                        }
                                    }
                                case HMCharacteristicTypeBrightness:
                                    characteristic.writeValue(brightness) { error in
                                        if let error = error {
                                            lastError = error
                                        } else {
                                            brightnessSet = true
                                        }
                                        if hueSet && saturationSet && brightnessSet {
                                            completion(true, nil)
                                        } else if lastError != nil {
                                            completion(false, lastError)
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                            return
                        }
                    }
                }
            }
        }
        completion(false, NSError(domain: "HomeManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Accessory not found"]))
    }
}
