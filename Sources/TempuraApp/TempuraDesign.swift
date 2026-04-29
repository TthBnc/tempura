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
        static var statCaption: NSFont { NSFont.systemFont(ofSize: 10.5, weight: .semibold) }
        static var statValue: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold) }
        static var cardDetail: NSFont { NSFont.systemFont(ofSize: 10.5, weight: .regular) }
        static var detailLabel: NSFont { NSFont.systemFont(ofSize: 10.5, weight: .semibold) }
        static var detailValue: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium) }
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
        static let panelWidth: CGFloat = 360
        static let panelHeight: CGFloat = 484
        static let panelExpandedHeight: CGFloat = 630
        static let panelInset: CGFloat = 14
        static let panelContentInset: CGFloat = panelInset * 2
        static let panelSpacing: CGFloat = 10
        static let chartHeight: CGFloat = 112
        static let temperatureStatsHeight: CGFloat = 34
        static let systemPressureHeight: CGFloat = 116
        static let detailControlHeight: CGFloat = 28
        static let telemetryDetailsHeight: CGFloat = 136
        static let cardHorizontalInset: CGFloat = 10
        static let cardVerticalInset: CGFloat = 8
        static let meterHeight: CGFloat = 5
        static let actionSpacing: CGFloat = 8
        static let settingsWidth: CGFloat = 504
        static let settingsHeight: CGFloat = 640
        static let settingsHorizontalInset: CGFloat = 36
        static let settingsTopInset: CGFloat = 34
        static let settingsBottomInset: CGFloat = 28
        static let settingsSectionSpacing: CGFloat = 18
        static let settingsRowSpacing: CGFloat = 12
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

    @MainActor
    static func styleActionButton(_ button: NSButton) {
        if #available(macOS 26.0, *) {
            button.bezelStyle = .glass
        } else {
            button.bezelStyle = .rounded
        }
    }
}

struct TempuraGlassPalette {
    let fill: NSColor
    let stroke: NSColor
    let topHighlight: NSColor
}

final class TempuraGlassBackdropView: NSView {
    let contentView = NSView()

    private let fallbackEffectView = NSVisualEffectView()
    private let topHighlightView = NSView()
    private var usesNativeGlass = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureSurface()
        configureChrome()
        if !usesNativeGlass {
            applyGlassPalette()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSurface()
        configureChrome()
        if !usesNativeGlass {
            applyGlassPalette()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if !usesNativeGlass {
            applyGlassPalette()
        }
    }

    private func configureSurface() {
        wantsLayer = true

        if #available(macOS 26.0, *) {
            configureNativeGlassSurface()
        } else {
            configureFallbackSurface()
        }
    }

    private func configureChrome() {
        guard !usesNativeGlass else {
            return
        }

        [contentView, topHighlightView].forEach { chromeView in
            chromeView.translatesAutoresizingMaskIntoConstraints = false
            chromeView.wantsLayer = true
        }

        fallbackEffectView.addSubview(contentView)
        fallbackEffectView.addSubview(topHighlightView)
        topHighlightView.layer?.cornerRadius = 0.5

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: fallbackEffectView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: fallbackEffectView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: fallbackEffectView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: fallbackEffectView.bottomAnchor),

            topHighlightView.leadingAnchor.constraint(equalTo: fallbackEffectView.leadingAnchor, constant: TempuraDesign.Layout.panelInset),
            topHighlightView.trailingAnchor.constraint(equalTo: fallbackEffectView.trailingAnchor, constant: -TempuraDesign.Layout.panelInset),
            topHighlightView.topAnchor.constraint(equalTo: fallbackEffectView.topAnchor),
            topHighlightView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    @available(macOS 26.0, *)
    private func configureNativeGlassSurface() {
        usesNativeGlass = true

        let containerView = NSGlassEffectContainerView()
        let glassView = NSGlassEffectView()

        containerView.translatesAutoresizingMaskIntoConstraints = false
        glassView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        containerView.spacing = 14
        glassView.style = .regular
        glassView.cornerRadius = TempuraDesign.Radius.shell
        glassView.contentView = contentView
        containerView.contentView = glassView

        addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            glassView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            glassView.topAnchor.constraint(equalTo: containerView.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: glassView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: glassView.bottomAnchor)
        ])
    }

    private func configureFallbackSurface() {
        fallbackEffectView.material = .popover
        fallbackEffectView.blendingMode = .behindWindow
        fallbackEffectView.state = .active
        fallbackEffectView.wantsLayer = true
        fallbackEffectView.layer?.cornerRadius = TempuraDesign.Radius.shell
        fallbackEffectView.layer?.cornerCurve = .continuous
        fallbackEffectView.layer?.masksToBounds = true
        fallbackEffectView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(fallbackEffectView)

        NSLayoutConstraint.activate([
            fallbackEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fallbackEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            fallbackEffectView.topAnchor.constraint(equalTo: topAnchor),
            fallbackEffectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func applyGlassPalette() {
        let palette = TempuraDesign.Color.shellPalette(isDark: TempuraDesign.isDarkAppearance(effectiveAppearance))
        fallbackEffectView.layer?.backgroundColor = palette.fill.cgColor
        fallbackEffectView.layer?.borderColor = palette.stroke.cgColor
        fallbackEffectView.layer?.borderWidth = 1
        topHighlightView.layer?.backgroundColor = palette.topHighlight.cgColor
    }
}

class TempuraGlassCardView: NSView {
    private var nativeGlassView: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureSurface()
        if nativeGlassView == nil {
            applyGlassPalette()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureSurface()
        if nativeGlassView == nil {
            applyGlassPalette()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if nativeGlassView == nil {
            applyGlassPalette()
        }
    }

    private func configureSurface() {
        wantsLayer = true
        layer?.cornerCurve = .continuous

        if #available(macOS 26.0, *) {
            configureNativeGlassSurface()
        } else {
            configureFallbackSurface()
        }
    }

    @available(macOS 26.0, *)
    private func configureNativeGlassSurface() {
        let glassView = NSGlassEffectView()
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.style = .regular
        glassView.cornerRadius = TempuraDesign.Radius.card
        glassView.contentView = NSView()
        nativeGlassView = glassView

        addSubview(glassView, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configureFallbackSurface() {
        layer?.cornerRadius = TempuraDesign.Radius.card
        layer?.borderWidth = 1
        applyGlassPalette()
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
