import Foundation
import Testing
@testable import Runic
@testable import RunicCore

/// A main provider whose login went unreadable must say so, even when its
/// usage history keeps the card populated.
struct MenuCardCredentialLossTests {
    private func model(provider: UsageProvider, liveFetchWasAvailable: Bool) throws -> UsageMenuCardView.Model {
        let metadata = try #require(ProviderDefaults.metadata[provider])
        let topModel = UsageLedgerModelSummary(
            provider: provider,
            projectID: nil,
            model: "some-model",
            entryCount: 10,
            totals: UsageLedgerTotals(
                inputTokens: 100,
                outputTokens: 50,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: nil))
        var input = UsageMenuCardView.Model.Input(
            provider: provider,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            ledgerTopModel: topModel,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: "No non-interactive Claude credentials found.",
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: Date())
        input.liveFetchWasAvailable = liveFetchWasAvailable
        return UsageMenuCardView.Model.make(input)
    }

    @Test
    func `claude with history but no readable login shows the error`() throws {
        let model = try self.model(provider: .claude, liveFetchWasAvailable: false)
        #expect(model.subtitleStyle == .error)
        #expect(model.subtitleText.contains("credentials"))
    }

    @Test
    func `a log-only provider with history stays quiet`() throws {
        let model = try self.model(provider: .qwen, liveFetchWasAvailable: false)
        #expect(model.subtitleStyle != .error)
    }
}
