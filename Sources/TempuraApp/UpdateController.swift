import AppKit
import Sparkle

@MainActor
final class UpdateController: NSObject {
    private let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        super.init()
    }

    func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }
}
