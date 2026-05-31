import Foundation
import RunicCore

extension UsageStoreLedgerInsightLoader {
    func ledgerForecastBuckets(
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

    func projectNameOverridesFromBudgets() -> [String: String] {
        var namesByProjectID: [String: String] = [:]
        for budget in ProjectBudgetStore.getAllBudgets() {
            let trimmed = budget.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                namesByProjectID[budget.projectID] = trimmed
            }
        }
        return namesByProjectID
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
}
