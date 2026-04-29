import Foundation

public enum TemperatureGroup: String, Codable, Sendable {
    case cpu = "CPU"
    case gpu = "GPU"
    case soc = "SoC"
    case system = "System"
    case sensor = "Sensor"
    case unknown = "Unknown"

    public var isComputeRelated: Bool {
        self == .cpu || self == .gpu || self == .soc
    }
}

public struct TemperatureReading: Codable, Sendable {
    public let celsius: Double
    public let sourceKey: String
    public let sourceName: String?
    public let sourceGroup: TemperatureGroup
    public let date: Date

    public init(
        celsius: Double,
        sourceKey: String,
        sourceName: String?,
        sourceGroup: TemperatureGroup,
        date: Date = Date()
    ) {
        self.celsius = celsius
        self.sourceKey = sourceKey
        self.sourceName = sourceName
        self.sourceGroup = sourceGroup
        self.date = date
    }
}

public protocol TemperatureReadingProvider: Sendable {
    func readCurrentTemperature() -> TemperatureReading?
    func readTemperature(sourceMode: TemperatureSourceMode) -> TemperatureReading?
}

public extension TemperatureReadingProvider {
    func readTemperature(sourceMode: TemperatureSourceMode) -> TemperatureReading? {
        readCurrentTemperature()
    }
}

public struct UnavailableTemperatureProvider: TemperatureReadingProvider {
    public init() {}

    public func readCurrentTemperature() -> TemperatureReading? {
        nil
    }
}
