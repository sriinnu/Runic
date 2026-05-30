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
    private struct LedgerEntryLoad {
        let providers: [UsageProvider]
        let entries: [UsageLedgerEntry]
        let errors: [UsageProvider: String]
    }

    private struct LedgerDailyBuckets {
        let dailyByProvider: [UsageProvider: UsageLedgerDailySummary]
        let allDailySummariesByProvider: [UsageProvider: [UsageLedgerDailySummary]]
        let mergedDailySummaries: [UsageLedgerDailySummary]
    }

    private struct LedgerUsageBreakdowns {
        let topModelsByProvider: [UsageProvider: UsageLedgerModelSummary]
        let topProjectsByProvider: [UsageProvider: UsageLedgerProjectSummary]
        let modelBreakdownsByProvider: [UsageProvider: [UsageLedgerModelSummary]]
        let projectBreakdownsByProvider: [UsageProvider: [UsageLedgerProjectSummary]]
    }

    private struct LedgerForecastBuckets {
        let spendForecastsByProvider: [UsageProvider: UsageLedgerSpendForecast]
        let projectSpendForecastsByProvider: [UsageProvider: [UsageLedgerSpendForecast]]
        let topProjectSpendForecastsByProvider: [UsageProvider: UsageLedgerSpendForecast]
    }

    private struct LedgerForecastContext {
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

    private func loadLedgerEntries(
        from sources: [(UsageProvider, any UsageLedgerSource)]) async -> LedgerEntryLoad
    {
        let providers = sources.map(\.0)
        var entries: [UsageLedgerEntry] = []
        var errors: [UsageProvider: String] = [:]

        await withTaskGroup(of: (UsageProvider, Result<[UsageLedgerEntry], Error>).self) { group in
            for (provider, source) in sources {
                group.addTask {
                    do {
                        let loaded = try await source.loadEntries()
                        return (provider, .success(loaded))
                    } catch {
                        return (provider, .failure(error))
                    }
                }
            }

            for await (provider, result) in group {
                switch result {
                case let .success(loaded):
                    entries.append(contentsOf: loaded)
                case let .failure(error):
                    errors[provider] = error.localizedDescription
                }
            }
        }

        return LedgerEntryLoad(
            providers: providers,
            entries: entries,
            errors: errors)
    }

    private func ledgerDailyBuckets(
        entries: [UsageLedgerEntry],
        providers: [UsageProvider],
        now: Date,
        calendar: Calendar,
        timeZone: TimeZone) async -> LedgerDailyBuckets
    {
        let todayStart = calendar.startOfDay(for: now)
        var dailyByProvider: [UsageProvider: UsageLedgerDailySummary] = [:]
        var allDailySummariesByProvider: [UsageProvider: [UsageLedgerDailySummary]] = [:]
        for summary in UsageLedgerAggregator.dailySummaries(
            entries: entries,
            timeZone: timeZone,
            groupByProject: false)
        {
            allDailySummariesByProvider[summary.provider, default: []].append(summary)
            if summary.dayStart == todayStart {
                dailyByProvider[summary.provider] = summary
            }
        }

        for provider in providers {
            guard let cached = await LedgerCache.shared.loadCachedDailies(provider: provider.rawValue) else { continue }
            let summaries = cached.dailies.compactMap { $0.toLedgerDailySummary(provider: provider) }
            guard !summaries.isEmpty else { continue }
            var byDay = Dictionary(uniqueKeysWithValues: summaries.map { ($0.dayKey, $0) })
            for summary in allDailySummariesByProvider[provider] ?? [] {
                byDay[summary.dayKey] = summary
            }
            allDailySummariesByProvider[provider] = byDay.values.sorted { $0.dayStart < $1.dayStart }
            if dailyByProvider[provider] == nil {
                dailyByProvider[provider] = byDay.values.first { $0.dayStart == todayStart }
            }
        }

        return LedgerDailyBuckets(
            dailyByProvider: dailyByProvider,
            allDailySummariesByProvider: allDailySummariesByProvider,
            mergedDailySummaries: allDailySummariesByProvider.values.flatMap { $0 })
    }

    private func hourlySummariesByProvider(
        entries: [UsageLedgerEntry],
        timeZone: TimeZone) -> [UsageProvider: [UsageLedgerHourlySummary]]
    {
        var hourlySummariesByProvider: [UsageProvider: [UsageLedgerHourlySummary]] = [:]
        for summary in UsageLedgerAggregator.hourlySummaries(
            entries: entries,
            timeZone: timeZone,
            groupByProject: false)
        {
            hourlySummariesByProvider[summary.provider, default: []].append(summary)
        }
        return hourlySummariesByProvider
    }

    private func activeBlocksByProvider(
        entries: [UsageLedgerEntry],
        now: Date) -> [UsageProvider: UsageLedgerBlockSummary]
    {
        var activeByProvider: [UsageProvider: UsageLedgerBlockSummary] = [:]
        let blocks = UsageLedgerAggregator.blockSummaries(entries: entries, blockHours: 5, now: now)
        for block in blocks where block.isActive {
            if activeByProvider[block.provider] == nil {
                activeByProvider[block.provider] = block
            }
        }
        return activeByProvider
    }

    private func ledgerUsageBreakdowns(
        todayEntries: [UsageLedgerEntry],
        budgetProjectNames: [String: String]) -> LedgerUsageBreakdowns
    {
        let modelSummaries = UsageLedgerAggregator.modelSummaries(entries: todayEntries)
        var topModelsByProvider: [UsageProvider: UsageLedgerModelSummary] = [:]
        for summary in modelSummaries where topModelsByProvider[summary.provider] == nil {
            topModelsByProvider[summary.provider] = summary
        }

        let projectSummaries = UsageLedgerAggregator.projectSummaries(entries: todayEntries)
            .map { self.resolvedProjectSummary($0, budgetProjectNames: budgetProjectNames) }
        var topProjectsByProvider: [UsageProvider: UsageLedgerProjectSummary] = [:]
        for summary in projectSummaries where topProjectsByProvider[summary.provider] == nil {
            topProjectsByProvider[summary.provider] = summary
        }

        let modelBreakdowns = modelSummaries.map {
            self.resolvedModelSummary($0, budgetProjectNames: budgetProjectNames)
        }
        var modelBreakdownsByProvider: [UsageProvider: [UsageLedgerModelSummary]] = [:]
        for summary in modelBreakdowns {
            modelBreakdownsByProvider[summary.provider, default: []].append(summary)
        }

        var projectBreakdownsByProvider: [UsageProvider: [UsageLedgerProjectSummary]] = [:]
        for summary in projectSummaries {
            projectBreakdownsByProvider[summary.provider, default: []].append(summary)
        }

        return LedgerUsageBreakdowns(
            topModelsByProvider: topModelsByProvider,
            topProjectsByProvider: topProjectsByProvider,
            modelBreakdownsByProvider: modelBreakdownsByProvider,
            projectBreakdownsByProvider: projectBreakdownsByProvider)
    }

    private func ledgerForecastBuckets(
        entries: [UsageLedgerEntry],
        mergedDailySummaries: [UsageLedgerDailySummary],
        topProjectsByProvider: [UsageProvider: UsageLedgerProjectSummary],
        context: LedgerForecastContext) -> LedgerForecastBuckets
    {
        let spendForecastsByProvider = self.topSpendForecastsByProvider(
            from: mergedDailySummaries,
            now: context.now,
            calendar: context.calendar)
        let projectSpendForecastsByProvider = self.projectSpendForecastsByProvider(
            entries: entries,
            budgetProjectNames: context.budgetProjectNames,
            now: context.now,
            timeZone: context.timeZone)

        return LedgerForecastBuckets(
            spendForecastsByProvider: spendForecastsByProvider,
            projectSpendForecastsByProvider: projectSpendForecastsByProvider,
            topProjectSpendForecastsByProvider: self.topProjectSpendForecastsByProvider(
                topProjectsByProvider: topProjectsByProvider,
                projectSpendForecastsByProvider: projectSpendForecastsByProvider))
    }

    private func topSpendForecastsByProvider(
        from dailySummaries: [UsageLedgerDailySummary],
        now: Date,
        calendar: Calendar) -> [UsageProvider: UsageLedgerSpendForecast]
    {
        let providerForecasts = self.providerSpendForecasts(
            from: dailySummaries,
            now: now,
            calendar: calendar)
        var spendForecastsByProvider: [UsageProvider: UsageLedgerSpendForecast] = [:]
        for forecast in providerForecasts where spendForecastsByProvider[forecast.provider] == nil {
            spendForecastsByProvider[forecast.provider] = forecast
        }
        return spendForecastsByProvider
    }

    private func projectSpendForecastsByProvider(
        entries: [UsageLedgerEntry],
        budgetProjectNames: [String: String],
        now: Date,
        timeZone: TimeZone) -> [UsageProvider: [UsageLedgerSpendForecast]]
    {
        let budgetLimitsByProjectID = self.activeBudgetLimitsByProjectID()
        let projectForecasts = UsageLedgerAggregator.projectSpendForecasts(
            entries: entries,
            now: now,
            timeZone: timeZone)
            .map {
                self.resolvedSpendForecast(
                    $0,
                    budgetProjectNames: budgetProjectNames,
                    budgetLimitsByProjectID: budgetLimitsByProjectID)
            }
        var projectSpendForecastsByProvider: [UsageProvider: [UsageLedgerSpendForecast]] = [:]
        for forecast in projectForecasts {
            projectSpendForecastsByProvider[forecast.provider, default: []].append(forecast)
        }
        return projectSpendForecastsByProvider
    }

    private func topProjectSpendForecastsByProvider(
        topProjectsByProvider: [UsageProvider: UsageLedgerProjectSummary],
        projectSpendForecastsByProvider: [UsageProvider: [UsageLedgerSpendForecast]])
        -> [UsageProvider: UsageLedgerSpendForecast]
    {
        var topProjectSpendForecastsByProvider: [UsageProvider: UsageLedgerSpendForecast] = [:]
        for (provider, summary) in topProjectsByProvider {
            guard let forecasts = projectSpendForecastsByProvider[provider] else { continue }
            if let matched = self.matchingProjectForecast(for: summary, forecasts: forecasts) {
                topProjectSpendForecastsByProvider[provider] = matched
            }
        }
        return topProjectSpendForecastsByProvider
    }

    private func compactionsByProvider(entries: [UsageLedgerEntry]) -> [UsageProvider: UsageLedgerCompactionSummary] {
        var compactionsByProvider: [UsageProvider: UsageLedgerCompactionSummary] = [:]
        for summary in UsageLedgerAggregator.compactionSummaries(entries: entries) {
            compactionsByProvider[summary.provider] = summary
        }
        return compactionsByProvider
    }

    private func lastActivityByProvider(entries: [UsageLedgerEntry]) -> [UsageProvider: Date] {
        var lastActivityByProvider: [UsageProvider: Date] = [:]
        for entry in entries {
            if let current = lastActivityByProvider[entry.provider] {
                if entry.timestamp > current { lastActivityByProvider[entry.provider] = entry.timestamp }
            } else {
                lastActivityByProvider[entry.provider] = entry.timestamp
            }
        }
        return lastActivityByProvider
    }

    private func projectNameOverridesFromBudgets() -> [String: String] {
        var namesByProjectID: [String: String] = [:]
        for budget in ProjectBudgetStore.getAllBudgets() {
            let trimmed = budget.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                namesByProjectID[budget.projectID] = trimmed
            }
        }
        return namesByProjectID
    }

    private func activeBudgetLimitsByProjectID() -> [String: Double] {
        var limitsByProjectID: [String: Double] = [:]
        for budget in ProjectBudgetStore.getAllBudgets() where budget.enabled && budget.monthlyLimit > 0 {
            limitsByProjectID[budget.projectID] = budget.monthlyLimit
        }
        return limitsByProjectID
    }

    private func providerSpendForecasts(
        from dailySummaries: [UsageLedgerDailySummary],
        now: Date,
        calendar: Calendar,
        projectionDays: Int = 30) -> [UsageLedgerSpendForecast]
    {
        struct Bucket {
            var costByDay: [Date: Double] = [:]
        }

        var buckets: [UsageProvider: Bucket] = [:]
        for summary in dailySummaries where calendar.isDate(summary.dayStart, equalTo: now, toGranularity: .month) {
            guard let cost = summary.totals.costUSD, cost.isFinite else { continue }
            buckets[summary.provider, default: Bucket()].costByDay[summary.dayStart, default: 0] += cost
        }

        return buckets.compactMap { provider, bucket in
            let costs = bucket.costByDay.values.filter(\.isFinite)
            guard !costs.isEmpty else { return nil }
            let observedCost = costs.reduce(0, +)
            guard observedCost.isFinite else { return nil }
            let averageDailyCost = observedCost / Double(costs.count)
            guard averageDailyCost.isFinite else { return nil }
            return UsageLedgerSpendForecast(
                provider: provider,
                observedDays: costs.count,
                observedCostUSD: observedCost,
                averageDailyCostUSD: averageDailyCost,
                projected30DayCostUSD: averageDailyCost * Double(projectionDays),
                projectionDays: projectionDays)
        }
        .sorted { lhs, rhs in
            if lhs.projected30DayCostUSD != rhs.projected30DayCostUSD {
                return lhs.projected30DayCostUSD > rhs.projected30DayCostUSD
            }
            return lhs.provider.rawValue < rhs.provider.rawValue
        }
    }

    private func resolvedSpendForecast(
        _ forecast: UsageLedgerSpendForecast,
        budgetProjectNames: [String: String],
        budgetLimitsByProjectID: [String: Double]) -> UsageLedgerSpendForecast
    {
        let budgetName = forecast.projectID.flatMap { budgetProjectNames[$0] }
        let identity = UsageLedgerProjectIdentityResolver.resolve(
            provider: forecast.provider,
            projectID: forecast.projectID,
            projectName: forecast.projectName,
            budgetNameOverride: budgetName)
        let resolved = UsageLedgerSpendForecast(
            provider: forecast.provider,
            projectKey: forecast.projectKey ?? identity.key,
            projectID: identity.projectID ?? forecast.projectID,
            projectName: identity.displayName ?? forecast.projectName,
            observedDays: forecast.observedDays,
            observedCostUSD: forecast.observedCostUSD,
            averageDailyCostUSD: forecast.averageDailyCostUSD,
            projected30DayCostUSD: forecast.projected30DayCostUSD,
            projectedCostP50USD: forecast.projectedCostP50USD,
            projectedCostP80USD: forecast.projectedCostP80USD,
            projectedCostP95USD: forecast.projectedCostP95USD,
            projectionDays: forecast.projectionDays,
            budgetLimitUSD: forecast.budgetLimitUSD,
            budgetETAInDays: forecast.budgetETAInDays,
            budgetWillBreach: forecast.budgetWillBreach)
        let budgetLimit = resolved.projectID.flatMap { budgetLimitsByProjectID[$0] }
        return resolved.applyingBudget(monthlyLimitUSD: budgetLimit)
    }

    private func matchingProjectForecast(
        for summary: UsageLedgerProjectSummary,
        forecasts: [UsageLedgerSpendForecast]) -> UsageLedgerSpendForecast?
    {
        if let key = summary.projectKey,
           let byKey = forecasts.first(where: { $0.projectKey == key })
        {
            return byKey
        }
        if let projectID = summary.projectID,
           let byID = forecasts.first(where: { $0.projectID == projectID })
        {
            return byID
        }
        let summaryName = summary.projectName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let summaryName, !summaryName.isEmpty {
            return forecasts.first {
                $0.projectName?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == summaryName
            }
        }
        return nil
    }

    private func resolvedProjectSummary(
        _ summary: UsageLedgerProjectSummary,
        budgetProjectNames: [String: String]) -> UsageLedgerProjectSummary
    {
        let budgetName = summary.projectID.flatMap { budgetProjectNames[$0] }
        let identity = UsageLedgerProjectIdentityResolver.resolve(
            provider: summary.provider,
            projectID: summary.projectID,
            projectName: summary.projectName,
            budgetNameOverride: budgetName)
        return UsageLedgerProjectSummary(
            provider: summary.provider,
            projectKey: summary.projectKey ?? identity.key,
            projectID: identity.projectID ?? summary.projectID,
            projectName: identity.displayName ?? summary.projectName,
            projectNameConfidence: identity.confidence,
            projectNameSource: identity.source,
            projectNameProvenance: identity.provenance,
            entryCount: summary.entryCount,
            totals: summary.totals,
            modelsUsed: summary.modelsUsed)
    }

    private func resolvedModelSummary(
        _ summary: UsageLedgerModelSummary,
        budgetProjectNames: [String: String]) -> UsageLedgerModelSummary
    {
        let budgetName = summary.projectID.flatMap { budgetProjectNames[$0] }
        let identity = UsageLedgerProjectIdentityResolver.resolve(
            provider: summary.provider,
            projectID: summary.projectID,
            projectName: summary.projectName,
            budgetNameOverride: budgetName)
        return UsageLedgerModelSummary(
            provider: summary.provider,
            projectKey: summary.projectKey ?? identity.key,
            projectID: identity.projectID ?? summary.projectID,
            projectName: identity.displayName ?? summary.projectName,
            projectNameConfidence: identity.confidence,
            projectNameSource: identity.source,
            projectNameProvenance: identity.provenance,
            model: summary.model,
            entryCount: summary.entryCount,
            totals: summary.totals)
    }
}
