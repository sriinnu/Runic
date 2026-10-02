import Foundation
import RunicCore
#if canImport(WidgetKit)
import WidgetKit
#endif

extension UsageStore {
    func persistWidgetSnapshot(reason: String) {
        let snapshot = self.makeWidgetSnapshot()
        let mcpState = self.makeMCPState()
        try? RunicMCPStateStore.save(mcpState)
        Task.detached(priority: .utility) {
            WidgetSnapshotStore.save(snapshot)
            #if canImport(WidgetKit)
            await MainActor.run {
                WidgetCenter.shared.reloadAllTimelines()
            }
            #endif
        }
    }

    private func makeMCPState() -> RunicMCPState {
        let providers = self.enabledProviders().map { provider in
            let snapshot = self.snapshots[provider]
            return RunicMCPState.Provider(
                id: provider,
                updatedAt: snapshot?.updatedAt,
                primary: snapshot?.primary,
                secondary: snapshot?.secondary,
                tertiary: snapshot?.tertiary,
                creditsRemaining: self.credits(for: provider)?.remaining,
                creditsUpdatedAt: self.credits(for: provider)?.updatedAt,
                creditsHasError: self.creditsError(for: provider) != nil,
                balance: snapshot?.balance,
                extraUsage: snapshot?.providerCost,
                source: Self.mcpSourceKind(self.lastSourceLabels[provider]),
                hasError: self.errors[provider] != nil)
        }
        return RunicMCPState(
            generatedAt: Date(),
            refreshFrequency: self.settings.refreshFrequency.rawValue,
            refreshStatus: self.autoRefreshStatusLine() ?? "Unknown",
            lastRefreshAt: self.lastRefreshAt,
            providers: providers)
    }

    private static func mcpSourceKind(_ label: String?) -> String? {
        guard let label else { return nil }
        let lower = label.lowercased()
        if lower.contains("web") || lower.contains("browser") { return "web" }
        if lower.contains("oauth") { return "oauth" }
        if lower.contains("cli") || lower.contains("gcloud") { return "cli" }
        if lower.contains("api") { return "api" }
        if lower.contains("local") { return "local" }
        return "other"
    }

    private func makeWidgetSnapshot() -> WidgetSnapshot {
        let enabledProviders = self.enabledProviders()
        let entries = UsageProvider.allCases.compactMap { provider in
            self.makeWidgetEntry(for: provider)
        }
        return WidgetSnapshot(entries: entries, enabledProviders: enabledProviders, generatedAt: Date())
    }

    private func makeWidgetEntry(for provider: UsageProvider) -> WidgetSnapshot.ProviderEntry? {
        guard let snapshot = self.snapshots[provider] else { return nil }

        let tokenSnapshot = self.tokenSnapshots[provider]
        let dailyUsage = tokenSnapshot?.daily.map { entry in
            WidgetSnapshot.DailyUsagePoint(
                dayKey: entry.date,
                totalTokens: entry.totalTokens,
                costUSD: entry.costUSD)
        } ?? []

        let tokenUsage = Self.widgetTokenUsageSummary(from: tokenSnapshot)
        let creditsRemaining = provider == .codex ? self.credits?.remaining : nil
        let codeReviewRemaining = provider == .codex ? self.openAIDashboard?.codeReviewRemainingPercent : nil

        return WidgetSnapshot.ProviderEntry(
            provider: provider,
            updatedAt: snapshot.updatedAt,
            primary: snapshot.primary,
            secondary: snapshot.secondary,
            tertiary: snapshot.tertiary,
            creditsRemaining: creditsRemaining,
            codeReviewRemainingPercent: codeReviewRemaining,
            tokenUsage: tokenUsage,
            dailyUsage: dailyUsage)
    }

    private nonisolated static func widgetTokenUsageSummary(
        from snapshot: CostUsageTokenSnapshot?) -> WidgetSnapshot.TokenUsageSummary?
    {
        guard let snapshot else { return nil }
        let fallbackTokens = snapshot.daily.compactMap(\.totalTokens).reduce(0, +)
        let monthTokensValue = snapshot.last30DaysTokens ?? (fallbackTokens > 0 ? fallbackTokens : nil)
        return WidgetSnapshot.TokenUsageSummary(
            sessionCostUSD: snapshot.sessionCostUSD,
            sessionTokens: snapshot.sessionTokens,
            last30DaysCostUSD: snapshot.last30DaysCostUSD,
            last30DaysTokens: monthTokensValue)
    }
}
