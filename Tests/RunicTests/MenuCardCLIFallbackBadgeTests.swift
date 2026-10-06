import Foundation
import Testing
@testable import Runic
@testable import RunicCore

/// While Claude's numbers come through the CLI because Runic's token copy is
/// stale, the card says so and offers Reconnect; a normal OAuth read does not.
struct MenuCardCLIFallbackBadgeTests {
    private func model(provider: UsageProvider, sourceLabel: String) throws -> UsageMenuCardView.Model {
        let metadata = try #require(ProviderDefaults.metadata[provider])
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 9, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: Date())
        var input = UsageMenuCardView.Model.Input(
            provider: provider,
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
            usageBarsShowUsed: true,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: Date())
        input.sourceLabel = sourceLabel
        return UsageMenuCardView.Model.make(input)
    }

    @Test
    func `cli fallback is badged on the claude card`() throws {
        let model = try self.model(provider: .claude, sourceLabel: ClaudeUsageDataSource.cliFallbackSourceLabel)
        #expect(model.isServedByCLIFallback)
        #expect(model.headerBadge?.text == "Via CLI")
        #expect(model.subtitleStyle == .info)
    }

    @Test
    func `oauth reads carry no fallback badge`() throws {
        let model = try self.model(provider: .claude, sourceLabel: "oauth")
        #expect(!model.isServedByCLIFallback)
        #expect(model.headerBadge?.text != "Via CLI")
    }

    @Test
    func `the label means nothing for other providers`() throws {
        let model = try self.model(provider: .codex, sourceLabel: ClaudeUsageDataSource.cliFallbackSourceLabel)
        #expect(!model.isServedByCLIFallback)
    }
}
