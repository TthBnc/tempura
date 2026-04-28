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
    private let settingsWindowController = SettingsWindowController()

    private var timer: Timer?
    private var readInFlight = false
    private var currentReading: TemperatureReading?
    private var currentThrottleStatus = ThrottleStatus.unavailable
    private var currentMemoryStatus = MemoryUsageStatus.unavailable
    private var history = TemperatureHistory(retention: 60)
    private var localDismissMonitor: Any?
    private var globalDismissMonitor: Any?
    private var temperatureUnit = TemperatureUnit.current
    private var menuBarSettings = MenuBarDisplaySettings.current

    init(provider: any TemperatureReadingProvider) {
        self.provider = provider
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        configureStatusItem()
        configureQuitMenu()
        configurePopover()
        configureTemperatureUnitObserver()
        configureMenuBarSettingsObserver()
        updateDisplay()
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

    private func configureMenuBarSettingsObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarSettingsDidChange(_:)),
            name: .menuBarDisplaySettingsDidChange,
            object: nil
        )
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = ThermalPanelViewController.preferredContentSize
        popover.contentViewController = panelViewController
        popover.delegate = self
        panelViewController.settingsRequested = { [weak self] in
            guard let self else {
                return
            }

            self.closePanel()
            self.settingsWindowController.showSettingsWindow()
        }
        panelViewController.setTemperatureUnit(temperatureUnit)
    }

    private func configureTemperatureUnitObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(temperatureUnitDidChange(_:)),
            name: .temperatureUnitDidChange,
            object: nil
        )
    }

    @objc private func temperatureUnitDidChange(_ notification: Notification) {
        guard let unit = notification.object as? TemperatureUnit else {
            return
        }

        temperatureUnit = unit
        panelViewController.setTemperatureUnit(unit)
        updateDisplay()
        panelViewController.update(
            samples: history.samples,
            currentReading: currentReading,
            throttleStatus: currentThrottleStatus,
            memoryStatus: currentMemoryStatus
        )
    }

    @objc private func menuBarSettingsDidChange(_ notification: Notification) {
        guard let settings = notification.object as? MenuBarDisplaySettings else {
            return
        }

        menuBarSettings = settings
        updateDisplay()
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
            currentReading: currentReading,
            throttleStatus: currentThrottleStatus,
            memoryStatus: currentMemoryStatus
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
            let pressure = SystemThermalPressure.current
            let thermalLimit = ThermalLimitReader.readCurrent()
            let memoryStatus = MemoryUsageReader.readCurrent()
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.readInFlight = false
                self.currentReading = reading
                self.history.record(reading)
                self.currentMemoryStatus = memoryStatus
                self.currentThrottleStatus = ThrottleStatus(
                    reading: reading,
                    samples: self.history.samples,
                    pressure: pressure,
                    thermalLimit: thermalLimit
                )
                self.updateDisplay()
                self.panelViewController.update(
                    samples: self.history.samples,
                    currentReading: reading,
                    throttleStatus: self.currentThrottleStatus,
                    memoryStatus: self.currentMemoryStatus
                )
            }
        }
    }

    private func updateDisplay() {
        let content = menuBarContent()
        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.image = nil
        statusItem.button?.attributedTitle = attributedTitle(for: content)
        statusItem.button?.toolTip = content.tooltip
        statusItem.button?.setAccessibilityLabel("Tempura \(content.plainTitle)")
    }

    private func menuBarContent() -> MenuBarContent {
        var components: [MenuBarComponent] = []
        let temperatureState = DisplayState(reading: currentReading, unit: temperatureUnit)

        if menuBarSettings.showsTemperature {
            components.append(
                MenuBarComponent(
                    title: temperatureState.title,
                    color: temperatureState.bucket.menuColor
                )
            )
        }

        if menuBarSettings.showsMemory {
            let percent = currentMemoryStatus.isAvailable ? currentMemoryStatus.memoryPercentTitle : "--"
            components.append(
                MenuBarComponent(
                    title: menuBarSettings.memoryLabelStyle.memoryTitle(percent: percent),
                    color: currentMemoryStatus.memoryLevel.menuColor
                )
            )
        }

        if menuBarSettings.showsSwap {
            let percent = currentMemoryStatus.isAvailable ? currentMemoryStatus.swapOverflowTitle : "--"
            components.append(
                MenuBarComponent(
                    title: menuBarSettings.memoryLabelStyle.swapTitle(percent: percent),
                    color: currentMemoryStatus.swapLevel.menuColor
                )
            )
        }

        if components.isEmpty {
            components.append(MenuBarComponent(title: "T", color: .labelColor))
        }

        return MenuBarContent(
            components: components,
            temperatureState: temperatureState,
            memoryStatus: currentMemoryStatus,
            settings: menuBarSettings
        )
    }

    private func attributedTitle(for content: MenuBarContent) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13.5, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributedTitle = NSMutableAttributedString()

        for (index, component) in content.components.enumerated() {
            if index > 0 {
                attributedTitle.append(
                    NSAttributedString(
                        string: "  ",
                        attributes: [
                            .font: font,
                            .foregroundColor: NSColor.tertiaryLabelColor,
                            .paragraphStyle: paragraph
                        ]
                    )
                )
            }

            attributedTitle.append(
                NSAttributedString(
                    string: component.title,
                    attributes: [
                        .font: font,
                        .foregroundColor: component.color,
                        .paragraphStyle: paragraph
                    ]
                )
            )
        }

        return attributedTitle
    }
}

private struct MenuBarComponent {
    let title: String
    let color: NSColor
}

private struct MenuBarContent {
    let components: [MenuBarComponent]
    let temperatureState: DisplayState
    let memoryStatus: MemoryUsageStatus
    let settings: MenuBarDisplaySettings

    var plainTitle: String {
        components.map(\.title).joined(separator: "  ")
    }

    var tooltip: String {
        var lines = ["Tempura"]

        if settings.showsTemperature {
            lines.append("Temperature: \(temperatureState.title)")
        }

        if settings.showsMemory {
            lines.append("Memory: \(memoryStatus.isAvailable ? memoryStatus.memoryPercentTitle : "--")")
        }

        if settings.showsSwap {
            lines.append("Swap overflow: \(memoryStatus.isAvailable ? memoryStatus.swapOverflowTitle : "--")")
        }

        if !settings.showsTemperature && !settings.showsMemory && !settings.showsSwap {
            lines.append("No menu bar metrics selected")
        }

        if memoryStatus.isAvailable && (settings.showsMemory || settings.showsSwap) {
            lines.append(memoryStatus.detail)
        }

        return lines.joined(separator: "\n")
    }
}
