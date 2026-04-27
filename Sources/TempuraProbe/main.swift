import Foundation
import TempuraCore

let machine = MachineInfo.current

print("Tempura sensor probe")
print("--------------------")
print("Model: \(machine.modelIdentifier ?? "unknown")")
print("CPU: \(machine.cpuBrand ?? "unknown")")
print("Architecture: \(machine.architecture)")
print("Detected chip: \(machine.chipGeneration.rawValue)")
print("")

do {
    let provider = try SMCTemperatureReadingProvider(machine: machine)

    if CommandLine.arguments.contains("--watch") {
        print("Watching selected temperature every 5 seconds. Press Ctrl-C to stop.")
        while true {
            printSelectedReading(provider.readCurrentTemperature())
            Thread.sleep(forTimeInterval: 5)
        }
    } else {
        printSelectedReading(provider.readCurrentTemperature())
        print("")
        print("Top valid temperature readings:")

        let readings = provider.readTopValidTemperatures(limit: 5)
        if readings.isEmpty {
            print("- none")
        } else {
            for reading in readings {
                print(format(reading))
            }
        }
    }
} catch {
    fputs("SMC probe failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}

private func printSelectedReading(_ reading: TemperatureReading?) {
    guard let reading else {
        print("Selected: --°C")
        return
    }

    print("Selected: \(format(reading))")
}

private func format(_ reading: TemperatureReading) -> String {
    let name = reading.sourceName.map { " \($0)" } ?? ""
    return String(
        format: "- %@ %.1f°C [%@%@]",
        reading.sourceKey,
        reading.celsius,
        reading.sourceGroup.rawValue,
        name
    )
}
