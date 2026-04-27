import Foundation

public struct TemperatureSample: Codable, Equatable, Sendable {
    public let celsius: Double
    public let date: Date

    public init(celsius: Double, date: Date) {
        self.celsius = celsius
        self.date = date
    }
}

public struct TemperatureHistory: Sendable {
    public let retention: TimeInterval
    public private(set) var samples: [TemperatureSample]

    public init(retention: TimeInterval = 60, samples: [TemperatureSample] = []) {
        self.retention = retention
        self.samples = samples
        prune(now: Date())
    }

    public mutating func record(_ reading: TemperatureReading?) {
        guard let reading else {
            prune(now: Date())
            return
        }

        record(celsius: reading.celsius, date: reading.date)
    }

    public mutating func record(celsius: Double, date: Date = Date()) {
        guard celsius.isFinite else {
            prune(now: date)
            return
        }

        samples.append(TemperatureSample(celsius: celsius, date: date))
        prune(now: date)
    }

    public mutating func prune(now: Date = Date()) {
        let oldestAllowedDate = now.addingTimeInterval(-retention)
        samples.removeAll { $0.date < oldestAllowedDate }
    }

    public func dynamicRange(minimumSpan: Double = 8, padding: Double = 3) -> ClosedRange<Double>? {
        guard
            let minimum = samples.map(\.celsius).min(),
            let maximum = samples.map(\.celsius).max()
        else {
            return nil
        }

        let midpoint = (minimum + maximum) / 2
        let paddedMinimum = minimum - padding
        let paddedMaximum = maximum + padding

        if paddedMaximum - paddedMinimum >= minimumSpan {
            return paddedMinimum...paddedMaximum
        }

        let halfSpan = minimumSpan / 2
        return (midpoint - halfSpan)...(midpoint + halfSpan)
    }
}
