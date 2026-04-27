import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    init() {
        let viewController = SettingsViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "General"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.contentMinSize = NSSize(width: 488, height: 430)
        window.setContentSize(NSSize(width: 488, height: 430))
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
    private let versionLabel = NSTextField(labelWithString: "")
    private let updateButton = NSButton(title: "Check for Updates", target: nil, action: nil)
    private let quitButton = NSButton(title: "Quit Tempura", target: NSApp, action: #selector(NSApplication.terminate(_:)))

    override func loadView() {
        let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 488, height: 430))
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

        let aboutSection = makeSection(
            title: "ABOUT",
            views: [
                makeAboutStack()
            ]
        )

        let firstSeparator = makeSeparator()
        let secondSeparator = makeSeparator()
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)

        let quitRow = NSStackView(views: [NSView(), quitButton])
        quitRow.orientation = .horizontal
        quitRow.alignment = .centerY

        let stack = NSStackView(views: [
            systemSection,
            firstSeparator,
            updatesSection,
            secondSeparator,
            aboutSection,
            spacer,
            quitRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 34, left: 36, bottom: 28, right: 36)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            systemSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -72),
            firstSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -72),
            updatesSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -72),
            secondSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -72),
            aboutSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -72),
            quitRow.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -72),
            quitButton.widthAnchor.constraint(equalToConstant: 120)
        ])

        refreshState()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshState()
    }

    private func configureControls() {
        launchAtLoginCheckbox.font = .systemFont(ofSize: 13, weight: .semibold)
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        launchAtLoginStatusLabel.font = .systemFont(ofSize: 11, weight: .regular)
        launchAtLoginStatusLabel.textColor = .secondaryLabelColor
        launchAtLoginStatusLabel.lineBreakMode = .byTruncatingTail

        versionLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor

        updateButton.bezelStyle = .rounded
        updateButton.controlSize = .regular
        updateButton.font = .systemFont(ofSize: 13, weight: .medium)
        updateButton.toolTip = "Open the Tempura releases page"
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates(_:))

        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .regular
        quitButton.font = .systemFont(ofSize: 13, weight: .medium)
    }

    private func makeSection(title: String, views: [NSView]) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
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
        let titleLabel = NSTextField(labelWithString: "Manual Updates")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor

        let helpLabel = NSTextField(
            labelWithString: "Opens the latest GitHub release page only when you click the button."
        )
        helpLabel.font = .systemFont(ofSize: 11, weight: .regular)
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.lineBreakMode = .byTruncatingTail

        let textStack = NSStackView(views: [titleLabel, helpLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        let row = NSStackView(views: [textStack, NSView(), updateButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        NSLayoutConstraint.activate([
            textStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 250),
            updateButton.widthAnchor.constraint(equalToConstant: 140)
        ])

        return row
    }

    private func makeAboutStack() -> NSStackView {
        let nameLabel = NSTextField(labelWithString: "Tempura")
        nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        nameLabel.textColor = .labelColor

        let descriptionLabel = NSTextField(labelWithString: "Local macOS temperature monitor. MIT License.")
        descriptionLabel.font = .systemFont(ofSize: 11, weight: .regular)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.lineBreakMode = .byTruncatingTail

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

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func refreshState() {
        launchAtLoginCheckbox.state = LaunchAtLoginController.isEnabled ? .on : .off
        launchAtLoginStatusLabel.stringValue = LaunchAtLoginController.statusMessage
        versionLabel.stringValue = applicationVersionText
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        do {
            try LaunchAtLoginController.setEnabled(sender.state == .on)
        } catch {
            showLaunchAtLoginError(error)
        }

        refreshState()
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
