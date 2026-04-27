import AppKit
import TempuraCore

@MainActor
final class ThermalPanelViewController: NSViewController {
    static let preferredContentSize = NSSize(width: 300, height: 276)

    var settingsRequested: (() -> Void)?

    private let currentValueLabel = NSTextField(labelWithString: "--°C")
    private let sourceLabel = NSTextField(labelWithString: "No reading")
    private let chartView = ThermalChartView()
    private let settingsButton = NSButton()
    private let quitButton = NSButton()

    override func loadView() {
        let backdropView = PanelGlassSurfaceView(
            role: .backdrop,
            frame: NSRect(origin: .zero, size: Self.preferredContentSize)
        )
        view = backdropView

        configureLabels()
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

        let readingSurface = PanelGlassSurfaceView(role: .reading)
        let readingStack = NSStackView(views: [
            headerStack,
            valueStack,
            chartView
        ])
        readingStack.orientation = .vertical
        readingStack.alignment = .leading
        readingStack.spacing = 8
        readingStack.edgeInsets = NSEdgeInsets(top: 9, left: 6, bottom: 8, right: 6)
        readingStack.translatesAutoresizingMaskIntoConstraints = false
        readingSurface.contentView.addSubview(readingStack)

        let actionStack = makeActionStack()
        let actionSurface = PanelGlassSurfaceView(role: .actions)
        let actionContainerStack = NSStackView(views: [actionStack])
        actionContainerStack.orientation = .vertical
        actionContainerStack.alignment = .leading
        actionContainerStack.edgeInsets = NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        actionContainerStack.translatesAutoresizingMaskIntoConstraints = false
        actionSurface.contentView.addSubview(actionContainerStack)

        let stack = NSStackView(views: [
            readingSurface,
            actionSurface
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false

        backdropView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: backdropView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: backdropView.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: backdropView.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: backdropView.contentView.bottomAnchor),

            readingSurface.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16),
            actionSurface.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -16),
            actionSurface.heightAnchor.constraint(equalToConstant: 42),

            readingStack.leadingAnchor.constraint(equalTo: readingSurface.contentView.leadingAnchor),
            readingStack.trailingAnchor.constraint(equalTo: readingSurface.contentView.trailingAnchor),
            readingStack.topAnchor.constraint(equalTo: readingSurface.contentView.topAnchor),
            readingStack.bottomAnchor.constraint(equalTo: readingSurface.contentView.bottomAnchor),

            headerStack.widthAnchor.constraint(equalTo: readingStack.widthAnchor, constant: -12),
            valueStack.widthAnchor.constraint(equalTo: readingStack.widthAnchor, constant: -12),
            chartView.widthAnchor.constraint(equalTo: readingStack.widthAnchor, constant: -12),
            chartView.heightAnchor.constraint(equalToConstant: 112),

            actionContainerStack.leadingAnchor.constraint(equalTo: actionSurface.contentView.leadingAnchor),
            actionContainerStack.trailingAnchor.constraint(equalTo: actionSurface.contentView.trailingAnchor),
            actionContainerStack.topAnchor.constraint(equalTo: actionSurface.contentView.topAnchor),
            actionContainerStack.bottomAnchor.constraint(equalTo: actionSurface.contentView.bottomAnchor),
            actionStack.widthAnchor.constraint(equalTo: actionContainerStack.widthAnchor, constant: -10)
        ])
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

    private func configureButtons() {
        configureUtilityButton(
            settingsButton,
            title: "Settings",
            action: #selector(openSettings(_:))
        )

        configureUtilityButton(
            quitButton,
            title: "Quit Tempura",
            action: #selector(NSApplication.terminate(_:)),
            target: NSApp,
            weight: .medium
        )
    }

    private func configureUtilityButton(
        _ button: NSButton,
        title: String,
        action: Selector,
        target: AnyObject? = nil,
        weight: NSFont.Weight = .regular
    ) {
        button.title = title
        button.image = nil
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

    @objc private func openSettings(_ sender: Any?) {
        settingsRequested?()
    }
}

private final class PanelGlassSurfaceView: NSVisualEffectView {
    enum Role {
        case backdrop
        case reading
        case actions

        var material: NSVisualEffectView.Material {
            switch self {
            case .backdrop:
                return .popover
            case .reading:
                return .contentBackground
            case .actions:
                return .menu
            }
        }

        var blendingMode: NSVisualEffectView.BlendingMode {
            switch self {
            case .backdrop:
                return .behindWindow
            case .reading, .actions:
                return .withinWindow
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .backdrop:
                return 18
            case .reading:
                return 14
            case .actions:
                return 12
            }
        }
    }

    let contentView = NSView()

    private let role: Role
    private let topHighlightView = NSView()
    private let bottomShadeView = NSView()

    init(role: Role, frame frameRect: NSRect = .zero) {
        self.role = role

        super.init(frame: frameRect)

        configureSurface()
        configureChrome()
        applyGlassPalette()
    }

    required init?(coder: NSCoder) {
        self.role = .reading

        super.init(coder: coder)

        configureSurface()
        configureChrome()
        applyGlassPalette()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyGlassPalette()
    }

    private func configureSurface() {
        material = role.material
        blendingMode = role.blendingMode
        state = .active
        wantsLayer = true
        layer?.cornerRadius = role.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    private func configureChrome() {
        [contentView, topHighlightView, bottomShadeView].forEach { chromeView in
            chromeView.translatesAutoresizingMaskIntoConstraints = false
            chromeView.wantsLayer = true
            addSubview(chromeView)
        }

        topHighlightView.layer?.cornerRadius = 0.5
        bottomShadeView.layer?.cornerRadius = 0.5

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            topHighlightView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: role.cornerRadius * 0.58),
            topHighlightView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(role.cornerRadius * 0.58)),
            topHighlightView.topAnchor.constraint(equalTo: topAnchor),
            topHighlightView.heightAnchor.constraint(equalToConstant: 1),

            bottomShadeView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: role.cornerRadius * 0.72),
            bottomShadeView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(role.cornerRadius * 0.72)),
            bottomShadeView.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomShadeView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func applyGlassPalette() {
        let palette = GlassPalette(role: role, isDark: isDarkAppearance)
        layer?.backgroundColor = palette.fill.cgColor
        layer?.borderColor = palette.stroke.cgColor
        layer?.borderWidth = 1
        topHighlightView.layer?.backgroundColor = palette.topHighlight.cgColor
        bottomShadeView.layer?.backgroundColor = palette.bottomShade.cgColor
    }

    private var isDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

private struct GlassPalette {
    let fill: NSColor
    let stroke: NSColor
    let topHighlight: NSColor
    let bottomShade: NSColor

    init(role: PanelGlassSurfaceView.Role, isDark: Bool) {
        switch (role, isDark) {
        case (.backdrop, true):
            fill = NSColor(calibratedWhite: 1, alpha: 0.045)
            stroke = NSColor(calibratedWhite: 1, alpha: 0.14)
            topHighlight = NSColor(calibratedWhite: 1, alpha: 0.18)
            bottomShade = NSColor(calibratedWhite: 0, alpha: 0.16)
        case (.reading, true):
            fill = NSColor(calibratedWhite: 1, alpha: 0.085)
            stroke = NSColor(calibratedWhite: 1, alpha: 0.16)
            topHighlight = NSColor(calibratedWhite: 1, alpha: 0.22)
            bottomShade = NSColor(calibratedWhite: 0, alpha: 0.14)
        case (.actions, true):
            fill = NSColor(calibratedWhite: 1, alpha: 0.07)
            stroke = NSColor(calibratedWhite: 1, alpha: 0.13)
            topHighlight = NSColor(calibratedWhite: 1, alpha: 0.16)
            bottomShade = NSColor(calibratedWhite: 0, alpha: 0.12)
        case (.backdrop, false):
            fill = NSColor(calibratedWhite: 1, alpha: 0.30)
            stroke = NSColor(calibratedWhite: 1, alpha: 0.68)
            topHighlight = NSColor(calibratedWhite: 1, alpha: 0.86)
            bottomShade = NSColor(calibratedWhite: 0, alpha: 0.06)
        case (.reading, false):
            fill = NSColor(calibratedWhite: 1, alpha: 0.42)
            stroke = NSColor(calibratedWhite: 1, alpha: 0.76)
            topHighlight = NSColor(calibratedWhite: 1, alpha: 0.92)
            bottomShade = NSColor(calibratedWhite: 0, alpha: 0.055)
        case (.actions, false):
            fill = NSColor(calibratedWhite: 1, alpha: 0.34)
            stroke = NSColor(calibratedWhite: 1, alpha: 0.66)
            topHighlight = NSColor(calibratedWhite: 1, alpha: 0.84)
            bottomShade = NSColor(calibratedWhite: 0, alpha: 0.05)
        }
    }
}
