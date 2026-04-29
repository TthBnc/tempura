import AppKit
import Darwin

enum MemoryUsageLevel: Int, Equatable {
    case unavailable = -1
    case normal = 0
    case elevated = 1
    case high = 2

    var tintColor: NSColor {
        switch self {
        case .unavailable:
            return .disabledControlTextColor
        case .normal:
            return TempuraDesign.Color.statusNormal
        case .elevated:
            return TempuraDesign.Color.statusWarm
        case .high:
            return TempuraDesign.Color.statusHot
        }
    }

    var menuColor: NSColor {
        switch self {
        case .unavailable:
            return .disabledControlTextColor
        case .normal:
            return .labelColor
        case .elevated:
            return TempuraDesign.Color.warningMenu
        case .high:
            return TempuraDesign.Color.criticalMenu
        }
    }
}

enum NativeMemoryPressureLevel: Int, Equatable {
    case unavailable = -1
    case normal = 0
    case warning = 2
    case critical = 4

    var title: String {
        switch self {
        case .unavailable:
            return "--"
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }

    var compactTitle: String {
        switch self {
        case .unavailable:
            return "--"
        case .normal:
            return "OK"
        case .warning:
            return "Warn"
        case .critical:
            return "Crit"
        }
    }

    var detailTitle: String {
        switch self {
        case .unavailable:
            return "memory pressure unavailable"
        case .normal:
            return "normal memory pressure"
        case .warning:
            return "warning memory pressure"
        case .critical:
            return "critical memory pressure"
        }
    }

    var tintColor: NSColor {
        switch self {
        case .unavailable:
            return .disabledControlTextColor
        case .normal:
            return TempuraDesign.Color.statusNormal
        case .warning:
            return TempuraDesign.Color.statusWarm
        case .critical:
            return TempuraDesign.Color.statusHot
        }
    }

    var progress: Double {
        switch self {
        case .unavailable:
            return 0.08
        case .normal:
            return 0.22
        case .warning:
            return 0.64
        case .critical:
            return 1.0
        }
    }
}

struct MemoryUsageStatus: Equatable {
    let physicalBytes: UInt64
    let usedBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cachedBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64?
    let pressureLevel: NativeMemoryPressureLevel

    static var unavailable: MemoryUsageStatus {
        MemoryUsageStatus(
            physicalBytes: 0,
            usedBytes: 0,
            appBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0,
            cachedBytes: 0,
            swapUsedBytes: 0,
            swapTotalBytes: nil,
            pressureLevel: .unavailable
        )
    }

    var isAvailable: Bool {
        physicalBytes > 0
    }

    var memoryFraction: Double {
        fraction(numerator: usedBytes, denominator: physicalBytes)
    }

    var swapOverflowFraction: Double {
        fraction(numerator: swapUsedBytes, denominator: physicalBytes)
    }

    var memoryPercentTitle: String {
        percentTitle(memoryFraction)
    }

    var swapOverflowTitle: String {
        percentTitle(swapOverflowFraction)
    }

    var memoryLevel: MemoryUsageLevel {
        guard isAvailable else {
            return .unavailable
        }

        if memoryFraction >= 0.92 {
            return .high
        }

        if memoryFraction >= 0.80 {
            return .elevated
        }

        return .normal
    }

    var swapLevel: MemoryUsageLevel {
        guard isAvailable else {
            return .unavailable
        }

        if swapOverflowFraction >= 0.20 {
            return .high
        }

        if swapOverflowFraction >= 0.05 {
            return .elevated
        }

        return .normal
    }

    var detail: String {
        guard isAvailable else {
            return "Waiting for memory data"
        }

        let memoryText = "\(usedMemoryTitle) of \(physicalMemoryTitle)"
        let swapText = swapTotalBytes == nil
            ? "swap unavailable"
            : "\(swapUsedTitle) swap"
        let cacheText = "\(cachedMemoryTitle) cached"

        return "\(memoryText) · \(cacheText) · \(pressureLevel.detailTitle) · \(swapText)"
    }

    var physicalMemoryTitle: String {
        Self.formatBytes(physicalBytes)
    }

    var usedMemoryTitle: String {
        Self.formatBytes(usedBytes)
    }

    var appMemoryTitle: String {
        Self.formatBytes(appBytes)
    }

    var wiredMemoryTitle: String {
        Self.formatBytes(wiredBytes)
    }

    var compressedMemoryTitle: String {
        Self.formatBytes(compressedBytes)
    }

    var cachedMemoryTitle: String {
        Self.formatBytes(cachedBytes)
    }

    var swapUsedTitle: String {
        Self.formatBytes(swapUsedBytes)
    }

    var swapTotalTitle: String {
        swapTotalBytes.map(Self.formatBytes) ?? "--"
    }

    private func fraction(numerator: UInt64, denominator: UInt64) -> Double {
        guard denominator > 0 else {
            return 0
        }

        return min(max(Double(numerator) / Double(denominator), 0), 1)
    }

    private func percentTitle(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    private static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true

        let cappedBytes = min(bytes, UInt64(Int64.max))
        return formatter.string(fromByteCount: Int64(cappedBytes))
    }
}

struct MemoryUsageReader {
    static func readCurrent() -> MemoryUsageStatus {
        let physicalBytes = ProcessInfo.processInfo.physicalMemory

        guard physicalBytes > 0, let breakdown = readMemoryBreakdown(physicalBytes: physicalBytes) else {
            return .unavailable
        }

        let swapUsage = readSwapUsage()

        return MemoryUsageStatus(
            physicalBytes: physicalBytes,
            usedBytes: breakdown.usedBytes,
            appBytes: breakdown.appBytes,
            wiredBytes: breakdown.wiredBytes,
            compressedBytes: breakdown.compressedBytes,
            cachedBytes: breakdown.cachedBytes,
            swapUsedBytes: swapUsage?.usedBytes ?? 0,
            swapTotalBytes: swapUsage?.totalBytes,
            pressureLevel: readMemoryPressureLevel()
        )
    }

    private static func readMemoryBreakdown(physicalBytes: UInt64) -> MemoryBreakdown? {
        guard let snapshot = readVirtualMemorySnapshot() else {
            return nil
        }

        // Match Activity Monitor's useful "Memory Used" shape by excluding cached file-backed pages.
        let pageSize = UInt64(snapshot.pageSize)
        let appBytes = UInt64(snapshot.statistics.internal_page_count) * pageSize
        let wiredBytes = UInt64(snapshot.statistics.wire_count) * pageSize
        let compressedBytes = UInt64(snapshot.statistics.compressor_page_count) * pageSize
        let cachedBytes = (
            UInt64(snapshot.statistics.purgeable_count)
                + UInt64(snapshot.statistics.external_page_count)
        ) * pageSize
        let usedBytes = min(appBytes + wiredBytes + compressedBytes, physicalBytes)

        return MemoryBreakdown(
            usedBytes: usedBytes,
            appBytes: min(appBytes, usedBytes),
            wiredBytes: min(wiredBytes, usedBytes),
            compressedBytes: min(compressedBytes, usedBytes),
            cachedBytes: cachedBytes
        )
    }

    private static func readMemoryPressureLevel() -> NativeMemoryPressureLevel {
        var pressureLevel: Int32 = 0
        var size = MemoryLayout<Int32>.stride

        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &size, nil, 0) == 0 else {
            return .unavailable
        }

        switch pressureLevel {
        case 2:
            return .warning
        case 4:
            return .critical
        default:
            return .normal
        }
    }

    private static func readVirtualMemorySnapshot() -> VirtualMemorySnapshot? {
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return nil
        }

        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    reboundPointer,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        return VirtualMemorySnapshot(statistics: statistics, pageSize: pageSize)
    }

    private static func readSwapUsage() -> SwapUsage? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride

        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else {
            return nil
        }

        return SwapUsage(
            totalBytes: UInt64(usage.xsu_total),
            usedBytes: UInt64(usage.xsu_used)
        )
    }
}

private struct VirtualMemorySnapshot {
    let statistics: vm_statistics64
    let pageSize: vm_size_t
}

private struct MemoryBreakdown {
    let usedBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cachedBytes: UInt64
}

private struct SwapUsage {
    let totalBytes: UInt64
    let usedBytes: UInt64
}
