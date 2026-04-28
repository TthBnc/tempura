import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    init() {
        let viewController = SettingsViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "General"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.contentMinSize = NSSize(
            width: TempuraDesign.Layout.settingsWidth,
            height: TempuraDesign.Layout.settingsHeight
        )
        window.setContentSize(window.contentMinSize)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func showSettingsWindow() {
        guard let window else {
            return
        }

        if !window.isVisible {
            window.center()
        }

        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class SettingsViewController: NSViewController {
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Start at Login", target: nil, action: nil)
    private let launchAtLoginStatusLabel = NSTextField(labelWithString: "")
    private let menuBarTemperatureCheckbox = NSButton(checkboxWithTitle: "Temperature", target: nil, action: nil)
    private let menuBarMemoryCheckbox = NSButton(checkboxWithTitle: "Memory", target: nil, action: nil)
    private let menuBarSwapCheckbox = NSButton(checkboxWithTitle: "Swap", target: nil, action: nil)
    private let menuBarLabelStyleControl = NSSegmentedControl(
        labels: MenuBarMemoryLabelStyle.allCases.map(\.displayName),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let temperatureUnitControl = NSSegmentedControl(
        labels: ["°C", "°F"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let versionLabel = NSTextField(labelWithString: "")
    private let updateButton = NSButton(title: "Check for Updates", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit Tempura", target: NSApp, action: #selector(NSApplication.terminate(_:)))

    override func loadView() {
        let visualEffectView = NSVisualEffectView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: TempuraDesign.Layout.settingsWidth,
                height: TempuraDesign.Layout.settingsHeight
            )
        )
        visualEffectView.material = .windowBackground
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        view = visualEffectView

        configureControls()

        let systemSection = makeSection(
            title: "SYSTEM",
            views: [
                makeControlStack(
                    control: launchAtLoginCheckbox,
                    help: launchAtLoginStatusLabel
                )
            ]
        )

        let updatesSection = makeSection(
            title: "UPDATES",
            views: [
                makeUpdateRow()
            ]
        )

        let displaySection = makeSection(
            title: "DISPLAY",
            views: [
                makeTemperatureUnitRow(),
                makeMenuBarMetricsStack(),
                makeMenuBarLabelStyleRow()
            ]
        )

        let aboutSection = makeSection(
            title: "ABOUT",
            views: [
                makeAboutStack()
            ]
        )

        let firstSeparator = makeSeparator()
        let secondSeparator = makeSeparator()
        let thirdSeparator = makeSeparator()
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        let quitRow = NSStackView(views: [NSView(), quitButton])
        quitRow.orientation = .horizontal
        quitRow.alignment = .centerY

        let stack = NSStackView(views: [
            systemSection,
            firstSeparator,
            displaySection,
            secondSeparator,
            updatesSection,
            thirdSeparator,
            aboutSection,
            spacer,
            quitRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = TempuraDesign.Layout.settingsSectionSpacing
        stack.edgeInsets = NSEdgeInsets(
            top: TempuraDesign.Layout.settingsTopInset,
            left: TempuraDesign.Layout.settingsHorizontalInset,
            bottom: TempuraDesign.Layout.settingsBottomInset,
            right: TempuraDesign.Layout.settingsHorizontalInset
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            systemSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.settingsHorizontalInset * 2),
            firstSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.settingsHorizontalInset * 2),
            displaySection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.settingsHorizontalInset * 2),
            secondSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.settingsHorizontalInset * 2),
            updatesSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.settingsHorizontalInset * 2),
            thirdSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.settingsHorizontalInset * 2),
            aboutSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.settingsHorizontalInset * 2),
            quitRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.settingsHorizontalInset * 2),
            quitButton.widthAnchor.constraint(equalToConstant: 120)
        ])

        refreshState()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshState()
    }

    private func configureControls() {
        launchAtLoginCheckbox.font = TempuraDesign.Font.settingsTitle
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))
        launchAtLoginCheckbox.setAccessibilityLabel("Start at Login")
        launchAtLoginCheckbox.setAccessibilityHelp("Automatically opens Tempura when you log in.")

        launchAtLoginStatusLabel.font = TempuraDesign.Font.settingsHelp
        launchAtLoginStatusLabel.textColor = .secondaryLabelColor
        launchAtLoginStatusLabel.lineBreakMode = .byWordWrapping
        launchAtLoginStatusLabel.maximumNumberOfLines = 2

        [menuBarTemperatureCheckbox, menuBarMemoryCheckbox, menuBarSwapCheckbox].forEach { checkbox in
            checkbox.font = TempuraDesign.Font.button
            checkbox.target = self
            checkbox.action = #selector(changeMenuBarMetrics(_:))
        }
        menuBarTemperatureCheckbox.setAccessibilityHelp("Shows or hides temperature in the menu bar.")
        menuBarMemoryCheckbox.setAccessibilityHelp("Shows or hides memory usage in the menu bar.")
        menuBarSwapCheckbox.setAccessibilityHelp("Shows or hides swap overflow in the menu bar.")

        menuBarLabelStyleControl.target = self
        menuBarLabelStyleControl.action = #selector(changeMenuBarLabelStyle(_:))
        menuBarLabelStyleControl.segmentStyle = .rounded
        menuBarLabelStyleControl.setWidth(72, forSegment: 0)
        menuBarLabelStyleControl.setWidth(72, forSegment: 1)
        menuBarLabelStyleControl.setWidth(88, forSegment: 2)
        menuBarLabelStyleControl.setAccessibilityLabel("Memory and Swap Labels")
        menuBarLabelStyleControl.setAccessibilityHelp("Controls how memory and swap values are labeled in the menu bar.")

        temperatureUnitControl.target = self
        temperatureUnitControl.action = #selector(changeTemperatureUnit(_:))
        temperatureUnitControl.segmentStyle = .rounded
        temperatureUnitControl.setWidth(52, forSegment: 0)
        temperatureUnitControl.setWidth(52, forSegment: 1)
        temperatureUnitControl.setAccessibilityLabel("Temperature Unit")
        temperatureUnitControl.setAccessibilityHelp("Sets whether temperatures are shown in Celsius or Fahrenheit.")

        versionLabel.font = TempuraDesign.Font.settingsVersion
        versionLabel.textColor = .secondaryLabelColor

        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .regular
        updateButton.font = TempuraDesign.Font.buttonStrong
        updateButton.toolTip = "Open the Tempura releases page"
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates(_:))
        updateButton.setAccessibilityLabel("Check for Updates")
        updateButton.setAccessibilityHelp("Opens the latest Tempura release page in your browser.")

        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .regular
        quitButton.font = TempuraDesign.Font.buttonStrong
        quitButton.setAccessibilityLabel("Quit Tempura")
    }

    private func makeSection(title: String, views: [NSView]) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = TempuraDesign.Font.settingsSection
        titleLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel] + views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10

        for view in views {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        return stack
    }

    private func makeControlStack(control: NSView, help: NSTextField) -> NSStackView {
        let stack = NSStackView(views: [control, help])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        NSLayoutConstraint.activate([
            help.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        return stack
    }

    private func makeUpdateRow() -> NSStackView {
        let titleLabel = makeTitleLabel("Manual Updates")
        let helpLabel = makeHelpLabel("Opens the latest GitHub release page only when you click the button.")

        let textStack = NSStackView(views: [titleLabel, helpLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let row = NSStackView(views: [textStack, NSView(), updateButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = TempuraDesign.Layout.settingsRowSpacing

        NSLayoutConstraint.activate([
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 250),
            updateButton.widthAnchor.constraint(equalToConstant: 140)
        ])

        return row
    }

    private func makeTemperatureUnitRow() -> NSStackView {
        let titleLabel = makeTitleLabel("Temperature Unit")
        let helpLabel = makeHelpLabel("Controls the menu bar, panel value, and chart labels.")

        let textStack = NSStackView(views: [titleLabel, helpLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let row = NSStackView(views: [textStack, NSView(), temperatureUnitControl])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = TempuraDesign.Layout.settingsRowSpacing

        NSLayoutConstraint.activate([
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 250),
            temperatureUnitControl.widthAnchor.constraint(equalToConstant: 108)
        ])

        return row
    }

    private func makeMenuBarMetricsStack() -> NSStackView {
        let titleLabel = makeTitleLabel("Menu Bar Metrics")
        let helpLabel = makeHelpLabel("Choose any combination to show beside the Tempura menu.")

        let checkboxStack = NSStackView(views: [
            menuBarTemperatureCheckbox,
            menuBarMemoryCheckbox,
            menuBarSwapCheckbox
        ])
        checkboxStack.orientation = .horizontal
        checkboxStack.alignment = .centerY
        checkboxStack.spacing = 18

        let stack = NSStackView(views: [titleLabel, helpLabel, checkboxStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        NSLayoutConstraint.activate([
            helpLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            checkboxStack.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor)
        ])

        return stack
    }

    private func makeMenuBarLabelStyleRow() -> NSStackView {
        let titleLabel = makeTitleLabel("Memory and Swap Labels")
        let helpLabel = makeHelpLabel("Full shows RAM/SWAP, Slim shows M/S, Compact shows percentages only.")

        let textStack = NSStackView(views: [titleLabel, helpLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let row = NSStackView(views: [textStack, NSView(), menuBarLabelStyleControl])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = TempuraDesign.Layout.settingsRowSpacing

        NSLayoutConstraint.activate([
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 190),
            menuBarLabelStyleControl.widthAnchor.constraint(equalToConstant: 236)
        ])

        return row
    }

    private func makeAboutStack() -> NSStackView {
        let nameLabel = makeTitleLabel("Tempura")

        let descriptionLabel = makeHelpLabel("Local macOS temperature monitor. MIT License.")

        let stack = NSStackView(views: [nameLabel, versionLabel, descriptionLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        NSLayoutConstraint.activate([
            versionLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            descriptionLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        return stack
    }

    private func makeTitleLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = TempuraDesign.Font.settingsTitle
        label.textColor = .labelColor
        return label
    }

    private func makeHelpLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = TempuraDesign.Font.settingsHelp
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        return label
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func refreshState() {
        launchAtLoginCheckbox.state = LaunchAtLoginController.isEnabled ? .on : .off
        launchAtLoginStatusLabel.stringValue = LaunchAtLoginController.statusMessage
        temperatureUnitControl.selectedSegment = TemperatureUnit.current == .celsius ? 0 : 1
        let menuBarSettings = MenuBarDisplaySettings.current
        menuBarTemperatureCheckbox.state = menuBarSettings.showsTemperature ? .on : .off
        menuBarMemoryCheckbox.state = menuBarSettings.showsMemory ? .on : .off
        menuBarSwapCheckbox.state = menuBarSettings.showsSwap ? .on : .off
        menuBarLabelStyleControl.selectedSegment = MenuBarMemoryLabelStyle.allCases
            .firstIndex(of: menuBarSettings.memoryLabelStyle) ?? 1
        versionLabel.stringValue = applicationVersionText
        temperatureUnitControl.setAccessibilityValue(TemperatureUnit.current.displayName)
        menuBarLabelStyleControl.setAccessibilityValue(menuBarSettings.memoryLabelStyle.displayName)
        versionLabel.setAccessibilityLabel(applicationVersionText)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        do {
            try LaunchAtLoginController.setEnabled(sender.state == .on)
        } catch {
            showLaunchAtLoginError(error)
        }

        refreshState()
    }

    @objc private func changeTemperatureUnit(_ sender: NSSegmentedControl) {
        TemperatureUnit.current = sender.selectedSegment == 1 ? .fahrenheit : .celsius
        refreshState()
    }

    @objc private func changeMenuBarMetrics(_ sender: NSButton) {
        saveMenuBarSettingsFromControls()
        refreshState()
    }

    @objc private func changeMenuBarLabelStyle(_ sender: NSSegmentedControl) {
        saveMenuBarSettingsFromControls()
        refreshState()
    }

    private func saveMenuBarSettingsFromControls() {
        let styleIndex = menuBarLabelStyleControl.selectedSegment
        let labelStyle = MenuBarMemoryLabelStyle.allCases.indices.contains(styleIndex)
            ? MenuBarMemoryLabelStyle.allCases[styleIndex]
            : .slim

        MenuBarDisplaySettings.current = MenuBarDisplaySettings(
            showsTemperature: menuBarTemperatureCheckbox.state == .on,
            showsMemory: menuBarMemoryCheckbox.state == .on,
            showsSwap: menuBarSwapCheckbox.state == .on,
            memoryLabelStyle: labelStyle
        )
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        guard let url = URL(string: "https://github.com/TthBnc/tempura/releases/latest") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func showLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "Could Not Update Start at Login"
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
