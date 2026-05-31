import AppKit
import Observation
import RunicCore
import SwiftUI

extension StatusItemController {
    func makeProviderSwitcherItem(
        providers: [UsageProvider],
        selected: UsageProvider?,
        menu: NSMenu) -> NSMenuItem
    {
        let view = ProviderSwitcherView(
            providers: providers,
            selected: selected,
            width: self.menuCardWidth(for: providers, menu: menu),
            showsIcons: self.settings.switcherShowsIcons,
            iconSizePreference: self.settings.providerSwitcherIconSize,
            theme: self.settings.theme.palette,
            iconProvider: { [weak self] provider, iconSize in
                self?.switcherIcon(for: provider, size: iconSize) ?? NSImage()
            },
            weeklyRemainingProvider: { [weak self] provider in
                self?.switcherWeeklyRemaining(for: provider)
            },
            onSelect: { [weak self, weak menu] provider in
                guard let self, let menu else { return }
                self.selectedMenuProvider = provider
                self.lastMenuProvider = provider
                self.populateMenu(menu, provider: provider)
                self.markMenuFresh(menu)
                self.refreshMenuCardHeights(in: menu)
                self.applyIcon(phase: nil)
            })
        let item = NSMenuItem()
        item.view = view
        item.isEnabled = false
        return item
    }

    func makeProviderTabBar(
        providers: [UsageProvider],
        selected: UsageProvider?,
        width: CGFloat,
        menu: NSMenu) -> ProviderTabBarView?
    {
        guard providers.count > 1 else { return nil }
        let overviewColor = self.settings.theme.palette.accent

        var tabs: [ProviderTabBarView.TabItem] = [
            ProviderTabBarView.TabItem(
                id: "overview",
                label: "Overview",
                icon: nil,
                provider: nil,
                isSelected: selected == nil,
                brandColor: overviewColor),
        ]

        for provider in providers {
            let meta = self.store.metadata(for: provider)
            let icon = ProviderBrandIcon.image(for: provider, size: 22)
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let brandColor = Color(
                red: Double(descriptor.branding.color.red),
                green: Double(descriptor.branding.color.green),
                blue: Double(descriptor.branding.color.blue))
            tabs.append(ProviderTabBarView.TabItem(
                id: provider.rawValue,
                label: Self.abbreviatedProviderName(meta.displayName),
                icon: icon,
                provider: provider,
                isSelected: selected == provider,
                brandColor: brandColor))
        }

        return ProviderTabBarView(
            tabs: tabs,
            width: width,
            onSelect: { [weak self, weak menu] provider in
                guard let self, let menu else { return }
                self.selectedMenuProvider = provider
                self.lastMenuProvider = provider
                Task { @MainActor [weak self, weak menu] in
                    guard let self, let menu else { return }
                    self.populateMenu(menu, provider: provider)
                    self.markMenuFresh(menu)
                    self.refreshMenuCardHeights(in: menu)
                    self.applyIcon(phase: nil)
                }
            })
    }

    func makeOverviewView(
        providers: [UsageProvider],
        width: CGFloat) -> OverviewMenuView
    {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        var summaries: [OverviewMenuView.ProviderSummary] = []
        var chartPoints: [OverviewMenuView.DailyPoint] = []
        var totalToday = 0

        for provider in providers {
            let meta = self.store.metadata(for: provider)
            let snapshot = self.store.snapshot(for: provider)
            let icon = ProviderBrandIcon.image(for: provider, size: 20)
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let brandColor = Color(
                red: Double(descriptor.branding.color.red),
                green: Double(descriptor.branding.color.green),
                blue: Double(descriptor.branding.color.blue))
            let usedPercent = snapshot?.primary.usedPercent ?? 0
            let todayTokens = self.store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0
            totalToday += todayTokens

            let resetDesc = snapshot?.primary.resetDescription
            let windowLabel = snapshot?.primary.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            let topModel = self.store.ledgerTopModel(for: provider)
            let topModelContext = ProviderContextWindowRegistry.shared
                .contextLabel(for: provider, model: topModel?.model)?
                .text

            summaries.append(OverviewMenuView.ProviderSummary(
                id: provider.rawValue,
                provider: provider,
                name: meta.displayName,
                icon: icon,
                usedPercent: usedPercent,
                todayTokens: todayTokens,
                brandColor: brandColor,
                resetDescription: resetDesc,
                windowLabel: windowLabel,
                topModelContext: topModelContext))

            let dailySummaries = self.store.ledgerAllDailySummary(for: provider)
            for summary in dailySummaries where summary.dayStart >= weekAgo {
                chartPoints.append(OverviewMenuView.DailyPoint(
                    id: "\(provider.rawValue)-\(summary.dayKey)",
                    date: summary.dayStart,
                    tokens: summary.totals.totalTokens,
                    provider: meta.displayName,
                    color: brandColor))
            }
        }

        let activeSummaries = summaries.filter { $0.usedPercent > 0 || $0.todayTokens > 0 }

        return OverviewMenuView(
            summaries: activeSummaries.isEmpty ? summaries : activeSummaries,
            chartPoints: chartPoints,
            totalTodayTokens: totalToday,
            totalProviders: providers.count,
            width: width)
    }

    static func abbreviatedProviderName(_ name: String) -> String {
        if name.count <= 8 { return name }
        let abbreviations: [String: String] = [
            "Antigravity": "AntiG",
            "OpenRouter": "ORouter",
            "Perplexity": "Perplx",
            "SambaNova": "SambaN",
            "Azure OpenAI": "Azure",
        ]
        return abbreviations[name] ?? String(name.prefix(6))
    }

    func switcherIcon(for provider: UsageProvider, size: CGFloat) -> NSImage {
        if let brand = ProviderBrandIcon.image(for: provider, size: size) {
            return brand
        }

        let snapshot = self.store.snapshot(for: provider)
        let showUsed = self.settings.usageBarsShowUsed
        let primary = showUsed ? snapshot?.primary.usedPercent : snapshot?.primary.remainingPercent
        let weekly = showUsed ? snapshot?.secondary?.usedPercent : snapshot?.secondary?.remainingPercent
        let credits = provider == .codex ? self.store.credits?.remaining : nil
        let stale = self.store.isStale(provider: provider)
        let style = self.store.style(for: provider)
        let indicator = self.store.statusIndicator(for: provider)
        let image = IconRenderer.makeIcon(
            primaryRemaining: primary,
            weeklyRemaining: weekly,
            creditsRemaining: credits,
            stale: stale,
            style: style,
            blink: 0,
            wiggle: 0,
            tilt: 0,
            statusIndicator: indicator)
        image.isTemplate = true
        image.size = NSSize(width: size, height: size)
        return image
    }

    func switcherWeeklyRemaining(for provider: UsageProvider) -> Double? {
        let snapshot = self.store.snapshot(for: provider)
        let window: RateWindow? = if provider == .factory {
            snapshot?.secondary ?? snapshot?.primary
        } else {
            snapshot?.primary ?? snapshot?.secondary
        }
        guard let window else { return nil }
        if self.settings.usageBarsShowUsed {
            return window.usedPercent
        }
        return window.remainingPercent
    }
}
