import AppKit
import RunicCore

// MARK: - ProviderSwitcherView

final class ProviderSwitcherView: NSView {
    struct Segment {
        let provider: UsageProvider
        let image: NSImage
        let title: String
    }

    struct WeeklyIndicator {
        let provider: UsageProvider
        let track: NSView
        let fill: NSView
    }

    let segments: [Segment]
    private let onSelect: (UsageProvider) -> Void
    private let showsIcons: Bool
    private let weeklyRemainingProvider: (UsageProvider) -> Double?
    var buttons: [NSButton] = []
    var weeklyIndicators: [ObjectIdentifier: WeeklyIndicator] = [:]
    private var hoverTrackingArea: NSTrackingArea?
    var segmentWidths: [CGFloat] = []
    let theme: RunicThemePalette
    let selectedTextColor = NSColor.white
    let stackedIcons: Bool
    let useTwoRows: Bool
    let rowSpacing: CGFloat
    let rowHeight: CGFloat
    var preferredWidth: CGFloat = 0
    var hoveredButtonTag: Int?
    let lightModeOverlayLayer = CALayer()
    static var buttonWidthCache: [ObjectIdentifier: CGFloat] = [:]

    init(
        providers: [UsageProvider],
        selected: UsageProvider?,
        width: CGFloat,
        showsIcons: Bool,
        iconSizePreference: ProviderSwitcherIconSize,
        theme: RunicThemePalette,
        iconProvider: (UsageProvider, CGFloat) -> NSImage,
        weeklyRemainingProvider: @escaping (UsageProvider) -> Double?,
        onSelect: @escaping (UsageProvider) -> Void)
    {
        let minimumGap: CGFloat = 1
        let iconSize: CGFloat = iconSizePreference == .small ? 28 : 34
        self.segments = providers.map { provider in
            let fullTitle = Self.switcherTitle(for: provider)
            let icon = iconProvider(provider, iconSize)
            icon.size = NSSize(width: iconSize, height: iconSize)
            return Segment(
                provider: provider,
                image: icon,
                title: fullTitle)
        }
        self.onSelect = onSelect
        self.showsIcons = showsIcons
        self.weeklyRemainingProvider = weeklyRemainingProvider
        self.theme = theme
        self.stackedIcons = showsIcons && providers.count > 3
        let initialOuterPadding = Self.switcherOuterPadding(
            for: width,
            count: self.segments.count,
            minimumGap: minimumGap)
        let initialMaxAllowedSegmentWidth = Self.maxAllowedUniformSegmentWidth(
            for: width,
            count: self.segments.count,
            outerPadding: initialOuterPadding,
            minimumGap: minimumGap)
        self.useTwoRows = Self.shouldUseTwoRows(
            count: self.segments.count,
            maxAllowedSegmentWidth: initialMaxAllowedSegmentWidth,
            stackedIcons: self.stackedIcons)
        self.rowSpacing = self.stackedIcons ? 3 : 3
        self.rowHeight = self.stackedIcons ? 56 : 42
        let height: CGFloat = self.useTwoRows ? (self.rowHeight * 2 + self.rowSpacing) : self.rowHeight
        self.preferredWidth = width
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        Self.clearButtonWidthCache()
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        self.layer?.backgroundColor = theme.nsMenuSubtleFillColor.withAlphaComponent(0.20).cgColor
        self.layer?.cornerRadius = theme.shape.cornerRadius(RunicCornerRadius.sm)
        self.lightModeOverlayLayer.masksToBounds = false
        self.layer?.insertSublayer(self.lightModeOverlayLayer, at: 0)
        self.updateLightModeStyling()

        let layoutCount = self.useTwoRows
            ? Int(ceil(Double(self.segments.count) / 2.0))
            : self.segments.count
        let outerPadding: CGFloat = Self.switcherOuterPadding(
            for: width,
            count: layoutCount,
            minimumGap: minimumGap)
        let maxAllowedSegmentWidth = Self.maxAllowedUniformSegmentWidth(
            for: width,
            count: layoutCount,
            outerPadding: outerPadding,
            minimumGap: minimumGap)

        func makeButton(index: Int, segment: Segment) -> NSButton {
            let button: NSButton
            if self.stackedIcons {
                let stacked = StackedToggleButton(
                    title: segment.title,
                    image: segment.image,
                    iconSize: iconSize,
                    target: self,
                    action: #selector(self.handleSelection(_:)))
                button = stacked
            } else if self.showsIcons {
                let inline = InlineIconToggleButton(
                    title: segment.title,
                    image: segment.image,
                    iconSize: iconSize,
                    target: self,
                    action: #selector(self.handleSelection(_:)))
                button = inline
            } else {
                button = PaddedToggleButton(
                    title: segment.title,
                    target: self,
                    action: #selector(self.handleSelection(_:)))
            }
            button.tag = index
            if !self.showsIcons {
                button.image = nil
                button.imagePosition = .noImage
            }

            let remaining = self.weeklyRemainingProvider(segment.provider)
            self.addWeeklyIndicator(to: button, provider: segment.provider, remainingPercent: remaining)
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.controlSize = .small
            button.font = RunicFont.nsFont(size: 12, weight: .medium)
            button.setButtonType(.toggle)
            button.contentTintColor = self.theme.nsSecondaryTextColor
            button.alignment = .center
            button.wantsLayer = true
            button.layer?.cornerRadius = self.theme.shape.cornerRadius(RunicCornerRadius.md)
            button.state = (selected == segment.provider) ? .on : .off
            button.toolTip = nil
            button.translatesAutoresizingMaskIntoConstraints = false
            self.buttons.append(button)
            return button
        }

        for (index, segment) in self.segments.enumerated() {
            let button = makeButton(index: index, segment: segment)
            self.addSubview(button)
        }

        let uniformWidth: CGFloat
        if self.useTwoRows || !self.stackedIcons {
            uniformWidth = self.applyUniformSegmentWidth(maxAllowedWidth: maxAllowedSegmentWidth)
            if uniformWidth > 0 {
                self.segmentWidths = Array(repeating: uniformWidth, count: self.buttons.count)
            }
        } else {
            self.segmentWidths = self.applyNonUniformSegmentWidths(
                totalWidth: width,
                outerPadding: outerPadding,
                minimumGap: minimumGap)
            uniformWidth = 0
        }

        self.applyLayout(
            outerPadding: outerPadding,
            minimumGap: minimumGap,
            uniformWidth: uniformWidth)
        if width > 0 {
            self.preferredWidth = width
            self.frame.size.width = width
        }

        self.updateButtonStyles()
    }

    override func layout() {
        super.layout()
        self.lightModeOverlayLayer.frame = self.bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.updateLightModeStyling()
        self.updateButtonStyles()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let hoverTrackingArea {
            self.removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [
                .activeAlways,
                .inVisibleRect,
                .mouseEnteredAndExited,
                .mouseMoved,
            ],
            owner: self,
            userInfo: nil)
        self.addTrackingArea(trackingArea)
        self.hoverTrackingArea = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, from: nil)
        let hoveredTag = self.buttons.first(where: { $0.frame.contains(location) })?.tag
        guard hoveredTag != self.hoveredButtonTag else { return }
        self.hoveredButtonTag = hoveredTag
        self.updateButtonStyles()
    }

    override func mouseExited(with event: NSEvent) {
        guard self.hoveredButtonTag != nil else { return }
        self.hoveredButtonTag = nil
        self.updateButtonStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: self.preferredWidth, height: self.frame.size.height)
    }

    @objc private func handleSelection(_ sender: NSButton) {
        let index = sender.tag
        guard self.segments.indices.contains(index) else { return }
        for (idx, button) in self.buttons.enumerated() {
            button.state = (idx == index) ? .on : .off
        }
        self.updateButtonStyles()
        self.onSelect(self.segments[index].provider)
    }
}
