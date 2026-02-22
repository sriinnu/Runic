import Foundation
import RunicCore
import Testing

@testable import Runic

@Suite
struct UsageLedgerAnomalyDetectionTests {
    @Test
    func detectsTokenSpikeAgainstSevenDayBaseline() {
        let now = Date(timeIntervalSince1970: 1_771_718_400) // 2026-02-22T00:00:00Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        var summaries: [UsageLedgerDailySummary] = []
        for offset in -7 ... -1 {
            summaries.append(self.dailySummary(
                provider: .codex,
                dayOffset: offset,
                tokens: 1_000,
                cost: nil,
                now: now,
                calendar: calendar))
        }
        summaries.append(self.dailySummary(
            provider: .codex,
            dayOffset: 0,
            tokens: 2_500,
            cost: nil,
            now: now,
            calendar: calendar))

        let anomalies = UsageLedgerAnomalyDetector.summaries(
            dailySummaries: summaries,
            now: now,
            calendar: calendar)

        let codex = anomalies[.codex]
        #expect(codex != nil)
        #expect(codex?.tokenAnomaly?.metric == .tokens)
        #expect(codex?.tokenAnomaly?.severity == .high)
        #expect(codex?.spendAnomaly == nil)
    }

    @Test
    func detectsSpendSpikeWhenCostDataExists() {
        let now = Date(timeIntervalSince1970: 1_771_718_400) // 2026-02-22T00:00:00Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        var summaries: [UsageLedgerDailySummary] = []
        for offset in -7 ... -1 {
            summaries.append(self.dailySummary(
                provider: .claude,
                dayOffset: offset,
                tokens: 1_000,
                cost: 2.0,
                now: now,
                calendar: calendar))
        }
        summaries.append(self.dailySummary(
            provider: .claude,
            dayOffset: 0,
            tokens: 1_100,
            cost: 7.0,
            now: now,
            calendar: calendar))

        let anomalies = UsageLedgerAnomalyDetector.summaries(
            dailySummaries: summaries,
            now: now,
            calendar: calendar)

        let claude = anomalies[.claude]
        #expect(claude != nil)
        #expect(claude?.tokenAnomaly == nil)
        #expect(claude?.spendAnomaly?.metric == .spend)
        #expect(claude?.spendAnomaly?.severity == .critical)
    }

    @Test
    func doesNotEmitAnomalyWhenHistoryHasFewerThanSevenDays() {
        let now = Date(timeIntervalSince1970: 1_771_718_400) // 2026-02-22T00:00:00Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        var summaries: [UsageLedgerDailySummary] = []
        for offset in -3 ... -1 {
            summaries.append(self.dailySummary(
                provider: .codex,
                dayOffset: offset,
                tokens: 800,
                cost: 1.0,
                now: now,
                calendar: calendar))
        }
        summaries.append(self.dailySummary(
            provider: .codex,
            dayOffset: 0,
            tokens: 4_000,
            cost: 8.0,
            now: now,
            calendar: calendar))

        let anomalies = UsageLedgerAnomalyDetector.summaries(
            dailySummaries: summaries,
            now: now,
            calendar: calendar)

        #expect(anomalies[.codex] == nil)
        #expect(anomalies.isEmpty)
    }

    private func dailySummary(
        provider: UsageProvider,
        dayOffset: Int,
        tokens: Int,
        cost: Double?,
        now: Date,
        calendar: Calendar) -> UsageLedgerDailySummary
    {
        let todayStart = calendar.startOfDay(for: now)
        let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) ?? todayStart
        return UsageLedgerDailySummary(
            provider: provider,
            projectID: nil,
            dayStart: dayStart,
            dayKey: "\(dayOffset)",
            totals: UsageLedgerTotals(
                inputTokens: tokens,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: cost),
            modelsUsed: ["gpt-5"])
    }
}
