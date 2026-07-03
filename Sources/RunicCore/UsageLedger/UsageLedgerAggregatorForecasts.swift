import Foundation

extension UsageLedgerAggregator {
    public static func providerSpendForecasts(
        entries: [UsageLedgerEntry],
        now: Date = Date(),
        timeZone: TimeZone = .current,
        projectionDays: Int = 30) -> [UsageLedgerSpendForecast]
    {
        self.spendForecasts(
            entries: entries,
            now: now,
            timeZone: timeZone,
            projectionDays: projectionDays,
            groupByProject: false)
    }

    public static func projectSpendForecasts(
        entries: [UsageLedgerEntry],
        now: Date = Date(),
        timeZone: TimeZone = .current,
        projectionDays: Int = 30) -> [UsageLedgerSpendForecast]
    {
        self.spendForecasts(
            entries: entries,
            now: now,
            timeZone: timeZone,
            projectionDays: projectionDays,
            groupByProject: true)
    }

    private static func spendForecasts(
        entries: [UsageLedgerEntry],
        now: Date,
        timeZone: TimeZone,
        projectionDays: Int,
        groupByProject: Bool) -> [UsageLedgerSpendForecast]
    {
        guard projectionDays > 0 else { return [] }
        let calendar = self.calendarFor(timeZone)
        var buckets: [SpendForecastKey: SpendForecastAccumulator] = [:]

        for entry in entries {
            guard self.isInSameMonth(entry.timestamp, as: now, calendar: calendar) else { continue }
            guard let cost = entry.costUSD else { continue }
            let dayStart = calendar.startOfDay(for: entry.timestamp)
            let projectIdentity: UsageLedgerProjectIdentity? = if groupByProject {
                UsageLedgerProjectIdentityResolver.resolve(
                    provider: entry.provider,
                    projectID: entry.projectID,
                    projectName: entry.projectName)
            } else {
                nil
            }
            let key = SpendForecastKey(
                provider: entry.provider,
                projectKey: projectIdentity?.key)
            buckets[key, default: SpendForecastAccumulator()]
                .consume(entry, costUSD: cost, dayStart: dayStart, identity: projectIdentity)
        }

        return buckets.compactMap { key, accumulator in
            accumulator.forecast(
                provider: key.provider,
                projectKey: key.projectKey,
                projectionDays: projectionDays,
                todayStart: calendar.startOfDay(for: now),
                calendar: calendar)
        }
        .sorted { lhs, rhs in
            if lhs.projected30DayCostUSD != rhs.projected30DayCostUSD {
                return lhs.projected30DayCostUSD > rhs.projected30DayCostUSD
            }
            if lhs.provider != rhs.provider {
                return lhs.provider.rawValue < rhs.provider.rawValue
            }
            return (lhs.projectKey ?? lhs.projectID ?? "") < (rhs.projectKey ?? rhs.projectID ?? "")
        }
    }

    private static func isInSameMonth(_ date: Date, as reference: Date, calendar: Calendar) -> Bool {
        calendar.isDate(date, equalTo: reference, toGranularity: .month)
    }
}
