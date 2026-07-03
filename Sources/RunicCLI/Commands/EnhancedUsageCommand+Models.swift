import Foundation
import RunicCore

extension EnhancedUsageCommand {
    struct EnhancedUsageData: Encodable {
        let providers: [ProviderUsageData]
        let summary: UsageSummary?
        let comparison: ProviderComparison?
    }

    struct ProviderUsageData: Encodable {
        let provider: UsageProvider
        let providerName: String
        let snapshot: UsageSnapshot
        let credits: CreditsSnapshot?
        let windows: [WindowData]
        let breakdown: TokenBreakdown?
        let trending: [DailyTrend]?
        let projected: ProjectedUsage?
    }

    struct WindowData: Encodable {
        let name: String
        let used: Int?
        let limit: Int?
        let usedPercent: Double
        let remainingPercent: Double
        let resetDescription: String?
        /// Mirrors `RateWindow.hasKnownLimit`; `false` means the percents are
        /// placeholders and renderers should show the summary text instead.
        let hasKnownLimit: Bool?
    }

    struct TokenBreakdown: Encodable {
        let totalTokens: Int
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationTokens: Int
        let cacheReadTokens: Int
        let inputPercent: Double
        let outputPercent: Double
        let cachePercent: Double
    }

    struct DailyTrend: Encodable {
        let date: String
        let totalTokens: Int
        let cost: Double?
    }

    struct ProjectedUsage: Encodable {
        let currentUsed: Int
        let projectedTotal: Int
        let projectedAtEndOfPeriod: Int
        let riskLevel: String
    }

    struct UsageSummary: Encodable {
        let totalProviders: Int
        let totalTokens: Int
        let totalCost: Double?
        let highestUsageProvider: String
        let averageUsagePercent: Double
    }

    struct ProviderComparison: Encodable {
        let comparisons: [ProviderComparisonItem]
        let mostEfficient: String?
        let mostExpensive: String?
    }

    struct ProviderComparisonItem: Encodable {
        let provider: String
        let totalTokens: Int
        let cost: Double?
        let efficiency: Double
    }
}
