import AppKit
import TempuraCore

@MainActor
final class StatusController: NSObject {
    private let statusItem: NSStatusItem
    private let provider: any TemperatureReadingProvider
    private let readQueue = DispatchQueue(label: "com.tebe.tempura.sensor-read", qos: .utility)
    private let quitMenu = NSMenu()

    private var timer: Timer?
    private var readInFlight = false
    private var lastDisplayState: DisplayState?

    init(provider: any TemperatureReadingProvider) {
        self.provider = provider
        self.statusItem = NSStatusBar.system.statusItem(withLength: 48)

        super.init()

        configureStatusItem()
        configureQuitMenu()
        updateDisplay(DisplayState.unavailable)
        readTemperature()

        timer = Timer.scheduledTimer(
            timeInterval: 5,
            target: self,
            selector: #selector(timerFired(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Tempura"
        button.image = nil
        button.title = ""
    }

    private func configureQuitMenu() {
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        quitMenu.addItem(quitItem)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showQuitMenu()
        }
    }

    @objc private func timerFired(_ timer: Timer) {
        readTemperature()
    }

    private func showQuitMenu() {
        guard let button = statusItem.button else {
            return
        }

        quitMenu.popUp(
            positioning: quitMenu.items.first,
            at: NSPoint(x: 0, y: button.bounds.height + 3),
            in: button
        )
    }

    private func readTemperature() {
        guard !readInFlight else {
            return
        }

        readInFlight = true
        let provider = provider

        readQueue.async { [provider] in
            let reading = provider.readCurrentTemperature()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.readInFlight = false
                self.updateDisplay(DisplayState(reading: reading))
            }
        }
    }

    private func updateDisplay(_ state: DisplayState) {
        guard state != lastDisplayState else {
            return
        }

        lastDisplayState = state
        statusItem.button?.attributedTitle = attributedTitle(for: state)
    }

    private func attributedTitle(for state: DisplayState) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        return NSAttributedString(
            string: state.title,
            attributes: [
                .font: font,
                .foregroundColor: state.bucket.color,
                .paragraphStyle: paragraph
            ]
        )
    }
}

private struct DisplayState: Equatable {
    let title: String
    let bucket: TemperatureBucket

    static let unavailable = DisplayState(title: "--°C", bucket: .unavailable)

    init(title: String, bucket: TemperatureBucket) {
        self.title = title
        self.bucket = bucket
    }

    init(reading: TemperatureReading?) {
        guard let reading else {
            self = .unavailable
            return
        }

        let roundedCelsius = Int(reading.celsius.rounded())
        self.title = "\(roundedCelsius)°C"
        self.bucket = TemperatureBucket(celsius: roundedCelsius)
    }
}

private enum TemperatureBucket: Equatable {
    case normal
    case warm
    case hot
    case unavailable

    init(celsius: Int) {
        if celsius >= 85 {
            self = .hot
        } else if celsius >= 70 {
            self = .warm
        } else {
            self = .normal
        }
    }

    var color: NSColor {
        switch self {
        case .normal:
            return .labelColor
        case .warm:
            return .systemOrange
        case .hot:
            return .systemRed
        case .unavailable:
            return .disabledControlTextColor
        }
    }
}
