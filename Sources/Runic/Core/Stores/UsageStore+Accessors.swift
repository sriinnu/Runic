import Foundation
import RunicCore

extension UsageStore {
    /// Returns the login method (plan type) for the specified provider, if available.
    private func loginMethod(for provider: UsageProvider) -> String? {
        self.snapshots[provider]?.loginMethod(for: provider)
    }

    var codexSnapshot: UsageSnapshot? {
        self.snapshots[.codex]
    }

    var claudeSnapshot: UsageSnapshot? {
        self.snapshots[.claude]
    }

    var lastCodexError: String? {
        self.errors[.codex]
    }

    var lastClaudeError: String? {
        self.errors[.claude]
    }

    /// Returns true if the Claude account appears to be a subscription (Max, Pro, Ultra, Team).
    /// Returns false for API users or when plan cannot be determined.
    func isClaudeSubscription() -> Bool {
        Self.isSubscriptionPlan(self.loginMethod(for: .claude))
    }

    /// Determines if a login method string indicates a Claude subscription plan.
    /// Known subscription indicators: Max, Pro, Ultra, Team (case-insensitive).
    nonisolated static func isSubscriptionPlan(_ loginMethod: String?) -> Bool {
        guard let method = loginMethod?.lowercased(), !method.isEmpty else {
            return false
        }
        let subscriptionIndicators = ["max", "pro", "ultra", "team"]
        return subscriptionIndicators.contains { method.contains($0) }
    }

    func version(for provider: UsageProvider) -> String? {
        switch provider {
        case .codex: self.codexVersion
        case .claude: self.claudeVersion
        case .zai: self.zaiVersion
        case .gemini: self.geminiVersion
        case .antigravity: self.antigravityVersion
        case .cursor: self.cursorVersion
        default: nil
        }
    }

    var preferredSnapshot: UsageSnapshot? {
        for provider in self.enabledProviders() {
            if let snap = self.snapshots[provider] { return snap }
        }
        return nil
    }

    var iconStyle: IconStyle {
        let enabled = self.enabledProviders()
        if enabled.count > 1 { return .combined }
        if let provider = enabled.first {
            return self.style(for: provider)
        }
        return .codex
    }

    var isStale: Bool {
        self.enabledProviders().contains { provider in
            switch provider {
            case .codex:
                self.lastCodexError != nil
            case .claude:
                self.lastClaudeError != nil
            default:
                self.errors[provider] != nil
            }
        }
    }

    func error(for provider: UsageProvider) -> String? {
        self.errors[provider]
    }

    func snapshot(for provider: UsageProvider) -> UsageSnapshot? {
        self.snapshots[provider]
    }

    func fetchAttempts(for provider: UsageProvider) -> [ProviderFetchAttempt] {
        self.lastFetchAttempts[provider] ?? []
    }

    func status(for provider: UsageProvider) -> ProviderStatus? {
        guard self.statusChecksEnabled else { return nil }
        return self.statuses[provider]
    }

    func statusIndicator(for provider: UsageProvider) -> ProviderStatusIndicator {
        self.status(for: provider)?.indicator ?? .none
    }

    func ledgerDailySummary(for provider: UsageProvider) -> UsageLedgerDailySummary? {
        self.ledgerDailySummaries[provider]
    }

    func ledgerAllDailySummary(for provider: UsageProvider) -> [UsageLedgerDailySummary] {
        self.ledgerAllDailySummaries[provider] ?? []
    }

    func ledgerHourlySummary(for provider: UsageProvider) -> [UsageLedgerHourlySummary] {
        self.ledgerHourlySummaries[provider] ?? []
    }

    func ledgerActiveBlock(for provider: UsageProvider) -> UsageLedgerBlockSummary? {
        self.ledgerActiveBlocks[provider]
    }

    func ledgerTopModel(for provider: UsageProvider) -> UsageLedgerModelSummary? {
        self.ledgerTopModels[provider]
    }

    func ledgerTopProject(for provider: UsageProvider) -> UsageLedgerProjectSummary? {
        self.ledgerTopProjects[provider]
    }

    func ledgerModelBreakdown(for provider: UsageProvider) -> [UsageLedgerModelSummary] {
        self.ledgerModelBreakdowns[provider] ?? []
    }

    func ledgerProjectBreakdown(for provider: UsageProvider) -> [UsageLedgerProjectSummary] {
        self.ledgerProjectBreakdowns[provider] ?? []
    }

    func ledgerSpendForecast(for provider: UsageProvider) -> UsageLedgerSpendForecast? {
        self.ledgerSpendForecasts[provider]
    }

    func ledgerProjectSpendForecasts(for provider: UsageProvider) -> [UsageLedgerSpendForecast] {
        self.ledgerProjectSpendForecasts[provider] ?? []
    }

    func ledgerTopProjectSpendForecast(for provider: UsageProvider) -> UsageLedgerSpendForecast? {
        self.ledgerTopProjectSpendForecasts[provider]
    }

    func ledgerAnomalySummary(for provider: UsageProvider) -> UsageLedgerAnomalySummary? {
        self.ledgerAnomalies[provider]
    }

    func ledgerCompactionSummary(for provider: UsageProvider) -> UsageLedgerCompactionSummary? {
        self.ledgerCompactions[provider]
    }

    func ledgerError(for provider: UsageProvider) -> String? {
        self.ledgerErrors[provider]
    }

    func ledgerUpdatedAt(for provider: UsageProvider) -> Date? {
        self.ledgerUpdatedAt[provider]
    }

    func ledgerReliabilityScore(for provider: UsageProvider) -> UsageLedgerReliabilityScore? {
        UsageLedgerInsightsAdvisor.reliabilityScore(.init(
            provider: provider,
            daily: self.ledgerDailySummary(for: provider),
            activeBlock: self.ledgerActiveBlock(for: provider),
            breakdowns: .init(
                models: self.ledgerModelBreakdown(for: provider),
                projects: self.ledgerProjectBreakdown(for: provider)),
            errors: .init(
                provider: self.error(for: provider),
                ledger: self.ledgerError(for: provider))))
    }

    func ledgerRoutingRecommendation(for provider: UsageProvider) -> UsageLedgerRoutingRecommendation? {
        UsageLedgerInsightsAdvisor.routingRecommendation(
            modelBreakdown: self.ledgerModelBreakdown(for: provider))
    }
}
