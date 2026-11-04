import Foundation
import Testing
@testable import Runic
@testable import RunicCore

/// The summary tiles read one number, whichever way a provider reports money.
/// With only the Console's API credits, Flight Deck showed `BAL ----` right
/// above a row saying "$206.84 left".
struct BalanceSummaryTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private func snapshot(cost: ProviderCostSnapshot? = nil, balance: ProviderBalance? = nil) -> UsageSnapshot {
        UsageSnapshot(
            primary: .noLimitsReported,
            secondary: nil,
            tertiary: nil,
            providerCost: cost,
            balance: balance,
            updatedAt: self.now)
    }

    private func cost(apiCredits: ProviderAPICredits?) -> ProviderCostSnapshot {
        var cost = ProviderCostSnapshot(used: 0, limit: 0, currencyCode: "USD", updatedAt: self.now)
        cost.apiCredits = apiCredits
        return cost
    }

    @Test
    func `console credits fill the tile`() {
        let credits = ProviderAPICredits(
            available: 206.84,
            currencyCode: "USD",
            grants: [],
            fetchedAt: self.now)
        let text = UsageMenuCardView.Model.balanceSummaryText(
            creditsText: nil,
            snapshot: self.snapshot(cost: self.cost(apiCredits: credits)),
            now: self.now)
        #expect(text == "$206.84")
        #expect(RunicFlightDeck.readout(from: text) == "$206.84")
    }

    @Test
    func `credits still come first`() {
        let text = UsageMenuCardView.Model.balanceSummaryText(
            creditsText: "5,447.13 left",
            snapshot: self.snapshot(),
            now: self.now)
        #expect(text == "5,447.13 left")
    }

    @Test
    func `a plans included credit is not A balance`() {
        var cost = self.cost(apiCredits: nil)
        cost.includedMonthlyCreditUSD = 200
        let text = UsageMenuCardView.Model.balanceSummaryText(
            creditsText: nil,
            snapshot: self.snapshot(cost: cost),
            now: self.now)
        #expect(text == nil)
    }
}
