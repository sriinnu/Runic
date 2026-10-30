import Foundation

extension LedgerCache {
    /// A provider's busiest time-of-day slot this week: past days from the
    /// relay rows' hourly counts, days the raw logs still cover from
    /// `liveEntries` (they win, being fresher).
    public func peakBurn(
        provider: UsageProvider,
        liveEntries: [UsageLedgerEntry],
        now: Date,
        calendar: Calendar = .current) -> UsageLedgerPeakBurn?
    {
        var byDay: [Date: [Int]] = [:]
        for daily in self.loadCachedDailies(provider: provider.rawValue)?.dailies ?? [] {
            guard let hours = daily.hourlyTokens, hours.count == 24,
                  let dayStart = Self.dayDate(fromKey: daily.dayKey)
            else { continue }
            byDay[calendar.startOfDay(for: dayStart)] = hours
        }
        let live = Dictionary(grouping: liveEntries.filter { $0.provider == provider }) {
            calendar.startOfDay(for: $0.timestamp)
        }
        for (day, dayEntries) in live {
            byDay[day] = UsageLedgerAggregator.hourlyTokens(dayEntries, calendar: calendar)
        }
        return UsageLedgerAggregator.peakBurn(
            provider: provider,
            hourlyTokensByDay: byDay,
            now: now,
            calendar: calendar)
    }
}
