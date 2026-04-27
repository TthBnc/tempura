import AppKit
import TempuraCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let provider: any TemperatureReadingProvider

        do {
            provider = try SMCTemperatureReadingProvider()
        } catch {
            #if DEBUG
            fputs("Tempura sensor unavailable: \(error.localizedDescription)\n", stderr)
            #endif
            provider = UnavailableTemperatureProvider()
        }

        statusController = StatusController(provider: provider)
    }
}
