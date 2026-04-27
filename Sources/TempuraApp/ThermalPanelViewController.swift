import AppKit
import TempuraCore

@MainActor
final class ThermalPanelViewController: NSViewController {
    static let collapsedContentSize = NSSize(width: 300, height: 276)
    static let expandedContentSize = NSSize(width: 300, height: 402)
    static let preferredContentSize = collapsedContentSize

    var contentSizeDidChange: ((NSSize) -> Void)?

    private let currentValueLabel = NSTextField(labelWithString: "--°C")
    private let sourceLabel = NSTextField(labelWithString: "No reading")
    private let chartView = ThermalChartView()
    private let appNameLabel = NSTextField(labelWithString: "Tempura")
    private let appVersionLabel = NSTextField(labelWithString: "")
    private let appDescriptionLabel = NSTextField(labelWithString: "Local macOS temperature monitor. MIT License.")
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Open at Login", target: nil, action: nil)
    private let launchAtLoginStatusLabel = NSTextField(labelWithString: "")
    private let settingsButton = NSButton()
    private let updateButton = NSButton()
    private let quitButton = NSButton()
    private let settingsStack = NSStackView()

    private var settingsAreVisible = false

    override func loadView() {
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.collapsedContentSize))
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        view = visualEffectView

        configureLabels()
        configureSettingsSection()
        configureButtons()

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

        let actionStack = makeActionStack()

        let stack = NSStackView(views: [
            headerStack,
            valueStack,
            chartView,
            separator,
            settingsStack,
            actionStack
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
            settingsStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            actionStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28)
        ])

        refreshAppInfo()
        refreshLaunchAtLoginState()
        applySettingsVisibility(false, notify: false)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshAppInfo()
        refreshLaunchAtLoginState()
    }

    func collapseSettings() {
        applySettingsVisibility(false, notify: true)
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

        appNameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        appNameLabel.textColor = .labelColor

        appVersionLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        appVersionLabel.textColor = .secondaryLabelColor
        appVersionLabel.lineBreakMode = .byTruncatingTail

        appDescriptionLabel.font = .systemFont(ofSize: 11, weight: .regular)
        appDescriptionLabel.textColor = .tertiaryLabelColor
        appDescriptionLabel.lineBreakMode = .byTruncatingTail

        launchAtLoginStatusLabel.font = .systemFont(ofSize: 11, weight: .regular)
        launchAtLoginStatusLabel.textColor = .tertiaryLabelColor
        launchAtLoginStatusLabel.lineBreakMode = .byTruncatingTail
    }

    private func configureSettingsSection() {
        let aboutStack = NSStackView(views: [appNameLabel, appVersionLabel, appDescriptionLabel])
        aboutStack.orientation = .vertical
        aboutStack.alignment = .leading
        aboutStack.spacing = 1

        launchAtLoginCheckbox.font = .systemFont(ofSize: 13, weight: .regular)
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        let launchStack = NSStackView(views: [launchAtLoginCheckbox, launchAtLoginStatusLabel])
        launchStack.orientation = .vertical
        launchStack.alignment = .leading
        launchStack.spacing = 1

        settingsStack.orientation = .vertical
        settingsStack.alignment = .leading
        settingsStack.spacing = 8
        settingsStack.setViews([aboutStack, launchStack, updateButton], in: .top)

        NSLayoutConstraint.activate([
            aboutStack.widthAnchor.constraint(equalTo: settingsStack.widthAnchor),
            appVersionLabel.widthAnchor.constraint(equalTo: aboutStack.widthAnchor),
            appDescriptionLabel.widthAnchor.constraint(equalTo: aboutStack.widthAnchor),
            launchStack.widthAnchor.constraint(equalTo: settingsStack.widthAnchor),
            launchAtLoginStatusLabel.widthAnchor.constraint(equalTo: launchStack.widthAnchor),
            updateButton.widthAnchor.constraint(equalTo: settingsStack.widthAnchor)
        ])
    }

    private func configureButtons() {
        configureUtilityButton(
            settingsButton,
            title: "Settings",
            symbolName: "gearshape",
            action: #selector(toggleSettings(_:))
        )

        configureUtilityButton(
            updateButton,
            title: "Check for Updates",
            symbolName: "arrow.triangle.2.circlepath",
            action: #selector(checkForUpdates(_:))
        )
        updateButton.toolTip = "Open the Tempura releases page"

        configureUtilityButton(
            quitButton,
            title: "Quit Tempura",
            symbolName: "power",
            action: #selector(NSApplication.terminate(_:)),
            target: NSApp,
            weight: .medium
        )
    }

    private func configureUtilityButton(
        _ button: NSButton,
        title: String,
        symbolName: String,
        action: Selector,
        target: AnyObject? = nil,
        weight: NSFont.Weight = .regular
    ) {
        button.title = title
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = .systemFont(ofSize: 13, weight: weight)
        button.target = target ?? self
        button.action = action
    }

    private func makeActionStack() -> NSStackView {
        let stack = NSStackView(views: [settingsButton, quitButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.distribution = .fill

        NSLayoutConstraint.activate([
            settingsButton.widthAnchor.constraint(equalToConstant: 108),
            quitButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 156)
        ])

        return stack
    }

    private func refreshAppInfo() {
        appVersionLabel.stringValue = applicationVersionText
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginCheckbox.state = LaunchAtLoginController.isEnabled ? .on : .off
        launchAtLoginStatusLabel.stringValue = LaunchAtLoginController.statusMessage
    }

    private func applySettingsVisibility(_ visible: Bool, notify: Bool) {
        settingsAreVisible = visible
        settingsStack.isHidden = !visible
        settingsButton.title = visible ? "Done" : "Settings"
        settingsButton.image = NSImage(
            systemSymbolName: visible ? "checkmark" : "gearshape",
            accessibilityDescription: settingsButton.title
        )

        let size = visible ? Self.expandedContentSize : Self.collapsedContentSize
        preferredContentSize = size
        view.setFrameSize(size)

        if notify {
            contentSizeDidChange?(size)
        }
    }

    @objc private func toggleSettings(_ sender: Any?) {
        applySettingsVisibility(!settingsAreVisible, notify: true)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        do {
            try LaunchAtLoginController.setEnabled(sender.state == .on)
        } catch {
            showLaunchAtLoginError(error)
        }

        refreshLaunchAtLoginState()
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
            return "Version \(version) · Build \(build)"
        case let (version?, _) where !version.isEmpty:
            return "Version \(version)"
        default:
            return "Development Build"
        }
    }
}
