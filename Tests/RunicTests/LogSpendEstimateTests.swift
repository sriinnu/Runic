import Foundation
import Testing
@testable import Runic
@testable import RunicCore

/// Spend estimated from local-log tokens for balance-only providers.
struct LogSpendEstimateTests {
    /// 2026-09-16 16:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_789_574_400)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let catalog = ModelPriceCatalog(
        prices: [
            "deepseek": ["deepseek-v4-pro": ModelPrice(input: 0.435, output: 0.87, cacheRead: 0.003625)],
            "moonshotai": ["kimi-k3": ModelPrice(input: 3, output: 15, cacheRead: 0.3)],
            "openrouter": ["kimi-k3": ModelPrice(input: 99, output: 99)],
        ],
        snapshot: "test")

    private func entry(
        _ provider: UsageProvider,
        _ model: String?,
        hoursAgo: Double,
        input: Int = 0,
        output: Int = 0,
        cacheWrite: Int = 0,
        cacheRead: Int = 0) -> UsageLedgerEntry
    {
        UsageLedgerEntry(
            provider: provider,
            timestamp: self.now.addingTimeInterval(-hoursAgo * 3600),
            sessionID: nil,
            projectID: nil,
            model: model,
            inputTokens: input,
            outputTokens: output,
            cacheCreationTokens: cacheWrite,
            cacheReadTokens: cacheRead,
            costUSD: nil,
            requestID: nil,
            messageID: nil,
            version: nil,
            source: .claudeLog)
    }

    @Test
    func `prices are scoped to the vendor and tolerate prefixes and dates`() {
        #expect(self.catalog.price(for: .kimiCN, model: "kimi-k3")?.input == 3)
        #expect(self.catalog.price(for: .kimi, model: "moonshotai/Kimi-K3")?.input == 3)
        #expect(self.catalog.price(for: .deepseek, model: "deepseek-v4-pro-20260812")?.output == 0.87)
        // Never priced from a reseller list or another vendor.
        #expect(self.catalog.price(for: .deepseek, model: "kimi-k3") == nil)
        #expect(self.catalog.price(for: .claude, model: "kimi-k3") == nil)
    }

    @Test
    func `a missing cache rate bills as input`() {
        let price = ModelPrice(input: 2, output: 10)
        #expect(price.cost(input: 1_000_000, output: 0, cacheWrite: 1_000_000, cacheRead: 1_000_000) == 6)
    }

    @Test
    func `today and month add up, unpriced models are counted not zeroed`() throws {
        let entries = [
            self.entry(.kimi, "kimi-k3", hoursAgo: 2, input: 1_000_000, output: 100_000, cacheRead: 1_000_000),
            self.entry(.kimi, "kimi-k3", hoursAgo: 40, output: 1_000_000),
            self.entry(.kimi, "kimi-k9-secret", hoursAgo: 1, input: 5000),
            self.entry(.kimi, "kimi-k3", hoursAgo: 24 * 20, output: 1_000_000), // last month
            self.entry(.deepseek, "deepseek-v4-pro", hoursAgo: 1, output: 1_000_000),
        ]
        let kimi = try #require(LogSpendEstimator.estimate(
            provider: .kimi, entries: entries, catalog: self.catalog, now: self.now, calendar: self.calendar))
        #expect(abs(kimi.today - (3 + 1.5 + 0.3)) < 0.000_1)
        #expect(abs(kimi.thisMonth - (4.8 + 15)) < 0.000_1)
        #expect(kimi.unpricedTokens == 5000)
        #expect(kimi.unpricedModels == ["kimi-k9-secret"])

        #expect(LogSpendEstimator.estimate(
            provider: .zai, entries: entries, catalog: self.catalog, now: self.now, calendar: self.calendar) == nil)
    }

    @Test
    func `models dev payload is trimmed to the lists Runic prices from`() throws {
        let json = """
        {"deepseek": {"models": {"DeepSeek-V4-Flash": {"cost": {"input": 0.15, "output": 0.6, "cache_read": 0.003}},
                                 "deepseek-ocr": {"name": "no cost"}}},
         "anthropic": {"models": {"claude-x": {"cost": {"input": 3, "output": 15}}}}}
        """
        let catalog = try ModelPriceCatalog.fromModelsDev(Data(json.utf8), snapshot: "2026-09-23")
        #expect(catalog.prices.keys.sorted() == ["deepseek"])
        #expect(catalog.price(for: .deepseek, model: "deepseek-v4-flash")?.cacheRead == 0.003)
        let roundTrip = try ModelPriceCatalog.decodeSnapshot(catalog.encodedSnapshot())
        #expect(roundTrip == catalog)
    }

    @Test
    func `the bundled prices cover the balance-only providers`() {
        let bundled = ModelPriceCatalog.bundled
        #expect(bundled.price(for: .deepseek, model: "deepseek-v4-pro") != nil)
        #expect(bundled.price(for: .kimiCN, model: "kimi-k3") != nil)
        #expect(bundled.price(for: .stepfun, model: "step-3.5-flash") != nil)
    }

    @Test
    func `overrides replace a model's price without dropping the rest`() {
        let custom = ModelPriceCatalog(
            prices: ["moonshotai": ["kimi-k3": ModelPrice(input: 1, output: 2)]], snapshot: nil)
        let merged = self.catalog.overlaid(by: custom)
        #expect(merged.price(for: .kimi, model: "kimi-k3")?.input == 1)
        #expect(merged.price(for: .deepseek, model: "deepseek-v4-pro") != nil)
    }

    // MARK: - Reconciliation

    private func balance(spentToday: Double, latestMinutesAgo: Double = 5) -> BalanceSpendSummary {
        var summary = BalanceSpendSummary(
            currency: "USD",
            spentToday: spentToday,
            spentThisMonth: spentToday,
            toppedUpThisMonth: 0,
            dailyBurnRate: nil,
            runwayDays: nil,
            trackedSince: self.now.addingTimeInterval(-48 * 3600),
            todayIsPartial: false,
            monthIsPartial: true)
        summary.latestReadingAt = self.now.addingTimeInterval(-latestMinutesAgo * 60)
        return summary
    }

    @Test
    func `logs are checked against the balance drop`() {
        typealias Card = UsageMenuCardView.Model
        let logs = LogSpendEstimate(today: 1.0, thisMonth: 5)
        #expect(Card.logSpendReconciliation(logs, balance: self.balance(spentToday: 1.1), now: self.now)
            == "Matches today's balance drop")
        #expect(Card.logSpendReconciliation(logs, balance: self.balance(spentToday: 3), now: self.now)?
            .hasPrefix("Balance fell 3.0× more") == true)
        #expect(Card.logSpendReconciliation(
            LogSpendEstimate(today: 0, thisMonth: 0),
            balance: self.balance(spentToday: 2),
            now: self.now)?.contains("no logged usage") == true)
        // A stale balance reading or another currency makes no claim.
        #expect(Card.logSpendReconciliation(
            logs, balance: self.balance(spentToday: 3, latestMinutesAgo: 90), now: self.now) == nil)
        var yuan = self.balance(spentToday: 3)
        yuan = BalanceSpendSummary(
            currency: "CNY",
            spentToday: 3,
            spentThisMonth: 3,
            toppedUpThisMonth: 0,
            dailyBurnRate: nil,
            runwayDays: nil,
            trackedSince: yuan.trackedSince,
            todayIsPartial: false,
            monthIsPartial: true)
        #expect(Card.logSpendReconciliation(logs, balance: yuan, now: self.now) == nil)
    }
}
