import Foundation
import RunicCore
import Testing
@testable import Runic

struct UsageLedgerAnomalyDetectionTests {
    @Test
    func `detects token spike against seven day baseline`() {
        let now = Date(timeIntervalSince1970: 1_771_718_400) // 2026-02-22T00:00:00Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        var summaries: [UsageLedgerDailySummary] = []
        for offset in -7 ... -1 {
            summaries.append(self.dailySummary(
                provider: .codex,
                dayOffset: offset,
                tokens: 1000,
                cost: nil,
                now: now,
                calendar: calendar))
        }
        summaries.append(self.dailySummary(
            provider: .codex,
            dayOffset: 0,
            tokens: 2500,
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
    func `detects spend spike when cost data exists`() {
        let now = Date(timeIntervalSince1970: 1_771_718_400) // 2026-02-22T00:00:00Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        var summaries: [UsageLedgerDailySummary] = []
        for offset in -7 ... -1 {
            summaries.append(self.dailySummary(
                provider: .claude,
                dayOffset: offset,
                tokens: 1000,
                cost: 2.0,
                now: now,
                calendar: calendar))
        }
        summaries.append(self.dailySummary(
            provider: .claude,
            dayOffset: 0,
            tokens: 1100,
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
    func `does not emit anomaly when history has fewer than seven days`() {
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
            tokens: 4000,
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

    @Test
    func `explanation includes headline and contributing factors`() {
        let summary = UsageLedgerAnomalySummary(
            provider: .codex,
            baselineDays: 7,
            tokenAnomaly: UsageLedgerAnomalySummary.MetricAnomaly(
                metric: .tokens,
                severity: .high,
                todayValue: 4200,
                baselineAverage: 1500,
                percentIncrease: 1.8),
            spendAnomaly: UsageLedgerAnomalySummary.MetricAnomaly(
                metric: .spend,
                severity: .elevated,
                todayValue: 17.5,
                baselineAverage: 9.0,
                percentIncrease: 0.94))

        let explanation = summary.explanation
        #expect(explanation?.headline == "Anomaly: High tokens spike")
        #expect(explanation?.details.count == 2)
        #expect(explanation?.details.first?.contains("+180%") == true)
        #expect(explanation?.details.last?.contains("+94%") == true)
    }

    @Test
    func `explanation is nil when no anomalies exist`() {
        let summary = UsageLedgerAnomalySummary(
            provider: .codex,
            baselineDays: 7,
            tokenAnomaly: nil,
            spendAnomaly: nil)
        #expect(summary.explanation == nil)
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
