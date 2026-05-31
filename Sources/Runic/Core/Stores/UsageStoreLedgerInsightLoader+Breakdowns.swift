import Foundation
import RunicCore

extension UsageStoreLedgerInsightLoader {
    func ledgerUsageBreakdowns(
        todayEntries: [UsageLedgerEntry],
        budgetProjectNames: [String: String]) -> LedgerUsageBreakdowns
    {
        let modelSummaries = UsageLedgerAggregator.modelSummaries(entries: todayEntries)
        var topModelsByProvider: [UsageProvider: UsageLedgerModelSummary] = [:]
        for summary in modelSummaries where topModelsByProvider[summary.provider] == nil {
            topModelsByProvider[summary.provider] = summary
        }

        let projectSummaries = UsageLedgerAggregator.projectSummaries(entries: todayEntries)
            .map { self.resolvedProjectSummary($0, budgetProjectNames: budgetProjectNames) }
        var topProjectsByProvider: [UsageProvider: UsageLedgerProjectSummary] = [:]
        for summary in projectSummaries where topProjectsByProvider[summary.provider] == nil {
            topProjectsByProvider[summary.provider] = summary
        }

        let modelBreakdowns = modelSummaries.map {
            self.resolvedModelSummary($0, budgetProjectNames: budgetProjectNames)
        }
        var modelBreakdownsByProvider: [UsageProvider: [UsageLedgerModelSummary]] = [:]
        for summary in modelBreakdowns {
            modelBreakdownsByProvider[summary.provider, default: []].append(summary)
        }

        var projectBreakdownsByProvider: [UsageProvider: [UsageLedgerProjectSummary]] = [:]
        for summary in projectSummaries {
            projectBreakdownsByProvider[summary.provider, default: []].append(summary)
        }

        return LedgerUsageBreakdowns(
            topModelsByProvider: topModelsByProvider,
            topProjectsByProvider: topProjectsByProvider,
            modelBreakdownsByProvider: modelBreakdownsByProvider,
            projectBreakdownsByProvider: projectBreakdownsByProvider)
    }

    private func resolvedProjectSummary(
        _ summary: UsageLedgerProjectSummary,
        budgetProjectNames: [String: String]) -> UsageLedgerProjectSummary
    {
        let budgetName = summary.projectID.flatMap { budgetProjectNames[$0] }
        let identity = UsageLedgerProjectIdentityResolver.resolve(
            provider: summary.provider,
            projectID: summary.projectID,
            projectName: summary.projectName,
            budgetNameOverride: budgetName)
        return UsageLedgerProjectSummary(
            provider: summary.provider,
            projectKey: summary.projectKey ?? identity.key,
            projectID: identity.projectID ?? summary.projectID,
            projectName: identity.displayName ?? summary.projectName,
            projectNameConfidence: identity.confidence,
            projectNameSource: identity.source,
            projectNameProvenance: identity.provenance,
            entryCount: summary.entryCount,
            totals: summary.totals,
            modelsUsed: summary.modelsUsed)
    }

    private func resolvedModelSummary(
        _ summary: UsageLedgerModelSummary,
        budgetProjectNames: [String: String]) -> UsageLedgerModelSummary
    {
        let budgetName = summary.projectID.flatMap { budgetProjectNames[$0] }
        let identity = UsageLedgerProjectIdentityResolver.resolve(
            provider: summary.provider,
            projectID: summary.projectID,
            projectName: summary.projectName,
            budgetNameOverride: budgetName)
        return UsageLedgerModelSummary(
            provider: summary.provider,
            projectKey: summary.projectKey ?? identity.key,
            projectID: identity.projectID ?? summary.projectID,
            projectName: identity.displayName ?? summary.projectName,
            projectNameConfidence: identity.confidence,
            projectNameSource: identity.source,
            projectNameProvenance: identity.provenance,
            model: summary.model,
            entryCount: summary.entryCount,
            totals: summary.totals)
    }
}
