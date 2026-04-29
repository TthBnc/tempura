import Foundation
import TempuraCore

enum TemperatureSourcePreference {
    private static let defaultsKey = "temperatureSourceMode"

    static var current: TemperatureSourceMode {
        get {
            let rawValue = UserDefaults.standard.string(forKey: defaultsKey)
            return rawValue.flatMap(TemperatureSourceMode.init(rawValue:)) ?? .automatic
        }
        set {
            guard newValue != current else {
                return
            }

            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            NotificationCenter.default.post(name: .temperatureSourceModeDidChange, object: newValue)
        }
    }
}

extension Notification.Name {
    static let temperatureSourceModeDidChange = Notification.Name("TemperatureSourceModeDidChange")
}
