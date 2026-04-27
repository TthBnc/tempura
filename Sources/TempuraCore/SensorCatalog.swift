// Temperature key mappings adapted from Stats:
// https://github.com/exelban/stats/blob/master/Modules/Sensors/values.swift
//
// Stats is MIT licensed. See THIRD_PARTY_NOTICES.md.

import Foundation

internal enum SensorPlatform: Sendable {
    case all
    case intel
    case apple
    case m1
    case m2
    case m3
    case m4
    case m5

    func matches(_ generation: ChipGeneration) -> Bool {
        switch self {
        case .all:
            return true
        case .intel:
            return generation == .intel
        case .apple:
            return generation.isAppleSilicon
        case .m1:
            return generation == .m1 || generation == .appleUnknown
        case .m2:
            return generation == .m2 || generation == .appleUnknown
        case .m3:
            return generation == .m3 || generation == .appleUnknown
        case .m4:
            return generation == .m4 || generation == .appleUnknown
        case .m5:
            return generation == .m5 || generation == .appleUnknown
        }
    }
}

internal struct SensorDefinition: Sendable {
    let keyPattern: String
    let name: String
    let group: TemperatureGroup
    let platforms: [SensorPlatform]

    init(_ keyPattern: String, _ name: String, _ group: TemperatureGroup, _ platforms: [SensorPlatform]) {
        self.keyPattern = keyPattern
        self.name = name
        self.group = group
        self.platforms = platforms
    }

    func matches(_ generation: ChipGeneration) -> Bool {
        platforms.contains { $0.matches(generation) }
    }
}

internal struct SensorCandidate: Hashable, Sendable {
    let key: String
    let name: String?
    let group: TemperatureGroup
    let isKnown: Bool
}

internal enum SensorCatalog {
    static func knownCandidates(for generation: ChipGeneration, allKeys: [String]) -> [SensorCandidate] {
        var seen = Set<String>()
        var candidates: [SensorCandidate] = []

        func append(_ candidate: SensorCandidate) {
            guard seen.insert(candidate.key).inserted else { return }
            candidates.append(candidate)
        }

        for definition in definitions where definition.matches(generation) {
            if definition.keyPattern.contains("%") {
                for key in allKeys.sorted() where wildcardMatch(pattern: definition.keyPattern, key: key) {
                    append(SensorCandidate(
                        key: key,
                        name: name(definition.name, from: definition.keyPattern, key: key),
                        group: definition.group,
                        isKnown: true
                    ))
                }
            } else {
                append(SensorCandidate(
                    key: definition.keyPattern,
                    name: definition.name,
                    group: definition.group,
                    isKnown: true
                ))
            }
        }

        return candidates
    }

    static func fallbackCandidates(allKeys: [String], excluding excludedKeys: Set<String>) -> [SensorCandidate] {
        allKeys
            .filter { $0.utf8.count == 4 && $0.first == "T" && !excludedKeys.contains($0) }
            .sorted()
            .map {
                SensorCandidate(
                    key: $0,
                    name: nil,
                    group: inferredGroup(for: $0),
                    isKnown: false
                )
            }
    }

    static func inferredGroup(for key: String) -> TemperatureGroup {
        if key.hasPrefix("TC") || key.hasPrefix("Tp") || key.hasPrefix("Te") || key.hasPrefix("Tf") {
            return .cpu
        }
        if key.hasPrefix("TG") || key.hasPrefix("Tg") {
            return .gpu
        }
        if key.hasPrefix("TZ") {
            return .soc
        }
        if key.hasPrefix("Tm") || key.hasPrefix("TA") || key.hasPrefix("Ta") {
            return .sensor
        }
        return .unknown
    }

    private static func wildcardMatch(pattern: String, key: String) -> Bool {
        let patternBytes = Array(pattern.utf8)
        let keyBytes = Array(key.utf8)
        guard patternBytes.count == keyBytes.count else { return false }

        return zip(patternBytes, keyBytes).allSatisfy { patternByte, keyByte in
            patternByte == 37 || patternByte == keyByte
        }
    }

    private static func name(_ patternName: String, from pattern: String, key: String) -> String {
        guard pattern.contains("%") else {
            return patternName
        }

        let wildcardValues = zip(pattern, key).compactMap { patternCharacter, keyCharacter in
            patternCharacter == "%" ? String(keyCharacter) : nil
        }

        guard !wildcardValues.isEmpty else {
            return patternName
        }

        return patternName.replacingOccurrences(of: "%", with: wildcardValues.joined(separator: " "))
    }

    private static let definitions: [SensorDefinition] = [
        // General and Intel temperature keys.
        .init("TA%P", "Ambient %", .sensor, [.all]),
        .init("Th%H", "Heatpipe %", .sensor, [.intel]),
        .init("TZ%C", "Thermal zone %", .soc, [.all]),
        .init("TC0D", "CPU diode", .cpu, [.all]),
        .init("TC0E", "CPU diode virtual", .cpu, [.all]),
        .init("TC0F", "CPU diode filtered", .cpu, [.all]),
        .init("TC0H", "CPU heatsink", .cpu, [.all]),
        .init("TC0P", "CPU proximity", .cpu, [.all]),
        .init("TCAD", "CPU package", .cpu, [.all]),
        .init("TC%c", "CPU core %", .cpu, [.all]),
        .init("TC%C", "CPU Core %", .cpu, [.all]),
        .init("TCGC", "GPU Intel Graphics", .gpu, [.all]),
        .init("TG0D", "GPU diode", .gpu, [.all]),
        .init("TGDD", "GPU AMD Radeon", .gpu, [.all]),
        .init("TG0H", "GPU heatsink", .gpu, [.all]),
        .init("TG0P", "GPU proximity", .gpu, [.all]),
        .init("Tm0P", "Mainboard", .system, [.all]),
        .init("Tp0P", "Powerboard", .system, [.intel]),
        .init("TB1T", "Battery", .system, [.intel]),
        .init("TW0P", "Airport", .system, [.all]),
        .init("TL0P", "Display", .system, [.all]),
        .init("TI%P", "Thunderbolt %", .system, [.all]),
        .init("TH%A", "Disk % (A)", .system, [.all]),
        .init("TH%B", "Disk % (B)", .system, [.all]),
        .init("TH%C", "Disk % (C)", .system, [.all]),
        .init("TTLD", "Thunderbolt left", .system, [.all]),
        .init("TTRD", "Thunderbolt right", .system, [.all]),
        .init("TN0D", "Northbridge diode", .system, [.all]),
        .init("TN0H", "Northbridge heatsink", .system, [.all]),
        .init("TN0P", "Northbridge proximity", .system, [.all]),

        // Apple M1.
        .init("Tp09", "CPU efficiency core 1", .cpu, [.m1]),
        .init("Tp0T", "CPU efficiency core 2", .cpu, [.m1]),
        .init("Tp01", "CPU performance core 1", .cpu, [.m1]),
        .init("Tp05", "CPU performance core 2", .cpu, [.m1]),
        .init("Tp0D", "CPU performance core 3", .cpu, [.m1]),
        .init("Tp0H", "CPU performance core 4", .cpu, [.m1]),
        .init("Tp0L", "CPU performance core 5", .cpu, [.m1]),
        .init("Tp0P", "CPU performance core 6", .cpu, [.m1]),
        .init("Tp0X", "CPU performance core 7", .cpu, [.m1]),
        .init("Tp0b", "CPU performance core 8", .cpu, [.m1]),
        .init("Tg05", "GPU 1", .gpu, [.m1]),
        .init("Tg0D", "GPU 2", .gpu, [.m1]),
        .init("Tg0L", "GPU 3", .gpu, [.m1]),
        .init("Tg0T", "GPU 4", .gpu, [.m1]),
        .init("Tm02", "Memory 1", .sensor, [.m1]),
        .init("Tm06", "Memory 2", .sensor, [.m1]),
        .init("Tm08", "Memory 3", .sensor, [.m1]),
        .init("Tm09", "Memory 4", .sensor, [.m1]),

        // Apple M2.
        .init("Tp1h", "CPU efficiency core 1", .cpu, [.m2]),
        .init("Tp1t", "CPU efficiency core 2", .cpu, [.m2]),
        .init("Tp1p", "CPU efficiency core 3", .cpu, [.m2]),
        .init("Tp1l", "CPU efficiency core 4", .cpu, [.m2]),
        .init("Tp01", "CPU performance core 1", .cpu, [.m2]),
        .init("Tp05", "CPU performance core 2", .cpu, [.m2]),
        .init("Tp09", "CPU performance core 3", .cpu, [.m2]),
        .init("Tp0D", "CPU performance core 4", .cpu, [.m2]),
        .init("Tp0X", "CPU performance core 5", .cpu, [.m2]),
        .init("Tp0b", "CPU performance core 6", .cpu, [.m2]),
        .init("Tp0f", "CPU performance core 7", .cpu, [.m2]),
        .init("Tp0j", "CPU performance core 8", .cpu, [.m2]),
        .init("Tg0f", "GPU 1", .gpu, [.m2]),
        .init("Tg0j", "GPU 2", .gpu, [.m2]),

        // Apple M3.
        .init("Te05", "CPU efficiency core 1", .cpu, [.m3]),
        .init("Te0L", "CPU efficiency core 2", .cpu, [.m3]),
        .init("Te0P", "CPU efficiency core 3", .cpu, [.m3]),
        .init("Te0S", "CPU efficiency core 4", .cpu, [.m3]),
        .init("Tf04", "CPU performance core 1", .cpu, [.m3]),
        .init("Tf09", "CPU performance core 2", .cpu, [.m3]),
        .init("Tf0A", "CPU performance core 3", .cpu, [.m3]),
        .init("Tf0B", "CPU performance core 4", .cpu, [.m3]),
        .init("Tf0D", "CPU performance core 5", .cpu, [.m3]),
        .init("Tf0E", "CPU performance core 6", .cpu, [.m3]),
        .init("Tf44", "CPU performance core 7", .cpu, [.m3]),
        .init("Tf49", "CPU performance core 8", .cpu, [.m3]),
        .init("Tf4A", "CPU performance core 9", .cpu, [.m3]),
        .init("Tf4B", "CPU performance core 10", .cpu, [.m3]),
        .init("Tf4D", "CPU performance core 11", .cpu, [.m3]),
        .init("Tf4E", "CPU performance core 12", .cpu, [.m3]),
        .init("Tf14", "GPU 1", .gpu, [.m3]),
        .init("Tf18", "GPU 2", .gpu, [.m3]),
        .init("Tf19", "GPU 3", .gpu, [.m3]),
        .init("Tf1A", "GPU 4", .gpu, [.m3]),
        .init("Tf24", "GPU 5", .gpu, [.m3]),
        .init("Tf28", "GPU 6", .gpu, [.m3]),
        .init("Tf29", "GPU 7", .gpu, [.m3]),
        .init("Tf2A", "GPU 8", .gpu, [.m3]),

        // Apple M4.
        .init("Te05", "CPU efficiency core 1", .cpu, [.m4]),
        .init("Te0S", "CPU efficiency core 2", .cpu, [.m4]),
        .init("Te09", "CPU efficiency core 3", .cpu, [.m4]),
        .init("Te0H", "CPU efficiency core 4", .cpu, [.m4]),
        .init("Tp01", "CPU performance core 1", .cpu, [.m4]),
        .init("Tp05", "CPU performance core 2", .cpu, [.m4]),
        .init("Tp09", "CPU performance core 3", .cpu, [.m4]),
        .init("Tp0D", "CPU performance core 4", .cpu, [.m4]),
        .init("Tp0V", "CPU performance core 5", .cpu, [.m4]),
        .init("Tp0Y", "CPU performance core 6", .cpu, [.m4]),
        .init("Tp0b", "CPU performance core 7", .cpu, [.m4]),
        .init("Tp0e", "CPU performance core 8", .cpu, [.m4]),
        .init("Tg0G", "GPU 1", .gpu, [.m4]),
        .init("Tg0H", "GPU 2", .gpu, [.m4]),
        .init("Tg1U", "GPU 1", .gpu, [.m4]),
        .init("Tg1k", "GPU 2", .gpu, [.m4]),
        .init("Tg0K", "GPU 3", .gpu, [.m4]),
        .init("Tg0L", "GPU 4", .gpu, [.m4]),
        .init("Tg0d", "GPU 5", .gpu, [.m4]),
        .init("Tg0e", "GPU 6", .gpu, [.m4]),
        .init("Tg0j", "GPU 7", .gpu, [.m4]),
        .init("Tg0k", "GPU 8", .gpu, [.m4]),
        .init("Tm0p", "Memory Proximity 1", .sensor, [.m4]),
        .init("Tm1p", "Memory Proximity 2", .sensor, [.m4]),
        .init("Tm2p", "Memory Proximity 3", .sensor, [.m4]),

        // Apple M5.
        .init("Tp00", "CPU super core 1", .cpu, [.m5]),
        .init("Tp04", "CPU super core 2", .cpu, [.m5]),
        .init("Tp08", "CPU super core 3", .cpu, [.m5]),
        .init("Tp0C", "CPU super core 4", .cpu, [.m5]),
        .init("Tp0G", "CPU super core 5", .cpu, [.m5]),
        .init("Tp0K", "CPU super core 6", .cpu, [.m5]),
        .init("Tp0O", "CPU performance core 1", .cpu, [.m5]),
        .init("Tp0R", "CPU performance core 2", .cpu, [.m5]),
        .init("Tp0U", "CPU performance core 3", .cpu, [.m5]),
        .init("Tp0X", "CPU performance core 4", .cpu, [.m5]),
        .init("Tp0a", "CPU performance core 5", .cpu, [.m5]),
        .init("Tp0d", "CPU performance core 6", .cpu, [.m5]),
        .init("Tp0g", "CPU performance core 7", .cpu, [.m5]),
        .init("Tp0j", "CPU performance core 8", .cpu, [.m5]),
        .init("Tp0m", "CPU performance core 9", .cpu, [.m5]),
        .init("Tp0p", "CPU performance core 10", .cpu, [.m5]),
        .init("Tp0u", "CPU performance core 11", .cpu, [.m5]),
        .init("Tp0y", "CPU performance core 12", .cpu, [.m5]),
        .init("Tg0U", "GPU 1", .gpu, [.m5]),
        .init("Tg0X", "GPU 2", .gpu, [.m5]),
        .init("Tg0d", "GPU 3", .gpu, [.m5]),
        .init("Tg0g", "GPU 4", .gpu, [.m5]),
        .init("Tg0j", "GPU 5", .gpu, [.m5]),
        .init("Tg1Y", "GPU 6", .gpu, [.m5]),
        .init("Tg1c", "GPU 7", .gpu, [.m5]),
        .init("Tg1g", "GPU 8", .gpu, [.m5]),

        // Apple Silicon generic.
        .init("TaLP", "Airflow left", .sensor, [.apple]),
        .init("TaRF", "Airflow right", .sensor, [.apple]),
        .init("TH0x", "NAND", .system, [.apple]),
        .init("TB1T", "Battery 1", .system, [.apple]),
        .init("TB2T", "Battery 2", .system, [.apple]),
        .init("TW0P", "Airport", .system, [.apple])
    ]
}
