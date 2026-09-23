import Foundation
import Testing
@testable import Runic
@testable import RunicCore

/// Balance-only providers must never look like "just a balance": the Spend row
/// is always there, and OpenRouter keeps its key spend if `/credits` refuses.
struct BalanceSpendVisibilityTests {
    private let now = Date(timeIntervalSince1970: 1_789_574_400)

    private func model(balanceSpend: BalanceSpendSummary?) throws -> UsageMenuCardView.Model {
        let metadata = try #require(ProviderDefaults.metadata[.deepseek])
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 0, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            balance: ProviderBalance(available: 19.13, currency: "USD"),
            updatedAt: self.now)
        var input = UsageMenuCardView.Model.Input(
            provider: .deepseek,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: self.now)
        input.balanceSpend = balanceSpend
        return UsageMenuCardView.Model.make(input)
    }

    @Test
    func `a single reading shows the spend row as measuring`() throws {
        let spend = try #require(try self.model(balanceSpend: nil).metrics.first { $0.id == "balance-spend" })
        #expect(spend.resetText == UsageMenuCardView.Model.balanceSpendPendingText)
        #expect(spend.detailText == UsageMenuCardView.Model.balanceSpendPendingDetail)
    }

    @Test
    func `two readings show real spend`() throws {
        let summary = try #require(BalanceSpendSummary.make(
            samples: [
                BalanceSample(at: self.now.addingTimeInterval(-3600), available: 22.13, currency: "USD"),
                BalanceSample(at: self.now, available: 19.13, currency: "USD"),
            ],
            now: self.now))
        let spend = try #require(try self.model(balanceSpend: summary).metrics.first { $0.id == "balance-spend" })
        #expect(spend.resetText?.hasPrefix("$3.00 today") == true)
    }

    @Test
    func `openrouter key-only snapshot keeps day and month spend`() throws {
        let keyInfo = try JSONDecoder().decode(
            OpenRouterKeyInfoResponse.self,
            from: Data(#"{"data": {"usage": 42.5, "usage_daily": 1.25, "usage_monthly": 18.75}}"#.utf8))
        let snapshot = keyInfo.toUsageSnapshot(now: self.now)
        #expect(snapshot.primary.resetDescription == "Spent $1.25 today · $18.75 this month (this key)")
        #expect(snapshot.primary.hasKnownLimit == false)
        #expect(snapshot.balance == nil)
    }
}
