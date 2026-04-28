import AppKit
import QuartzCore
import TempuraCore

final class ThermalChartView: NSView {
    var temperatureUnit = TemperatureUnit.current {
        didSet {
            guard temperatureUnit != oldValue else {
                return
            }

            needsDisplay = true
        }
    }

    var samples: [TemperatureSample] = [] {
        didSet {
            animateSamplesChange()
        }
    }

    private struct ChartState {
        let samples: [TemperatureSample]
        let range: ClosedRange<Double>?
        let latestDate: Date

        init(samples: [TemperatureSample]) {
            self.samples = samples
            range = TemperatureHistory(samples: samples).dynamicRange()
            latestDate = samples.last?.date ?? Date()
        }

        init(samples: [TemperatureSample], range: ClosedRange<Double>?, latestDate: Date) {
            self.samples = samples
            self.range = range
            self.latestDate = latestDate
        }
    }

    private var presentationState = ChartState(samples: [])
    private var animationStartState: ChartState?
    private var animationTargetState: ChartState?
    private var animationStartTime: CFTimeInterval = 0
    private var animationTimer: Timer?
    private let animationDuration: CFTimeInterval = 0.42

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    isolated deinit {
        stopAnimation()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        drawBackground(in: bounds)

        let chartRect = bounds.insetBy(dx: 12, dy: 12)
        let plotRect = plotRect(in: chartRect)
        drawGrid(in: plotRect)

        guard !presentationState.samples.isEmpty else {
            drawEmptyState(in: chartRect)
            return
        }

        drawSeries(in: plotRect, state: presentationState)
        drawAxisLabels(in: chartRect, state: presentationState)
    }

    private func configureLayer() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    private func drawBackground(in rect: NSRect) {
        let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor(calibratedWhite: 0.08, alpha: 0.62).setFill()
        backgroundPath.fill()

        NSColor.separatorColor.withAlphaComponent(0.26).setStroke()
        backgroundPath.lineWidth = 1
        backgroundPath.stroke()
    }

    private func drawGrid(in rect: NSRect) {
        NSColor.white.withAlphaComponent(0.08).setStroke()

        for index in 0...2 {
            let y = rect.minY + (rect.height / 2) * CGFloat(index)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            path.lineWidth = 1
            path.stroke()
        }
    }

    private func drawEmptyState(in rect: NSRect) {
        let text = "--°C"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor.disabledControlTextColor
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(
                x: rect.midX - size.width / 2,
                y: rect.midY - size.height / 2
            ),
            withAttributes: attributes
        )
    }

    private func drawSeries(in rect: NSRect, state: ChartState) {
        let points = plottedPoints(in: rect, state: state)

        guard points.count > 1 else {
            drawPoint(points.first?.point, celsius: points.first?.sample.celsius)
            return
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let bucket = TemperatureBucket(celsius: max(previous.sample.celsius, current.sample.celsius))

            bucket.chartColor.setStroke()
            let segment = NSBezierPath()
            segment.move(to: previous.point)
            segment.line(to: current.point)
            segment.lineWidth = 3
            segment.lineCapStyle = .round
            segment.lineJoinStyle = .round
            segment.stroke()
        }

        if let last = points.last {
            drawPoint(last.point, celsius: last.sample.celsius)
        }
    }

    private func drawPoint(_ point: NSPoint?, celsius: Double?) {
        guard let point, let celsius else {
            return
        }

        let bucket = TemperatureBucket(celsius: celsius)
        let dotRect = NSRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)
        let dot = NSBezierPath(ovalIn: dotRect)
        bucket.chartColor.setFill()
        dot.fill()
    }

    private func drawAxisLabels(in rect: NSRect, state: ChartState) {
        guard let range = state.range else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold),
            .foregroundColor: NSColor(calibratedWhite: 0.86, alpha: 1)
        ]

        let high = temperatureUnit.formatted(celsius: range.upperBound, includeUnit: false)
        let midpoint = temperatureUnit.formatted(
            celsius: (range.lowerBound + range.upperBound) / 2,
            includeUnit: false
        )
        let low = temperatureUnit.formatted(celsius: range.lowerBound, includeUnit: false)

        drawAxisLabel(high, atY: rect.minY + 1, in: rect, attributes: attributes)
        drawAxisLabel(midpoint, atY: rect.midY - 7, in: rect, attributes: attributes)
        drawAxisLabel(low, atY: rect.maxY - 15, in: rect, attributes: attributes)
    }

    private func drawAxisLabel(
        _ label: String,
        atY y: CGFloat,
        in rect: NSRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let size = label.size(withAttributes: attributes)
        let labelRect = NSRect(
            x: rect.maxX - size.width - 5,
            y: y,
            width: size.width + 4,
            height: size.height + 2
        )
        let plate = NSBezierPath(roundedRect: labelRect, xRadius: 3.5, yRadius: 3.5)

        NSColor(calibratedWhite: 0.12, alpha: 0.72).setFill()
        plate.fill()
        NSColor.white.withAlphaComponent(0.08).setStroke()
        plate.lineWidth = 1
        plate.stroke()

        label.draw(
            at: NSPoint(x: labelRect.minX + 2, y: labelRect.minY + 1),
            withAttributes: attributes
        )
    }

    private func plottedPoints(in rect: NSRect, state: ChartState) -> [(sample: TemperatureSample, point: NSPoint)] {
        guard let range = state.range else {
            return []
        }

        let startDate = state.latestDate.addingTimeInterval(-60)
        let span = max(range.upperBound - range.lowerBound, 1)

        return state.samples.map { sample in
            let xProgress = min(max(sample.date.timeIntervalSince(startDate) / 60, 0), 1)
            let yProgress = min(max((sample.celsius - range.lowerBound) / span, 0), 1)

            return (
                sample,
                NSPoint(
                    x: rect.minX + CGFloat(xProgress) * rect.width,
                    y: rect.maxY - CGFloat(yProgress) * rect.height
                )
            )
        }
    }

    private func plotRect(in chartRect: NSRect) -> NSRect {
        NSRect(
            x: chartRect.minX,
            y: chartRect.minY,
            width: max(chartRect.width - 42, 1),
            height: chartRect.height
        )
    }

    private func animateSamplesChange() {
        let targetState = ChartState(samples: samples)

        guard window != nil else {
            stopAnimation()
            presentationState = targetState
            needsDisplay = true
            return
        }

        let sourceState = currentPresentationState()

        guard !sourceState.samples.isEmpty, !targetState.samples.isEmpty else {
            stopAnimation()
            presentationState = targetState
            needsDisplay = true
            return
        }

        animationStartState = sourceState
        animationTargetState = targetState
        animationStartTime = CACurrentMediaTime()

        if animationTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.advanceAnimation()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            animationTimer = timer
        }

        advanceAnimation()
    }

    private func advanceAnimation() {
        guard let startState = animationStartState, let targetState = animationTargetState else {
            stopAnimation()
            return
        }

        let elapsed = CACurrentMediaTime() - animationStartTime
        let rawProgress = min(max(elapsed / animationDuration, 0), 1)
        let easedProgress = Self.easeInOut(rawProgress)

        presentationState = Self.interpolate(from: startState, to: targetState, progress: easedProgress)
        needsDisplay = true

        if rawProgress >= 1 {
            presentationState = targetState
            stopAnimation()
            needsDisplay = true
        }
    }

    private func currentPresentationState() -> ChartState {
        guard let startState = animationStartState, let targetState = animationTargetState else {
            return presentationState
        }

        let elapsed = CACurrentMediaTime() - animationStartTime
        let rawProgress = min(max(elapsed / animationDuration, 0), 1)
        return Self.interpolate(from: startState, to: targetState, progress: Self.easeInOut(rawProgress))
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationStartState = nil
        animationTargetState = nil
    }

    private static func interpolate(from start: ChartState, to target: ChartState, progress: Double) -> ChartState {
        let samples = interpolatedSamples(from: start, to: target, progress: progress)
        let range = interpolatedRange(from: start.range, to: target.range, progress: progress)
        let latestDate = interpolatedDate(from: start.latestDate, to: target.latestDate, progress: progress)

        return ChartState(samples: samples, range: range, latestDate: latestDate)
    }

    private static func interpolatedSamples(
        from start: ChartState,
        to target: ChartState,
        progress: Double
    ) -> [TemperatureSample] {
        let fallbackSample = start.samples.last

        return target.samples.enumerated().map { index, targetSample in
            let indexedStartSample = start.samples.indices.contains(index) ? start.samples[index] : nil
            let startSample = start.samples.first { $0.date == targetSample.date }
                ?? indexedStartSample
                ?? fallbackSample
                ?? targetSample

            return TemperatureSample(
                celsius: interpolate(from: startSample.celsius, to: targetSample.celsius, progress: progress),
                date: interpolatedDate(from: startSample.date, to: targetSample.date, progress: progress)
            )
        }
    }

    private static func interpolatedRange(
        from start: ClosedRange<Double>?,
        to target: ClosedRange<Double>?,
        progress: Double
    ) -> ClosedRange<Double>? {
        guard let target else {
            return nil
        }

        guard let start else {
            return target
        }

        return interpolate(from: start.lowerBound, to: target.lowerBound, progress: progress)
            ... interpolate(from: start.upperBound, to: target.upperBound, progress: progress)
    }

    private static func interpolatedDate(from start: Date, to target: Date, progress: Double) -> Date {
        Date(
            timeIntervalSinceReferenceDate: interpolate(
                from: start.timeIntervalSinceReferenceDate,
                to: target.timeIntervalSinceReferenceDate,
                progress: progress
            )
        )
    }

    private static func interpolate(from start: Double, to target: Double, progress: Double) -> Double {
        start + ((target - start) * progress)
    }

    private static func easeInOut(_ progress: Double) -> Double {
        progress * progress * (3 - (2 * progress))
    }
}
