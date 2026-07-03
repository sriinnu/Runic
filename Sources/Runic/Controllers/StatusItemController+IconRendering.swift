import AppKit
import RunicCore

// MARK: - Menu bar icon rendering

extension StatusItemController {
    func applyIcon(phase: Double?) {
        guard let button = self.statusItem.button else { return }

        let style = self.store.iconStyle
        let showUsed = self.settings.usageBarsShowUsed
        let showBrandPercent = self.settings.menuBarShowsBrandIconWithPercent
        let primaryProvider = self.primaryProviderForUnifiedIcon()
        let snapshot = self.store.snapshot(for: primaryProvider)

        // IconRenderer treats these values as a left-to-right "progress fill" percentage. Depending on the
        // user setting, pass either "percent left" or "percent used". Windows without a real limit
        // yield nil so the plain icon renders instead of a fake full/empty gauge.
        var primary = snapshot?.primary.gaugePercent(showUsed: showUsed)
        var weekly = snapshot?.secondary?.gaugePercent(showUsed: showUsed)
        var credits: Double? = primaryProvider == .codex ? self.store.credits?.remaining : nil
        var stale = self.store.isStale(provider: primaryProvider)
        var morphProgress: Double?

        let needsAnimation = self.needsMenuBarIconAnimation()
        if let phase, needsAnimation {
            var pattern = self.animationPattern
            if style == .combined, pattern == .unbraid {
                pattern = .cylon
            }
            if pattern == .unbraid {
                morphProgress = pattern.value(phase: phase) / 100
                primary = nil
                weekly = nil
                credits = nil
                stale = false
            } else {
                primary = pattern.value(phase: phase)
                weekly = pattern.value(phase: phase + pattern.secondaryOffset)
                credits = nil
                stale = false
            }
        }

        let blink: CGFloat = style == .combined ? 0 : self.blinkAmount(for: primaryProvider)
        let wiggle: CGFloat = style == .combined ? 0 : self.wiggleAmount(for: primaryProvider)
        let tilt: CGFloat = style == .combined ? 0 : self.tiltAmount(for: primaryProvider) * .pi / 28

        let statusIndicator = self.mergedIconStatusIndicator()
        let appearance: IconAppearance = self.settings.menuBarVibrantIconEnabled ? .vibrant : .template
        let dataMode: IconDataMode = showUsed ? .used : .remaining

        if showBrandPercent,
           let brand = ProviderBrandIcon.image(for: primaryProvider)
        {
            let percentText = self.menuBarPercentText(for: primaryProvider, snapshot: snapshot)
            self.setButtonImage(brand, for: button)
            self.setButtonTitle(percentText, for: button)
            return
        }

        self.setButtonTitle(nil, for: button)
        if let morphProgress {
            let image = IconRenderer.makeMorphIcon(progress: morphProgress, style: style, appearance: appearance)
            self.setButtonImage(image, for: button)
        } else {
            let image = IconRenderer.makeIcon(
                primaryRemaining: primary,
                weeklyRemaining: weekly,
                creditsRemaining: credits,
                stale: stale,
                style: style,
                blink: blink,
                wiggle: wiggle,
                tilt: tilt,
                statusIndicator: statusIndicator,
                appearance: appearance,
                dataMode: dataMode)
            self.setButtonImage(image, for: button)
        }
    }

    func applyIcon(for provider: UsageProvider, phase: Double?) {
        guard let button = self.statusItems[provider]?.button else { return }
        let snapshot = self.store.snapshot(for: provider)
        // IconRenderer treats these values as a left-to-right "progress fill" percentage. Depending on the
        // user setting, pass either "percent left" or "percent used".
        let showUsed = self.settings.usageBarsShowUsed
        let showBrandPercent = self.settings.menuBarShowsBrandIconWithPercent
        let appearance: IconAppearance = self.settings.menuBarVibrantIconEnabled ? .vibrant : .template
        let dataMode: IconDataMode = showUsed ? .used : .remaining
        if showBrandPercent,
           let brand = ProviderBrandIcon.image(for: provider)
        {
            let percentText = self.menuBarPercentText(for: provider, snapshot: snapshot)
            self.setButtonImage(brand, for: button)
            self.setButtonTitle(percentText, for: button)
            return
        }
        var primary = snapshot?.primary.gaugePercent(showUsed: showUsed)
        var weekly = snapshot?.secondary?.gaugePercent(showUsed: showUsed)
        var credits: Double? = provider == .codex ? self.store.credits?.remaining : nil
        var stale = self.store.isStale(provider: provider)
        var morphProgress: Double?

        if let phase, self.shouldAnimate(provider: provider) {
            var pattern = self.animationPattern
            if provider == .claude, pattern == .unbraid {
                pattern = .cylon
            }
            if pattern == .unbraid {
                morphProgress = pattern.value(phase: phase) / 100
                primary = nil
                weekly = nil
                credits = nil
                stale = false
            } else {
                primary = pattern.value(phase: phase)
                weekly = pattern.value(phase: phase + pattern.secondaryOffset)
                credits = nil
                stale = false
            }
        }

        let style: IconStyle = self.store.style(for: provider)
        let blink = self.blinkAmount(for: provider)
        let wiggle = self.wiggleAmount(for: provider)
        let tilt = self.tiltAmount(for: provider) * .pi / 28 // limit to ~6.4 degrees
        if let morphProgress {
            let image = IconRenderer.makeMorphIcon(progress: morphProgress, style: style, appearance: appearance)
            self.setButtonImage(image, for: button)
        } else {
            self.setButtonTitle(nil, for: button)
            let image = IconRenderer.makeIcon(
                primaryRemaining: primary,
                weeklyRemaining: weekly,
                creditsRemaining: credits,
                stale: stale,
                style: style,
                blink: blink,
                wiggle: wiggle,
                tilt: tilt,
                statusIndicator: self.store.statusIndicator(for: provider),
                appearance: appearance,
                dataMode: dataMode)
            self.setButtonImage(image, for: button)
        }
    }

    func primaryProviderForUnifiedIcon() -> UsageProvider {
        if self.shouldMergeIcons,
           let selected = self.selectedMenuProvider,
           self.store.isEnabled(selected)
        {
            return selected
        }
        for provider in UsageProvider.allCases {
            if self.store.isEnabled(provider), self.store.snapshot(for: provider) != nil {
                return provider
            }
        }
        if let enabled = self.store.enabledProviders().first {
            return enabled
        }
        return .codex
    }

    private func mergedIconStatusIndicator() -> ProviderStatusIndicator {
        for provider in UsageProvider.allCases {
            let indicator = self.store.statusIndicator(for: provider)
            if indicator.hasIssue { return indicator }
        }
        return .none
    }

    private func setButtonImage(_ image: NSImage, for button: NSStatusBarButton) {
        if button.image === image { return }
        let previousSize = button.image?.size
        button.image = image
        if previousSize != image.size {
            button.sizeToFit()
        }
    }

    private func setButtonTitle(_ title: String?, for button: NSStatusBarButton) {
        let value = title ?? ""
        let position: NSControl.ImagePosition = value.isEmpty ? .imageOnly : .imageLeft
        var needsResize = false
        if button.title != value {
            button.title = value
            needsResize = true
        }
        if button.imagePosition != position {
            button.imagePosition = position
            needsResize = true
        }
        if needsResize {
            button.sizeToFit()
        }
    }

    private func menuBarPercentText(for provider: UsageProvider, snapshot: UsageSnapshot?) -> String? {
        guard let window = self.menuBarPercentWindow(for: provider, snapshot: snapshot),
              let percent = window.gaugePercent(showUsed: self.settings.usageBarsShowUsed)
        else { return nil }
        return String(format: "%.0f%%", percent)
    }

    private func menuBarPercentWindow(for provider: UsageProvider, snapshot: UsageSnapshot?) -> RateWindow? {
        let ordered: [RateWindow?] = provider == .factory
            ? [snapshot?.secondary, snapshot?.primary]
            : [snapshot?.primary, snapshot?.secondary]
        let windows = ordered.compactMap(\.self)
        return windows.first { $0.hasKnownLimit != false } ?? windows.first
    }
}
