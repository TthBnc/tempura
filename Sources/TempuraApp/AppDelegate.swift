import AppKit
import TempuraCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusController?
    private var updateController: UpdateController?

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

        let updateController = UpdateController()
        self.updateController = updateController

        statusController = StatusController(
            provider: provider,
            checkForUpdates: { [weak updateController] in
                updateController?.checkForUpdates(nil)
            }
        )
    }
}
