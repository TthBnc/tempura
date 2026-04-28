import AppKit
import TempuraCore

enum SystemThermalPressure: Equatable {
    case nominal
    case fair
    case serious
    case critical
    case unavailable

    static var current: SystemThermalPressure {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .unavailable
        }
    }

    var displayName: String {
        switch self {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        case .unavailable:
            return "Pressure unavailable"
        }
    }

    var minimumRisk: ThrottleRisk {
        switch self {
        case .nominal, .unavailable:
            return .normal
        case .fair:
            return .elevated
        case .serious:
            return .likely
        case .critical:
            return .severe
        }
    }
}

struct ThermalLimitSnapshot: Equatable {
    let schedulerLimit: Int?
    let availableCPUs: Int?
    let speedLimit: Int?

    var strongestLimit: Int? {
        let limits = [schedulerLimit, speedLimit].compactMap { $0 }
        return limits.min()
    }
}

struct ThermalLimitReader {
    static func readCurrent() -> ThermalLimitSnapshot? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "therm"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
        outputPipe.fileHandleForReading.closeFile()
        errorPipe.fileHandleForReading.closeFile()

        let text = [
            String(data: output, encoding: .utf8),
            String(data: errorOutput, encoding: .utf8)
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        return parse(text)
    }

    static func parse(_ output: String) -> ThermalLimitSnapshot? {
        var schedulerLimit: Int?
        var availableCPUs: Int?
        var speedLimit: Int?

        output.split(separator: "\n").forEach { line in
            if line.contains("CPU_Scheduler_Limit") {
                schedulerLimit = integerAfterEquals(in: line)
            } else if line.contains("CPU_Available_CPUs") {
                availableCPUs = integerAfterEquals(in: line)
            } else if line.contains("CPU_Speed_Limit") {
                speedLimit = integerAfterEquals(in: line)
            }
        }

        guard schedulerLimit != nil || availableCPUs != nil || speedLimit != nil else {
            return nil
        }

        return ThermalLimitSnapshot(
            schedulerLimit: schedulerLimit,
            availableCPUs: availableCPUs,
            speedLimit: speedLimit
        )
    }

    private static func integerAfterEquals(in line: Substring) -> Int? {
        guard let equalsRange = line.range(of: "=") else {
            return nil
        }

        let valueText = line[equalsRange.upperBound...]
        let digits = valueText.filter(\.isNumber)
        return Int(String(digits))
    }
}

enum ThrottleRisk: Int, Equatable {
    case unavailable = -1
    case normal = 0
    case elevated = 1
    case likely = 2
    case severe = 3

    var title: String {
        switch self {
        case .unavailable:
            return "Monitoring"
        case .normal:
            return "Normal"
        case .elevated:
            return "Elevated"
        case .likely:
            return "Likely Throttling"
        case .severe:
            return "Severe"
        }
    }

    var tintColor: NSColor {
        switch self {
        case .unavailable:
            return .disabledControlTextColor
        case .normal:
            return TemperatureBucket.normalColor
        case .elevated:
            return TemperatureBucket.warmColor
        case .likely:
            return NSColor(calibratedRed: 0.88, green: 0.46, blue: 0.18, alpha: 1)
        case .severe:
            return TemperatureBucket.hotColor
        }
    }

    var meterProgress: CGFloat {
        switch self {
        case .unavailable:
            return 0.08
        case .normal:
            return 0.22
        case .elevated:
            return 0.48
        case .likely:
            return 0.74
        case .severe:
            return 1.0
        }
    }

    func raised() -> ThrottleRisk {
        switch self {
        case .unavailable:
            return .elevated
        case .normal:
            return .elevated
        case .elevated:
            return .likely
        case .likely:
            return .severe
        case .severe:
            return .severe
        }
    }
}

struct ThrottleStatus: Equatable {
    let risk: ThrottleRisk
    let pressure: SystemThermalPressure
    let thermalLimit: ThermalLimitSnapshot?
    let trendCelsiusPerMinute: Double?
    let temperatureCelsius: Double?

    static var unavailable: ThrottleStatus {
        ThrottleStatus(
            risk: .unavailable,
            pressure: .unavailable,
            thermalLimit: nil,
            trendCelsiusPerMinute: nil,
            temperatureCelsius: nil
        )
    }

    init(
        reading: TemperatureReading?,
        samples: [TemperatureSample],
        pressure: SystemThermalPressure,
        thermalLimit: ThermalLimitSnapshot?
    ) {
        self.pressure = pressure
        self.thermalLimit = thermalLimit
        self.temperatureCelsius = reading?.celsius
        let trendCelsiusPerMinute = Self.temperatureTrend(samples: samples)
        self.trendCelsiusPerMinute = trendCelsiusPerMinute
        self.risk = Self.resolveRisk(
            reading: reading,
            trendCelsiusPerMinute: trendCelsiusPerMinute,
            pressure: pressure,
            thermalLimit: thermalLimit
        )
    }

    private init(
        risk: ThrottleRisk,
        pressure: SystemThermalPressure,
        thermalLimit: ThermalLimitSnapshot?,
        trendCelsiusPerMinute: Double?,
        temperatureCelsius: Double?
    ) {
        self.risk = risk
        self.pressure = pressure
        self.thermalLimit = thermalLimit
        self.trendCelsiusPerMinute = trendCelsiusPerMinute
        self.temperatureCelsius = temperatureCelsius
    }

    var detail: String {
        let limitText = thermalLimit.flatMap(Self.limitDescription)
        let pressureText = pressure.displayName

        if let limitText {
            return "\(limitText) · \(pressureText)"
        }

        if pressure != .unavailable {
            return "\(pressureText) thermal pressure"
        }

        if temperatureCelsius != nil {
            return "Estimated from temperature trend"
        }

        return "Waiting for thermal data"
    }

    private static func resolveRisk(
        reading: TemperatureReading?,
        trendCelsiusPerMinute: Double?,
        pressure: SystemThermalPressure,
        thermalLimit: ThermalLimitSnapshot?
    ) -> ThrottleRisk {
        guard reading != nil || pressure != .unavailable || thermalLimit != nil else {
            return .unavailable
        }

        var risk = pressure.minimumRisk

        if let celsius = reading?.celsius {
            if celsius >= 95 {
                risk = maxRisk(risk, .severe)
            } else if celsius >= 85 {
                risk = maxRisk(risk, .likely)
            } else if celsius >= 72 {
                risk = maxRisk(risk, .elevated)
            }
        }

        if
            let trendCelsiusPerMinute,
            let celsius = reading?.celsius,
            trendCelsiusPerMinute >= 7,
            celsius >= 68
        {
            risk = risk.raised()
        }

        if let strongestLimit = thermalLimit?.strongestLimit {
            if strongestLimit <= 60 {
                risk = maxRisk(risk, .severe)
            } else if strongestLimit <= 85 {
                risk = maxRisk(risk, .likely)
            } else if strongestLimit < 100 {
                risk = maxRisk(risk, .elevated)
            }
        }

        return risk
    }

    private static func maxRisk(_ lhs: ThrottleRisk, _ rhs: ThrottleRisk) -> ThrottleRisk {
        lhs.rawValue >= rhs.rawValue ? lhs : rhs
    }

    private static func temperatureTrend(samples: [TemperatureSample]) -> Double? {
        guard
            let first = samples.first,
            let last = samples.last,
            samples.count >= 2
        else {
            return nil
        }

        let minutes = last.date.timeIntervalSince(first.date) / 60
        guard minutes > 0 else {
            return nil
        }

        return (last.celsius - first.celsius) / minutes
    }

    private static func limitDescription(_ limit: ThermalLimitSnapshot) -> String? {
        if let speedLimit = limit.speedLimit {
            return "CPU limit \(speedLimit)%"
        }

        if let schedulerLimit = limit.schedulerLimit {
            return "Scheduler \(schedulerLimit)%"
        }

        if let availableCPUs = limit.availableCPUs {
            return "\(availableCPUs) CPUs available"
        }

        return nil
    }
}
