import AppKit
import TempuraCore

enum TemperatureUnit: String, CaseIterable {
    case celsius
    case fahrenheit

    private static let defaultsKey = "temperatureUnit"

    static var current: TemperatureUnit {
        get {
            let rawValue = UserDefaults.standard.string(forKey: defaultsKey)
            return rawValue.flatMap(TemperatureUnit.init(rawValue:)) ?? .celsius
        }
        set {
            guard newValue != current else {
                return
            }

            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            NotificationCenter.default.post(name: .temperatureUnitDidChange, object: newValue)
        }
    }

    var displayName: String {
        switch self {
        case .celsius:
            return "Celsius"
        case .fahrenheit:
            return "Fahrenheit"
        }
    }

    var symbol: String {
        switch self {
        case .celsius:
            return "°C"
        case .fahrenheit:
            return "°F"
        }
    }

    func value(fromCelsius celsius: Double) -> Double {
        switch self {
        case .celsius:
            return celsius
        case .fahrenheit:
            return (celsius * 9 / 5) + 32
        }
    }

    func formatted(celsius: Double, includeUnit: Bool = true) -> String {
        let value = Int(value(fromCelsius: celsius).rounded())
        return includeUnit ? "\(value)\(symbol)" : "\(value)°"
    }
}

extension Notification.Name {
    static let temperatureUnitDidChange = Notification.Name("TemperatureUnitDidChange")
}

struct DisplayState: Equatable {
    let title: String
    let bucket: TemperatureBucket

    static var unavailable: DisplayState {
        DisplayState(title: "--\(TemperatureUnit.current.symbol)", bucket: .unavailable)
    }

    init(title: String, bucket: TemperatureBucket) {
        self.title = title
        self.bucket = bucket
    }

    init(reading: TemperatureReading?, unit: TemperatureUnit = .current) {
        guard let reading else {
            self = DisplayState(title: "--\(unit.symbol)", bucket: .unavailable)
            return
        }

        self.title = unit.formatted(celsius: reading.celsius)
        self.bucket = TemperatureBucket(celsius: reading.celsius)
    }
}

enum TemperatureBucket: Equatable {
    case normal
    case warm
    case hot
    case unavailable

    init(celsius: Int) {
        if celsius >= 85 {
            self = .hot
        } else if celsius >= 70 {
            self = .warm
        } else {
            self = .normal
        }
    }

    init(celsius: Double) {
        self.init(celsius: Int(celsius.rounded()))
    }

    var menuColor: NSColor {
        switch self {
        case .normal:
            return .labelColor
        case .warm:
            return Self.warmMenuColor
        case .hot:
            return Self.hotMenuColor
        case .unavailable:
            return .disabledControlTextColor
        }
    }

    var chartColor: NSColor {
        switch self {
        case .normal:
            return Self.normalColor
        case .warm:
            return Self.warmColor
        case .hot:
            return Self.hotColor
        case .unavailable:
            return .disabledControlTextColor
        }
    }

    static let normalColor = TempuraDesign.Color.statusNormal
    static let warmColor = TempuraDesign.Color.statusWarm
    static let hotColor = TempuraDesign.Color.statusHot

    private static let warmMenuColor = TempuraDesign.Color.warningMenu
    private static let hotMenuColor = TempuraDesign.Color.criticalMenu
}
