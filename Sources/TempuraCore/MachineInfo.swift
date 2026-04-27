import Darwin
import Foundation

public enum ChipGeneration: String, Codable, Sendable {
    case intel = "Intel"
    case m1 = "Apple M1"
    case m2 = "Apple M2"
    case m3 = "Apple M3"
    case m4 = "Apple M4"
    case m5 = "Apple M5"
    case appleUnknown = "Apple Silicon"

    public var isAppleSilicon: Bool {
        self != .intel
    }
}

public struct MachineInfo: Codable, Sendable {
    public let modelIdentifier: String?
    public let cpuBrand: String?
    public let architecture: String
    public let chipGeneration: ChipGeneration

    public static var current: MachineInfo {
        let cpuBrand = sysctlString("machdep.cpu.brand_string")
        let architecture = machineArchitecture()
        let isArm64 = architecture == "arm64" || sysctlInt32("hw.optional.arm64") == 1
        let generation = detectChipGeneration(cpuBrand: cpuBrand, isArm64: isArm64)

        return MachineInfo(
            modelIdentifier: sysctlString("hw.model"),
            cpuBrand: cpuBrand,
            architecture: architecture,
            chipGeneration: generation
        )
    }

    private static func detectChipGeneration(cpuBrand: String?, isArm64: Bool) -> ChipGeneration {
        guard isArm64 else {
            return .intel
        }

        let normalized = (cpuBrand ?? "").lowercased()
        if normalized.contains("m5") { return .m5 }
        if normalized.contains("m4") { return .m4 }
        if normalized.contains("m3") { return .m3 }
        if normalized.contains("m2") { return .m2 }
        if normalized.contains("m1") { return .m1 }
        return .appleUnknown
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sysctlInt32(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
            return nil
        }
        return value
    }

    private static func machineArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
