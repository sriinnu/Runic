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

        for provider in providers {
            let meta = self.store.metadata(for: provider)
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            tabs.append(ProviderTabBarView.TabItem(
                id: provider.rawValue,
                label: Self.abbreviatedProviderName(meta.displayName),
                icon: ProviderBrandIcon.image(for: provider, size: 24),
                provider: provider,
                isSelected: selected == provider,
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
            width: self.contentWidth)
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
        var chartPoints: [OverviewMenuView.DailyPoint] = []
        var totalToday = 0

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

            summaries.append(OverviewMenuView.ProviderSummary(
                id: provider.rawValue,
                provider: provider,
                name: meta.displayName,
                icon: ProviderBrandIcon.image(for: provider, size: 20),
                usedPercent: snapshot?.primary.usedPercent ?? 0,
                todayTokens: todayTokens,
                brandColor: brandColor,
                resetDescription: snapshot?.primary.resetDescription,
                windowLabel: snapshot?.primary.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                topModelContext: context))

            for summary in self.store.ledgerAllDailySummary(for: provider) where summary.dayStart >= weekAgo {
                chartPoints.append(OverviewMenuView.DailyPoint(
                    id: "\(provider.rawValue)-\(summary.dayKey)",
                    date: summary.dayStart,
                    tokens: summary.totals.totalTokens,
                    provider: meta.displayName,
                    color: brandColor))
            }
        }

        let activeSummaries = summaries.filter { $0.usedPercent > 0 || $0.todayTokens > 0 }
        return (activeSummaries.isEmpty ? summaries : activeSummaries, chartPoints, totalToday)
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
}
