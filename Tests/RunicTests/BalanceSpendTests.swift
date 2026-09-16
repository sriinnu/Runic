import Foundation
import Testing
@testable import Runic
@testable import RunicCore

/// Balance APIs return a snapshot only; Runic derives spend and runway from the
/// readings it records.
struct BalanceSpendTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 2026-09-16 16:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_789_574_400)

    private func sample(_ hoursAgo: Double, _ available: Double, _ currency: String? = "CNY") -> BalanceSample {
        BalanceSample(at: self.now.addingTimeInterval(-hoursAgo * 3600), available: available, currency: currency)
    }

    @Test
    func `drops are spend, rises are top-ups`() throws {
        let samples = [
            self.sample(40, 200), // Sep 14 midnight: before today, same month
            self.sample(30, 180), // spend 20 (Sep 15)
            self.sample(20, 230), // top-up 50
            self.sample(10, 210), // spend 20 (Sep 16 06:00)
            self.sample(1, 110.04), // spend 99.96 (today)
        ]
        let spend = try #require(BalanceSpendSummary.make(samples: samples, now: self.now, calendar: self.calendar))

        #expect(abs(spend.spentToday - 119.96) < 0.001)
        #expect(abs(spend.spentThisMonth - 139.96) < 0.001)
        #expect(spend.toppedUpThisMonth == 50)
        #expect(spend.currency == "CNY")
        #expect(spend.todayIsPartial == false)
        #expect(spend.monthIsPartial == true)
        // 139.96 over 40h of coverage.
        let rate = try #require(spend.dailyBurnRate)
        #expect(abs(rate - 139.96 / (40.0 / 24)) < 0.001)
        #expect(abs((spend.runwayDays ?? 0) - 110.04 / rate) < 0.001)
    }

    @Test
    func `short coverage has spend but no rate yet`() throws {
        let spend = try #require(BalanceSpendSummary.make(
            samples: [self.sample(3, 120), self.sample(1, 110)], now: self.now, calendar: self.calendar))
        #expect(spend.spentToday == 10)
        #expect(spend.todayIsPartial == true)
        #expect(spend.dailyBurnRate == nil)
        #expect(spend.runwayDays == nil)
    }

    @Test
    func `a single reading or a currency switch yields no comparison`() {
        #expect(BalanceSpendSummary.make(samples: [self.sample(1, 10)], now: self.now) == nil)
        let switched = [self.sample(5, 100, "USD"), self.sample(1, 50, "CNY")]
        #expect(BalanceSpendSummary.make(samples: switched, now: self.now) == nil)
    }

    @Test
    func `readings older than the trailing week don't inflate the rate`() throws {
        let samples = [
            self.sample(24 * 20, 1000),
            self.sample(24 * 8, 500),
            self.sample(24 * 7 - 1, 490),
            self.sample(1, 420),
        ]
        let spend = try #require(BalanceSpendSummary.make(samples: samples, now: self.now, calendar: self.calendar))
        // Only the 10 + 70 spent inside the last 7 days count, over 7 days.
        #expect(abs((spend.dailyBurnRate ?? 0) - 80.0 / 7) < 0.001)
    }

    @Test
    func `store drops unchanged readings inside the heartbeat, keeps changes`() {
        let store = BalanceSampleStore(directory: nil, memoryOnly: true)
        let start = Date(timeIntervalSince1970: 1_000_000)
        store.record(provider: .kimiCN, sample: BalanceSample(at: start, available: 100, currency: "CNY"))
        store.record(provider: .kimiCN, sample: BalanceSample(at: start + 60, available: 100, currency: "CNY"))
        store.record(provider: .kimiCN, sample: BalanceSample(at: start + 120, available: 99.5, currency: "CNY"))
        store.record(provider: .kimiCN, sample: BalanceSample(at: start + 60, available: 90, currency: "CNY"))
        store.record(
            provider: .kimiCN,
            sample: BalanceSample(at: start + 120 + BalanceSampleStore.heartbeat, available: 99.5, currency: "CNY"))
        #expect(store.samples(provider: .kimiCN).map(\.available) == [100, 99.5, 99.5])
    }

    // MARK: - Providers

    @Test
    func `kimi balance is structured with platform currency and parts`() throws {
        let response = KimiBalanceResponse(
            data: .init(availableBalance: 110.04083, voucherBalance: 25, cashBalance: 85.04083),
            status: true)
        let cnURL = KimiUsageFetcher.balanceURL(baseURL: "https://api.moonshot.cn")
        let currency = KimiBalanceResponse.currency(forBalanceURL: cnURL)
        let balance = try #require(response.toUsageSnapshot(currency: currency).balance)

        #expect(currency == "CNY")
        #expect(KimiBalanceResponse.currency(forBalanceURL: KimiUsageFetcher.balanceURL(baseURL: nil)) == "USD")
        #expect(KimiBalanceResponse.currency(forBalanceURL: URL(string: "https://gateway.local/v1")) == nil)
        #expect(balance.available == 110.04083)
        #expect(balance.components == [.init(label: "Paid", amount: 85.04083), .init(label: "Bonus", amount: 25)])
    }

    @Test
    func `deepseek balance carries its currency and parts`() throws {
        let response = DeepSeekBalanceResponse(
            is_available: true,
            balance_infos: [.init(
                currency: "CNY",
                total_balance: "30.00",
                granted_balance: "10.00",
                topped_up_balance: "20.00")])
        let balance = try #require(response.toUsageSnapshot().balance)
        #expect(balance.currency == "CNY")
        #expect(balance.available == 30)
        #expect(balance.components.map(\.label) == ["Paid", "Bonus"])
    }

    @Test
    func `balance survives a snapshot encode and decode`() throws {
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: nil,
                hasKnownLimit: false),
            secondary: nil,
            balance: ProviderBalance(
                available: 5,
                currency: "USD",
                components: [.init(label: "Paid", amount: 5)],
                lifetimeSpent: 2),
            updatedAt: Date(timeIntervalSince1970: 0))
        let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(decoded.balance == snapshot.balance)
        #expect(snapshot.scoped(to: .openrouter).balance == snapshot.balance)
    }

    // MARK: - Card text

    @Test
    func `formatter uses the platform symbol and never guesses one`() {
        #expect(BalanceFormatter.amount(110.04083, currency: "CNY") == "¥110.04")
        #expect(BalanceFormatter.amount(1234.5, currency: "USD") == "$1,234.50")
        #expect(BalanceFormatter.amount(3, currency: "GBP") == "3.00 GBP")
        #expect(BalanceFormatter.amount(3, currency: nil) == "3.00")
    }

    @Test
    func `card lines read like the dashboard`() throws {
        let balance = ProviderBalance(
            available: 110.04,
            currency: "CNY",
            components: [
                .init(label: "Paid", amount: 85.04),
                .init(label: "Bonus", amount: 25),
                .init(label: "Gift", amount: 0),
            ])
        #expect(UsageMenuCardView.Model.balanceComponentsText(balance) == "¥85.04 paid · ¥25.00 bonus")

        let spend = try #require(BalanceSpendSummary.make(
            samples: [self.sample(40, 250), self.sample(1, 110.04)], now: self.now, calendar: self.calendar))
        #expect(UsageMenuCardView.Model.balanceSpendText(spend) == "¥139.96 today · ¥139.96 this month")
        let runway = UsageMenuCardView.Model.balanceRunwayText(spend, now: self.now, calendar: self.calendar)
        #expect(runway.hasPrefix("~1.3 days left at ¥83.98/day"))
        #expect(runway.contains("tracked since"))

        #expect(UsageMenuCardView.Model.runwayPhrase(days: 0.2) == "~5h left")
        #expect(UsageMenuCardView.Model.runwayPhrase(days: 23.6) == "~24 days left")
        #expect(UsageMenuCardView.Model.runwayPhrase(days: 500) == "over a year left")
    }
}

/// Blocked / low-balance states and OpenRouter's reported key usage.
struct BalanceStateTests {
    @Test
    func `calls are blocked when the provider says so or nothing is left`() {
        #expect(ProviderBalance(available: 0, currency: "CNY").blocksAPICalls)
        #expect(ProviderBalance(available: -1.2, currency: "CNY").blocksAPICalls)
        #expect(!ProviderBalance(available: 3, currency: "CNY").blocksAPICalls)
        #expect(ProviderBalance(available: 5, currency: "USD", apiCallsAllowed: false).blocksAPICalls)
        // The provider's own verdict wins over the number.
        #expect(!ProviderBalance(available: 0, currency: "USD", apiCallsAllowed: true).blocksAPICalls)
    }

    @Test
    func `deepseek is_available flows into the balance`() throws {
        let response = DeepSeekBalanceResponse(
            is_available: false,
            balance_infos: [
                .init(currency: "USD", total_balance: "0.02", granted_balance: "0.00", topped_up_balance: "0.02"),
            ])
        let balance = try #require(response.toUsageSnapshot().balance)
        #expect(balance.apiCallsAllowed == false)
        #expect(balance.blocksAPICalls)
    }

    @Test
    @MainActor
    func `badge says top up when blocked and low balance under a day of runway`() throws {
        let blocked = ProviderBalance(available: 0, currency: "CNY")
        #expect(UsageMenuCardView.Model.balanceBadge(balance: blocked, spend: nil)?.text == "Top up")

        let now = Date(timeIntervalSince1970: 1_789_574_400)
        let samples = [
            BalanceSample(at: now.addingTimeInterval(-20 * 3600), available: 150, currency: "CNY"),
            BalanceSample(at: now.addingTimeInterval(-600), available: 30, currency: "CNY"),
        ]
        let spend = try #require(BalanceSpendSummary.make(samples: samples, now: now))
        let low = ProviderBalance(available: 30, currency: "CNY")
        #expect(try #require(spend.runwayDays) < 1)
        #expect(UsageMenuCardView.Model.balanceBadge(balance: low, spend: spend)?.text == "Low balance")
        #expect(UsageMenuCardView.Model.balanceBadge(
            balance: ProviderBalance(available: 30, currency: "CNY"),
            spend: nil) == nil)
        #expect(UsageMenuCardView.Model.balanceBadge(balance: nil, spend: spend) == nil)
    }

    @Test
    func `openrouter key usage gives exact spend, a key limit and the free quota`() throws {
        let now = Date(timeIntervalSince1970: 1_789_574_400) // Wed 2026-09-16 16:00 UTC
        let keyJSON = """
        {"data": {"label": "runic", "usage": 42.5, "limit": 50, "limit_remaining": 7.5, "limit_reset": "weekly",
                  "usage_daily": 1.25, "usage_weekly": 6.5, "usage_monthly": 18.75, "is_free_tier": false,
                  "free_model_daily_requests": {"used": 12, "limit": 50, "remaining": 38}}}
        """
        let keyInfo = try JSONDecoder().decode(OpenRouterKeyInfoResponse.self, from: Data(keyJSON.utf8))
        let credits = try JSONDecoder().decode(
            OpenRouterCreditsResponse.self,
            from: Data(#"{"data": {"total_credits": 100, "total_usage": 60}}"#.utf8))
        let snapshot = credits.toUsageSnapshot(keyInfo: keyInfo, now: now)

        let reported = try #require(snapshot.balance?.reportedSpend)
        #expect(reported == .init(today: 1.25, thisWeek: 6.5, thisMonth: 18.75, scope: "this key"))

        let limit = try #require(snapshot.secondary)
        #expect(limit.label == "Key limit")
        #expect(limit.usedPercent == 85)
        #expect(limit.windowMinutes == 10080)
        // Next Monday 00:00 UTC after Wed Sep 16.
        #expect(limit.resetsAt == Date(timeIntervalSince1970: 1_789_948_800))

        let free = try #require(snapshot.tertiary)
        #expect(free.label == "Free requests")
        #expect(free.usedPercent == 24)
        #expect(free.resetsAt == Date(timeIntervalSince1970: 1_789_603_200))

        let spend = try BalanceSpendSummary.make(
            reported: reported,
            balance: #require(snapshot.balance),
            samples: [],
            now: now)
        #expect(spend.spentToday == 1.25)
        #expect(spend.monthIsPartial == false)
        #expect(spend.scope == "this key")
        // No readings yet: month-to-date over 15.67 elapsed days.
        #expect(abs((spend.dailyBurnRate ?? 0) - 18.75 / (15 + 16.0 / 24)) < 0.0001)
    }

    @Test
    func `legacy key payload without usage fields adds nothing`() throws {
        let keyInfo = try JSONDecoder().decode(
            OpenRouterKeyInfoResponse.self,
            from: Data(#"{"data": {"label": "old", "usage": 3, "limit": null, "is_free_tier": true}}"#.utf8))
        let credits = try JSONDecoder().decode(
            OpenRouterCreditsResponse.self, from: Data(#"{"data": {"total_credits": 10, "total_usage": 3}}"#.utf8))
        let snapshot = credits.toUsageSnapshot(keyInfo: keyInfo)
        #expect(snapshot.secondary == nil)
        #expect(snapshot.tertiary == nil)
        #expect(snapshot.balance?.reportedSpend == nil)
    }
}
