import Foundation

enum MenuBarMemoryLabelStyle: String, CaseIterable {
    case full
    case slim
    case compact

    var displayName: String {
        switch self {
        case .full:
            return "Full"
        case .slim:
            return "Slim"
        case .compact:
            return "Compact"
        }
    }

    func memoryTitle(percent: String) -> String {
        switch self {
        case .full:
            return "RAM \(percent)"
        case .slim:
            return "M\(percent)"
        case .compact:
            return percent
        }
    }

    func swapTitle(percent: String) -> String {
        switch self {
        case .full:
            return "SWAP \(percent)"
        case .slim:
            return "S\(percent)"
        case .compact:
            return percent
        }
    }
}

struct MenuBarDisplaySettings: Equatable {
    var showsTemperature: Bool
    var showsMemory: Bool
    var showsSwap: Bool
    var memoryLabelStyle: MenuBarMemoryLabelStyle

    private static let showsTemperatureKey = "menuBarShowsTemperature"
    private static let showsMemoryKey = "menuBarShowsMemory"
    private static let showsSwapKey = "menuBarShowsSwap"
    private static let memoryLabelStyleKey = "menuBarMemoryLabelStyle"

    static var current: MenuBarDisplaySettings {
        get {
            MenuBarDisplaySettings(
                showsTemperature: boolValue(forKey: showsTemperatureKey, defaultValue: true),
                showsMemory: boolValue(forKey: showsMemoryKey, defaultValue: false),
                showsSwap: boolValue(forKey: showsSwapKey, defaultValue: false),
                memoryLabelStyle: memoryLabelStyle
            )
        }
        set {
            guard newValue != current else {
                return
            }

            UserDefaults.standard.set(newValue.showsTemperature, forKey: showsTemperatureKey)
            UserDefaults.standard.set(newValue.showsMemory, forKey: showsMemoryKey)
            UserDefaults.standard.set(newValue.showsSwap, forKey: showsSwapKey)
            UserDefaults.standard.set(newValue.memoryLabelStyle.rawValue, forKey: memoryLabelStyleKey)
            NotificationCenter.default.post(name: .menuBarDisplaySettingsDidChange, object: newValue)
        }
    }

    private static var memoryLabelStyle: MenuBarMemoryLabelStyle {
        let rawValue = UserDefaults.standard.string(forKey: memoryLabelStyleKey)
        return rawValue.flatMap(MenuBarMemoryLabelStyle.init(rawValue:)) ?? .slim
    }

    private static func boolValue(forKey key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }

        return UserDefaults.standard.bool(forKey: key)
    }
}

extension Notification.Name {
    static let menuBarDisplaySettingsDidChange = Notification.Name("MenuBarDisplaySettingsDidChange")
}
