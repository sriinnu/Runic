import Foundation
import RunicCore

extension MenuPopoverView {
    func menuCardModel(for provider: UsageProvider) -> UsageMenuCardView.Model? {
        let metadata = self.store.metadata(for: provider)
        let snapshot = self.store.snapshot(for: provider)
        let ledgerTopModel = self.store.ledgerTopModel(for: provider)
        let providerContextStatus = ledgerTopModel.flatMap {
            ProviderContextWindowRegistry.shared.contextLabel(for: provider, model: $0.model)
        } ?? ProviderContextWindowRegistry.shared.contextLabel(for: provider)
        let ledgerTopModelContextLabel = providerContextStatus?.text
        let credits: CreditsSnapshot? = provider == .codex ? self.store.credits : nil
        let creditsError: String? = provider == .codex ? self.store.lastCreditsError : nil
        let dashboard: OpenAIDashboardSnapshot? = provider == .codex && !self.store.openAIDashboardRequiresLogin
            ? self.store.openAIDashboard
            : nil
        let dashboardError: String? = provider == .codex ? self.store.lastOpenAIDashboardError : nil

        let input = UsageMenuCardView.Model.Input(
            provider: provider,
            metadata: metadata,
            snapshot: snapshot,
            credits: credits,
            creditsError: creditsError,
            dashboard: dashboard,
            dashboardError: dashboardError,
            tokenSnapshot: self.store.tokenSnapshot(for: provider),
            tokenError: self.store.tokenError(for: provider),
            ledgerDaily: self.store.ledgerDailySummary(for: provider),
            ledgerActiveBlock: self.store.ledgerActiveBlock(for: provider),
            ledgerTopModel: ledgerTopModel,
            ledgerTopModelContextLabel: ledgerTopModelContextLabel,
            ledgerTopProject: self.store.ledgerTopProject(for: provider),
            ledgerSpendForecast: self.store.ledgerSpendForecast(for: provider),
            ledgerTopProjectSpendForecast: self.store.ledgerTopProjectSpendForecast(for: provider),
            ledgerAnomaly: self.store.ledgerAnomalySummary(for: provider),
            ledgerCompaction: self.store.ledgerCompactionSummary(for: provider),
            ledgerReliability: self.store.ledgerReliabilityScore(for: provider),
            ledgerRouting: self.store.ledgerRoutingRecommendation(for: provider),
            ledgerError: self.store.ledgerError(for: provider),
            ledgerUpdatedAt: self.store.ledgerUpdatedAt(for: provider),
            providerContextStatus: providerContextStatus,
            account: self.account,
            isRefreshing: self.store.isRefreshing,
            lastError: self.store.error(for: provider),
            usageBarsShowUsed: self.settings.usageBarsShowUsed,
            usageMetricDisplayMode: self.settings.usageMetricDisplayMode,
            menuMode: self.settings.menuMode,
            tokenCostUsageEnabled: self.settings.isCostUsageEffectivelyEnabled(for: provider),
            showOptionalCreditsAndExtraUsage: self.settings.showOptionalCreditsAndExtraUsage,
            now: Date())
        return UsageMenuCardView.Model.make(input)
    }
}
