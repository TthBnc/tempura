import AppKit
import TempuraCore

@MainActor
final class ThermalPanelViewController: NSViewController {
    static let preferredContentSize = NSSize(width: 300, height: 348)

    private let currentValueLabel = NSTextField(labelWithString: "--°C")
    private let sourceLabel = NSTextField(labelWithString: "No reading")
    private let chartView = ThermalChartView()
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Open at Login", target: nil, action: nil)
    private let launchAtLoginStatusLabel = NSTextField(labelWithString: "")
    private let aboutButton = NSButton()
    private let updateButton = NSButton()
    private let quitButton = NSButton()

    override func loadView() {
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.preferredContentSize))
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        view = visualEffectView

        configureLabels()
        configureUtilityControls()
        configureQuitButton()

        let titleLabel = NSTextField(labelWithString: "Thermal")
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        let windowLabel = NSTextField(labelWithString: "Last 60s")
        windowLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        windowLabel.textColor = .tertiaryLabelColor

        let headerStack = NSStackView(views: [titleLabel, NSView(), windowLabel])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY

        let valueStack = NSStackView(views: [currentValueLabel, sourceLabel])
        valueStack.orientation = .vertical
        valueStack.alignment = .left
        valueStack.spacing = 1

        let separator = NSBox()
        separator.boxType = .separator

        let utilityStack = makeUtilityStack()

        let quitSeparator = NSBox()
        quitSeparator.boxType = .separator

        let stack = NSStackView(views: [
            headerStack,
            valueStack,
            chartView,
            separator,
            utilityStack,
            quitSeparator,
            quitButton
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 12, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            headerStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            valueStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            chartView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            chartView.heightAnchor.constraint(equalToConstant: 112),
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            utilityStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            quitSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            quitButton.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28)
        ])

        refreshLaunchAtLoginState()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshLaunchAtLoginState()
    }

    func update(samples: [TemperatureSample], currentReading: TemperatureReading?) {
        let displayState = DisplayState(reading: currentReading)
        currentValueLabel.stringValue = displayState.title
        currentValueLabel.textColor = displayState.bucket.chartColor

        if let currentReading {
            let source = currentReading.sourceName ?? currentReading.sourceGroup.rawValue
            sourceLabel.stringValue = "\(currentReading.sourceKey) · \(source)"
        } else {
            sourceLabel.stringValue = "No reading"
        }

        chartView.samples = samples
    }

    private func configureLabels() {
        currentValueLabel.font = .monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        currentValueLabel.textColor = .disabledControlTextColor
        currentValueLabel.lineBreakMode = .byClipping

        sourceLabel.font = .systemFont(ofSize: 11, weight: .regular)
        sourceLabel.textColor = .tertiaryLabelColor
        sourceLabel.lineBreakMode = .byTruncatingTail
    }

    private func configureUtilityControls() {
        launchAtLoginCheckbox.font = .systemFont(ofSize: 13, weight: .regular)
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        launchAtLoginStatusLabel.font = .systemFont(ofSize: 11, weight: .regular)
        launchAtLoginStatusLabel.textColor = .tertiaryLabelColor
        launchAtLoginStatusLabel.lineBreakMode = .byTruncatingTail

        aboutButton.title = "About"
        aboutButton.bezelStyle = .rounded
        aboutButton.controlSize = .regular
        aboutButton.font = .systemFont(ofSize: 13, weight: .regular)
        aboutButton.target = self
        aboutButton.action = #selector(showAbout(_:))

        updateButton.title = "Check for Updates"
        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .regular
        updateButton.font = .systemFont(ofSize: 13, weight: .regular)
        updateButton.toolTip = "Open the Tempura releases page"
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates(_:))
    }

    private func makeUtilityStack() -> NSStackView {
        let launchStack = NSStackView(views: [launchAtLoginCheckbox, launchAtLoginStatusLabel])
        launchStack.orientation = .vertical
        launchStack.alignment = .leading
        launchStack.spacing = 1

        let actionStack = NSStackView(views: [aboutButton, updateButton])
        actionStack.orientation = .horizontal
        actionStack.alignment = .centerY
        actionStack.spacing = 8
        actionStack.distribution = .fill

        let stack = NSStackView(views: [launchStack, actionStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        NSLayoutConstraint.activate([
            launchStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            launchAtLoginStatusLabel.widthAnchor.constraint(equalTo: launchStack.widthAnchor),
            actionStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            aboutButton.widthAnchor.constraint(equalToConstant: 84),
            updateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])

        return stack
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginCheckbox.state = LaunchAtLoginController.isEnabled ? .on : .off
        launchAtLoginStatusLabel.stringValue = LaunchAtLoginController.statusMessage
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        do {
            try LaunchAtLoginController.setEnabled(sender.state == .on)
        } catch {
            showLaunchAtLoginError(error)
        }

        refreshLaunchAtLoginState()
    }

    @objc private func showAbout(_ sender: Any?) {
        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "Tempura"
        alert.informativeText = "\(applicationVersionText)\nLocal macOS temperature monitor.\nMIT License."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        guard let url = URL(string: "https://github.com/TthBnc/tempura/releases/latest") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func showLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "Could Not Update Open at Login"
        alert.informativeText = error.localizedDescription
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private var applicationVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return "Version \(version) (\(build))"
        case let (version?, _) where !version.isEmpty:
            return "Version \(version)"
        default:
            return "Development Build"
        }
    }

    private func configureQuitButton() {
        quitButton.title = "Quit Tempura"
        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .regular
        quitButton.font = .systemFont(ofSize: 13, weight: .medium)
        quitButton.target = NSApp
        quitButton.action = #selector(NSApplication.terminate(_:))
    }
}
