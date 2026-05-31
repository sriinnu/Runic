import AppKit
import RunicCore

// MARK: - ProviderSwitcherView

final class ProviderSwitcherView: NSView {
    private struct Segment {
        let provider: UsageProvider
        let image: NSImage
        let title: String
    }

    private struct WeeklyIndicator {
        let provider: UsageProvider
        let track: NSView
        let fill: NSView
    }

    private let segments: [Segment]
    private let onSelect: (UsageProvider) -> Void
    private let showsIcons: Bool
    private let weeklyRemainingProvider: (UsageProvider) -> Double?
    private var buttons: [NSButton] = []
    private var weeklyIndicators: [ObjectIdentifier: WeeklyIndicator] = [:]
    private var hoverTrackingArea: NSTrackingArea?
    private var segmentWidths: [CGFloat] = []
    private let theme: RunicThemePalette
    private let selectedTextColor = NSColor.white
    private let stackedIcons: Bool
    private let useTwoRows: Bool
    private let rowSpacing: CGFloat
    private let rowHeight: CGFloat
    private var preferredWidth: CGFloat = 0
    private var hoveredButtonTag: Int?
    private let lightModeOverlayLayer = CALayer()

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

    private func applyLayout(
        outerPadding: CGFloat,
        minimumGap: CGFloat,
        uniformWidth: CGFloat)
    {
        if self.useTwoRows {
            self.applyTwoRowLayout(
                outerPadding: outerPadding,
                minimumGap: minimumGap,
                uniformWidth: uniformWidth)
            return
        }

        if self.buttons.count == 2 {
            let left = self.buttons[0]
            let right = self.buttons[1]
            let gap = right.leadingAnchor.constraint(greaterThanOrEqualTo: left.trailingAnchor, constant: minimumGap)
            gap.priority = .defaultHigh
            NSLayoutConstraint.activate([
                left.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: outerPadding),
                left.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                right.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -outerPadding),
                right.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                gap,
            ])
            return
        }

        if self.buttons.count == 3 {
            let left = self.buttons[0]
            let mid = self.buttons[1]
            let right = self.buttons[2]

            let leftGap = mid.leadingAnchor.constraint(greaterThanOrEqualTo: left.trailingAnchor, constant: minimumGap)
            leftGap.priority = .defaultHigh
            let rightGap = right.leadingAnchor.constraint(
                greaterThanOrEqualTo: mid.trailingAnchor,
                constant: minimumGap)
            rightGap.priority = .defaultHigh

            NSLayoutConstraint.activate([
                left.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: outerPadding),
                left.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                mid.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                mid.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                right.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -outerPadding),
                right.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                leftGap,
                rightGap,
            ])
            return
        }

        if self.buttons.count >= 4 {
            let widths = self.segmentWidths.isEmpty
                ? self.buttons.map { ceil($0.fittingSize.width) }
                : self.segmentWidths
            let layoutWidth = self.preferredWidth > 0 ? self.preferredWidth : self.bounds.width
            let availableWidth = max(0, layoutWidth - outerPadding * 2)
            let gaps = max(1, widths.count - 1)
            let computedGap = gaps > 0
                ? max(minimumGap, (availableWidth - widths.reduce(0, +)) / CGFloat(gaps))
                : 0
            let rowContainer = NSView()
            rowContainer.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(rowContainer)

            NSLayoutConstraint.activate([
                rowContainer.topAnchor.constraint(equalTo: self.topAnchor),
                rowContainer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                rowContainer.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: outerPadding),
                rowContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -outerPadding),
            ])

            var xOffset: CGFloat = 0
            for (index, button) in self.buttons.enumerated() {
                let width = index < widths.count ? widths[index] : 0
                if self.stackedIcons {
                    NSLayoutConstraint.activate([
                        button.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor, constant: xOffset),
                        button.topAnchor.constraint(equalTo: rowContainer.topAnchor),
                    ])
                } else {
                    NSLayoutConstraint.activate([
                        button.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor, constant: xOffset),
                        button.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
                    ])
                }
                xOffset += width + computedGap
            }
            return
        }

        if let first = self.buttons.first {
            NSLayoutConstraint.activate([
                first.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                first.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            ])
        }
    }

    private func applyTwoRowLayout(
        outerPadding: CGFloat,
        minimumGap: CGFloat,
        uniformWidth: CGFloat)
    {
        let splitIndex = Int(ceil(Double(self.buttons.count) / 2.0))
        let topButtons = Array(self.buttons.prefix(splitIndex))
        let bottomButtons = Array(self.buttons.dropFirst(splitIndex))

        let columns = max(topButtons.count, bottomButtons.count)
        let layoutWidth = self.preferredWidth > 0 ? self.preferredWidth : self.bounds.width
        let availableWidth = max(0, layoutWidth - outerPadding * 2)
        let gaps = max(1, columns - 1)
        let totalWidth = uniformWidth * CGFloat(columns)
        let computedGap = gaps > 0
            ? max(minimumGap, (availableWidth - totalWidth) / CGFloat(gaps))
            : 0
        let gridContainer = NSView()
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(gridContainer)

        NSLayoutConstraint.activate([
            gridContainer.topAnchor.constraint(equalTo: self.topAnchor),
            gridContainer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            gridContainer.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: outerPadding),
            gridContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -outerPadding),
        ])

        let topRow = NSView()
        topRow.translatesAutoresizingMaskIntoConstraints = false
        gridContainer.addSubview(topRow)

        let bottomRow = NSView()
        bottomRow.translatesAutoresizingMaskIntoConstraints = false
        gridContainer.addSubview(bottomRow)

        NSLayoutConstraint.activate([
            topRow.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor),
            topRow.trailingAnchor.constraint(equalTo: gridContainer.trailingAnchor),
            topRow.topAnchor.constraint(equalTo: gridContainer.topAnchor),
            topRow.heightAnchor.constraint(equalToConstant: self.rowHeight),
            bottomRow.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor),
            bottomRow.trailingAnchor.constraint(equalTo: gridContainer.trailingAnchor),
            bottomRow.bottomAnchor.constraint(equalTo: gridContainer.bottomAnchor),
            bottomRow.heightAnchor.constraint(equalToConstant: self.rowHeight),
            bottomRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: self.rowSpacing),
        ])

        for index in 0..<columns {
            let xOffset = CGFloat(index) * (uniformWidth + computedGap)
            if index < topButtons.count {
                let button = topButtons[index]
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor, constant: xOffset),
                    button.centerYAnchor.constraint(equalTo: topRow.centerYAnchor),
                ])
            }
            if index < bottomButtons.count {
                let button = bottomButtons[index]
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor, constant: xOffset),
                    button.centerYAnchor.constraint(equalTo: bottomRow.centerYAnchor),
                ])
            }
        }
    }

    private static func shouldUseTwoRows(
        count: Int,
        maxAllowedSegmentWidth: CGFloat,
        stackedIcons: Bool) -> Bool
    {
        guard count > 1 else { return false }
        let minimumComfortableAverage: CGFloat = stackedIcons ? 52 : 54
        return maxAllowedSegmentWidth < minimumComfortableAverage
    }

    private static func switcherOuterPadding(for width: CGFloat, count: Int, minimumGap: CGFloat) -> CGFloat {
        let preferred: CGFloat = MenuCardMetrics.horizontalPadding
        let reduced: CGFloat = 8
        let minimal: CGFloat = 6

        func averageButtonWidth(outerPadding: CGFloat) -> CGFloat {
            let available = width - outerPadding * 2 - minimumGap * CGFloat(max(0, count - 1))
            guard count > 0 else { return 0 }
            return available / CGFloat(count)
        }

        let minimumComfortableAverage: CGFloat = count >= 5 ? 50 : 56

        if averageButtonWidth(outerPadding: preferred) >= minimumComfortableAverage { return preferred }
        if averageButtonWidth(outerPadding: reduced) >= minimumComfortableAverage { return reduced }
        return minimal
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

    private func updateButtonStyles() {
        for button in self.buttons {
            let isSelected = button.state == .on
            let isHovered = self.hoveredButtonTag == button.tag
            button.contentTintColor = isSelected ? self.selectedTextColor : self.theme.nsSecondaryTextColor
            button.layer?.backgroundColor = if isSelected {
                self.theme.nsAccentColor.withAlphaComponent(0.78).cgColor
            } else if isHovered {
                self.hoverPlateColor()
            } else {
                NSColor.clear.cgColor
            }
            self.updateWeeklyIndicatorVisibility(for: button)
            (button as? StackedToggleButton)?.setContentTintColor(button.contentTintColor)
            (button as? InlineIconToggleButton)?.setContentTintColor(button.contentTintColor)
        }
    }

    private func isLightMode() -> Bool {
        self.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
    }

    private func updateLightModeStyling() {
        self.lightModeOverlayLayer.backgroundColor = self.theme.nsMenuSubtleFillColor
            .withAlphaComponent(self.isLightMode() ? 0.24 : 0.16)
            .cgColor
    }

    private func hoverPlateColor() -> CGColor {
        self.theme.nsAccentColor.withAlphaComponent(self.isLightMode() ? 0.18 : 0.14).cgColor
    }

    private static var buttonWidthCache: [ObjectIdentifier: CGFloat] = [:]

    private static func maxToggleWidth(for button: NSButton) -> CGFloat {
        let buttonId = ObjectIdentifier(button)

        if let cached = buttonWidthCache[buttonId] {
            return cached
        }

        let originalState = button.state
        defer { button.state = originalState }

        button.state = .off
        button.layoutSubtreeIfNeeded()
        let offWidth = button.fittingSize.width

        button.state = .on
        button.layoutSubtreeIfNeeded()
        let onWidth = button.fittingSize.width

        let maxWidth = max(offWidth, onWidth)
        self.buttonWidthCache[buttonId] = maxWidth
        return maxWidth
    }

    private static func clearButtonWidthCache() {
        self.buttonWidthCache.removeAll()
    }

    private func applyUniformSegmentWidth(maxAllowedWidth: CGFloat) -> CGFloat {
        guard !self.buttons.isEmpty else { return 0 }

        var desiredWidths: [CGFloat] = []
        desiredWidths.reserveCapacity(self.buttons.count)

        for (index, button) in self.buttons.enumerated() {
            if self.stackedIcons,
               self.segments.indices.contains(index)
            {
                let font = RunicFont.nsFont(size: NSFont.smallSystemFontSize)
                let titleWidth = ceil((self.segments[index].title as NSString).size(withAttributes: [.font: font])
                    .width)
                let contentPadding: CGFloat = 6 + 6
                let extraSlack: CGFloat = 1
                desiredWidths.append(ceil(titleWidth + contentPadding + extraSlack))
            } else {
                desiredWidths.append(ceil(Self.maxToggleWidth(for: button)))
            }
        }

        let maxDesired = desiredWidths.max() ?? 0
        let evenMaxDesired = maxDesired.truncatingRemainder(dividingBy: 2) == 0 ? maxDesired : maxDesired + 1
        let evenMaxAllowed = maxAllowedWidth > 0
            ? (maxAllowedWidth.truncatingRemainder(dividingBy: 2) == 0 ? maxAllowedWidth : maxAllowedWidth - 1)
            : 0
        let finalWidth: CGFloat = if evenMaxAllowed > 0 {
            min(evenMaxDesired, evenMaxAllowed)
        } else {
            evenMaxDesired
        }

        if finalWidth > 0 {
            for button in self.buttons {
                button.widthAnchor.constraint(equalToConstant: finalWidth).isActive = true
            }
        }

        return finalWidth
    }

    @discardableResult
    private func applyNonUniformSegmentWidths(
        totalWidth: CGFloat,
        outerPadding: CGFloat,
        minimumGap: CGFloat) -> [CGFloat]
    {
        guard !self.buttons.isEmpty else { return [] }

        let count = self.buttons.count
        let available = totalWidth -
            outerPadding * 2 -
            minimumGap * CGFloat(max(0, count - 1))
        guard available > 0 else { return [] }

        func evenFloor(_ value: CGFloat) -> CGFloat {
            var v = floor(value)
            if Int(v) % 2 != 0 { v -= 1 }
            return v
        }

        let desired = self.buttons.map { ceil(Self.maxToggleWidth(for: $0)) }
        let desiredSum = desired.reduce(0, +)
        let avg = floor(available / CGFloat(count))
        let minWidth = max(24, min(40, avg))

        var widths: [CGFloat]
        if desiredSum <= available {
            widths = desired
        } else {
            let totalCapacity = max(0, desiredSum - minWidth * CGFloat(count))
            if totalCapacity <= 0 {
                widths = Array(repeating: available / CGFloat(count), count: count)
            } else {
                let overflow = desiredSum - available
                widths = desired.map { desiredWidth in
                    let capacity = max(0, desiredWidth - minWidth)
                    let shrink = overflow * (capacity / totalCapacity)
                    return desiredWidth - shrink
                }
            }
        }

        widths = widths.map { max(minWidth, evenFloor($0)) }
        var used = widths.reduce(0, +)

        while available - used >= 2 {
            if let best = widths.indices
                .filter({ desired[$0] - widths[$0] >= 2 })
                .max(by: { lhs, rhs in
                    (desired[lhs] - widths[lhs]) < (desired[rhs] - widths[rhs])
                })
            {
                widths[best] += 2
                used += 2
                continue
            }

            guard let best = widths.indices.min(by: { lhs, rhs in widths[lhs] < widths[rhs] }) else { break }
            widths[best] += 2
            used += 2
        }

        for (index, button) in self.buttons.enumerated() where index < widths.count {
            button.widthAnchor.constraint(equalToConstant: widths[index]).isActive = true
        }

        return widths
    }

    private static func maxAllowedUniformSegmentWidth(
        for totalWidth: CGFloat,
        count: Int,
        outerPadding: CGFloat,
        minimumGap: CGFloat) -> CGFloat
    {
        guard count > 0 else { return 0 }
        let available = totalWidth -
            outerPadding * 2 -
            minimumGap * CGFloat(max(0, count - 1))
        guard available > 0 else { return 0 }
        return floor(available / CGFloat(count))
    }

    private func addWeeklyIndicator(to view: NSView, provider: UsageProvider, remainingPercent: Double?) {
        guard let remainingPercent else { return }

        let track = NSView()
        track.wantsLayer = true
        track.layer?.backgroundColor = self.theme.nsCardStrokeColor
            .withAlphaComponent(CGFloat(RunicColors.Opacity.strong)).cgColor
        track.layer?.cornerRadius = 3
        track.layer?.masksToBounds = true
        track.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(track)

        let fill = NSView()
        fill.wantsLayer = true
        fill.layer?.backgroundColor = Self.weeklyIndicatorColor(for: provider).cgColor
        fill.layer?.cornerRadius = 3
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)

        let ratio = CGFloat(max(0, min(1, remainingPercent / 100)))

        NSLayoutConstraint.activate([
            track.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            track.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            track.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -1),
            track.heightAnchor.constraint(equalToConstant: 5),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
        ])

        fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: ratio).isActive = true

        self.weeklyIndicators[ObjectIdentifier(view)] = WeeklyIndicator(provider: provider, track: track, fill: fill)
        self.updateWeeklyIndicatorVisibility(for: view)
    }

    private func updateWeeklyIndicatorVisibility(for view: NSView) {
        guard let indicator = self.weeklyIndicators[ObjectIdentifier(view)] else { return }
        let isSelected = (view as? NSButton)?.state == .on
        indicator.track.isHidden = isSelected
        indicator.fill.isHidden = isSelected
    }

    private static func weeklyIndicatorColor(for provider: UsageProvider) -> NSColor {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        return NSColor(deviceRed: color.red, green: color.green, blue: color.blue, alpha: 1)
    }

    private static func switcherTitle(for provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
    }
}
