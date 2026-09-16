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
