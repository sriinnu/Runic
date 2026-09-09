import Foundation
import RunicCore
import SwiftUI

extension MenuPopoverView {
    func providerTabs(providers: [UsageProvider], selected: UsageProvider?) -> some View {
        let tabs = self.providerTabItems(providers: providers, selected: selected)
        return ProviderTabBarView(
            tabs: tabs,
            width: self.contentWidth,
            onSelect: { provider in
                self.selectProvider(provider)
            })
            .clipShape(RoundedRectangle(
                cornerRadius: self.settings.theme.palette.shape.cornerRadius(RunicCornerRadius.lg),
                style: .continuous))
            .overlay {
                RoundedRectangle(
                    cornerRadius: self.settings.theme.palette.shape.cornerRadius(RunicCornerRadius.lg),
                    style: .continuous)
                    .stroke(
                        self.settings.theme.palette.cardStroke.opacity(
                            self.settings.theme.palette.style.chrome.borderOpacity * 0.7),
                        lineWidth: self.settings.theme.palette.style.chrome.borderWeight)
            }
            .frame(width: self.contentWidth, alignment: .leading)
    }

    func providerTabItems(
        providers: [UsageProvider],
        selected: UsageProvider?) -> [ProviderTabBarView.TabItem]
    {
        var tabs: [ProviderTabBarView.TabItem] = [
            ProviderTabBarView.TabItem(
                id: "overview",
                label: "Overview",
                icon: nil,
                provider: nil,
                isSelected: selected == nil,
                brandColor: self.settings.theme.palette.accent),
        ]

        // One tab per brand: a China slot rides under its international
        // sibling's tab, and the card area stacks both regions.
        var seenRoots: Set<UsageProvider> = []
        for provider in providers {
            let root = provider.brandRoot
            guard seenRoots.insert(root).inserted else { continue }
            let meta = self.store.metadata(for: root)
            let descriptor = ProviderDescriptorRegistry.descriptor(for: root)
            tabs.append(ProviderTabBarView.TabItem(
                id: root.rawValue,
                label: Self.abbreviatedProviderName(meta.displayName),
                icon: ProviderBrandIcon.image(for: root, size: 24),
                provider: root,
                isSelected: selected?.brandRoot == root,
                brandColor: Color(
                    red: Double(descriptor.branding.color.red),
                    green: Double(descriptor.branding.color.green),
                    blue: Double(descriptor.branding.color.blue))))
        }

        return tabs
    }

    func overviewView(providers: [UsageProvider]) -> some View {
        let model = self.overviewModel(providers: providers)
        return OverviewMenuView(
            summaries: model.summaries,
            chartPoints: model.chartPoints,
            totalTodayTokens: model.totalTodayTokens,
            totalProviders: providers.count,
            width: self.contentWidth,
            showsUsed: self.settings.usageBarsShowUsed,
            numberStyle: self.settings.numberFormat.formatterStyle,
            onAddRegion: { slot in self.actions.openProviderSettings(slot) })
    }

    func overviewModel(providers: [UsageProvider])
        -> (
            summaries: [OverviewMenuView.ProviderSummary],
            chartPoints: [OverviewMenuView.DailyPoint],
            totalTodayTokens: Int)
    {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        var summaries: [OverviewMenuView.ProviderSummary] = []
        var activeIDs: Set<String> = []
        var chartPoints: [OverviewMenuView.DailyPoint] = []
        var totalToday = 0
        let showsUsed = self.settings.usageBarsShowUsed

        for provider in providers {
            let meta = self.store.metadata(for: provider)
            let snapshot = self.store.snapshot(for: provider)
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let brandColor = Color(
                red: Double(descriptor.branding.color.red),
                green: Double(descriptor.branding.color.green),
                blue: Double(descriptor.branding.color.blue))
            let todayTokens = self.store.ledgerDailySummary(for: provider)?.totals.totalTokens ?? 0
            totalToday += todayTokens
            let topModel = self.store.ledgerTopModel(for: provider)
            let context = ProviderContextWindowRegistry.shared.contextLabel(for: provider, model: topModel?.model)?.text

            let hasQuota = OverviewMenuView.windowHasQuota(snapshot?.primary)
            // "Active" stays anchored on raw consumption so the used/left
            // toggle doesn't change which providers the overview lists.
            if (snapshot?.primary.usedPercent ?? 0) > 0 || todayTokens > 0 {
                activeIDs.insert(provider.rawValue)
            }

            summaries.append(OverviewMenuView.ProviderSummary(
                id: provider.rawValue,
                provider: provider,
                name: UsageProvider.compactDisplayName(meta.displayName),
                icon: ProviderBrandIcon.image(for: provider, size: 20),
                usedPercent: OverviewMenuView.displayPercent(for: snapshot?.primary, showsUsed: showsUsed),
                todayTokens: todayTokens,
                brandColor: brandColor,
                resetDescription: OverviewMenuView.resetPill(for: snapshot?.primary),
                windowLabel: snapshot?.primary.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                topModelContext: context,
                hasQuota: hasQuota,
                bankedResetsText: OverviewMenuView.bankedResetsPill(for: snapshot?.resetCredits)))

            for summary in self.store.ledgerAllDailySummary(for: provider) where summary.dayStart >= weekAgo {
                chartPoints.append(OverviewMenuView.DailyPoint(
                    id: "\(provider.rawValue)-\(summary.dayKey)",
                    date: summary.dayStart,
                    tokens: summary.totals.totalTokens,
                    provider: UsageProvider.compactDisplayName(meta.displayName),
                    color: brandColor))
            }
        }

        // Keep a brand's sibling row alongside an active one so a two-region
        // brand always stacks as a unit.
        let activeRoots = Set(summaries.filter { activeIDs.contains($0.id) }.map(\.brandRoot))
        let activeSummaries = summaries.filter { activeRoots.contains($0.brandRoot) }
        return (activeSummaries.isEmpty ? summaries : activeSummaries, chartPoints, totalToday)
    }

    /// Visible slots of the brand `provider` belongs to, international first.
    func brandSlots(for provider: UsageProvider, in enabledProviders: [UsageProvider]) -> [UsageProvider] {
        let root = provider.brandRoot
        let candidates = [root] + (root.chinaSibling.map { [$0] } ?? [])
        let visible = candidates.filter { enabledProviders.contains($0) }
        return visible.isEmpty ? [provider] : visible
    }

    /// For a two-region brand with one side unconfigured, the slot to offer.
    func missingBrandSlot(for provider: UsageProvider, in enabledProviders: [UsageProvider]) -> UsageProvider? {
        let root = provider.brandRoot
        guard let china = root.chinaSibling else { return nil }
        if !enabledProviders.contains(china) { return china }
        if !enabledProviders.contains(root) { return root }
        return nil
    }

    static func abbreviatedProviderName(_ name: String) -> String {
        ProviderNameAbbreviator.abbreviate(name)
    }
}
