import AppKit
import TempuraCore

@MainActor
final class ThermalPanelViewController: NSViewController {
    static let preferredContentSize = NSSize(
        width: TempuraDesign.Layout.panelWidth,
        height: TempuraDesign.Layout.panelHeight
    )

    var settingsRequested: (() -> Void)?
    var contentSizeDidChange: ((NSSize) -> Void)?

    private let currentValueLabel = NSTextField(labelWithString: "--°C")
    private let sourceLabel = NSTextField(labelWithString: "No reading")
    private let historyWindowControl = NSSegmentedControl(
        labels: TemperatureHistoryWindow.allCases.map(\.displayName),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let chartView = ThermalChartView()
    private let temperatureStatsView = TemperatureStatsStripView()
    private let systemPressureView = SystemPressureView()
    private let detailsControl = NSSegmentedControl(
        labels: TelemetryDetailsMode.selectableCases.map(\.title),
        trackingMode: .selectAny,
        target: nil,
        action: nil
    )
    private let telemetryDetailsView = TelemetryDetailsView()
    private let settingsButton = NSButton()
    private let quitButton = NSButton()
    private var temperatureUnit = TemperatureUnit.current
    private var historyWindow = TemperatureHistoryWindow.current
    private var detailsMode = TelemetryDetailsMode.none
    private var currentReading: TemperatureReading?
    private var currentMemoryStatus = MemoryUsageStatus.unavailable
    private var currentTemperatureStats: TemperatureHistoryStats?

    override func loadView() {
        let backdropView = TempuraGlassBackdropView(
            frame: NSRect(origin: .zero, size: Self.preferredContentSize)
        )
        view = backdropView

        configureLabels()
        configureButtons()
        configureDetailsControl()
        configureHistoryWindowControl()

        let titleLabel = NSTextField(labelWithString: "Thermal")
        titleLabel.font = TempuraDesign.Font.panelTitle
        titleLabel.textColor = .secondaryLabelColor

        let headerStack = NSStackView(views: [titleLabel, NSView(), historyWindowControl])
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
            temperatureStatsView,
            systemPressureView,
            makeDetailsControlRow(),
            telemetryDetailsView,
            separator,
            actionStack
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.detachesHiddenViews = true
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
            historyWindowControl.widthAnchor.constraint(equalToConstant: 126),
            temperatureStatsView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset),
            temperatureStatsView.heightAnchor.constraint(equalToConstant: TempuraDesign.Layout.temperatureStatsHeight),
            systemPressureView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset),
            systemPressureView.heightAnchor.constraint(equalToConstant: TempuraDesign.Layout.systemPressureHeight),
            detailsControl.widthAnchor.constraint(equalToConstant: 154),
            detailsControl.heightAnchor.constraint(equalToConstant: TempuraDesign.Layout.detailControlHeight),
            telemetryDetailsView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset),
            telemetryDetailsView.heightAnchor.constraint(equalToConstant: TempuraDesign.Layout.telemetryDetailsHeight),
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset),
            actionStack.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -TempuraDesign.Layout.panelContentInset)
        ])

        updateDetailsMode(.none, notify: false)
    }

    func setTemperatureUnit(_ unit: TemperatureUnit) {
        temperatureUnit = unit
        chartView.temperatureUnit = unit
        temperatureStatsView.temperatureUnit = unit
    }

    func setHistoryWindow(_ window: TemperatureHistoryWindow) {
        historyWindow = window
        selectHistoryWindow(window)
    }

    func update(
        samples: [TemperatureSample],
        temperatureStats: TemperatureHistoryStats?,
        currentReading: TemperatureReading?,
        throttleStatus: ThrottleStatus,
        memoryStatus: MemoryUsageStatus
    ) {
        self.currentReading = currentReading
        self.currentMemoryStatus = memoryStatus
        self.currentTemperatureStats = temperatureStats

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
        temperatureStatsView.update(stats: temperatureStats)
        systemPressureView.update(throttleStatus: throttleStatus, memoryStatus: memoryStatus)
        telemetryDetailsView.update(
            mode: detailsMode,
            reading: currentReading,
            stats: temperatureStats,
            memoryStatus: memoryStatus,
            temperatureUnit: temperatureUnit
        )
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

    private func configureDetailsControl() {
        detailsControl.target = self
        detailsControl.action = #selector(detailsControlChanged(_:))
        detailsControl.segmentStyle = .rounded
        detailsControl.setWidth(74, forSegment: 0)
        detailsControl.setWidth(74, forSegment: 1)
        detailsControl.setAccessibilityLabel("Details")
        detailsControl.setAccessibilityHelp("Expands thermal or memory details.")
    }

    private func configureHistoryWindowControl() {
        historyWindowControl.target = self
        historyWindowControl.action = #selector(historyWindowControlChanged(_:))
        historyWindowControl.segmentStyle = .rounded
        historyWindowControl.controlSize = .small
        historyWindowControl.toolTip = "Choose the chart history window"
        historyWindowControl.setWidth(42, forSegment: 0)
        historyWindowControl.setWidth(40, forSegment: 1)
        historyWindowControl.setWidth(40, forSegment: 2)
        historyWindowControl.setAccessibilityLabel("History Window")
        historyWindowControl.setAccessibilityHelp("Changes the chart and summary time window.")
        selectHistoryWindow(historyWindow)
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
        TempuraDesign.styleActionButton(button)
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

    private func makeDetailsControlRow() -> NSStackView {
        let label = NSTextField(labelWithString: "Details")
        label.font = TempuraDesign.Font.cardCaption
        label.textColor = .secondaryLabelColor

        let row = NSStackView(views: [label, NSView(), detailsControl])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8

        return row
    }

    private func updateDetailsMode(_ mode: TelemetryDetailsMode, notify: Bool = true) {
        detailsMode = mode
        telemetryDetailsView.isHidden = mode == .none
        telemetryDetailsView.update(
            mode: mode,
            reading: currentReading,
            stats: currentTemperatureStats,
            memoryStatus: currentMemoryStatus,
            temperatureUnit: temperatureUnit
        )

        for (index, selectableMode) in TelemetryDetailsMode.selectableCases.enumerated() {
            detailsControl.setSelected(mode == selectableMode, forSegment: index)
        }

        let nextSize = NSSize(
            width: TempuraDesign.Layout.panelWidth,
            height: mode == .none
                ? TempuraDesign.Layout.panelHeight
                : TempuraDesign.Layout.panelExpandedHeight
        )
        preferredContentSize = nextSize
        view.frame.size = nextSize

        if notify {
            contentSizeDidChange?(nextSize)
        }
    }

    @objc private func openSettings(_ sender: Any?) {
        settingsRequested?()
    }

    @objc private func detailsControlChanged(_ sender: NSSegmentedControl) {
        let selectedMode = TelemetryDetailsMode.mode(forSegment: sender.selectedSegment)
        updateDetailsMode(selectedMode == detailsMode ? .none : selectedMode)
    }

    @objc private func historyWindowControlChanged(_ sender: NSSegmentedControl) {
        let index = sender.selectedSegment
        guard TemperatureHistoryWindow.allCases.indices.contains(index) else {
            setHistoryWindow(.oneMinute)
            TemperatureHistoryWindow.current = .oneMinute
            return
        }

        let window = TemperatureHistoryWindow.allCases[index]
        historyWindow = window
        historyWindowControl.setAccessibilityValue(window.accessibilityTitle)
        TemperatureHistoryWindow.current = window
    }

    private func selectHistoryWindow(_ window: TemperatureHistoryWindow) {
        historyWindowControl.selectedSegment = TemperatureHistoryWindow.allCases.firstIndex(of: window) ?? 0
        historyWindowControl.setAccessibilityValue(window.accessibilityTitle)
    }
}

private enum TelemetryDetailsMode: Equatable {
    case none
    case thermal
    case memory

    static let selectableCases: [TelemetryDetailsMode] = [.thermal, .memory]

    var title: String {
        switch self {
        case .none:
            return "Details"
        case .thermal:
            return "Thermal"
        case .memory:
            return "Memory"
        }
    }

    static func mode(forSegment segment: Int) -> TelemetryDetailsMode {
        guard selectableCases.indices.contains(segment) else {
            return .none
        }

        return selectableCases[segment]
    }
}

private final class TelemetryDetailsView: TempuraGlassCardView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let firstColumnStack = NSStackView()
    private let secondColumnStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayout()
        update(mode: .none, reading: nil, stats: nil, memoryStatus: .unavailable, temperatureUnit: .current)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayout()
        update(mode: .none, reading: nil, stats: nil, memoryStatus: .unavailable, temperatureUnit: .current)
    }

    func update(
        mode: TelemetryDetailsMode,
        reading: TemperatureReading?,
        stats: TemperatureHistoryStats?,
        memoryStatus: MemoryUsageStatus,
        temperatureUnit: TemperatureUnit
    ) {
        titleLabel.stringValue = mode == .memory ? "Memory Breakdown" : "Thermal Detail"

        let rows: [TelemetryDetailRow]
        switch mode {
        case .none:
            rows = []
        case .thermal:
            rows = thermalRows(reading: reading, stats: stats, unit: temperatureUnit)
        case .memory:
            rows = memoryRows(memoryStatus)
        }

        render(rows)
        setAccessibilityLabel(titleLabel.stringValue)
        setAccessibilityValue(rows.map { "\($0.title) \($0.value)" }.joined(separator: ". "))
    }

    private func configureLayout() {
        titleLabel.font = TempuraDesign.Font.cardCaption
        titleLabel.textColor = .secondaryLabelColor

        [firstColumnStack, secondColumnStack].forEach { stack in
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 7
        }

        let columnStack = NSStackView(views: [firstColumnStack, secondColumnStack])
        columnStack.orientation = .horizontal
        columnStack.alignment = .top
        columnStack.spacing = 14
        columnStack.distribution = .fillEqually

        let stack = NSStackView(views: [titleLabel, columnStack])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TempuraDesign.Layout.cardHorizontalInset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TempuraDesign.Layout.cardHorizontalInset),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: TempuraDesign.Layout.cardVerticalInset),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -TempuraDesign.Layout.cardVerticalInset),
            columnStack.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    private func render(_ rows: [TelemetryDetailRow]) {
        let firstColumnRows = Array(rows.prefix(3))
        let secondColumnRows = Array(rows.dropFirst(3).prefix(3))
        render(firstColumnRows, in: firstColumnStack)
        render(secondColumnRows, in: secondColumnStack)
    }

    private func render(_ rows: [TelemetryDetailRow], in stack: NSStackView) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for row in rows {
            stack.addArrangedSubview(makeRow(row))
        }
    }

    private func makeRow(_ row: TelemetryDetailRow) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: row.title)
        titleLabel.font = TempuraDesign.Font.detailLabel
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        let valueLabel = NSTextField(labelWithString: row.value)
        valueLabel.font = TempuraDesign.Font.detailValue
        valueLabel.textColor = row.tintColor
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byTruncatingTail

        let rowStack = NSStackView(views: [titleLabel, NSView(), valueLabel])
        rowStack.orientation = .horizontal
        rowStack.alignment = .firstBaseline
        rowStack.spacing = 6

        NSLayoutConstraint.activate([
            rowStack.widthAnchor.constraint(equalToConstant: 124),
            valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])

        return rowStack
    }

    private func thermalRows(
        reading: TemperatureReading?,
        stats: TemperatureHistoryStats?,
        unit: TemperatureUnit
    ) -> [TelemetryDetailRow] {
        let sourceValue: String
        let groupValue: String
        let sampleAgeValue: String

        if let reading {
            let source = reading.sourceName ?? reading.sourceGroup.rawValue
            sourceValue = reading.sourceKey
            groupValue = source
            sampleAgeValue = Self.sampleAgeTitle(since: reading.date)
        } else {
            sourceValue = "--"
            groupValue = "--"
            sampleAgeValue = "--"
        }

        return [
            TelemetryDetailRow(title: "Sensor", value: sourceValue, tintColor: .labelColor),
            TelemetryDetailRow(title: "Source", value: groupValue, tintColor: .labelColor),
            TelemetryDetailRow(title: "Sample", value: sampleAgeValue, tintColor: .labelColor),
            TelemetryDetailRow(
                title: "Average",
                value: stats.map { unit.formatted(celsius: $0.averageCelsius) } ?? "--",
                tintColor: stats.map { TemperatureBucket(celsius: $0.averageCelsius).chartColor } ?? .tertiaryLabelColor
            ),
            TelemetryDetailRow(
                title: "Peak",
                value: stats.map { unit.formatted(celsius: $0.peakCelsius) } ?? "--",
                tintColor: stats.map { TemperatureBucket(celsius: $0.peakCelsius).chartColor } ?? .tertiaryLabelColor
            ),
            TelemetryDetailRow(
                title: "Samples",
                value: stats.map { "\($0.sampleCount)" } ?? "--",
                tintColor: .labelColor
            )
        ]
    }

    private func memoryRows(_ status: MemoryUsageStatus) -> [TelemetryDetailRow] {
        guard status.isAvailable else {
            return [
                TelemetryDetailRow(title: "App", value: "--", tintColor: .tertiaryLabelColor),
                TelemetryDetailRow(title: "Wired", value: "--", tintColor: .tertiaryLabelColor),
                TelemetryDetailRow(title: "Compressed", value: "--", tintColor: .tertiaryLabelColor),
                TelemetryDetailRow(title: "Cached", value: "--", tintColor: .tertiaryLabelColor),
                TelemetryDetailRow(title: "Swap", value: "--", tintColor: .tertiaryLabelColor),
                TelemetryDetailRow(title: "Pressure", value: "--", tintColor: .tertiaryLabelColor)
            ]
        }

        return [
            TelemetryDetailRow(title: "App", value: status.appMemoryTitle, tintColor: .labelColor),
            TelemetryDetailRow(title: "Wired", value: status.wiredMemoryTitle, tintColor: .labelColor),
            TelemetryDetailRow(title: "Compressed", value: status.compressedMemoryTitle, tintColor: .labelColor),
            TelemetryDetailRow(title: "Cached", value: status.cachedMemoryTitle, tintColor: .labelColor),
            TelemetryDetailRow(title: "Swap", value: status.swapUsedTitle, tintColor: status.swapLevel.tintColor),
            TelemetryDetailRow(title: "Pressure", value: status.pressureLevel.title, tintColor: status.pressureLevel.tintColor)
        ]
    }

    private static func sampleAgeTitle(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date).rounded()))

        if seconds < 2 {
            return "now"
        }

        return "\(seconds)s"
    }
}

private struct TelemetryDetailRow {
    let title: String
    let value: String
    let tintColor: NSColor
}

private final class TemperatureStatsStripView: NSView {
    var temperatureUnit = TemperatureUnit.current {
        didSet {
            render()
        }
    }

    private let averageValueLabel = NSTextField(labelWithString: "--")
    private let peakValueLabel = NSTextField(labelWithString: "--")
    private let lowValueLabel = NSTextField(labelWithString: "--")
    private var stats: TemperatureHistoryStats?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayout()
        render()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayout()
        render()
    }

    func update(stats: TemperatureHistoryStats?) {
        self.stats = stats
        render()
    }

    private func configureLayout() {
        let stack = NSStackView(views: [
            makeMetric(title: "Avg", valueLabel: averageValueLabel),
            makeMetric(title: "Peak", valueLabel: peakValueLabel),
            makeMetric(title: "Low", valueLabel: lowValueLabel)
        ])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Temperature summary")
    }

    private func makeMetric(title: String, valueLabel: NSTextField) -> NSStackView {
        let captionLabel = NSTextField(labelWithString: title)
        captionLabel.font = TempuraDesign.Font.statCaption
        captionLabel.textColor = .secondaryLabelColor

        valueLabel.font = TempuraDesign.Font.statValue
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .right
        valueLabel.lineBreakMode = .byClipping

        let stack = NSStackView(views: [captionLabel, NSView(), valueLabel])
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 6

        NSLayoutConstraint.activate([
            valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 34)
        ])

        return stack
    }

    private func render() {
        guard let stats else {
            [averageValueLabel, peakValueLabel, lowValueLabel].forEach { label in
                label.stringValue = "--"
                label.textColor = .tertiaryLabelColor
            }
            setAccessibilityValue("No temperature summary yet")
            return
        }

        averageValueLabel.stringValue = temperatureUnit.formatted(celsius: stats.averageCelsius, includeUnit: false)
        peakValueLabel.stringValue = temperatureUnit.formatted(celsius: stats.peakCelsius, includeUnit: false)
        lowValueLabel.stringValue = temperatureUnit.formatted(celsius: stats.lowCelsius, includeUnit: false)

        averageValueLabel.textColor = TemperatureBucket(celsius: stats.averageCelsius).chartColor
        peakValueLabel.textColor = TemperatureBucket(celsius: stats.peakCelsius).chartColor
        lowValueLabel.textColor = .labelColor

        setAccessibilityValue(
            "Average \(temperatureUnit.formatted(celsius: stats.averageCelsius)), " +
                "peak \(temperatureUnit.formatted(celsius: stats.peakCelsius)), " +
                "low \(temperatureUnit.formatted(celsius: stats.lowCelsius))"
        )
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
    private let pressureCaptionLabel = NSTextField(labelWithString: "Pressure")
    private let pressureValueLabel = NSTextField(labelWithString: "--")
    private let pressureMeterView = TempuraMeterView()
    private let swapCaptionLabel = NSTextField(labelWithString: "Swap")
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

        pressureValueLabel.stringValue = memoryStatus.pressureLevel.compactTitle
        pressureValueLabel.textColor = memoryStatus.pressureLevel.tintColor
        pressureMeterView.progress = CGFloat(memoryStatus.pressureLevel.progress)
        pressureMeterView.tintColor = memoryStatus.pressureLevel.tintColor

        swapValueLabel.stringValue = memoryStatus.isAvailable ? memoryStatus.swapOverflowTitle : "--"
        swapValueLabel.textColor = memoryStatus.swapLevel.tintColor
        swapMeterView.progress = memoryStatus.isAvailable ? CGFloat(memoryStatus.swapOverflowFraction) : 0.08
        swapMeterView.tintColor = memoryStatus.swapLevel.tintColor

        setAccessibilityValue(accessibilityValue(throttleStatus: throttleStatus, memoryStatus: memoryStatus))
    }

    private func configureLabels() {
        [captionLabel, memoryCaptionLabel, pressureCaptionLabel, swapCaptionLabel].forEach { label in
            label.font = TempuraDesign.Font.cardCaption
            label.textColor = .secondaryLabelColor
        }

        riskLabel.font = TempuraDesign.Font.cardValue
        riskLabel.alignment = .right
        riskLabel.lineBreakMode = .byTruncatingTail

        [memoryValueLabel, pressureValueLabel, swapValueLabel].forEach { label in
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
        let pressureStack = makeMetricStack(
            titleLabel: pressureCaptionLabel,
            valueLabel: pressureValueLabel,
            meterView: pressureMeterView
        )
        let swapStack = makeMetricStack(
            titleLabel: swapCaptionLabel,
            valueLabel: swapValueLabel,
            meterView: swapMeterView
        )

        let resourceStack = NSStackView(views: [memoryStack, pressureStack, swapStack])
        resourceStack.orientation = .horizontal
        resourceStack.alignment = .top
        resourceStack.spacing = 8
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
            parts.append("Native memory pressure \(memoryStatus.pressureLevel.title)")
            parts.append("Swap overflow \(memoryStatus.swapOverflowTitle)")
            parts.append(memoryStatus.detail)
        } else {
            parts.append("Memory data unavailable")
        }

        return parts.joined(separator: ". ")
    }
}
