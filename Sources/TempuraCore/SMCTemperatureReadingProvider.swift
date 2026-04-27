import Foundation

public final class SMCTemperatureReadingProvider: TemperatureReadingProvider, @unchecked Sendable {
    private let smcClient: any SMCReadingClient
    private let machine: MachineInfo
    private let cacheLock = NSLock()
    private var cachedAllKeys: [String]?

    public convenience init(machine: MachineInfo = .current) throws {
        try self.init(machine: machine, smcClient: SMCClient())
    }

    public init(machine: MachineInfo, smcClient: any SMCReadingClient) {
        self.machine = machine
        self.smcClient = smcClient
    }

    public func readCurrentTemperature() -> TemperatureReading? {
        let knownCandidates = SensorCatalog.knownCandidates(
            for: machine.chipGeneration,
            allKeys: allKeys()
        )
        let knownReadings = read(candidates: knownCandidates)

        if let computeReading = hottest(knownReadings.filter { $0.sourceGroup.isComputeRelated }) {
            return computeReading
        }

        if let knownReading = hottest(knownReadings) {
            return knownReading
        }

        let knownKeys = Set(knownCandidates.map(\.key))
        return hottest(read(candidates: SensorCatalog.fallbackCandidates(
            allKeys: allKeys(),
            excluding: knownKeys
        )))
    }

    public func readTopValidTemperatures(limit: Int = 5) -> [TemperatureReading] {
        let knownCandidates = SensorCatalog.knownCandidates(
            for: machine.chipGeneration,
            allKeys: allKeys()
        )
        let knownKeys = Set(knownCandidates.map(\.key))
        let fallbackCandidates = SensorCatalog.fallbackCandidates(
            allKeys: allKeys(),
            excluding: knownKeys
        )

        return read(candidates: knownCandidates + fallbackCandidates)
            .sorted { $0.celsius > $1.celsius }
            .prefix(limit)
            .map { $0 }
    }

    public func validTemperatureKeyCount() -> Int {
        readTopValidTemperatures(limit: Int.max).count
    }

    private func allKeys() -> [String] {
        cacheLock.lock()
        if let cachedAllKeys {
            cacheLock.unlock()
            return cachedAllKeys
        }
        cacheLock.unlock()

        let keys = smcClient.allKeys()

        cacheLock.lock()
        cachedAllKeys = keys
        cacheLock.unlock()

        return keys
    }

    private func read(candidates: [SensorCandidate]) -> [TemperatureReading] {
        candidates.compactMap { candidate in
            guard
                let celsius = smcClient.decodedDouble(forKey: candidate.key),
                isValidTemperature(celsius)
            else {
                return nil
            }

            return TemperatureReading(
                celsius: celsius,
                sourceKey: candidate.key,
                sourceName: candidate.name,
                sourceGroup: candidate.group
            )
        }
    }

    private func hottest(_ readings: [TemperatureReading]) -> TemperatureReading? {
        readings.max { $0.celsius < $1.celsius }
    }

    private func isValidTemperature(_ celsius: Double) -> Bool {
        celsius.isFinite && celsius >= 10 && celsius <= 125
    }
}
