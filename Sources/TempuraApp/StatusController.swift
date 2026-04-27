import AppKit
import TempuraCore

@MainActor
final class StatusController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let provider: any TemperatureReadingProvider
    private let readQueue = DispatchQueue(label: "com.tebe.tempura.sensor-read", qos: .utility)
    private let quitMenu = NSMenu()
    private let panelViewController = ThermalPanelViewController()
    private let popover = NSPopover()

    private var timer: Timer?
    private var readInFlight = false
    private var lastDisplayState: DisplayState?
    private var currentReading: TemperatureReading?
    private var history = TemperatureHistory(retention: 60)
    private var localDismissMonitor: Any?
    private var globalDismissMonitor: Any?

    init(provider: any TemperatureReadingProvider) {
        self.provider = provider
        self.statusItem = NSStatusBar.system.statusItem(withLength: 48)

        super.init()

        configureStatusItem()
        configureQuitMenu()
        configurePopover()
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
        } else {
            togglePanel()
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

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 300, height: 232)
        popover.contentViewController = panelViewController
        popover.delegate = self
    }

    private func togglePanel() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button else {
            return
        }

        panelViewController.update(
            samples: history.samples,
            currentReading: currentReading
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.highlight(true)
        installDismissMonitors()
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.statusItem.button?.highlight(false)
            self.removeDismissMonitors()
        }
    }

    private func closePanel() {
        guard popover.isShown else {
            return
        }

        popover.performClose(nil)
        statusItem.button?.highlight(false)
        removeDismissMonitors()
    }

    private func installDismissMonitors() {
        removeDismissMonitors()

        localDismissMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self else {
                return event
            }

            if event.type == .keyDown && event.keyCode == 53 {
                self.closePanel()
                return nil
            }

            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if self.eventIsInsidePanelOrStatusItem(event) {
                    return event
                }

                self.closePanel()
            }

            return event
        }

        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.closePanel()
            }
        }
    }

    private func removeDismissMonitors() {
        if let localDismissMonitor {
            NSEvent.removeMonitor(localDismissMonitor)
            self.localDismissMonitor = nil
        }

        if let globalDismissMonitor {
            NSEvent.removeMonitor(globalDismissMonitor)
            self.globalDismissMonitor = nil
        }
    }

    private func eventIsInsidePanelOrStatusItem(_ event: NSEvent) -> Bool {
        guard let eventWindow = event.window else {
            return false
        }

        if eventWindow == popover.contentViewController?.view.window {
            return true
        }

        if eventWindow == statusItem.button?.window {
            return true
        }

        return false
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
                self.currentReading = reading
                self.history.record(reading)
                self.updateDisplay(DisplayState(reading: reading))
                self.panelViewController.update(
                    samples: self.history.samples,
                    currentReading: reading
                )
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
                .foregroundColor: state.bucket.menuColor,
                .paragraphStyle: paragraph
            ]
        )
    }
}
