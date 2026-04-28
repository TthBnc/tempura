import AppKit
import TempuraCore

@MainActor
final class ThermalPanelViewController: NSViewController {
    static let preferredContentSize = NSSize(width: 300, height: 338)

    var settingsRequested: (() -> Void)?

    private let currentValueLabel = NSTextField(labelWithString: "--°C")
    private let sourceLabel = NSTextField(labelWithString: "No reading")
    private let chartView = ThermalChartView()
    private let throttleView = ThrottleRiskView()
    private let settingsButton = NSButton()
    private let quitButton = NSButton()
    private var temperatureUnit = TemperatureUnit.current

    override func loadView() {
        let backdropView = PanelGlassBackdropView(
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

        let separator = NSBox()
        separator.boxType = .separator

        let actionStack = makeActionStack()

        let stack = NSStackView(views: [
            headerStack,
            valueStack,
            chartView,
            throttleView,
            separator,
            actionStack
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 12, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        backdropView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: backdropView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: backdropView.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: backdropView.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: backdropView.contentView.bottomAnchor),

            headerStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            valueStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            chartView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            chartView.heightAnchor.constraint(equalToConstant: 112),
            throttleView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            throttleView.heightAnchor.constraint(equalToConstant: 54),
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            actionStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28)
        ])
    }

    func setTemperatureUnit(_ unit: TemperatureUnit) {
        temperatureUnit = unit
        chartView.temperatureUnit = unit
    }

    func update(
        samples: [TemperatureSample],
        currentReading: TemperatureReading?,
        throttleStatus: ThrottleStatus
    ) {
        let displayState = DisplayState(reading: currentReading, unit: temperatureUnit)
        currentValueLabel.stringValue = displayState.title
        currentValueLabel.textColor = displayState.bucket.chartColor

        if let currentReading {
            let source = currentReading.sourceName ?? currentReading.sourceGroup.rawValue
            sourceLabel.stringValue = "\(currentReading.sourceKey) · \(source)"
        } else {
            sourceLabel.stringValue = "No reading"
        }

        chartView.samples = samples
        throttleView.status = throttleStatus
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

private final class ThrottleRiskView: NSView {
    var status = ThrottleStatus.unavailable {
        didSet {
            applyStatus()
        }
    }

    private let captionLabel = NSTextField(labelWithString: "Throttle Risk")
    private let riskLabel = NSTextField(labelWithString: ThrottleRisk.unavailable.title)
    private let detailLabel = NSTextField(labelWithString: ThrottleStatus.unavailable.detail)
    private let meterView = ThrottleRiskMeterView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
        configureLabels()
        configureLayout()
        applyStatus()
        applyPalette()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
        configureLabels()
        configureLayout()
        applyStatus()
        applyPalette()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    private func configureView() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.cornerCurve = .continuous
    }

    private func configureLabels() {
        captionLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        captionLabel.textColor = .secondaryLabelColor

        riskLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        riskLabel.alignment = .right
        riskLabel.lineBreakMode = .byTruncatingTail

        detailLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        detailLabel.textColor = .tertiaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
    }

    private func configureLayout() {
        let topStack = NSStackView(views: [captionLabel, NSView(), riskLabel])
        topStack.orientation = .horizontal
        topStack.alignment = .centerY
        topStack.spacing = 8

        let stack = NSStackView(views: [topStack, detailLabel, meterView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            topStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            meterView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            meterView.heightAnchor.constraint(equalToConstant: 5)
        ])
    }

    private func applyStatus() {
        riskLabel.stringValue = status.risk.title
        riskLabel.textColor = status.risk.tintColor
        detailLabel.stringValue = status.detail
        meterView.status = status
    }

    private func applyPalette() {
        let fillAlpha: CGFloat = isDarkAppearance ? 0.18 : 0.24
        layer?.backgroundColor = NSColor.controlBackgroundColor
            .withAlphaComponent(fillAlpha)
            .cgColor
    }

    private var isDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

private final class ThrottleRiskMeterView: NSView {
    var status = ThrottleStatus.unavailable {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let trackRect = bounds.insetBy(dx: 0, dy: 0.5)
        let trackPath = NSBezierPath(
            roundedRect: trackRect,
            xRadius: trackRect.height / 2,
            yRadius: trackRect.height / 2
        )
        NSColor.separatorColor.withAlphaComponent(0.28).setFill()
        trackPath.fill()

        let fillWidth = max(trackRect.width * status.risk.meterProgress, trackRect.height)
        let fillRect = NSRect(
            x: trackRect.minX,
            y: trackRect.minY,
            width: fillWidth,
            height: trackRect.height
        )
        let fillPath = NSBezierPath(
            roundedRect: fillRect,
            xRadius: fillRect.height / 2,
            yRadius: fillRect.height / 2
        )
        status.risk.tintColor.setFill()
        fillPath.fill()
    }
}

private final class PanelGlassBackdropView: NSVisualEffectView {
    let contentView = NSView()

    private let topHighlightView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        configureSurface()
        configureChrome()
        applyGlassPalette()
    }

    required init?(coder: NSCoder) {
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
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    private func configureChrome() {
        [contentView, topHighlightView].forEach { chromeView in
            chromeView.translatesAutoresizingMaskIntoConstraints = false
            chromeView.wantsLayer = true
            addSubview(chromeView)
        }

        topHighlightView.layer?.cornerRadius = 0.5

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),

            topHighlightView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            topHighlightView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            topHighlightView.topAnchor.constraint(equalTo: topAnchor),
            topHighlightView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func applyGlassPalette() {
        let palette = GlassPalette(isDark: isDarkAppearance)
        layer?.backgroundColor = palette.fill.cgColor
        layer?.borderColor = palette.stroke.cgColor
        layer?.borderWidth = 1
        topHighlightView.layer?.backgroundColor = palette.topHighlight.cgColor
    }

    private var isDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

private struct GlassPalette {
    let fill: NSColor
    let stroke: NSColor
    let topHighlight: NSColor

    init(isDark: Bool) {
        if isDark {
            fill = NSColor(calibratedWhite: 1, alpha: 0.02)
            stroke = NSColor(calibratedWhite: 1, alpha: 0.08)
            topHighlight = NSColor(calibratedWhite: 1, alpha: 0.12)
        } else {
            fill = NSColor(calibratedWhite: 1, alpha: 0.20)
            stroke = NSColor(calibratedWhite: 1, alpha: 0.46)
            topHighlight = NSColor(calibratedWhite: 1, alpha: 0.68)
        }
    }
}
