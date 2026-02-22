import Foundation
import Testing

@testable import RunicCore

@Suite
struct UsageLedgerForecastTests {
    private let utc = TimeZone(secondsFromGMT: 0)!

    @Test
    func providerForecastUsesObservedDaysInCurrentMonth() {
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
        #expect(abs((codex?.averageDailyCostUSD ?? 0) - 15) < 0.0001)
        #expect(abs((codex?.projected30DayCostUSD ?? 0) - 450) < 0.0001)
        #expect(codex?.projectedCostP50USD == nil)
        #expect(codex?.projectedCostP80USD == nil)
        #expect(codex?.projectedCostP95USD == nil)
    }

    @Test
    func projectForecastsAreComputedPerProject() {
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
        #expect(abs((projectA?.projected30DayCostUSD ?? 0) - 300) < 0.0001)
        #expect(projectB?.observedDays == 1)
        #expect(abs((projectB?.projected30DayCostUSD ?? 0) - 600) < 0.0001)
    }

    @Test
    func providerForecastIncludesConfidenceBandQuantilesWhenEnoughDailyHistoryExists() {
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
    func budgetETAIsComputedOnlyWhenForecastBreachesBudget() {
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
