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

    @Test
    func `codex missing credits keeps placeholder text without filling balance summary`() throws {
        let metadata = try #require(ProviderDefaults.metadata[.codex])
        let model = UsageMenuCardView.Model.make(.init(
            provider: .codex,
            metadata: metadata,
            snapshot: self.snapshot(),
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
            now: self.now))
        #expect(model.creditsText == "0 left")
        #expect(model.creditsHintText != nil)
        #expect(model.balanceSummaryText == nil)
    }

    @Test
    func `flight deck balance readout preserves currency symbols and iso codes`() {
        #expect(RunicFlightDeck.compactBalance(from: "12.50 EUR") == "12.50 EUR")
        #expect(RunicFlightDeck.compactBalance(from: "¥85.04") == "¥85.04")
        #expect(RunicFlightDeck.compactBalance(from: "$12.34 left") == "$12.34")
        #expect(RunicFlightDeck.compactBalance(from: nil) == nil)
    }

    @MainActor
    @Test
    func `flight deck front page exhausted helper respects showsUsed toggle`() {
        let fullLeft = OverviewMenuView.ProviderSummary(
            id: "claude",
            provider: .claude,
            name: "Claude",
            icon: nil,
            usedPercent: 100,
            todayTokens: 0,
            brandColor: .accentColor,
            resetDescription: nil,
            windowLabel: nil,
            topModelContext: nil,
            hasQuota: true,
            bankedResetsText: nil)
        #expect(FlightDeckFrontPage.isExhausted(fullLeft, showsUsed: false) == false)
        #expect(FlightDeckFrontPage.isExhausted(fullLeft, showsUsed: true) == true)

        let emptyLeft = OverviewMenuView.ProviderSummary(
            id: "claude",
            provider: .claude,
            name: "Claude",
            icon: nil,
            usedPercent: 0,
            todayTokens: 0,
            brandColor: .accentColor,
            resetDescription: nil,
            windowLabel: nil,
            topModelContext: nil,
            hasQuota: true,
            bankedResetsText: nil)
        #expect(FlightDeckFrontPage.isExhausted(emptyLeft, showsUsed: false) == true)
        #expect(FlightDeckFrontPage.isExhausted(emptyLeft, showsUsed: true) == false)
    }
}
