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

struct MemoryUsageStatus: Equatable {
    let physicalBytes: UInt64
    let usedBytes: UInt64
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64?

    static var unavailable: MemoryUsageStatus {
        MemoryUsageStatus(
            physicalBytes: 0,
            usedBytes: 0,
            swapUsedBytes: 0,
            swapTotalBytes: nil
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

        let memoryText = "\(Self.formatBytes(usedBytes)) of \(Self.formatBytes(physicalBytes))"
        let swapText = swapTotalBytes == nil
            ? "swap unavailable"
            : "\(Self.formatBytes(swapUsedBytes)) swap"

        return "\(memoryText) · \(swapText)"
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

        guard
            physicalBytes > 0,
            let usedBytes = readUsedMemoryBytes(physicalBytes: physicalBytes)
        else {
            return .unavailable
        }

        let swapUsage = readSwapUsage()

        return MemoryUsageStatus(
            physicalBytes: physicalBytes,
            usedBytes: usedBytes,
            swapUsedBytes: swapUsage?.usedBytes ?? 0,
            swapTotalBytes: swapUsage?.totalBytes
        )
    }

    private static func readUsedMemoryBytes(physicalBytes: UInt64) -> UInt64? {
        guard let snapshot = readVirtualMemorySnapshot() else {
            return nil
        }

        let immediatelyAvailablePages = UInt64(snapshot.statistics.free_count)
            + UInt64(snapshot.statistics.speculative_count)
        let availableBytes = immediatelyAvailablePages * UInt64(snapshot.pageSize)

        guard physicalBytes > availableBytes else {
            return 0
        }

        return physicalBytes - availableBytes
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

private struct SwapUsage {
    let totalBytes: UInt64
    let usedBytes: UInt64
}
