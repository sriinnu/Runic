import Foundation
import Testing
@testable import RunicCore

struct UsageLedgerForecastTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test
    func `provider forecast uses observed days in current month`() {
        let now = self.date(year: 2026, month: 2, day: 20)
        let entries = [
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 1),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 10),
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 2),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 20),
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 1, day: 31),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 99),
        ]

        let forecasts = UsageLedgerAggregator.providerSpendForecasts(
            entries: entries,
            now: now,
            timeZone: self.utc,
            projectionDays: 30)
        let codex = forecasts.first { $0.provider == .codex }

        #expect(codex != nil)
        #expect(codex?.projectKey == nil)
        #expect(codex?.observedDays == 2)
        #expect(abs((codex?.observedCostUSD ?? 0) - 30) < 0.0001)
        // Calendar-day average: $30 over the 19 complete days Feb 1-19, not
        // $30 over the 2 active days.
        #expect(abs((codex?.averageDailyCostUSD ?? 0) - (30.0 / 19.0)) < 0.0001)
        #expect(abs((codex?.projected30DayCostUSD ?? 0) - (30.0 / 19.0 * 30.0)) < 0.0001)
        #expect(codex?.projectedCostP50USD == nil)
        #expect(codex?.projectedCostP80USD == nil)
        #expect(codex?.projectedCostP95USD == nil)
    }

    @Test
    func `project forecasts are computed per project`() {
        let now = self.date(year: 2026, month: 2, day: 20)
        let entries = [
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 1),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 5),
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 2),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 15),
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 3),
                projectID: "proj-b",
                projectName: "Project B",
                costUSD: 20),
        ]

        let forecasts = UsageLedgerAggregator.projectSpendForecasts(
            entries: entries,
            now: now,
            timeZone: self.utc,
            projectionDays: 30)

        let projectA = forecasts.first { $0.projectID == "proj-a" }
        let projectB = forecasts.first { $0.projectID == "proj-b" }

        #expect(projectA != nil)
        #expect(projectB != nil)
        #expect(projectA?.observedDays == 2)
        // $20 over Feb 1-19 (19 calendar days), projected to 30 days.
        #expect(abs((projectA?.projected30DayCostUSD ?? 0) - (20.0 / 19.0 * 30.0)) < 0.0001)
        #expect(projectB?.observedDays == 1)
        // $20 over Feb 3-19 (17 calendar days), projected to 30 days.
        #expect(abs((projectB?.projected30DayCostUSD ?? 0) - (20.0 / 17.0 * 30.0)) < 0.0001)
    }

    @Test
    func `provider forecast includes confidence band quantiles when enough daily history exists`() {
        // Viewed the morning after five consecutive active days, so the
        // calendar span has no idle days and the quantiles sample exactly the
        // five daily costs.
        let now = self.date(year: 2026, month: 2, day: 6)
        let entries = [
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 1),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 10),
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 2),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 20),
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 3),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 30),
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 4),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 40),
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 5),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 50),
        ]

        let forecasts = UsageLedgerAggregator.providerSpendForecasts(
            entries: entries,
            now: now,
            timeZone: self.utc,
            projectionDays: 30)
        let codex = forecasts.first { $0.provider == .codex }

        #expect(codex != nil)
        #expect(abs((codex?.projectedCostP50USD ?? 0) - 900) < 0.0001)
        #expect(abs((codex?.projectedCostP80USD ?? 0) - 1260) < 0.0001)
        #expect(abs((codex?.projectedCostP95USD ?? 0) - 1440) < 0.0001)
        #expect((codex?.projectedCostP95USD ?? 0) >= (codex?.projectedCostP80USD ?? 0))
        #expect((codex?.projectedCostP80USD ?? 0) >= (codex?.projectedCostP50USD ?? 0))
    }

    @Test
    func `sparse active days project on calendar days not active days`() {
        // Weekend-only user: $50 on each of 8 active days spread over Feb 1-23,
        // viewed on Feb 26. The active-day average used to project
        // $50 x 30 = $1,500/30d; the true calendar rate is $400 over 25
        // complete days = $16/day -> $480/30d.
        let now = self.date(year: 2026, month: 2, day: 26)
        let weekendDays = [1, 2, 8, 9, 15, 16, 22, 23]
        let entries = weekendDays.map { day in
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: day),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 50)
        }

        let forecasts = UsageLedgerAggregator.providerSpendForecasts(
            entries: entries,
            now: now,
            timeZone: self.utc,
            projectionDays: 30)
        let codex = forecasts.first { $0.provider == .codex }

        #expect(codex != nil)
        #expect(codex?.observedDays == 8)
        #expect(abs((codex?.observedCostUSD ?? 0) - 400) < 0.0001)
        #expect(abs((codex?.averageDailyCostUSD ?? 0) - 16) < 0.0001)
        #expect(abs((codex?.projected30DayCostUSD ?? 0) - 480) < 0.0001)

        // No false breach against a $500 budget (the old projection was $1,500).
        let noBreach = codex?.applyingBudget(monthlyLimitUSD: 500)
        #expect(noBreach?.budgetWillBreach == false)

        // ETA is calendar-day denominated: ($450 - $400) / $16 per day.
        let breach = codex?.applyingBudget(monthlyLimitUSD: 450)
        #expect(breach?.budgetWillBreach == true)
        #expect(abs((breach?.budgetETAInDays ?? 0) - 3.125) < 0.0001)
    }

    @Test
    func `forecast quantiles use calendar days so idle days sample as zero`() {
        // Same weekend-only user as above: 8 active $50 days over the 25
        // complete calendar days Feb 1-25, viewed on Feb 26. Sampling only
        // active days made P50 read $50/day -> $1,500/30d while the calendar
        // mean said $480 — the median CALENDAR day for this user is $0.
        let now = self.date(year: 2026, month: 2, day: 26)
        let weekendDays = [1, 2, 8, 9, 15, 16, 22, 23]
        let entries = weekendDays.map { day in
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: day),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 50)
        }

        let forecasts = UsageLedgerAggregator.providerSpendForecasts(
            entries: entries,
            now: now,
            timeZone: self.utc,
            projectionDays: 30)
        let codex = forecasts.first { $0.provider == .codex }

        #expect(codex != nil)
        // 25 samples: 17 idle $0 days + 8 active $50 days.
        // p50 lands on an idle day; p80/p95 land on active days.
        #expect(abs((codex?.projectedCostP50USD ?? -1) - 0) < 0.0001)
        #expect(abs((codex?.projectedCostP80USD ?? -1) - 1500) < 0.0001)
        #expect(abs((codex?.projectedCostP95USD ?? -1) - 1500) < 0.0001)
        // Quantiles stay ordered and the P50 no longer dwarfs the mean ($480).
        #expect((codex?.projectedCostP50USD ?? 1) <= (codex?.projected30DayCostUSD ?? 0))
    }

    @Test
    func `todays partial day is excluded from the calendar average`() {
        let now = self.date(year: 2026, month: 2, day: 5)
        var entries = (1...4).map { day in
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: day),
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 10)
        }
        // Today's partial spend must not drag the daily rate down mid-day.
        entries.append(self.entry(
            provider: .codex,
            timestamp: now,
            projectID: "proj-a",
            projectName: "Project A",
            costUSD: 2))

        let forecasts = UsageLedgerAggregator.providerSpendForecasts(
            entries: entries,
            now: now,
            timeZone: self.utc,
            projectionDays: 30)
        let codex = forecasts.first { $0.provider == .codex }

        // $40 over the 4 complete days Feb 1-4.
        #expect(abs((codex?.averageDailyCostUSD ?? 0) - 10) < 0.0001)
        #expect(abs((codex?.projected30DayCostUSD ?? 0) - 300) < 0.0001)
    }

    @Test
    func `first day of activity projects today as a full day`() {
        let now = self.date(year: 2026, month: 2, day: 5)
        let entries = [
            self.entry(
                provider: .codex,
                timestamp: now,
                projectID: "proj-a",
                projectName: "Project A",
                costUSD: 12),
        ]

        let forecasts = UsageLedgerAggregator.providerSpendForecasts(
            entries: entries,
            now: now,
            timeZone: self.utc,
            projectionDays: 30)
        let codex = forecasts.first { $0.provider == .codex }

        #expect(abs((codex?.averageDailyCostUSD ?? 0) - 12) < 0.0001)
        #expect(abs((codex?.projected30DayCostUSD ?? 0) - 360) < 0.0001)
    }

    @Test
    func `budget ETA is computed only when forecast breaches budget`() {
        let base = UsageLedgerSpendForecast(
            provider: .codex,
            projectKey: "id:proj-a",
            projectID: "proj-a",
            projectName: "Project A",
            observedDays: 5,
            observedCostUSD: 50,
            averageDailyCostUSD: 10,
            projected30DayCostUSD: 300,
            projectedCostP50USD: 270,
            projectedCostP80USD: 330,
            projectedCostP95USD: 390)

        let breach = base.applyingBudget(monthlyLimitUSD: 90)
        #expect(breach.budgetWillBreach)
        #expect(breach.budgetLimitUSD == 90)
        #expect(abs((breach.budgetETAInDays ?? 0) - 4) < 0.0001)
        #expect(breach.projectedCostP50USD == 270)
        #expect(breach.projectedCostP80USD == 330)
        #expect(breach.projectedCostP95USD == 390)

        let noBreach = base.applyingBudget(monthlyLimitUSD: 500)
        #expect(!noBreach.budgetWillBreach)
        #expect(noBreach.budgetLimitUSD == 500)
        #expect(noBreach.budgetETAInDays == nil)

        let alreadyBreached = base.applyingBudget(monthlyLimitUSD: 40)
        #expect(alreadyBreached.budgetWillBreach)
        #expect(alreadyBreached.budgetETAInDays == 0)
    }

    private func entry(
        provider: UsageProvider,
        timestamp: Date,
        projectID: String?,
        projectName: String?,
        costUSD: Double?) -> UsageLedgerEntry
    {
        UsageLedgerEntry(
            provider: provider,
            timestamp: timestamp,
            sessionID: "session",
            projectID: projectID,
            projectName: projectName,
            model: "gpt-5",
            inputTokens: 100,
            outputTokens: 50,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            costUSD: costUSD,
            requestID: UUID().uuidString,
            messageID: nil,
            version: nil,
            source: .codexLog)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = self.utc
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: self.utc,
            year: year,
            month: month,
            day: day,
            hour: hour))!
    }
}
