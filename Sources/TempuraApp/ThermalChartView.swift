import AppKit
import TempuraCore

final class ThermalChartView: NSView {
    var samples: [TemperatureSample] = [] {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        drawBackground(in: bounds)

        let chartRect = bounds.insetBy(dx: 12, dy: 12)
        drawGrid(in: chartRect)

        guard !samples.isEmpty else {
            drawEmptyState(in: chartRect)
            return
        }

        drawSeries(in: chartRect)
        drawAxisLabels(in: chartRect)
    }

    private func drawBackground(in rect: NSRect) {
        let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor(calibratedWhite: 0.08, alpha: 0.86).setFill()
        backgroundPath.fill()

        NSColor.separatorColor.withAlphaComponent(0.42).setStroke()
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

    private func drawSeries(in rect: NSRect) {
        let points = plottedPoints(in: rect)

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

    private func drawAxisLabels(in rect: NSRect) {
        guard let range = dynamicRange() else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        let high = "\(Int(range.upperBound.rounded()))°"
        let low = "\(Int(range.lowerBound.rounded()))°"

        high.draw(at: NSPoint(x: rect.maxX - 30, y: rect.minY + 2), withAttributes: attributes)
        low.draw(at: NSPoint(x: rect.maxX - 30, y: rect.maxY - 14), withAttributes: attributes)
    }

    private func plottedPoints(in rect: NSRect) -> [(sample: TemperatureSample, point: NSPoint)] {
        guard let range = dynamicRange() else {
            return []
        }

        let latestDate = samples.last?.date ?? Date()
        let startDate = latestDate.addingTimeInterval(-60)
        let span = max(range.upperBound - range.lowerBound, 1)

        return samples.map { sample in
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

    private func dynamicRange() -> ClosedRange<Double>? {
        TemperatureHistory(samples: samples).dynamicRange()
    }
}
