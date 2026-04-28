import AppKit
import TempuraCore

@MainActor
final class ThermalPanelViewController: NSViewController {
    static let preferredContentSize = NSSize(
        width: TempuraDesign.Layout.panelWidth,
        height: TempuraDesign.Layout.panelHeight
    )

    var settingsRequested: (() -> Void)?

    private let currentValueLabel = NSTextField(labelWithString: "--°C")
    private let sourceLabel = NSTextField(labelWithString: "No reading")
    private let chartView = ThermalChartView()
    private let systemPressureView = SystemPressureView()
    private let settingsButton = NSButton()
    private let quitButton = NSButton()
    private var temperatureUnit = TemperatureUnit.current

    override func loadView() {
        let backdropView = TempuraGlassBackdropView(
            frame: NSRect(origin: .zero, size: Self.preferredContentSize)
        )
        view = backdropView

        configureLabels()
        configureButtons()

        let titleLabel = NSTextField(labelWithString: "Thermal")
        titleLabel.font = TempuraDesign.Font.panelTitle
        titleLabel.textColor = .secondaryLabelColor

        let windowLabel = NSTextField(labelWithString: "Last 60s")
        windowLabel.font = TempuraDesign.Font.panelWindow
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
            systemPressureView,
            separator,
            actionStack
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = TempuraDesign.Layout.panelSpacing
        stack.edgeInsets = NSEdgeInsets(
            top: TempuraDesign.Layout.panelInset,
            left: TempuraDesign.Layout.panelInset,
            bottom: 12,
            right: TempuraDesign.Layout.panelInset
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        backdropView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: backdropView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: backdropView.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: backdropView.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: backdropView.contentView.bottomAnchor),

            headerStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset),
            valueStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset),
            chartView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset),
            chartView.heightAnchor.constraint(equalToConstant: TempuraDesign.Layout.chartHeight),
            systemPressureView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset),
            systemPressureView.heightAnchor.constraint(equalToConstant: TempuraDesign.Layout.systemPressureHeight),
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset),
            actionStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset)
        ])
    }

    func setTemperatureUnit(_ unit: TemperatureUnit) {
        temperatureUnit = unit
        chartView.temperatureUnit = unit
    }

    func update(
        samples: [TemperatureSample],
        currentReading: TemperatureReading?,
        throttleStatus: ThrottleStatus,
        memoryStatus: MemoryUsageStatus
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
        systemPressureView.update(throttleStatus: throttleStatus, memoryStatus: memoryStatus)
    }

    private func configureLabels() {
        currentValueLabel.font = TempuraDesign.Font.primaryValue
        currentValueLabel.textColor = .disabledControlTextColor
        currentValueLabel.lineBreakMode = .byClipping

        sourceLabel.font = TempuraDesign.Font.source
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
        button.font = weight == .medium ? TempuraDesign.Font.buttonStrong : TempuraDesign.Font.button
        button.target = target ?? self
        button.action = action
    }

    private func makeActionStack() -> NSStackView {
        let stack = NSStackView(views: [settingsButton, quitButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = TempuraDesign.Layout.actionSpacing
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

private final class SystemPressureView: TempuraGlassCardView {
    private let captionLabel = NSTextField(labelWithString: "System Pressure")
    private let riskLabel = NSTextField(labelWithString: ThrottleRisk.unavailable.title)
    private let throttleDetailLabel = NSTextField(labelWithString: ThrottleStatus.unavailable.detail)
    private let throttleMeterView = TempuraMeterView()
    private let memoryCaptionLabel = NSTextField(labelWithString: "Memory")
    private let memoryValueLabel = NSTextField(labelWithString: "--")
    private let memoryMeterView = TempuraMeterView()
    private let swapCaptionLabel = NSTextField(labelWithString: "Swap Overflow")
    private let swapValueLabel = NSTextField(labelWithString: "--")
    private let swapMeterView = TempuraMeterView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLabels()
        configureLayout()
        update(throttleStatus: .unavailable, memoryStatus: .unavailable)
        configureAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabels()
        configureLayout()
        update(throttleStatus: .unavailable, memoryStatus: .unavailable)
        configureAccessibility()
    }

    func update(throttleStatus: ThrottleStatus, memoryStatus: MemoryUsageStatus) {
        riskLabel.stringValue = throttleStatus.risk.title
        riskLabel.textColor = throttleStatus.risk.tintColor
        throttleDetailLabel.stringValue = throttleStatus.detail
        throttleMeterView.progress = throttleStatus.risk.meterProgress
        throttleMeterView.tintColor = throttleStatus.risk.tintColor

        memoryValueLabel.stringValue = memoryStatus.isAvailable ? memoryStatus.memoryPercentTitle : "--"
        memoryValueLabel.textColor = memoryStatus.memoryLevel.tintColor
        memoryMeterView.progress = memoryStatus.isAvailable ? CGFloat(memoryStatus.memoryFraction) : 0.08
        memoryMeterView.tintColor = memoryStatus.memoryLevel.tintColor

        swapValueLabel.stringValue = memoryStatus.isAvailable ? memoryStatus.swapOverflowTitle : "--"
        swapValueLabel.textColor = memoryStatus.swapLevel.tintColor
        swapMeterView.progress = memoryStatus.isAvailable ? CGFloat(memoryStatus.swapOverflowFraction) : 0.08
        swapMeterView.tintColor = memoryStatus.swapLevel.tintColor

        setAccessibilityValue(accessibilityValue(throttleStatus: throttleStatus, memoryStatus: memoryStatus))
    }

    private func configureLabels() {
        [captionLabel, memoryCaptionLabel, swapCaptionLabel].forEach { label in
            label.font = TempuraDesign.Font.cardCaption
            label.textColor = .secondaryLabelColor
        }

        riskLabel.font = TempuraDesign.Font.cardValue
        riskLabel.alignment = .right
        riskLabel.lineBreakMode = .byTruncatingTail

        [memoryValueLabel, swapValueLabel].forEach { label in
            label.font = TempuraDesign.Font.cardValueSmall
            label.alignment = .right
            label.lineBreakMode = .byClipping
        }

        throttleDetailLabel.font = TempuraDesign.Font.cardDetail
        throttleDetailLabel.textColor = .tertiaryLabelColor
        throttleDetailLabel.lineBreakMode = .byTruncatingTail
    }

    private func configureLayout() {
        let topStack = NSStackView(views: [captionLabel, NSView(), riskLabel])
        topStack.orientation = .horizontal
        topStack.alignment = .centerY
        topStack.spacing = 8

        let throttleStack = NSStackView(views: [topStack, throttleDetailLabel, throttleMeterView])
        throttleStack.orientation = .vertical
        throttleStack.alignment = .leading
        throttleStack.spacing = 5

        let memoryStack = makeMetricStack(
            titleLabel: memoryCaptionLabel,
            valueLabel: memoryValueLabel,
            meterView: memoryMeterView
        )
        let swapStack = makeMetricStack(
            titleLabel: swapCaptionLabel,
            valueLabel: swapValueLabel,
            meterView: swapMeterView
        )

        let resourceStack = NSStackView(views: [memoryStack, swapStack])
        resourceStack.orientation = .horizontal
        resourceStack.alignment = .top
        resourceStack.spacing = 10
        resourceStack.distribution = .fillEqually

        let stack = NSStackView(views: [throttleStack, resourceStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TempuraDesign.Layout.cardHorizontalInset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TempuraDesign.Layout.cardHorizontalInset),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: TempuraDesign.Layout.cardVerticalInset),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -TempuraDesign.Layout.cardVerticalInset),

            topStack.widthAnchor.constraint(equalTo: throttleStack.widthAnchor),
            throttleDetailLabel.widthAnchor.constraint(equalTo: throttleStack.widthAnchor),
            throttleMeterView.widthAnchor.constraint(equalTo: throttleStack.widthAnchor),
            throttleMeterView.heightAnchor.constraint(equalToConstant: TempuraDesign.Layout.meterHeight),
            throttleStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            resourceStack.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func makeMetricStack(
        titleLabel: NSTextField,
        valueLabel: NSTextField,
        meterView: TempuraMeterView
    ) -> NSStackView {
        let labelStack = NSStackView(views: [titleLabel, NSView(), valueLabel])
        labelStack.orientation = .horizontal
        labelStack.alignment = .centerY
        labelStack.spacing = 6

        let stack = NSStackView(views: [labelStack, meterView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5

        NSLayoutConstraint.activate([
            labelStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            meterView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            meterView.heightAnchor.constraint(equalToConstant: TempuraDesign.Layout.meterHeight)
        ])

        return stack
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("System Pressure")
    }

    private func accessibilityValue(
        throttleStatus: ThrottleStatus,
        memoryStatus: MemoryUsageStatus
    ) -> String {
        var parts = [
            "Throttle risk \(throttleStatus.risk.title)",
            throttleStatus.detail
        ]

        if memoryStatus.isAvailable {
            parts.append("Memory \(memoryStatus.memoryPercentTitle)")
            parts.append("Swap overflow \(memoryStatus.swapOverflowTitle)")
            parts.append(memoryStatus.detail)
        } else {
            parts.append("Memory data unavailable")
        }

        return parts.joined(separator: ". ")
    }
}
