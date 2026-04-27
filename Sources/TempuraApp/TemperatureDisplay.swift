import AppKit
import TempuraCore

struct DisplayState: Equatable {
    let title: String
    let bucket: TemperatureBucket

    static let unavailable = DisplayState(title: "--°C", bucket: .unavailable)

    init(title: String, bucket: TemperatureBucket) {
        self.title = title
        self.bucket = bucket
    }

    init(reading: TemperatureReading?) {
        guard let reading else {
            self = .unavailable
            return
        }

        let roundedCelsius = Int(reading.celsius.rounded())
        self.title = "\(roundedCelsius)°C"
        self.bucket = TemperatureBucket(celsius: roundedCelsius)
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
            return Self.warmColor
        case .hot:
            return Self.hotColor
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

    static let normalColor = NSColor(calibratedRed: 0.26, green: 0.68, blue: 0.42, alpha: 1)
    static let warmColor = NSColor(calibratedRed: 0.78, green: 0.62, blue: 0.24, alpha: 1)
    static let hotColor = NSColor(calibratedRed: 0.83, green: 0.27, blue: 0.27, alpha: 1)
}
