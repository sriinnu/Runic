import Foundation

/// The slot of the day that burned the most tokens over a recent stretch:
/// "15–18, 41% of the last seven days' tokens".
public struct UsageLedgerPeakBurn: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    /// Local hour the slot starts: 0, 3, 6 … 21.
    public let startHour: Int
    public let slotHours: Int
    /// The slot's share of every token in the lookback, 0…1.
    public let share: Double
    public let tokens: Int
    /// Days in the lookback with any usage at all.
    public let activeDays: Int
    public let lookbackDays: Int

    public init(
        provider: UsageProvider,
        startHour: Int,
        slotHours: Int,
        share: Double,
        tokens: Int,
        activeDays: Int,
        lookbackDays: Int)
    {
        self.provider = provider
        self.startHour = startHour
        self.slotHours = slotHours
        self.share = share
        self.tokens = tokens
        self.activeDays = activeDays
        self.lookbackDays = lookbackDays
    }

    /// Local hour the slot ends, 24 wrapping to 0.
    public var endHour: Int {
        (self.startHour + self.slotHours) % 24
    }
}

extension UsageLedgerAggregator {
    /// Fewer active days than this and a "peak" is one busy afternoon.
    public static let peakBurnMinimumActiveDays = 3
    /// The peak slot must hold at least this share of the tokens…
    public static let peakBurnMinimumShare = 0.2
    /// …and beat the runner-up by this factor, or there is no real peak.
    public static let peakBurnMinimumLead = 1.25

    /// The fixed slot (00–03, 03–06 … 21–00) that burned the most tokens over
    /// the last `lookbackDays` days including today, or nil when the usage is
    /// too thin or too even for a peak to mean anything. `hourlyTokensByDay`
    /// maps a local day start to its 24 hourly token counts.
    public static func peakBurn(
        provider: UsageProvider,
        hourlyTokensByDay: [Date: [Int]],
        now: Date,
        calendar: Calendar = .current,
        lookbackDays: Int = 7,
        slotHours: Int = 3) -> UsageLedgerPeakBurn?
    {
        let today = calendar.startOfDay(for: now)
        guard lookbackDays > 0, slotHours > 0, 24 % slotHours == 0,
              let windowStart = calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: today)
        else { return nil }

        var slotTokens = [Int](repeating: 0, count: 24 / slotHours)
        var activeDays = 0
        for (dayStart, hours) in hourlyTokensByDay where dayStart >= windowStart && dayStart <= today {
            var dayTotal = 0
            for (hour, tokens) in hours.prefix(24).enumerated() where tokens > 0 {
                slotTokens[hour / slotHours] += tokens
                dayTotal += tokens
            }
            if dayTotal > 0 { activeDays += 1 }
        }

        let total = slotTokens.reduce(0, +)
        guard total > 0, activeDays >= Self.peakBurnMinimumActiveDays else { return nil }
        let ranked = slotTokens.indices.sorted { slotTokens[$0] > slotTokens[$1] }
        let peakSlot = ranked[0]
        let peakTokens = slotTokens[peakSlot]
        let runnerUp = ranked.count > 1 ? slotTokens[ranked[1]] : 0
        let share = Double(peakTokens) / Double(total)
        guard share >= Self.peakBurnMinimumShare,
              Double(peakTokens) >= Double(runnerUp) * Self.peakBurnMinimumLead
        else { return nil }

        return UsageLedgerPeakBurn(
            provider: provider,
            startHour: peakSlot * slotHours,
            slotHours: slotHours,
            share: share,
            tokens: peakTokens,
            activeDays: activeDays,
            lookbackDays: lookbackDays)
    }

    /// The peak over hourly summaries alone (one provider).
    public static func peakBurn(
        hourly: [UsageLedgerHourlySummary],
        now: Date,
        calendar: Calendar = .current,
        lookbackDays: Int = 7,
        slotHours: Int = 3) -> UsageLedgerPeakBurn?
    {
        guard let provider = hourly.first?.provider else { return nil }
        return self.peakBurn(
            provider: provider,
            hourlyTokensByDay: self.hourlyTokensByDay(hourly.filter { $0.provider == provider }, calendar: calendar),
            now: now,
            calendar: calendar,
            lookbackDays: lookbackDays,
            slotHours: slotHours)
    }

    /// Hourly summaries folded into local day start → 24 hourly token counts.
    public static func hourlyTokensByDay(
        _ hourly: [UsageLedgerHourlySummary],
        calendar: Calendar = .current) -> [Date: [Int]]
    {
        var byDay: [Date: [Int]] = [:]
        for summary in hourly {
            let day = calendar.startOfDay(for: summary.hourStart)
            var hours = byDay[day] ?? [Int](repeating: 0, count: 24)
            hours[calendar.component(.hour, from: summary.hourStart)] += summary.totals.totalTokens
            byDay[day] = hours
        }
        return byDay
    }

    /// One day's entries as 24 local-hour token counts, the shape a relay
    /// day row keeps so the time-of-day picture outlives the raw logs.
    public static func hourlyTokens(_ entries: [UsageLedgerEntry], calendar: Calendar = .current) -> [Int] {
        var hours = [Int](repeating: 0, count: 24)
        for entry in entries {
            hours[calendar.component(.hour, from: entry.timestamp)] += entry.totalTokens
        }
        return hours
    }
}
