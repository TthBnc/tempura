import Foundation

enum TemperatureHistoryWindow: Int, CaseIterable {
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    private static let defaultsKey = "temperatureHistoryWindow"

    static var current: TemperatureHistoryWindow {
        get {
            let rawValue = UserDefaults.standard.integer(forKey: defaultsKey)
            return TemperatureHistoryWindow(rawValue: rawValue) ?? .oneMinute
        }
        set {
            guard newValue != current else {
                return
            }

            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            NotificationCenter.default.post(name: .temperatureHistoryWindowDidChange, object: newValue)
        }
    }

    var retention: TimeInterval {
        TimeInterval(rawValue)
    }

    var displayName: String {
        switch self {
        case .oneMinute:
            return "60s"
        case .fiveMinutes:
            return "5m"
        case .fifteenMinutes:
            return "15m"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .oneMinute:
            return "Last 60 seconds"
        case .fiveMinutes:
            return "Last 5 minutes"
        case .fifteenMinutes:
            return "Last 15 minutes"
        }
    }
}

extension Notification.Name {
    static let temperatureHistoryWindowDidChange = Notification.Name("TemperatureHistoryWindowDidChange")
}
