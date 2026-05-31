import Foundation
import RunicCore

struct LedgerRefreshResult {
    let dailyByProvider: [UsageProvider: UsageLedgerDailySummary]
    let allDailySummariesByProvider: [UsageProvider: [UsageLedgerDailySummary]]
    let hourlySummariesByProvider: [UsageProvider: [UsageLedgerHourlySummary]]
    let activeBlocksByProvider: [UsageProvider: UsageLedgerBlockSummary]
    let topModelsByProvider: [UsageProvider: UsageLedgerModelSummary]
    let topProjectsByProvider: [UsageProvider: UsageLedgerProjectSummary]
    let modelBreakdownsByProvider: [UsageProvider: [UsageLedgerModelSummary]]
    let projectBreakdownsByProvider: [UsageProvider: [UsageLedgerProjectSummary]]
    let spendForecastsByProvider: [UsageProvider: UsageLedgerSpendForecast]
    let projectSpendForecastsByProvider: [UsageProvider: [UsageLedgerSpendForecast]]
    let topProjectSpendForecastsByProvider: [UsageProvider: UsageLedgerSpendForecast]
    let anomaliesByProvider: [UsageProvider: UsageLedgerAnomalySummary]
    let compactionsByProvider: [UsageProvider: UsageLedgerCompactionSummary]
    let errorsByProvider: [UsageProvider: String]
    let lastActivityByProvider: [UsageProvider: Date]
    let updatedAt: Date
    let scanDays: Int
    let providers: [UsageProvider]

    static func empty(updatedAt: Date, scanDays: Int) -> Self {
        Self(
            dailyByProvider: [:],
            allDailySummariesByProvider: [:],
            hourlySummariesByProvider: [:],
            activeBlocksByProvider: [:],
            topModelsByProvider: [:],
            topProjectsByProvider: [:],
            modelBreakdownsByProvider: [:],
            projectBreakdownsByProvider: [:],
            spendForecastsByProvider: [:],
            projectSpendForecastsByProvider: [:],
            topProjectSpendForecastsByProvider: [:],
            anomaliesByProvider: [:],
            compactionsByProvider: [:],
            errorsByProvider: [:],
            lastActivityByProvider: [:],
            updatedAt: updatedAt,
            scanDays: scanDays,
            providers: [])
    }
}

struct UsageStoreLedgerInsightLoader {
    struct LedgerEntryLoad {
        let providers: [UsageProvider]
        let entries: [UsageLedgerEntry]
        let errors: [UsageProvider: String]
    }

    struct LedgerDailyBuckets {
        let dailyByProvider: [UsageProvider: UsageLedgerDailySummary]
        let allDailySummariesByProvider: [UsageProvider: [UsageLedgerDailySummary]]
        let mergedDailySummaries: [UsageLedgerDailySummary]
    }

    struct LedgerUsageBreakdowns {
        let topModelsByProvider: [UsageProvider: UsageLedgerModelSummary]
        let topProjectsByProvider: [UsageProvider: UsageLedgerProjectSummary]
        let modelBreakdownsByProvider: [UsageProvider: [UsageLedgerModelSummary]]
        let projectBreakdownsByProvider: [UsageProvider: [UsageLedgerProjectSummary]]
    }

    struct LedgerForecastBuckets {
        let spendForecastsByProvider: [UsageProvider: UsageLedgerSpendForecast]
        let projectSpendForecastsByProvider: [UsageProvider: [UsageLedgerSpendForecast]]
        let topProjectSpendForecastsByProvider: [UsageProvider: UsageLedgerSpendForecast]
    }

    struct LedgerForecastContext {
        let budgetProjectNames: [String: String]
        let now: Date
        let calendar: Calendar
        let timeZone: TimeZone
    }

    func load(
        sources: [(UsageProvider, any UsageLedgerSource)],
        now: Date,
        scanDays: Int) async -> LedgerRefreshResult
    {
        guard !sources.isEmpty else {
            return .empty(updatedAt: now, scanDays: scanDays)
        }

        let load = await self.loadLedgerEntries(from: sources)
        let timeZone = TimeZone.current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let dailyBuckets = await self.ledgerDailyBuckets(
            entries: load.entries,
            providers: load.providers,
            now: now,
            calendar: calendar,
            timeZone: timeZone)
        let budgetProjectNames = self.projectNameOverridesFromBudgets()
        let todayEntries = load.entries.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
        let usageBreakdowns = self.ledgerUsageBreakdowns(
            todayEntries: todayEntries,
            budgetProjectNames: budgetProjectNames)
        let forecastBuckets = self.ledgerForecastBuckets(
            entries: load.entries,
            mergedDailySummaries: dailyBuckets.mergedDailySummaries,
            topProjectsByProvider: usageBreakdowns.topProjectsByProvider,
            context: LedgerForecastContext(
                budgetProjectNames: budgetProjectNames,
                now: now,
                calendar: calendar,
                timeZone: timeZone))
        let anomaliesByProvider = UsageLedgerAnomalyDetector.summaries(
            dailySummaries: dailyBuckets.mergedDailySummaries,
            now: now,
            calendar: calendar)

        return LedgerRefreshResult(
            dailyByProvider: dailyBuckets.dailyByProvider,
            allDailySummariesByProvider: dailyBuckets.allDailySummariesByProvider,
            hourlySummariesByProvider: self.hourlySummariesByProvider(entries: load.entries, timeZone: timeZone),
            activeBlocksByProvider: self.activeBlocksByProvider(entries: load.entries, now: now),
            topModelsByProvider: usageBreakdowns.topModelsByProvider,
            topProjectsByProvider: usageBreakdowns.topProjectsByProvider,
            modelBreakdownsByProvider: usageBreakdowns.modelBreakdownsByProvider,
            projectBreakdownsByProvider: usageBreakdowns.projectBreakdownsByProvider,
            spendForecastsByProvider: forecastBuckets.spendForecastsByProvider,
            projectSpendForecastsByProvider: forecastBuckets.projectSpendForecastsByProvider,
            topProjectSpendForecastsByProvider: forecastBuckets.topProjectSpendForecastsByProvider,
            anomaliesByProvider: anomaliesByProvider,
            compactionsByProvider: self.compactionsByProvider(entries: load.entries),
            errorsByProvider: load.errors,
            lastActivityByProvider: self.lastActivityByProvider(entries: load.entries),
            updatedAt: now,
            scanDays: scanDays,
            providers: load.providers)
    }
}
