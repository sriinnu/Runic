import Foundation
import RunicCore

extension UsageStore {
    func tokenSnapshot(for provider: UsageProvider) -> CostUsageTokenSnapshot? {
        self.tokenSnapshots[provider] ?? self.ledgerTokenSnapshot(for: provider)
    }

    func tokenError(for provider: UsageProvider) -> String? {
        self.tokenErrors[provider]
    }

    func tokenLastAttemptAt(for provider: UsageProvider) -> Date? {
        self.lastTokenFetchAt[provider]
    }

    func isTokenRefreshInFlight(for provider: UsageProvider) -> Bool {
        self.tokenRefreshInFlight.contains(provider)
    }

    nonisolated static func costUsageCacheDirectory(
        fileManager: FileManager = .default) -> URL
    {
        let root = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return root
            .appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("cost-usage", isDirectory: true)
    }

    nonisolated static func costUsageLedgerCacheDirectory(
        fileManager: FileManager = .default) -> URL
    {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root
            .appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("ledger-cache", isDirectory: true)
    }

    nonisolated static func costUsageRelayDirectory(
        fileManager: FileManager = .default) -> URL
    {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root
            .appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("relay", isDirectory: true)
    }

    nonisolated static func tokenCostNoDataMessage(for provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).tokenCost.noDataMessage()
    }

    private func ledgerTokenSnapshot(for provider: UsageProvider) -> CostUsageTokenSnapshot? {
        let allDaily = self.ledgerAllDailySummary(for: provider)
        guard !allDaily.isEmpty else { return nil }

        let now = Date()
        let todayKey = Self.ledgerDayKey(for: now)
        let today = allDaily.first(where: { $0.dayKey == todayKey })
        let since = Calendar.current.date(byAdding: .day, value: -29, to: now) ?? now
        let last30 = allDaily.filter { $0.dayStart >= since && $0.dayStart <= now }
        let window = last30.isEmpty ? allDaily : last30

        let totalTokens = window.reduce(0) { $0 + $1.totals.totalTokens }
        let costs = window.compactMap(\.totals.costUSD)
        let totalCost = costs.isEmpty ? nil : costs.reduce(0, +)
        guard totalTokens > 0 || totalCost != nil else { return nil }

        let daily = window
            .sorted { $0.dayStart < $1.dayStart }
            .map { summary in
                CostUsageDailyReport.Entry(
                    date: summary.dayKey,
                    inputTokens: summary.totals.inputTokens,
                    outputTokens: summary.totals.outputTokens,
                    cacheReadTokens: summary.totals.cacheReadTokens,
                    cacheCreationTokens: summary.totals.cacheCreationTokens,
                    totalTokens: summary.totals.totalTokens,
                    costUSD: summary.totals.costUSD,
                    modelsUsed: summary.modelsUsed,
                    modelBreakdowns: nil)
            }

        return CostUsageTokenSnapshot(
            sessionTokens: today?.totals.totalTokens,
            sessionCostUSD: today?.totals.costUSD,
            last30DaysTokens: totalTokens > 0 ? totalTokens : nil,
            last30DaysCostUSD: totalCost,
            daily: daily,
            updatedAt: self.ledgerUpdatedAt(for: provider) ?? now)
    }

    private nonisolated static func ledgerDayKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            comps.year ?? 1970,
            comps.month ?? 1,
            comps.day ?? 1)
    }
}
