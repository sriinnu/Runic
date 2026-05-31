import Foundation
import RunicCore

extension EnhancedUsageCommand {
    static func loadUsageData(
        providers: [UsageProvider],
        days: Int,
        includeCost: Bool) async throws -> EnhancedUsageData
    {
        let fetcher = UsageFetcher()
        _ = includeCost ? CostUsageFetcher() : nil
        var providerData: [ProviderUsageData] = []

        for provider in providers {
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let context = ProviderFetchContext(
                runtime: .cli,
                sourceMode: .cli,
                includeCredits: true,
                webTimeout: 60,
                webDebugDumpHTML: false,
                verbose: false,
                env: ProcessInfo.processInfo.environment,
                settings: nil,
                fetcher: fetcher,
                claudeFetcher: ClaudeUsageFetcher())

            let outcome = await descriptor.fetchOutcome(context: context)

            if case let .success(result) = outcome.result {
                let trending = try? await loadTrendingData(
                    provider: provider,
                    days: days)

                let data = self.buildProviderData(
                    provider: provider,
                    snapshot: result.usage,
                    credits: result.credits,
                    metadata: descriptor.metadata,
                    trending: trending)

                providerData.append(data)
            }
        }

        let summary = self.buildSummary(providerData: providerData)
        let comparison = self.buildComparison(providerData: providerData)

        return EnhancedUsageData(
            providers: providerData,
            summary: summary,
            comparison: comparison)
    }

    static func buildProviderData(
        provider: UsageProvider,
        snapshot: UsageSnapshot,
        credits: CreditsSnapshot?,
        metadata: ProviderMetadata,
        trending: [DailyTrend]?) -> ProviderUsageData
    {
        var windows: [WindowData] = []

        windows.append(WindowData(
            name: metadata.sessionLabel,
            used: nil,
            limit: nil,
            usedPercent: snapshot.primary.usedPercent,
            remainingPercent: snapshot.primary.remainingPercent,
            resetDescription: snapshot.primary.resetDescription))

        if let secondary = snapshot.secondary {
            windows.append(WindowData(
                name: metadata.weeklyLabel,
                used: nil,
                limit: nil,
                usedPercent: secondary.usedPercent,
                remainingPercent: secondary.remainingPercent,
                resetDescription: secondary.resetDescription))
        }

        return ProviderUsageData(
            provider: provider,
            providerName: provider.rawValue.capitalized,
            snapshot: snapshot,
            credits: credits,
            windows: windows,
            breakdown: nil,
            trending: trending,
            projected: nil)
    }

    static func loadTrendingData(
        provider: UsageProvider,
        days: Int) async throws -> [DailyTrend]?
    {
        let source = UsageLedgerSourceFactory.source(for: provider, now: Date(), maxAgeDays: days)

        guard let source else { return nil }

        let entries = try await source.loadEntries()
        let summaries = UsageLedgerAggregator.dailySummaries(
            entries: entries,
            timeZone: .current,
            groupByProject: false)

        return summaries.map { summary in
            DailyTrend(
                date: summary.dayKey,
                totalTokens: summary.totals.totalTokens,
                cost: summary.totals.costUSD)
        }
    }

    static func buildSummary(
        providerData: [ProviderUsageData]) -> UsageSummary?
    {
        guard !providerData.isEmpty else { return nil }

        let totalTokens = providerData.reduce(0) { sum, data in
            sum + data.windows.reduce(0) { $0 + ($1.used ?? 0) }
        }

        let averageUsage = providerData.reduce(0.0) { sum, data in
            let providerAvg = data.windows.map(\.usedPercent).reduce(0.0, +) / Double(data.windows.count)
            return sum + providerAvg
        } / Double(providerData.count)

        let highestProvider = providerData.max { lhs, rhs in
            let lhsMax = lhs.windows.map(\.usedPercent).max() ?? 0
            let rhsMax = rhs.windows.map(\.usedPercent).max() ?? 0
            return lhsMax < rhsMax
        }

        return UsageSummary(
            totalProviders: providerData.count,
            totalTokens: totalTokens,
            totalCost: nil,
            highestUsageProvider: highestProvider?.providerName ?? "unknown",
            averageUsagePercent: averageUsage)
    }

    static func buildComparison(
        providerData: [ProviderUsageData]) -> ProviderComparison?
    {
        guard providerData.count > 1 else { return nil }

        let comparisons = providerData.map { data in
            let totalTokens = data.windows.reduce(0) { $0 + ($1.used ?? 0) }
            let efficiency = data.windows.map(\.usedPercent).min() ?? 100

            return ProviderComparisonItem(
                provider: data.providerName,
                totalTokens: totalTokens,
                cost: nil,
                efficiency: efficiency)
        }

        let mostEfficient = comparisons.min { $0.efficiency < $1.efficiency }?.provider

        return ProviderComparison(
            comparisons: comparisons,
            mostEfficient: mostEfficient,
            mostExpensive: nil)
    }
}
