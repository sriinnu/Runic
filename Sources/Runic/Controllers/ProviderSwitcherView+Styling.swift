import AppKit
import RunicCore

extension ProviderSwitcherView {
    func updateButtonStyles() {
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

    func isLightMode() -> Bool {
        self.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
    }

    func updateLightModeStyling() {
        self.lightModeOverlayLayer.backgroundColor = self.theme.nsMenuSubtleFillColor
            .withAlphaComponent(self.isLightMode() ? 0.24 : 0.16)
            .cgColor
    }

    func hoverPlateColor() -> CGColor {
        self.theme.nsAccentColor.withAlphaComponent(self.isLightMode() ? 0.18 : 0.14).cgColor
    }

    func addWeeklyIndicator(to view: NSView, provider: UsageProvider, remainingPercent: Double?) {
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

    func updateWeeklyIndicatorVisibility(for view: NSView) {
        guard let indicator = self.weeklyIndicators[ObjectIdentifier(view)] else { return }
        let isSelected = (view as? NSButton)?.state == .on
        indicator.track.isHidden = isSelected
        indicator.fill.isHidden = isSelected
    }

    static func weeklyIndicatorColor(for provider: UsageProvider) -> NSColor {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        return NSColor(deviceRed: color.red, green: color.green, blue: color.blue, alpha: 1)
    }

    static func switcherTitle(for provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
    }
}
