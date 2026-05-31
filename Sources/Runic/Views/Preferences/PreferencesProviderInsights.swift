import Foundation
import RunicCore

struct ProviderInsightLine: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let help: String?

    init(id: String, label: String, value: String, help: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.help = help
    }
}

@MainActor
enum ProviderInsightsComposer {
    static func lines(
        for provider: UsageProvider,
        store: UsageStore,
        maxRows: Int? = nil) -> [ProviderInsightLine]
    {
        var rows: [ProviderInsightLine] = []
        let snapshot = store.snapshot(for: provider)
        let identity = snapshot?.identity(for: provider) ?? snapshot?.identity
        let tokenSnapshot = store.tokenSnapshot(for: provider)
        let attempts = store.fetchAttempts(for: provider)
        let reliability = store.ledgerReliabilityScore(for: provider)
        let anomaly = store.ledgerAnomalySummary(for: provider)
        let spendForecast = store.ledgerSpendForecast(for: provider)
        let topProjectSpendForecast = store.ledgerTopProjectSpendForecast(for: provider)
        let topModel = store.ledgerTopModel(for: provider)
        let topProject = store.ledgerTopProject(for: provider)
        let modelBreakdown = store.ledgerModelBreakdown(for: provider)
        let projectBreakdown = store.ledgerProjectBreakdown(for: provider)
        let coverage = Self.effectiveCoverage(
            provider: provider,
            evidence: .init(
                metadataCoverage: store.metadata(for: provider).usageCoverage,
                topModel: topModel,
                topProject: topProject,
                modelBreakdown: modelBreakdown,
                projectBreakdown: projectBreakdown,
                snapshot: snapshot,
                tokenSnapshot: tokenSnapshot))
        let hasModelBreakdown = coverage.supportsModelBreakdown
        let hasProjectAttribution = coverage.supportsProjectAttribution

        if let who = self.actorValue(identity: identity) {
            rows.append(ProviderInsightLine(id: "actor", label: "Who", value: who))
        }
        if let planAuth = self.planAuthValue(identity: identity) {
            rows.append(ProviderInsightLine(id: "plan-auth", label: "Plan/Auth", value: planAuth))
        }
        if let fetch = self.fetchHealthValue(attempts) {
            rows.append(ProviderInsightLine(
                id: "fetch",
                label: "Fetch",
                value: fetch,
                help: self.fetchAttemptsHelp(attempts)))
        }
        if store.isStale(provider: provider), let fetchError = self.fetchErrorValue(attempts) {
            rows.append(ProviderInsightLine(
                id: "fetch-error",
                label: "Fetch err",
                value: fetchError,
                help: self.fetchAttemptsHelp(attempts)))
        }
        if let reliabilityValue = self.reliabilityValue(reliability) {
            rows.append(ProviderInsightLine(
                id: "reliability",
                label: "Reliability",
                value: reliabilityValue,
                help: self.reliabilityHelpText(reliability)))
        }
        if let costAlertValue = self.costAnomalyValue(anomaly) {
            rows.append(ProviderInsightLine(
                id: "cost-alert",
                label: "Cost alert",
                value: costAlertValue,
                help: self.costAnomalyHelpText(anomaly)))
        }

        if hasModelBreakdown, let topModel, topModel.provider == provider {
            rows.append(ProviderInsightLine(
                id: "top-model",
                label: "Top model",
                value: self.topModelValue(topModel)))
        } else if !hasModelBreakdown, let windowModels = self.windowModelsValue(snapshot) {
            rows.append(ProviderInsightLine(
                id: "models",
                label: "Quota windows",
                value: windowModels,
                help: "Live quota windows grouped by provider response window IDs."))
        }

        if hasProjectAttribution,
           let topProject,
           topProject.provider == provider
        {
            rows.append(ProviderInsightLine(
                id: "top-project",
                label: "Top project",
                value: self.topProjectValue(topProject),
                help: self.projectIdentityHelpText(topProject)))
        }

        if hasModelBreakdown, let modelMix = self.modelMixValue(modelBreakdown) {
            rows.append(ProviderInsightLine(id: "model-mix", label: "Model mix", value: modelMix))
        }

        if hasProjectAttribution, let projectMix = self.projectMixValue(projectBreakdown) {
            rows.append(ProviderInsightLine(
                id: "project-mix",
                label: "Project mix",
                value: projectMix,
                help: self.projectMixHelpText(projectBreakdown)))
        }

        if let usage = self.usageValue(snapshot?.primary) {
            rows.append(ProviderInsightLine(id: "usage", label: "Usage", value: usage))
        }

        if let spend = self.spendValue(snapshot?.providerCost) {
            rows.append(ProviderInsightLine(id: "spend", label: "Spend", value: spend))
        }
        if let forecast = self.forecastValue(spendForecast) {
            rows.append(ProviderInsightLine(
                id: "forecast",
                label: "Forecast",
                value: forecast,
                help: self.forecastHelpText(spendForecast)))
        }
        if let budget = self.budgetValue(spendForecast) {
            rows.append(ProviderInsightLine(
                id: "budget",
                label: "Budget",
                value: budget,
                help: self.budgetHelpText(spendForecast)))
        }
        if hasProjectAttribution, let projectBudget = self.projectBudgetValue(topProjectSpendForecast) {
            rows.append(ProviderInsightLine(
                id: "project-budget",
                label: "Prj budget",
                value: projectBudget,
                help: self.budgetHelpText(topProjectSpendForecast)))
        }

        if let today = self
            .tokenWindowValue(tokens: tokenSnapshot?.sessionTokens, cost: tokenSnapshot?.sessionCostUSD)
        {
            rows.append(ProviderInsightLine(id: "today", label: "Today", value: today))
        }

        if let last30 = self.tokenWindowValue(
            tokens: tokenSnapshot?.last30DaysTokens,
            cost: tokenSnapshot?.last30DaysCostUSD)
        {
            rows.append(ProviderInsightLine(id: "last30", label: "30d", value: last30))
        }

        if let reset = self.resetValue(snapshot?.primary) {
            rows.append(ProviderInsightLine(id: "reset", label: "Reset", value: reset))
        }

        guard let maxRows, maxRows > 0, rows.count > maxRows else {
            return rows
        }
        return Array(rows.prefix(maxRows))
    }

    static func coverageSummaryLabel(for provider: UsageProvider, store: UsageStore) -> String? {
        self.effectiveCoverage(for: provider, store: store).summaryLabel
    }

    static func effectiveCoverage(
        for provider: UsageProvider,
        store: UsageStore) -> ProviderUsageCoverage
    {
        self.effectiveCoverage(
            provider: provider,
            evidence: .init(
                metadataCoverage: store.metadata(for: provider).usageCoverage,
                topModel: store.ledgerTopModel(for: provider),
                topProject: store.ledgerTopProject(for: provider),
                modelBreakdown: store.ledgerModelBreakdown(for: provider),
                projectBreakdown: store.ledgerProjectBreakdown(for: provider),
                snapshot: store.snapshot(for: provider),
                tokenSnapshot: store.tokenSnapshot(for: provider)))
    }
}
