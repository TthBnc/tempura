import Testing
@testable import TempuraCore

@Test("Prefers known compute sensor over hotter unknown fallback")
func prefersKnownComputeSensor() throws {
    let provider = SMCTemperatureReadingProvider(
        machine: m5Machine,
        smcClient: MockSMCReadingClient(
            keys: ["Tp00", "TVD0"],
            values: [
                "Tp00": 58,
                "TVD0": 64
            ]
        )
    )

    let reading = try #require(provider.readCurrentTemperature())
    #expect(reading.sourceKey == "Tp00")
    #expect(reading.sourceGroup == .cpu)
}

@Test("Falls back to scanned temperature when known keys are unavailable")
func fallsBackToScannedTemperature() throws {
    let provider = SMCTemperatureReadingProvider(
        machine: m5Machine,
        smcClient: MockSMCReadingClient(
            keys: ["TVD0"],
            values: [
                "TVD0": 64
            ]
        )
    )

    let reading = try #require(provider.readCurrentTemperature())
    #expect(reading.sourceKey == "TVD0")
    #expect(reading.sourceGroup == .unknown)
}

@Test("Selects average CPU source mode")
func selectsAverageCPUSourceMode() throws {
    let provider = SMCTemperatureReadingProvider(
        machine: m5Machine,
        smcClient: MockSMCReadingClient(
            keys: ["Tp00", "Tp04", "Tg0U"],
            values: [
                "Tp00": 60,
                "Tp04": 72,
                "Tg0U": 80
            ]
        )
    )

    let reading = try #require(provider.readTemperature(sourceMode: .averageCPU))
    #expect(reading.celsius == 66)
    #expect(reading.sourceKey == "CPU")
    #expect(reading.sourceName == "Average CPU")
    #expect(reading.sourceGroup == .cpu)
}

@Test("Selects hottest GPU source mode")
func selectsHottestGPUSourceMode() throws {
    let provider = SMCTemperatureReadingProvider(
        machine: m5Machine,
        smcClient: MockSMCReadingClient(
            keys: ["Tp00", "Tg0U", "Tg0X"],
            values: [
                "Tp00": 82,
                "Tg0U": 64,
                "Tg0X": 69
            ]
        )
    )

    let reading = try #require(provider.readTemperature(sourceMode: .hottestGPU))
    #expect(reading.sourceKey == "Tg0X")
    #expect(reading.sourceGroup == .gpu)
}

@Test("Rejects implausible temperature values")
func rejectsImplausibleTemperatures() {
    let provider = SMCTemperatureReadingProvider(
        machine: m5Machine,
        smcClient: MockSMCReadingClient(
            keys: ["Tp00", "TVD0"],
            values: [
                "Tp00": 9,
                "TVD0": 126
            ]
        )
    )

    #expect(provider.readCurrentTemperature() == nil)
}

private let m5Machine = MachineInfo(
    modelIdentifier: "Mac17,8",
    cpuBrand: "Apple M5 Pro",
    architecture: "arm64",
    chipGeneration: .m5
)

private struct MockSMCReadingClient: SMCReadingClient {
    let keys: [String]
    let values: [String: Double]

    func decodedDouble(forKey key: String) -> Double? {
        values[key]
    }

    func allKeys() -> [String] {
        keys
    }
}
