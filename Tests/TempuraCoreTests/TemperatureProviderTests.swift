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
