import Foundation

public enum TemperatureSourceMode: String, CaseIterable, Codable, Sendable {
    case automatic
    case hottestCPU
    case averageCPU
    case hottestGPU
    case averageGPU
    case hottestSoC
    case averageSoC

    public var displayName: String {
        switch self {
        case .automatic:
            return "Auto"
        case .hottestCPU:
            return "Hottest CPU"
        case .averageCPU:
            return "Average CPU"
        case .hottestGPU:
            return "Hottest GPU"
        case .averageGPU:
            return "Average GPU"
        case .hottestSoC:
            return "Hottest SoC"
        case .averageSoC:
            return "Average SoC"
        }
    }
}
