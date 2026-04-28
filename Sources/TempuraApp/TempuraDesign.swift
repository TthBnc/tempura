import AppKit

enum TempuraDesign {
    enum Font {
        static var menuBar: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 13.5, weight: .semibold) }
        static var panelTitle: NSFont { NSFont.systemFont(ofSize: 12, weight: .semibold) }
        static var panelWindow: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular) }
        static var primaryValue: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold) }
        static var source: NSFont { NSFont.systemFont(ofSize: 11, weight: .regular) }
        static var cardCaption: NSFont { NSFont.systemFont(ofSize: 11, weight: .semibold) }
        static var cardValue: NSFont { NSFont.systemFont(ofSize: 13, weight: .semibold) }
        static var cardValueSmall: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold) }
        static var cardDetail: NSFont { NSFont.systemFont(ofSize: 10.5, weight: .regular) }
        static var button: NSFont { NSFont.systemFont(ofSize: 13, weight: .regular) }
        static var buttonStrong: NSFont { NSFont.systemFont(ofSize: 13, weight: .medium) }
        static var settingsTitle: NSFont { NSFont.systemFont(ofSize: 13, weight: .semibold) }
        static var settingsHelp: NSFont { NSFont.systemFont(ofSize: 11, weight: .regular) }
        static var settingsSection: NSFont { NSFont.systemFont(ofSize: 11, weight: .semibold) }
        static var settingsVersion: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular) }
        static var chartEmpty: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium) }
        static var chartAxis: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold) }
    }

    enum Radius {
        static let shell: CGFloat = 18
        static let card: CGFloat = 9
        static let chart: CGFloat = 8
        static let axisPlate: CGFloat = 3.5
    }

    enum Layout {
        static let panelWidth: CGFloat = 320
        static let panelHeight: CGFloat = 392
        static let panelInset: CGFloat = 14
        static let panelContentInset: CGFloat = panelInset * 2
        static let panelSpacing: CGFloat = 10
        static let chartHeight: CGFloat = 112
        static let systemPressureHeight: CGFloat = 104
        static let cardHorizontalInset: CGFloat = 10
        static let cardVerticalInset: CGFloat = 8
        static let meterHeight: CGFloat = 5
        static let actionSpacing: CGFloat = 8
    }

    enum Color {
        static let statusNormal = NSColor(calibratedRed: 0.26, green: 0.68, blue: 0.42, alpha: 1)
        static let statusWarm = NSColor(calibratedRed: 0.78, green: 0.62, blue: 0.24, alpha: 1)
        static let statusLikely = NSColor(calibratedRed: 0.88, green: 0.46, blue: 0.18, alpha: 1)
        static let statusHot = NSColor(calibratedRed: 0.83, green: 0.27, blue: 0.27, alpha: 1)

        static let warningMenu = adaptiveColor(
            light: NSColor(calibratedRed: 0.74, green: 0.39, blue: 0.00, alpha: 1),
            dark: NSColor(calibratedRed: 1.00, green: 0.74, blue: 0.24, alpha: 1)
        )
        static let criticalMenu = adaptiveColor(
            light: NSColor(calibratedRed: 0.82, green: 0.12, blue: 0.08, alpha: 1),
            dark: NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.34, alpha: 1)
        )

        static let chartBackground = NSColor(calibratedWhite: 0.08, alpha: 0.62)
        static let chartGrid = NSColor.white.withAlphaComponent(0.08)
        static let chartAxisText = NSColor(calibratedWhite: 0.86, alpha: 1)
        static let chartAxisPlate = NSColor(calibratedWhite: 0.12, alpha: 0.72)
        static let meterTrack = NSColor.separatorColor.withAlphaComponent(0.28)

        static func shellPalette(isDark: Bool) -> TempuraGlassPalette {
            if isDark {
                return TempuraGlassPalette(
                    fill: NSColor(calibratedWhite: 1, alpha: 0.02),
                    stroke: NSColor(calibratedWhite: 1, alpha: 0.08),
                    topHighlight: NSColor(calibratedWhite: 1, alpha: 0.12)
                )
            }

            return TempuraGlassPalette(
                fill: NSColor(calibratedWhite: 1, alpha: 0.20),
                stroke: NSColor(calibratedWhite: 1, alpha: 0.46),
                topHighlight: NSColor(calibratedWhite: 1, alpha: 0.68)
            )
        }

        static func cardPalette(isDark: Bool) -> TempuraGlassPalette {
            if isDark {
                return TempuraGlassPalette(
                    fill: NSColor(calibratedWhite: 1, alpha: 0.055),
                    stroke: NSColor(calibratedWhite: 1, alpha: 0.075),
                    topHighlight: NSColor(calibratedWhite: 1, alpha: 0.10)
                )
            }

            return TempuraGlassPalette(
                fill: NSColor(calibratedWhite: 1, alpha: 0.28),
                stroke: NSColor(calibratedWhite: 1, alpha: 0.38),
                topHighlight: NSColor(calibratedWhite: 1, alpha: 0.58)
            )
        }

        private static func adaptiveColor(light: NSColor, dark: NSColor) -> NSColor {
            NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .aqua])
                return match == .darkAqua ? dark : light
            }
        }
    }

    static func isDarkAppearance(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

struct TempuraGlassPalette {
    let fill: NSColor
    let stroke: NSColor
    let topHighlight: NSColor
}

final class TempuraGlassBackdropView: NSVisualEffectView {
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
        layer?.cornerRadius = TempuraDesign.Radius.shell
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

            topHighlightView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TempuraDesign.Layout.panelInset),
            topHighlightView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TempuraDesign.Layout.panelInset),
            topHighlightView.topAnchor.constraint(equalTo: topAnchor),
            topHighlightView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func applyGlassPalette() {
        let palette = TempuraDesign.Color.shellPalette(isDark: TempuraDesign.isDarkAppearance(effectiveAppearance))
        layer?.backgroundColor = palette.fill.cgColor
        layer?.borderColor = palette.stroke.cgColor
        layer?.borderWidth = 1
        topHighlightView.layer?.backgroundColor = palette.topHighlight.cgColor
    }
}

class TempuraGlassCardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureSurface()
        applyGlassPalette()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSurface()
        applyGlassPalette()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyGlassPalette()
    }

    private func configureSurface() {
        wantsLayer = true
        layer?.cornerRadius = TempuraDesign.Radius.card
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
    }

    private func applyGlassPalette() {
        let palette = TempuraDesign.Color.cardPalette(isDark: TempuraDesign.isDarkAppearance(effectiveAppearance))
        layer?.backgroundColor = palette.fill.cgColor
        layer?.borderColor = palette.stroke.cgColor
    }
}

final class TempuraMeterView: NSView {
    var progress: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }

    var tintColor: NSColor = .disabledControlTextColor {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityElement(false)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let trackRect = bounds.insetBy(dx: 0, dy: 0.5)
        let trackPath = NSBezierPath(
            roundedRect: trackRect,
            xRadius: trackRect.height / 2,
            yRadius: trackRect.height / 2
        )
        TempuraDesign.Color.meterTrack.setFill()
        trackPath.fill()

        let clampedProgress = min(max(progress, 0), 1)
        let fillWidth = max(trackRect.width * clampedProgress, trackRect.height)
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
        tintColor.setFill()
        fillPath.fill()
    }
}
