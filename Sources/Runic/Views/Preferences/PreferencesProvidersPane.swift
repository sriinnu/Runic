import AppKit
import RunicCore
import SwiftUI

private struct ProviderUsageStatus {
    let text: String
    let style: Style

    enum Style {
        case success
        case error
        case neutral
    }
}

private enum ProviderListMetrics {
    static let contentInset: CGFloat = 16
    static let rowSpacing: CGFloat = RunicSpacing.sm
    static let reorderHandleSize: CGFloat = 12
    static let reorderDotSize: CGFloat = 4
    static let reorderDotSpacing: CGFloat = 4
    static let rowInsets = EdgeInsets(
        top: RunicSpacing.xxxs,
        leading: contentInset,
        bottom: RunicSpacing.xxxs,
        trailing: contentInset)
    static let sectionEdgeInset: CGFloat = RunicSpacing.md
    static let dividerBottomInset: CGFloat = RunicSpacing.xxs
    static let checkboxSize: CGFloat = 20
    static let iconSize: CGFloat = 30
    static let dividerLeadingInset: CGFloat = contentInset
    static let dividerTrailingInset: CGFloat = contentInset
    static let providerCardPadding = EdgeInsets(
        top: RunicSpacing.sm,
        leading: RunicSpacing.sm,
        bottom: RunicSpacing.sm,
        trailing: RunicSpacing.sm)
    static let providerCardBackgroundOpacity: Double = 0.55
    static let providerCardBorderOpacity: Double = 0.25
    static let providerCardCornerRadius: CGFloat = RunicCornerRadius.md
    static let providerInsightsCardCornerRadius: CGFloat = RunicCornerRadius.sm
    static let providerInsightsGridItemMinWidth: CGFloat = 210
    static let providerInsightsChipCornerRadius: CGFloat = RunicCornerRadius.sm
    static let providerInsightsChipSpacing: CGFloat = RunicSpacing.xxs
    static let providerInsightsChipPadding: CGFloat = RunicSpacing.xs

    static let supplementalCardPadding = EdgeInsets(
        top: RunicSpacing.sm,
        leading: RunicSpacing.sm,
        bottom: RunicSpacing.sm,
        trailing: RunicSpacing.sm)
    static let supplementalCardBackgroundOpacity: Double = 0.28
    static let supplementalCardBorderOpacity: Double = 0.18
    static let fieldMaxWidth: CGFloat = 420
    static let errorCardPadding: CGFloat = RunicSpacing.sm
    static let statusBadgePaddingH: CGFloat = RunicSpacing.xs
    static let statusBadgePaddingV: CGFloat = RunicSpacing.xxxs
    static let errorCardCornerRadius: CGFloat = RunicCornerRadius.sm
    static let insightsCardPadding: CGFloat = RunicSpacing.xs
    static let insightsLineSpacing: CGFloat = RunicSpacing.xxxs
    static let insightsLabelWidth: CGFloat = 84
    static let sidebarStatusLabelWidth: CGFloat = 62
    static let sidebarCardCornerRadius: CGFloat = RunicCornerRadius.md
    static let sidebarCardPadding: CGFloat = RunicSpacing.md
    static let sidebarCardBackgroundOpacity: Double = 0.36
    static let sidebarCardBorderOpacity: Double = 0.22
    static let sidebarMicroCardCornerRadius: CGFloat = RunicCornerRadius.sm
    static let sidebarMicroCardBackgroundOpacity: Double = 0.52
    static let sidebarMicroCardBorderOpacity: Double = 0.2
    static let sidebarSectionSpacing: CGFloat = RunicSpacing.md
    static let sidebarContentGap: CGFloat = RunicSpacing.sm
}

private struct ProviderInsightLine: Identifiable, Equatable {
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
private enum ProviderInsightsComposer {
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
        let modelBreakdown = store.ledgerModelBreakdown(for: provider)
        let projectBreakdown = store.ledgerProjectBreakdown(for: provider)
        let coverage = store.metadata(for: provider).usageCoverage

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

        if let topModel = store.ledgerTopModel(for: provider), topModel.provider == provider, coverage.supportsModelBreakdown {
            rows.append(ProviderInsightLine(
                id: "top-model",
                label: "Top model",
                value: self.topModelValue(topModel)))
        } else if !coverage.supportsModelBreakdown, let windowModels = self.windowModelsValue(snapshot) {
            rows.append(ProviderInsightLine(
                id: "models",
                label: "Quota windows",
                value: windowModels,
                help: "Live quota windows grouped by provider response window IDs."))
        }

        if coverage.supportsProjectAttribution,
           let topProject = store.ledgerTopProject(for: provider),
           topProject.provider == provider
        {
            rows.append(ProviderInsightLine(
                id: "top-project",
                label: "Top project",
                value: self.topProjectValue(topProject),
                help: self.projectIdentityHelpText(topProject)))
        }

        if coverage.supportsModelBreakdown, let modelMix = self.modelMixValue(modelBreakdown) {
            rows.append(ProviderInsightLine(id: "model-mix", label: "Model mix", value: modelMix))
        }

        if coverage.supportsProjectAttribution, let projectMix = self.projectMixValue(projectBreakdown) {
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
        if coverage.supportsProjectAttribution, let projectBudget = self.projectBudgetValue(topProjectSpendForecast) {
            rows.append(ProviderInsightLine(
                id: "project-budget",
                label: "Prj budget",
                value: projectBudget,
                help: self.budgetHelpText(topProjectSpendForecast)))
        }

        if let today = self.tokenWindowValue(tokens: tokenSnapshot?.sessionTokens, cost: tokenSnapshot?.sessionCostUSD) {
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

    private static func actorValue(identity: ProviderIdentitySnapshot?) -> String? {
        let email = self.trimmed(identity?.accountEmail)
        let organization = self.trimmed(identity?.accountOrganization)
        if let email, let organization {
            if email.caseInsensitiveCompare(organization) == .orderedSame {
                return email
            }
            return "\(email) · \(organization)"
        }
        return email ?? organization
    }

    private static func planAuthValue(identity: ProviderIdentitySnapshot?) -> String? {
        guard let raw = self.trimmed(identity?.loginMethod) else { return nil }
        let cleaned = UsageFormatter.cleanPlanName(raw)
        return cleaned.isEmpty ? raw : cleaned
    }

    private static func topModelValue(_ summary: UsageLedgerModelSummary) -> String {
        let model = UsageFormatter.modelDisplayName(summary.model)
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        var parts = [model, "\(tokens) tok", "\(summary.entryCount) req"]
        if let context = UsageFormatter.modelContextLabel(for: summary.model) {
            parts.append(context)
        }
        if let cost = summary.totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: summary.totals.totalTokens) {
                parts.append("~\(per1K)")
            }
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: summary.entryCount) {
                parts.append("~\(perReq)")
            }
        }
        return parts.joined(separator: " · ")
    }

    private static func topProjectValue(_ summary: UsageLedgerProjectSummary) -> String {
        let project = self.shortProjectName(summary.displayProjectName)
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        var parts = [project, "\(tokens) tok", "\(summary.entryCount) req"]
        if let cost = summary.totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: summary.totals.totalTokens) {
                parts.append("~\(per1K)")
            }
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: summary.entryCount) {
                parts.append("~\(perReq)")
            }
        }
        return parts.joined(separator: " · ")
    }

    private static func modelMixValue(_ summaries: [UsageLedgerModelSummary]) -> String? {
        guard !summaries.isEmpty else { return nil }
        var tokensByModel: [String: Int] = [:]
        for summary in summaries {
            tokensByModel[summary.model, default: 0] += summary.totals.totalTokens
        }
        let ranked = tokensByModel.map { (model: $0.key, tokens: $0.value) }.sorted { lhs, rhs in
            if lhs.tokens == rhs.tokens {
                return UsageFormatter.modelDisplayName(lhs.model) < UsageFormatter.modelDisplayName(rhs.model)
            }
            return lhs.tokens > rhs.tokens
        }
        guard ranked.count > 1 else { return nil }
        let rendered = ranked.prefix(2).map { item in
            let name = UsageFormatter.modelDisplayName(item.model)
            let tokens = UsageFormatter.tokenCountString(item.tokens)
            return "\(name) \(tokens)"
        }
        var value = rendered.joined(separator: " · ")
        if ranked.count > 2 {
            value += " +\(ranked.count - 2) more"
        }
        return value
    }

    private static func projectMixValue(_ summaries: [UsageLedgerProjectSummary]) -> String? {
        guard summaries.count > 1 else { return nil }
        let ranked = summaries.sorted { lhs, rhs in
            if lhs.totals.totalTokens == rhs.totals.totalTokens {
                return lhs.displayProjectName < rhs.displayProjectName
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        let rendered = ranked.prefix(2).map { summary in
            let project = self.shortProjectName(summary.displayProjectName)
            let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
            return "\(project) \(tokens)"
        }
        var value = rendered.joined(separator: " · ")
        if ranked.count > 2 {
            value += " +\(ranked.count - 2) more"
        }
        return value
    }

    private static func shortProjectName(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLength = 44
        guard trimmed.count > maxLength else { return trimmed }
        let prefixLength = 28
        let suffixLength = 12
        guard trimmed.count > (prefixLength + suffixLength + 1) else {
            let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
            return "\(trimmed[..<index])…"
        }
        let prefixEnd = trimmed.index(trimmed.startIndex, offsetBy: prefixLength)
        let suffixStart = trimmed.index(trimmed.endIndex, offsetBy: -suffixLength)
        return "\(trimmed[..<prefixEnd])…\(trimmed[suffixStart...])"
    }

    private static func projectMixHelpText(_ summaries: [UsageLedgerProjectSummary]) -> String? {
        guard summaries.count > 1 else { return nil }
        let ranked = summaries.sorted { lhs, rhs in
            if lhs.totals.totalTokens == rhs.totals.totalTokens {
                return lhs.displayProjectName < rhs.displayProjectName
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        let details = ranked.prefix(3).map { summary in
            let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
            let project = summary.displayProjectName
            return "\(project): \(tokens) tok"
        }
        return details.isEmpty ? nil : details.joined(separator: "\n")
    }

    private static func projectIdentityHelpText(_ summary: UsageLedgerProjectSummary) -> String? {
        let displayName = summary.displayProjectName
        let source = summary.projectNameSource ?? .unknown
        let confidence = summary.projectNameConfidence ?? .none
        let shouldAnnotateSource = source != .projectName && source != .budgetOverride
        let shouldAnnotateConfidence = confidence != .high
        let isUnknown = displayName == "Unknown project"

        var details: [String] = []
        if shouldAnnotateSource {
            details.append("source: \(self.projectSourceLabel(source))")
        }
        if shouldAnnotateConfidence {
            details.append("confidence: \(self.projectConfidenceLabel(confidence))")
        }
        if isUnknown, let fingerprint = self.projectIDFingerprint(summary.projectID) {
            details.append("id: \(fingerprint)")
        }
        if let provenance = self.trimmed(summary.projectNameProvenance) {
            details.append("via: \(provenance)")
        }
        guard !details.isEmpty else { return nil }
        return ([displayName] + details).joined(separator: "\n")
    }

    private static func projectSourceLabel(_ source: UsageLedgerProjectNameSource) -> String {
        switch source {
        case .projectName: return "project name"
        case .projectID: return "project id"
        case .inferredFromPath: return "path-derived"
        case .inferredFromName: return "name-derived"
        case .budgetOverride: return "budget override"
        case .unknown: return "unknown"
        }
    }

    private static func projectConfidenceLabel(_ confidence: UsageLedgerProjectNameConfidence) -> String {
        switch confidence {
        case .high: return "high"
        case .medium: return "medium"
        case .low: return "low"
        case .none: return "none"
        }
    }

    private static func projectIDFingerprint(_ projectID: String?) -> String? {
        guard let projectID = projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !projectID.isEmpty else {
            return nil
        }

        var hash: UInt64 = 0xcbf29ce484222325
        for byte in projectID.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%08llx", hash)
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func usageValue(_ window: RateWindow?) -> String? {
        guard let window else { return nil }
        var parts = ["\(Int(window.usedPercent.rounded()))% used"]
        if let minutes = window.windowMinutes, minutes > 0 {
            parts.append("\(minutes)m window")
        }
        return parts.joined(separator: " · ")
    }

    private static func spendValue(_ providerCost: ProviderCostSnapshot?) -> String? {
        guard let providerCost else { return nil }
        let used = UsageFormatter.currencyString(providerCost.used, currencyCode: providerCost.currencyCode)
        var value: String
        if providerCost.limit > 0 {
            let limitText = UsageFormatter.currencyString(providerCost.limit, currencyCode: providerCost.currencyCode)
            value = "\(used) / \(limitText)"
        } else {
            value = used
        }
        if let period = self.trimmed(providerCost.period) {
            value += " · \(period)"
        }
        return value
    }

    private static func forecastValue(_ forecast: UsageLedgerSpendForecast?) -> String? {
        guard let forecast else { return nil }
        var parts = [UsageFormatter.usdString(forecast.projected30DayCostUSD), "/ 30d"]
        if forecast.averageDailyCostUSD.isFinite, forecast.averageDailyCostUSD >= 0 {
            parts.append("· \(UsageFormatter.usdString(forecast.averageDailyCostUSD))/day")
        }
        return parts.joined(separator: " ")
    }

    private static func budgetValue(_ forecast: UsageLedgerSpendForecast?) -> String? {
        guard let forecast, let limit = forecast.budgetLimitUSD, limit > 0 else { return nil }
        let limitText = UsageFormatter.usdString(limit)
        if let eta = forecast.budgetETAInDays {
            return "\(limitText) · \(self.budgetBreachETAText(days: eta))"
        }
        if forecast.budgetWillBreach {
            return "\(limitText) · Breach risk"
        }
        return "\(limitText) · On track"
    }

    private static func projectBudgetValue(_ forecast: UsageLedgerSpendForecast?) -> String? {
        guard let forecast, let limit = forecast.budgetLimitUSD, limit > 0 else { return nil }
        let name = self.shortProjectName(forecast.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Top project")
        if let eta = forecast.budgetETAInDays {
            return "\(name) · \(self.budgetBreachETAText(days: eta))"
        }
        if forecast.budgetWillBreach {
            return "\(name) · Breach risk"
        }
        return "\(name) · On track"
    }

    private static func forecastHelpText(_ forecast: UsageLedgerSpendForecast?) -> String? {
        guard let forecast else { return nil }
        var lines: [String] = []
        let observedLabel = forecast.observedDays == 1 ? "day" : "days"
        lines.append("Observed: \(forecast.observedDays) \(observedLabel)")
        lines.append("Projected 30d: \(UsageFormatter.usdString(forecast.projected30DayCostUSD))")
        if let p50 = forecast.projectedCostP50USD {
            lines.append("p50: \(UsageFormatter.usdString(p50))")
        }
        if let p80 = forecast.projectedCostP80USD {
            lines.append("p80: \(UsageFormatter.usdString(p80))")
        }
        if let p95 = forecast.projectedCostP95USD {
            lines.append("p95: \(UsageFormatter.usdString(p95))")
        }
        return lines.joined(separator: "\n")
    }

    private static func budgetHelpText(_ forecast: UsageLedgerSpendForecast?) -> String? {
        guard let forecast, let limit = forecast.budgetLimitUSD, limit > 0 else { return nil }
        var lines = [
            "Budget limit: \(UsageFormatter.usdString(limit))",
            "Projected 30d: \(UsageFormatter.usdString(forecast.projected30DayCostUSD))"
        ]
        if let eta = forecast.budgetETAInDays {
            lines.append(self.budgetBreachETAText(days: eta))
        } else if forecast.budgetWillBreach {
            lines.append("Breach risk at current pace")
        } else {
            lines.append("No breach at current pace")
        }
        return lines.joined(separator: "\n")
    }

    private static func budgetBreachETAText(days: Double) -> String {
        guard days.isFinite else { return "Breach ETA unavailable" }
        if days <= 0 { return "Breach now" }
        let now = Date()
        let etaDate = now.addingTimeInterval(days * 24 * 60 * 60)
        let countdown = UsageFormatter.resetCountdownDescription(from: etaDate, now: now)
        if countdown == "now" { return "Breach now" }
        return "Breach \(countdown)"
    }

    private static func resetValue(_ window: RateWindow?) -> String? {
        guard let window else { return nil }
        if let resetsAt = window.resetsAt {
            return UsageFormatter.resetCountdownDescription(from: resetsAt)
        }
        return self.trimmed(window.resetDescription)
    }

    private static func tokenWindowValue(tokens: Int?, cost: Double?) -> String? {
        var parts: [String] = []
        if let cost, cost.isFinite, cost >= 0 {
            parts.append(UsageFormatter.usdString(cost))
        }
        if let tokens, tokens >= 0 {
            parts.append("\(UsageFormatter.tokenCountString(tokens)) tok")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func reliabilityValue(_ reliability: UsageLedgerReliabilityScore?) -> String? {
        guard let reliability else { return nil }
        return "\(reliability.grade) · \(reliability.score)/100"
    }

    private static func reliabilityHelpText(_ reliability: UsageLedgerReliabilityScore?) -> String? {
        guard let reliability else { return nil }
        var lines = [reliability.summary]
        if let primary = self.trimmed(reliability.primarySignal), !primary.isEmpty {
            lines.append(primary)
        }
        for signal in reliability.signals {
            let trimmed = self.trimmed(signal) ?? ""
            guard !trimmed.isEmpty else { continue }
            if lines.contains(trimmed) { continue }
            lines.append(trimmed)
            if lines.count >= 5 { break }
        }
        return lines.joined(separator: "\n")
    }

    private static func costAnomalyValue(_ anomaly: UsageLedgerAnomalySummary?) -> String? {
        guard let spend = anomaly?.spendAnomaly else { return nil }
        let percent = Int((spend.percentIncrease * 100).rounded())
        return "\(spend.severity.label) spend +\(percent)%"
    }

    private static func costAnomalyHelpText(_ anomaly: UsageLedgerAnomalySummary?) -> String? {
        guard let anomaly, let spend = anomaly.spendAnomaly else { return nil }
        let percent = Int((spend.percentIncrease * 100).rounded())
        var lines = [
            "Spend today: \(UsageFormatter.usdString(spend.todayValue))",
            "Baseline (\(anomaly.baselineDays)d avg): \(UsageFormatter.usdString(spend.baselineAverage))",
            "Increase: +\(percent)%",
            "Severity: \(spend.severity.label)"
        ]
        if let explanation = anomaly.explanation {
            lines.append(contentsOf: explanation.details.prefix(2))
        }
        return lines.joined(separator: "\n")
    }

    private static func fetchHealthValue(_ attempts: [ProviderFetchAttempt]) -> String? {
        guard !attempts.isEmpty else { return nil }
        let rendered = attempts.prefix(3).map { attempt in
            let status: String
            if !attempt.wasAvailable {
                status = "unavailable"
            } else if self.trimmed(attempt.errorDescription) != nil {
                status = "failed"
            } else {
                status = "ok"
            }
            return "\(self.fetchStrategyLabel(attempt)) \(status)"
        }
        var value = rendered.joined(separator: " · ")
        if attempts.count > 3 {
            value += " +\(attempts.count - 3) more"
        }
        return value
    }

    private static func fetchErrorValue(_ attempts: [ProviderFetchAttempt]) -> String? {
        guard let latestError = attempts.reversed().compactMap({ self.trimmed($0.errorDescription) }).first else {
            return nil
        }
        return self.truncated(latestError, maxLength: 88)
    }

    private static func fetchAttemptsHelp(_ attempts: [ProviderFetchAttempt]) -> String? {
        guard !attempts.isEmpty else { return nil }
        return attempts.map { attempt in
            let status: String
            if !attempt.wasAvailable {
                status = "unavailable"
            } else if let error = self.trimmed(attempt.errorDescription) {
                return "\(attempt.strategyID) (\(self.fetchKindLabel(attempt.kind))) failed: \(error)"
            } else {
                status = "ok"
            }
            return "\(attempt.strategyID) (\(self.fetchKindLabel(attempt.kind))) \(status)"
        }.joined(separator: "\n")
    }

    private static func fetchStrategyLabel(_ attempt: ProviderFetchAttempt) -> String {
        let raw = attempt.strategyID
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let cleaned = UsageFormatter.cleanPlanName(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            return cleaned
        }
        return self.fetchKindLabel(attempt.kind)
    }

    private static func fetchKindLabel(_ kind: ProviderFetchKind) -> String {
        switch kind {
        case .cli: return "cli"
        case .web: return "web"
        case .oauth: return "oauth"
        case .apiToken: return "api"
        case .api: return "api"
        case .localProbe: return "local"
        case .webDashboard: return "web"
        }
    }

    private static func truncated(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return "\(text[..<index])…"
    }

    private static func windowModelsValue(_ snapshot: UsageSnapshot?) -> String? {
        guard let snapshot else { return nil }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap { $0 }
        guard !windows.isEmpty else { return nil }

        var seen: Set<String> = []
        var items: [String] = []
        for window in windows {
            guard let rawLabel = self.trimmed(window.label) else { continue }
            let normalized = rawLabel.lowercased()
            guard !seen.contains(normalized) else { continue }
            seen.insert(normalized)

            let label = UsageFormatter.modelDisplayName(rawLabel)
            let used = Int(window.usedPercent.rounded())
            items.append("\(label) \(used)%")
        }
        guard !items.isEmpty else { return nil }
        if items.count > 3 {
            let visible = items.prefix(3).joined(separator: " · ")
            return "\(visible) +\(items.count - 3) more"
        }
        return items.joined(separator: " · ")
    }
}

@MainActor
struct ProvidersPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var expandedErrors: Set<UsageProvider> = []
    @State private var settingsStatusTextByID: [String: String] = [:]
    @State private var settingsLastAppActiveRunAtByID: [String: Date] = [:]
    @State private var activeConfirmation: ProviderSettingsConfirmationState?
    @State private var sidebarSelection: UsageProvider?

    private var providers: [UsageProvider] { self.settings.orderedProviders() }

    var body: some View {
        Group {
            if self.settings.providersPaneSidebar {
                self.sidebarLayout
            } else {
                self.listLayout
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            self.runSettingsDidBecomeActiveHooks()
        }
        .alert(
            self.activeConfirmation?.title ?? "",
            isPresented: Binding(
                get: { self.activeConfirmation != nil },
                set: { isPresented in
                    if !isPresented { self.activeConfirmation = nil }
                }),
            actions: {
                if let active = self.activeConfirmation {
                    Button(active.confirmTitle) {
                        active.onConfirm()
                        self.activeConfirmation = nil
                    }
                    Button("Cancel", role: .cancel) { self.activeConfirmation = nil }
                }
            },
            message: {
                if let active = self.activeConfirmation {
                    Text(active.message)
                }
            })
    }

    // MARK: - List layout (default)

    private var listLayout: some View {
        PreferencesListPane(horizontalPadding: 0, verticalPadding: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: RunicSpacing.xs) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    Text("Provider History calendar is in Sidebar layout.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Sidebar") {
                        self.settings.providersPaneSidebar = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, ProviderListMetrics.contentInset)
                .padding(.vertical, RunicSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
                )
                .padding(.horizontal, ProviderListMetrics.contentInset)
                .padding(.top, RunicSpacing.xs)
                .padding(.bottom, RunicSpacing.xxs)

                ProviderListView(
                    providers: self.providers,
                    store: self.store,
                    isEnabled: { provider in self.binding(for: provider) },
                    subtitle: { provider in self.providerSubtitle(provider) },
                    usageStatus: { provider in self.providerUsageStatus(provider) },
                    sourceLabel: { provider in self.providerSourceLabel(provider) },
                    statusLabel: { provider in self.providerStatusLabel(provider) },
                    settingsToggles: { provider in self.extraSettingsToggles(for: provider) },
                    settingsFields: { provider in self.extraSettingsFields(for: provider) },
                    errorDisplay: { provider in self.providerErrorDisplay(provider) },
                    isErrorExpanded: { provider in self.expandedBinding(for: provider) },
                    onCopyError: { text in self.copyToPasteboard(text) },
                    moveProviders: { fromOffsets, toOffset in
                        self.settings.moveProvider(fromOffsets: fromOffsets, toOffset: toOffset)
                    })
            }
        }
    }

    // MARK: - Sidebar layout

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(selection: self.$sidebarSelection) {
                ForEach(self.providers, id: \.self) { provider in
                    ProviderSidebarRow(
                        provider: provider,
                        store: self.store,
                        isEnabled: self.binding(for: provider).wrappedValue)
                        .tag(provider)
                }
                .onMove { fromOffsets, toOffset in
                    self.settings.moveProvider(fromOffsets: fromOffsets, toOffset: toOffset)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160, idealWidth: 180)
            .onAppear {
                if self.sidebarSelection == nil {
                    self.sidebarSelection = self.providers.first
                }
            }
        } detail: {
            if let selected = self.sidebarSelection {
                ProviderSidebarDetailView(
                    provider: selected,
                    store: self.store,
                    isEnabled: self.binding(for: selected),
                    subtitle: self.providerSubtitle(selected),
                    usageStatus: self.providerUsageStatus(selected),
                    sourceLabel: self.providerSourceLabel(selected),
                    statusLabel: self.providerStatusLabel(selected),
                    settingsToggles: self.extraSettingsToggles(for: selected),
                    settingsFields: self.extraSettingsFields(for: selected),
                    errorDisplay: self.providerErrorDisplay(selected),
                    isErrorExpanded: self.expandedBinding(for: selected),
                    onCopyError: { text in self.copyToPasteboard(text) })
            } else {
                Text("Select a provider")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func binding(for provider: UsageProvider) -> Binding<Bool> {
        let meta = self.store.metadata(for: provider)
        return Binding(
            get: { self.settings.isProviderEnabled(provider: provider, metadata: meta) },
            set: { self.settings.setProviderEnabled(provider: provider, metadata: meta, enabled: $0) })
    }

    private func providerSubtitle(_ provider: UsageProvider) -> String {
        let meta = self.store.metadata(for: provider)
        let cliName = meta.cliName
        let coverageSuffix = meta.usageCoverage.summaryLabel.map { " • \($0)" } ?? ""
        let version = self.store.version(for: provider)
        var versionText = version ?? "not detected"
        if provider == .claude, let parenRange = versionText.range(of: "(") {
            versionText = versionText[..<parenRange.lowerBound].trimmingCharacters(in: .whitespaces)
        }

        if cliName == "codex" {
            return "\(versionText)\(coverageSuffix)"
        }

        // Cursor is web-based, no CLI version to detect
        if provider == .cursor || provider == .minimax {
            return "web"
        }
        let apiBackedProviders: Set<UsageProvider> = [
            .zai,
            .openrouter,
            .groq,
            .deepseek,
            .fireworks,
            .mistral,
            .perplexity,
            .kimi,
            .auggie,
            .together,
            .cohere,
            .xai,
            .cerebras,
            .sambanova,
            .azure,
            .bedrock,
        ]
        if apiBackedProviders.contains(provider) {
            return "api\(coverageSuffix)"
        }

        var detail = "\(cliName) \(versionText)"
        if provider == .antigravity {
            detail += " • experimental"
        }
        return "\(detail)\(coverageSuffix)"
    }

    private func providerUsageStatus(_ provider: UsageProvider) -> ProviderUsageStatus {
        if let snapshot = self.store.snapshot(for: provider) {
            let relative = snapshot.updatedAt.relativeDescription()
            return ProviderUsageStatus(text: "usage fetched \(relative)", style: .success)
        } else if self.store.isStale(provider: provider) {
            return ProviderUsageStatus(text: "last fetch failed", style: .error)
        } else {
            return ProviderUsageStatus(text: "usage not fetched yet", style: .neutral)
        }
    }

    private func providerSourceLabel(_ provider: UsageProvider) -> String {
        self.store.sourceLabel(for: provider)
    }

    private func providerStatusLabel(_ provider: UsageProvider) -> String {
        if let snapshot = self.store.snapshot(for: provider) {
            return snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened)
        }
        if self.store.isStale(provider: provider) {
            return "failed"
        }
        return "not yet"
    }

    private func providerErrorDisplay(_ provider: UsageProvider) -> ProviderErrorDisplay? {
        guard self.store.isStale(provider: provider), let raw = self.store.error(for: provider) else { return nil }
        return ProviderErrorDisplay(
            preview: self.truncated(raw, prefix: ""),
            full: raw)
    }

    private func extraSettingsToggles(for provider: UsageProvider) -> [ProviderSettingsToggleDescriptor] {
        guard let impl = ProviderCatalog.implementation(for: provider) else { return [] }
        let context = self.makeSettingsContext(provider: provider)
        return impl.settingsToggles(context: context)
            .filter { $0.isVisible?() ?? true }
    }

    private func extraSettingsFields(for provider: UsageProvider) -> [ProviderSettingsFieldDescriptor] {
        guard let impl = ProviderCatalog.implementation(for: provider) else { return [] }
        let context = self.makeSettingsContext(provider: provider)
        return impl.settingsFields(context: context)
            .filter { $0.isVisible?() ?? true }
    }

    private func makeSettingsContext(provider: UsageProvider) -> ProviderSettingsContext {
        ProviderSettingsContext(
            provider: provider,
            settings: self.settings,
            store: self.store,
            boolBinding: { keyPath in
                Binding(
                    get: { self.settings[keyPath: keyPath] },
                    set: { self.settings[keyPath: keyPath] = $0 })
            },
            stringBinding: { keyPath in
                Binding(
                    get: { self.settings[keyPath: keyPath] },
                    set: { self.settings[keyPath: keyPath] = $0 })
            },
            statusText: { id in
                self.settingsStatusTextByID[id]
            },
            setStatusText: { id, text in
                if let text {
                    self.settingsStatusTextByID[id] = text
                } else {
                    self.settingsStatusTextByID.removeValue(forKey: id)
                }
            },
            lastAppActiveRunAt: { id in
                self.settingsLastAppActiveRunAtByID[id]
            },
            setLastAppActiveRunAt: { id, date in
                if let date {
                    self.settingsLastAppActiveRunAtByID[id] = date
                } else {
                    self.settingsLastAppActiveRunAtByID.removeValue(forKey: id)
                }
            },
            requestConfirmation: { confirmation in
                self.activeConfirmation = ProviderSettingsConfirmationState(confirmation: confirmation)
            })
    }

    private func runSettingsDidBecomeActiveHooks() {
        for provider in UsageProvider.allCases {
            for toggle in self.extraSettingsToggles(for: provider) {
                guard let hook = toggle.onAppDidBecomeActive else { continue }
                Task { @MainActor in
                    await hook()
                }
            }
        }
    }

    private func truncated(_ text: String, prefix: String, maxLength: Int = 160) -> String {
        var message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.count > maxLength {
            let idx = message.index(message.startIndex, offsetBy: maxLength)
            message = "\(message[..<idx])…"
        }
        return prefix + message
    }

    private func expandedBinding(for provider: UsageProvider) -> Binding<Bool> {
        Binding(
            get: { self.expandedErrors.contains(provider) },
            set: { expanded in
                if expanded {
                    self.expandedErrors.insert(provider)
                } else {
                    self.expandedErrors.remove(provider)
                }
            })
    }

    private func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

@MainActor
private struct ProviderListView: View {
    let providers: [UsageProvider]
    @Bindable var store: UsageStore
    let isEnabled: (UsageProvider) -> Binding<Bool>
    let subtitle: (UsageProvider) -> String
    let usageStatus: (UsageProvider) -> ProviderUsageStatus
    let sourceLabel: (UsageProvider) -> String
    let statusLabel: (UsageProvider) -> String
    let settingsToggles: (UsageProvider) -> [ProviderSettingsToggleDescriptor]
    let settingsFields: (UsageProvider) -> [ProviderSettingsFieldDescriptor]
    let errorDisplay: (UsageProvider) -> ProviderErrorDisplay?
    let isErrorExpanded: (UsageProvider) -> Binding<Bool>
    let onCopyError: (String) -> Void
    let moveProviders: (IndexSet, Int) -> Void

    var body: some View {
        List {
            ForEach(self.providers, id: \.self) { provider in
                let fields = self.settingsFields(provider)
                let toggles = self.settingsToggles(provider)
                let isEnabled = self.isEnabled(provider).wrappedValue
                let isFirstProvider = provider == self.providers.first
                let isLastProvider = provider == self.providers.last
                let shouldShowDivider = provider != self.providers.last
                let showDividerOnProviderRow = shouldShowDivider &&
                    (!isEnabled || (fields.isEmpty && toggles.isEmpty))
                let providerAddsBottomPadding = isLastProvider && (!isEnabled || (fields.isEmpty && toggles.isEmpty))

                ProviderListProviderRowView(
                    provider: provider,
                    store: self.store,
                    isEnabled: self.isEnabled(provider),
                    subtitle: self.subtitle(provider),
                    usageStatus: self.usageStatus(provider),
                    sourceLabel: self.sourceLabel(provider),
                    statusLabel: self.statusLabel(provider),
                    errorDisplay: self.isEnabled(provider).wrappedValue ? self.errorDisplay(provider) : nil,
                    isErrorExpanded: self.isErrorExpanded(provider),
                    onCopyError: self.onCopyError)
                    .padding(.bottom, showDividerOnProviderRow ? ProviderListMetrics.dividerBottomInset : 0)
                    .listRowInsets(self.rowInsets(
                        withDivider: showDividerOnProviderRow,
                        addTopPadding: isFirstProvider,
                        addBottomPadding: providerAddsBottomPadding))
                    .listRowSeparator(.hidden)
                    .providerSectionDivider(isVisible: showDividerOnProviderRow)

                if isEnabled {
                    let lastFieldID = fields.last?.id
                    ForEach(fields) { field in
                        let isLastField = field.id == lastFieldID
                        let showDivider = shouldShowDivider && toggles.isEmpty && isLastField
                        let fieldAddsBottomPadding = isLastProvider && toggles.isEmpty && isLastField

                        ProviderListFieldRowView(provider: provider, field: field)
                            .id(self.rowID(provider: provider, suffix: field.id))
                            .padding(.bottom, showDivider ? ProviderListMetrics.dividerBottomInset : 0)
                            .listRowInsets(self.rowInsets(
                                withDivider: showDivider,
                                addTopPadding: false,
                                addBottomPadding: fieldAddsBottomPadding))
                            .listRowSeparator(.hidden)
                            .providerSectionDivider(isVisible: showDivider)
                    }
                    let lastToggleID = toggles.last?.id
                    ForEach(toggles) { toggle in
                        let isLastToggle = toggle.id == lastToggleID
                        let showDivider = shouldShowDivider && isLastToggle
                        let toggleAddsBottomPadding = isLastProvider && isLastToggle

                        ProviderListToggleRowView(provider: provider, toggle: toggle)
                            .id(self.rowID(provider: provider, suffix: toggle.id))
                            .padding(.bottom, showDivider ? ProviderListMetrics.dividerBottomInset : 0)
                            .listRowInsets(self.rowInsets(
                                withDivider: showDivider,
                                addTopPadding: false,
                                addBottomPadding: toggleAddsBottomPadding))
                            .listRowSeparator(.hidden)
                            .providerSectionDivider(isVisible: showDivider)
                    }
                }
            }
            .onMove { fromOffsets, toOffset in
                self.moveProviders(fromOffsets, toOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ProviderListScrollInsetFixer())
    }

    private func rowInsets(withDivider: Bool, addTopPadding: Bool, addBottomPadding: Bool) -> EdgeInsets {
        let base = ProviderListMetrics.rowInsets
        let topInset = addTopPadding ? ProviderListMetrics.sectionEdgeInset : base.top
        let bottomInset = addBottomPadding
            ? ProviderListMetrics.sectionEdgeInset
            : (withDivider ? ProviderListMetrics.dividerBottomInset : base.bottom)
        return EdgeInsets(
            top: topInset,
            leading: base.leading,
            bottom: bottomInset,
            trailing: base.trailing)
    }

    private func rowID(provider: UsageProvider, suffix: String) -> String {
        "\(provider.rawValue)-\(suffix)"
    }
}

@MainActor
private struct ProviderListBrandIcon: View {
    let provider: UsageProvider

    var body: some View {
        if let brand = ProviderBrandIcon.image(for: self.provider, size: ProviderListMetrics.iconSize) {
            Image(nsImage: brand)
                .resizable()
                .scaledToFit()
                .frame(width: ProviderListMetrics.iconSize, height: ProviderListMetrics.iconSize)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "circle.dotted")
                .font(.system(size: ProviderListMetrics.iconSize, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}

@MainActor
private struct ProviderInsightsView: View {
    let lines: [ProviderInsightLine]

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: ProviderListMetrics.providerInsightsGridItemMinWidth),
                    spacing: ProviderListMetrics.providerInsightsChipSpacing)
            ],
            alignment: .leading,
            spacing: ProviderListMetrics.providerInsightsChipSpacing)
        {
            ForEach(self.lines) { line in
                ProviderInsightChip(line: line)
            }
        }
        .padding(ProviderListMetrics.insightsCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: ProviderListMetrics.providerInsightsCardCornerRadius,
                style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.42))
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: ProviderListMetrics.providerInsightsCardCornerRadius,
                style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
        }
    }
}

private struct ProviderInsightChip: View {
    let line: ProviderInsightLine

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
            Text(line.label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.2)
                .foregroundStyle(.tertiary)
            Text(line.value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .help(line.help ?? "")
        }
        .padding(ProviderListMetrics.providerInsightsChipPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerInsightsChipCornerRadius, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerInsightsChipCornerRadius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
        )
        .help(line.help ?? "")
        .accessibilityLabel("\(line.label): \(line.value)")
        .accessibilityHint(line.help ?? "")
    }
}

@MainActor
private struct ProviderListProviderRowView: View {
    let provider: UsageProvider
    @Bindable var store: UsageStore
    @Binding var isEnabled: Bool
    let subtitle: String
    let usageStatus: ProviderUsageStatus
    let sourceLabel: String
    let statusLabel: String
    let errorDisplay: ProviderErrorDisplay?
    @Binding var isErrorExpanded: Bool
    let onCopyError: (String) -> Void
    @State private var isHovering = false
    @FocusState private var isToggleFocused: Bool

    var body: some View {
        let isRefreshing = self.store.refreshingProviders.contains(self.provider)
        let showReorderHandle = self.isHovering || self.isToggleFocused
        let metadata = self.store.metadata(for: self.provider)
        let insightLines = ProviderInsightsComposer.lines(for: self.provider, store: self.store, maxRows: 4)

        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Toggle("", isOn: self.$isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }
                .focused(self.$isToggleFocused)

            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    HStack(alignment: .top, spacing: RunicSpacing.sm) {
                        ProviderListBrandIcon(provider: self.provider)
                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                            Text(metadata.displayName)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(self.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: RunicSpacing.xs)
                    }

                    HStack(alignment: .center, spacing: RunicSpacing.xs) {
                        self.sourceBadge
                        Text(self.statusLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)

                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                            Text("Refreshing…")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            self.usageStatusBadge
                                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { self.isEnabled.toggle() }

                if !insightLines.isEmpty {
                    ProviderInsightsView(lines: insightLines)
                        .padding(.top, RunicSpacing.xxs)
                }

                if let errorDisplay {
                    ProviderErrorView(
                        title: "Last \(metadata.displayName) fetch failed:",
                        display: errorDisplay,
                        isExpanded: self.$isErrorExpanded,
                        onCopy: { self.onCopyError(errorDisplay.full) })
                        .padding(.top, RunicSpacing.xxs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProviderListMetrics.providerCardPadding)
        .background(self.cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
                .strokeBorder(self.cardBorderColor, lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            ProviderListReorderHandle(isVisible: showReorderHandle)
                .offset(
                    x: -(ProviderListMetrics.reorderHandleSize + RunicSpacing.xs),
                    y: RunicSpacing.sm)
        }
        .onHover { isHovering in
            self.isHovering = isHovering
        }
    }

    private var usageStatusBadge: some View {
        let (color, backgroundColor) = self.usageStatusColors

        return Text(self.usageStatus.text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, ProviderListMetrics.statusBadgePaddingH)
            .padding(.vertical, ProviderListMetrics.statusBadgePaddingV)
            .background(Capsule(style: .continuous).fill(backgroundColor))
            .foregroundStyle(color)
    }

    private var sourceBadge: some View {
        Text(self.sourceLabel)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxxs)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
            )
    }

    private var usageStatusColors: (Color, Color) {
        switch self.usageStatus.style {
        case .success:
            return (.green, Color.green.opacity(0.15))
        case .error:
            return (.red, Color.red.opacity(0.15))
        case .neutral:
            return (.secondary, Color(nsColor: .controlBackgroundColor))
        }
    }

    private var rowBackgroundColor: Color {
        if self.isHovering {
            return Color(nsColor: .controlBackgroundColor).opacity(0.72)
        } else if self.isEnabled {
            return Color(nsColor: .controlBackgroundColor).opacity(ProviderListMetrics.providerCardBackgroundOpacity)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.35)
    }

    private var cardBorderColor: Color {
        if self.isHovering {
            return Color.accentColor.opacity(0.35)
        }
        if self.isEnabled {
            return Color(nsColor: .separatorColor).opacity(ProviderListMetrics.providerCardBorderOpacity)
        }
        return Color(nsColor: .separatorColor).opacity(0.18)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
            .fill(self.rowBackgroundColor)
    }
}

@MainActor
private struct ProviderListReorderHandle: View {
    let isVisible: Bool

    var body: some View {
        VStack(spacing: ProviderListMetrics.reorderDotSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: ProviderListMetrics.reorderDotSpacing) {
                    Circle()
                        .frame(
                            width: ProviderListMetrics.reorderDotSize,
                            height: ProviderListMetrics.reorderDotSize)
                    Circle()
                        .frame(
                            width: ProviderListMetrics.reorderDotSize,
                            height: ProviderListMetrics.reorderDotSize)
                }
            }
        }
        .frame(width: ProviderListMetrics.reorderHandleSize, height: ProviderListMetrics.reorderHandleSize)
        .foregroundStyle(.tertiary)
        .opacity(self.isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: self.isVisible)
        .help("Drag to reorder")
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

@MainActor
private struct ProviderListSectionDividerView: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.5))
            .frame(height: 1)
            .padding(.leading, ProviderListMetrics.dividerLeadingInset)
            .padding(.trailing, ProviderListMetrics.dividerTrailingInset)
    }
}

extension View {
    @ViewBuilder
    fileprivate func providerSectionDivider(isVisible: Bool) -> some View {
        overlay(alignment: .bottom) {
            if isVisible {
                ProviderListSectionDividerView()
            }
        }
    }
}

@MainActor
private struct ProviderListToggleRowView: View {
    let provider: UsageProvider
    let toggle: ProviderSettingsToggleDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Toggle("", isOn: self.toggle.binding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    Text(self.toggle.title)
                        .font(.callout.weight(.semibold))
                    Text(self.toggle.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if self.toggle.binding.wrappedValue {
                    if let status = self.toggle.statusText?(), !status.isEmpty {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(RunicSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 1)
                            }
                    }

                    let actions = self.toggle.actions.filter { $0.isVisible?() ?? true }
                    if !actions.isEmpty {
                        HStack(spacing: RunicSpacing.xs) {
                            ForEach(actions) { action in
                                Button(action.title) {
                                    Task { @MainActor in
                                        await action.perform()
                                    }
                                }
                                .applyProviderSettingsButtonStyle(action.style)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .padding(.leading, ProviderListMetrics.iconSize + RunicSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProviderListMetrics.supplementalCardPadding)
        .background(self.supplementalCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
                .strokeBorder(self.supplementalCardBorderColor, lineWidth: 1)
        }
        .onChange(of: self.toggle.binding.wrappedValue) { _, enabled in
            guard let onChange = self.toggle.onChange else { return }
            Task { @MainActor in
                await onChange(enabled)
            }
        }
        .task(id: self.toggle.binding.wrappedValue) {
            guard self.toggle.binding.wrappedValue else { return }
            guard let onAppear = self.toggle.onAppearWhenEnabled else { return }
            await onAppear()
        }
    }

    private var supplementalCardBackground: some View {
        RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(ProviderListMetrics.supplementalCardBackgroundOpacity))
    }

    private var supplementalCardBorderColor: Color {
        Color(nsColor: .separatorColor).opacity(ProviderListMetrics.supplementalCardBorderOpacity)
    }
}

@MainActor
private struct ProviderListFieldRowView: View {
    let provider: UsageProvider
    let field: ProviderSettingsFieldDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Color.clear
                .frame(width: ProviderListMetrics.checkboxSize, height: ProviderListMetrics.checkboxSize)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    Text(self.field.title)
                        .font(.callout.weight(.semibold))
                    Text(self.field.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                switch self.field.kind {
                case .plain:
                    TextField(self.field.placeholder ?? "", text: self.field.binding)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .frame(maxWidth: ProviderListMetrics.fieldMaxWidth, alignment: .leading)
                case .secure:
                    SecureField(self.field.placeholder ?? "", text: self.field.binding)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .frame(maxWidth: ProviderListMetrics.fieldMaxWidth, alignment: .leading)
                }

                let actions = self.field.actions.filter { $0.isVisible?() ?? true }
                if !actions.isEmpty {
                    HStack(spacing: RunicSpacing.xs) {
                        ForEach(actions) { action in
                            Button(action.title) {
                                Task { @MainActor in
                                    await action.perform()
                                }
                            }
                            .applyProviderSettingsButtonStyle(action.style)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(.leading, ProviderListMetrics.iconSize + RunicSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProviderListMetrics.supplementalCardPadding)
        .background(self.supplementalCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
                .strokeBorder(self.supplementalCardBorderColor, lineWidth: 1)
        }
    }

    private var supplementalCardBackground: some View {
        RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(ProviderListMetrics.supplementalCardBackgroundOpacity))
    }

    private var supplementalCardBorderColor: Color {
        Color(nsColor: .separatorColor).opacity(0.18)
    }
}

extension View {
    @ViewBuilder
    fileprivate func applyProviderSettingsButtonStyle(_ style: ProviderSettingsActionDescriptor.Style) -> some View {
        switch style {
        case .bordered:
            self.buttonStyle(.bordered)
        case .link:
            self.buttonStyle(.link)
        }
    }
}

private struct ProviderErrorDisplay: Sendable {
    let preview: String
    let full: String
}

@MainActor
private struct ProviderListScrollInsetFixer: NSViewRepresentable {
    private final class HitTestIgnoringView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> NSView {
        HitTestIgnoringView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            guard let scrollView = Self.findScrollView(from: nsView) else { return }
            if scrollView.automaticallyAdjustsContentInsets {
                scrollView.automaticallyAdjustsContentInsets = false
            }
            let zeroInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            let currentContentInsets = scrollView.contentInsets
            if currentContentInsets.top != 0 || currentContentInsets.left != 0 ||
               currentContentInsets.bottom != 0 || currentContentInsets.right != 0 {
                scrollView.contentInsets = zeroInsets
            }
            let currentScrollerInsets = scrollView.scrollerInsets
            if currentScrollerInsets.top != 0 || currentScrollerInsets.left != 0 ||
               currentScrollerInsets.bottom != 0 || currentScrollerInsets.right != 0 {
                scrollView.scrollerInsets = zeroInsets
            }
        }
    }

    private static func findScrollView(from view: NSView) -> NSScrollView? {
        var current: NSView? = view
        while let candidate = current {
            if let scroll = candidate as? NSScrollView { return scroll }
            if let found = candidate.subviews.compactMap({ $0 as? NSScrollView }).first {
                return found
            }
            current = candidate.superview
        }
        return nil
    }
}

@MainActor
private struct ProviderErrorView: View {
    let title: String
    let display: ProviderErrorDisplay
    @Binding var isExpanded: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                Text(self.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    self.onCopy()
                } label: {
                    HStack(alignment: .center, spacing: RunicSpacing.xxs) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                        Text("Copy")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copy error to clipboard")
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
            }

            Text(self.display.preview)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(RunicSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .fill(Color.orange.opacity(0.08))
                )

            if self.display.preview != self.display.full {
                Button(self.isExpanded ? "Hide details" : "Show details") { self.isExpanded.toggle() }
                    .buttonStyle(.link)
                    .font(.callout)
            }

            if self.isExpanded {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(self.display.full)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(ProviderListMetrics.errorCardPadding)
                }
                .frame(maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(ProviderListMetrics.errorCardPadding)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.03))
        )
    }
}

@MainActor
private struct ProviderSettingsConfirmationState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void

    init(confirmation: ProviderSettingsConfirmation) {
        self.title = confirmation.title
        self.message = confirmation.message
        self.confirmTitle = confirmation.confirmTitle
        self.onConfirm = confirmation.onConfirm
    }
}

// MARK: - Sidebar layout views

@MainActor
private struct ProviderSidebarRow: View {
    let provider: UsageProvider
    @Bindable var store: UsageStore
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
            if let brand = ProviderBrandIcon.image(for: self.provider, size: 20) {
                Image(nsImage: brand)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(self.isEnabled ? .primary : .tertiary)
            } else {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20, height: 20)
            }
            Text(self.store.metadata(for: self.provider).displayName)
                .font(.body)
                .foregroundStyle(self.isEnabled ? .primary : .secondary)
                .lineLimit(1)
        }
        .opacity(self.isEnabled ? 1 : 0.6)
    }
}

private struct ProviderSidebarSectionCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        self.content
            .padding(ProviderListMetrics.sidebarCardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(
                    cornerRadius: ProviderListMetrics.sidebarCardCornerRadius,
                    style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(ProviderListMetrics.sidebarCardBackgroundOpacity))
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: ProviderListMetrics.sidebarCardCornerRadius,
                    style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(ProviderListMetrics.sidebarCardBorderOpacity), lineWidth: 1)
            )
    }
}

private struct ProviderSidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(self.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .tracking(0.25)
    }
}

@MainActor
private struct ProviderSidebarKeyValueRow: View {
    let label: String
    let value: String
    let helpText: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: RunicSpacing.xs) {
            Text("\(self.label):")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: ProviderListMetrics.sidebarStatusLabelWidth, alignment: .leading)
            if let helpText = self.helpText {
                Text(self.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .help(helpText)
            } else {
                Text(self.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

@MainActor
private struct ProviderSidebarMetricChip: View {
    let title: String
    let value: String
    let helpText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
            Text(self.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(self.value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.xs)
        .background(
            RoundedRectangle(
                cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(ProviderListMetrics.sidebarMicroCardBackgroundOpacity))
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                style: .continuous)
                .strokeBorder(Color(
                    nsColor: .separatorColor).opacity(ProviderListMetrics.sidebarMicroCardBorderOpacity), lineWidth: 1)
        )
        .help(self.helpText ?? "")
    }
}

private enum ProviderDetailSubview: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case history = "History"

    var id: String { self.rawValue }
}

private enum ProviderHistoryMetricMode: String, CaseIterable, Identifiable {
    case tokens = "Tokens"
    case cost = "Cost"
    case requests = "Requests"

    var id: String { self.rawValue }
}

private enum ProviderHistoryDayDetailMode: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case models = "Models"
    case projects = "Projects"

    var id: String { self.rawValue }
}

@MainActor
private struct ProviderHistoryCalendarDayCell: View {
    let dayNumber: Int
    let isInMonth: Bool
    let isSelected: Bool
    let hasActivity: Bool
    let intensity: Double
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                Text("\(self.dayNumber)")
                    .font(.caption.weight(self.isSelected ? .semibold : .regular))
                    .foregroundStyle(self.isInMonth ? .primary : .tertiary)
                Spacer(minLength: 0)
                if self.hasActivity {
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.35 + (0.45 * self.intensity)))
                        .frame(height: 4)
                } else {
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .separatorColor).opacity(self.isInMonth ? 0.14 : 0.08))
                        .frame(height: 2)
                }
            }
            .padding(RunicSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                    .fill(self.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                    .strokeBorder(self.borderColor, lineWidth: self.isSelected ? 1.5 : 1)
            )
            .opacity(self.isInMonth ? 1 : 0.52)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if self.isSelected {
            return Color.accentColor.opacity(0.18)
        }
        if self.hasActivity {
            return Color.accentColor.opacity(0.06 + (0.18 * self.intensity))
        }
        return Color(nsColor: .textBackgroundColor).opacity(self.isInMonth ? 0.55 : 0.32)
    }

    private var borderColor: Color {
        if self.isSelected {
            return Color.accentColor.opacity(0.75)
        }
        return Color(nsColor: .separatorColor).opacity(self.isInMonth ? 0.22 : 0.12)
    }
}

@MainActor
private struct ProviderSidebarDetailView: View {
    let provider: UsageProvider
    @Bindable var store: UsageStore
    @Binding var isEnabled: Bool
    let subtitle: String
    let usageStatus: ProviderUsageStatus
    let sourceLabel: String
    let statusLabel: String
    let settingsToggles: [ProviderSettingsToggleDescriptor]
    let settingsFields: [ProviderSettingsFieldDescriptor]
    let errorDisplay: ProviderErrorDisplay?
    @Binding var isErrorExpanded: Bool
    let onCopyError: (String) -> Void
    @State private var diagnosticsCopyStatus: String?
    @State private var selectedSubview: ProviderDetailSubview = .overview
    @State private var historyMetricMode: ProviderHistoryMetricMode = .tokens
    @State private var historyMonthStart: Date = Self.monthStart(for: Date())
    @State private var historySnapshot: ProviderHistoryMonthSnapshot?
    @State private var historySelectedDay: Date?
    @State private var historyDayDetailMode: ProviderHistoryDayDetailMode = .summary
    @State private var historyIsLoading = false
    @State private var historyError: String?

    var body: some View {
        let insightLines = ProviderInsightsComposer.lines(for: self.provider, store: self.store)
        let topModelLines = self.topModelLines
        let topProjectLines = self.topProjectLines

        ScrollView {
            VStack(alignment: .leading, spacing: ProviderListMetrics.sidebarSectionSpacing) {
                ProviderSidebarSectionCard {
                    VStack(alignment: .leading, spacing: RunicSpacing.md) {
                        HStack(alignment: .top, spacing: RunicSpacing.sm) {
                            ProviderListBrandIcon(provider: self.provider)
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                Text(self.store.metadata(for: self.provider).displayName)
                                    .font(.title2.weight(.semibold))
                                Text(self.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Enabled", isOn: self.$isEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        Divider()

                        Picker("View", selection: self.$selectedSubview) {
                            ForEach(ProviderDetailSubview.allCases) { view in
                                Text(view.rawValue).tag(view)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if self.selectedSubview == .overview {
                    ProviderSidebarSectionCard {
                        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                ProviderSidebarSectionHeader(title: "Overview")
                                ProviderSidebarKeyValueRow(label: "Source", value: self.sourceLabel, helpText: nil)
                                ProviderSidebarKeyValueRow(label: "Updated", value: self.statusLabel, helpText: nil)
                                if let runtimeMetrics = self.runtimeMetrics {
                                    ProviderSidebarKeyValueRow(
                                        label: "Runtime",
                                        value: runtimeMetrics.lineText,
                                        helpText: runtimeMetrics.hoverText)
                                }
                                self.statusBadge
                            }

                            if !self.quickMetrics.isEmpty {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(minimum: 120), spacing: RunicSpacing.xs),
                                        GridItem(.flexible(minimum: 120), spacing: RunicSpacing.xs),
                                    ],
                                    alignment: .leading,
                                    spacing: RunicSpacing.xs)
                                {
                                    ForEach(self.quickMetrics) { metric in
                                        ProviderSidebarMetricChip(
                                            title: metric.title,
                                            value: metric.value,
                                            helpText: metric.helpText)
                                    }
                                }
                            }

                            HStack(spacing: RunicSpacing.xs) {
                                Button("Copy diagnostics") {
                                    self.copyDiagnostics()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Copy fetch path, reliability, anomaly, and budget/forecast details.")

                                if let diagnosticsCopyStatus {
                                    Text(diagnosticsCopyStatus)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    if !insightLines.isEmpty {
                        ProviderSidebarSectionCard {
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                ProviderSidebarSectionHeader(title: "Insights")
                                ProviderInsightsView(lines: insightLines)
                            }
                        }
                    }

                    if !topModelLines.isEmpty || !topProjectLines.isEmpty {
                        ProviderSidebarSectionCard {
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                ProviderSidebarSectionHeader(title: "Activity leaders")
                                HStack(alignment: .top, spacing: RunicSpacing.md) {
                                    if !topModelLines.isEmpty {
                                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                            Text(self.modelSectionTitle)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            ForEach(Array(topModelLines.enumerated()), id: \.offset) { index, line in
                                                Text("\(index + 1). \(line)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    if !topProjectLines.isEmpty {
                                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                            Text("Projects")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                            ForEach(Array(topProjectLines.enumerated()), id: \.offset) { index, line in
                                                Text("\(index + 1). \(line)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    self.historyContent
                }

                if let errorDisplay, self.isEnabled {
                    ProviderErrorView(
                        title: "Last fetch failed:",
                        display: errorDisplay,
                        isExpanded: self.$isErrorExpanded,
                        onCopy: { self.onCopyError(errorDisplay.full) })
                }

                if self.isEnabled, !self.settingsFields.isEmpty {
                    ProviderSidebarSectionCard {
                        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                            ProviderSidebarSectionHeader(title: "Settings fields")
                            ForEach(self.settingsFields) { field in
                                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                    Text(field.title)
                                        .font(.body.weight(.medium))
                                    Text(field.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    switch field.kind {
                                    case .plain:
                                        TextField(field.placeholder ?? "", text: field.binding)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.callout)
                                    case .secure:
                                        SecureField(field.placeholder ?? "", text: field.binding)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.callout)
                                    }
                                    self.fieldActions(field.actions)
                                }
                            }
                        }
                    }
                }

                if self.isEnabled, !self.settingsToggles.isEmpty {
                    ProviderSidebarSectionCard {
                        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                            ProviderSidebarSectionHeader(title: "Settings toggles")
                            ForEach(self.settingsToggles) { toggle in
                                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                    Toggle(isOn: toggle.binding) {
                                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                            Text(toggle.title)
                                                .font(.body.weight(.medium))
                                            Text(toggle.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)

                                    if toggle.binding.wrappedValue {
                                        if let status = toggle.statusText?(), !status.isEmpty {
                                            Text(status)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(RunicSpacing.xs)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(
                                                    RoundedRectangle(
                                                        cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                                                        style: .continuous)
                                                        .fill(Color(
                                                            nsColor: .controlBackgroundColor).opacity(
                                                                ProviderListMetrics.sidebarMicroCardBackgroundOpacity)))
                                        }
                                        self.toggleActions(toggle.actions)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(RunicSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: self.historyTaskID) {
            guard self.selectedSubview == .history else { return }
            await self.loadHistoryMonth()
        }
        .onChange(of: self.provider) { _, _ in
            self.selectedSubview = .overview
            self.historyMetricMode = .tokens
            self.historyMonthStart = Self.monthStart(for: Date())
            self.historySnapshot = nil
            self.historySelectedDay = nil
            self.historyDayDetailMode = .summary
            self.historyError = nil
            self.historyIsLoading = false
        }
    }

    private var statusBadge: some View {
        let (color, bg) = self.statusColors
        return Text(self.usageStatus.text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxs)
            .background(bg)
            .foregroundStyle(color)
            .clipShape(.capsule)
    }

    private var statusColors: (Color, Color) {
        switch self.usageStatus.style {
        case .success: return (.green, Color.green.opacity(0.15))
        case .error: return (.red, Color.red.opacity(0.15))
        case .neutral: return (.secondary, Color(nsColor: .controlBackgroundColor))
        }
    }

    private var historyTaskID: String {
        let monthKey = Int(self.historyMonthStart.timeIntervalSince1970)
        return "\(self.provider.rawValue)-\(self.selectedSubview.rawValue)-\(monthKey)"
    }

    private var historyContent: some View {
        ProviderSidebarSectionCard {
            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                HStack(alignment: .center, spacing: RunicSpacing.xs) {
                    Button {
                        self.shiftHistoryMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Previous month")

                    Text(self.historyMonthTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 110, alignment: .leading)

                    Button {
                        self.shiftHistoryMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!self.canShiftHistoryForward)
                    .help("Next month")

                    Spacer()

                    Picker("Metric", selection: self.$historyMetricMode) {
                        ForEach(ProviderHistoryMetricMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                if self.historyIsLoading, self.historySnapshot == nil {
                    HStack(spacing: RunicSpacing.xs) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading history…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, RunicSpacing.xs)
                } else if let snapshot = self.historySnapshot {
                    if !snapshot.isSupported {
                        Text(snapshot.note ?? "History is not available for this provider yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, RunicSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                                    style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(ProviderListMetrics.sidebarCardBackgroundOpacity))
                            )
                    } else {
                        if let note = snapshot.note, !note.isEmpty {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        self.historyCalendarGrid
                        self.historyDayDetailCard
                    }
                } else {
                    Text("History is empty for this period.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, RunicSpacing.xs)
                }

                if let historyError = self.historyError {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        Text("History load failed")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        Text(historyError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Button("Retry") {
                            Task { await self.loadHistoryMonth(forceRefresh: true) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(RunicSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(
                            cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                            style: .continuous)
                            .fill(Color.red.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                            style: .continuous)
                            .strokeBorder(Color.red.opacity(0.28), lineWidth: 1)
                    )
                }

                Text("Local aggregated history only. Prompts, cookies, API keys, and raw payloads are never shown here.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var historyCalendarGrid: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            let weekdays = self.weekdaySymbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: RunicSpacing.xxs), count: 7), spacing: RunicSpacing.xxs) {
                ForEach(weekdays, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: RunicSpacing.xxs), count: 7), spacing: RunicSpacing.xxs) {
                ForEach(self.calendarDaysForMonth, id: \.self) { day in
                    let inMonth = self.historyCalendar.isDate(day, equalTo: self.historyMonthStart, toGranularity: .month)
                    let normalizedDay = self.historyCalendar.startOfDay(for: day)
                    let summary = self.historySummaryByDay[normalizedDay]
                    let dayNumber = self.historyCalendar.component(.day, from: day)
                    let isSelected = self.historySelectedDay.map { self.historyCalendar.isDate($0, inSameDayAs: day) } ?? false
                    ProviderHistoryCalendarDayCell(
                        dayNumber: dayNumber,
                        isInMonth: inMonth,
                        isSelected: isSelected,
                        hasActivity: summary != nil,
                        intensity: self.historyIntensity(for: summary),
                        action: { self.historySelectedDay = normalizedDay })
                    .help(self.historyDayHelp(for: day, summary: summary))
                }
            }
        }
    }

    private var historyDayDetailCard: some View {
        ProviderSidebarSectionCard {
            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: RunicSpacing.xs) {
                    Text("Day details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.25)
                    Spacer()
                    if self.selectedHistoryDaySummary != nil {
                        Picker("History detail", selection: self.$historyDayDetailMode) {
                            ForEach(ProviderHistoryDayDetailMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.mini)
                        .frame(maxWidth: 240)
                    }
                }

                if let selected = self.selectedHistoryDaySummary {
                    Text(selected.dayStart.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if self.historyDayDetailMode == .summary {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 90), spacing: RunicSpacing.xs),
                                GridItem(.flexible(minimum: 90), spacing: RunicSpacing.xs),
                                GridItem(.flexible(minimum: 90), spacing: RunicSpacing.xs),
                            ],
                            alignment: .leading,
                            spacing: RunicSpacing.xs)
                        {
                            ProviderSidebarMetricChip(
                                title: "Requests",
                                value: self.decimalString(selected.requestCount),
                                helpText: "Count of requests recorded in local ledger logs.")
                            ProviderSidebarMetricChip(
                                title: "Tokens",
                                value: UsageFormatter.tokenSummaryString(selected.totals),
                                helpText: "Input, output, and cache token composition.")
                            if let spend = selected.totals.costUSD {
                                ProviderSidebarMetricChip(
                                    title: "Spend",
                                    value: UsageFormatter.usdString(spend),
                                    helpText: "Estimated day spend from ledger pricing.")
                            }
                        }

                        if self.supportsModelBreakdown, let topModel = selected.topModel {
                            Text("Top model: \(self.usageLine(title: UsageFormatter.modelDisplayName(topModel.model), totals: topModel.totals, requests: topModel.entryCount, model: topModel.model))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        if self.supportsProjectAttribution, let topProject = selected.topProject {
                            let project = self.projectDisplay(topProject)
                            Text("Top project: \(project.title)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .help(project.helpText ?? "")
                        }
                    }

                    if self.historyDayDetailMode == .models {
                        if self.supportsModelBreakdown, !selected.modelSummaries.isEmpty {
                            Text("Models used")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            ForEach(Array(selected.modelSummaries.prefix(12).enumerated()), id: \.offset) { _, summary in
                                Text("• \(self.historyModelLine(summary))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                                    .help(self.historyModelLine(summary))
                            }
                        } else if self.supportsModelBreakdown, !selected.modelsUsed.isEmpty {
                            Text("Models used: \(self.renderedModelsList(selected.modelsUsed).joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .textSelection(.enabled)
                        } else {
                            Text(self.supportsModelBreakdown ? "No models recorded for this day." : "Model attribution is not available for this provider.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if self.historyDayDetailMode == .projects {
                        if self.supportsProjectAttribution, !selected.projectSummaries.isEmpty {
                            Text("Top projects")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            ForEach(Array(selected.projectSummaries.prefix(12).enumerated()), id: \.offset) { _, summary in
                                let project = self.projectDisplay(summary)
                                Text("• \(self.historyProjectLine(summary))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                                    .help(project.helpText ?? "")
                            }
                        } else {
                            Text(self.supportsProjectAttribution ? "No projects recorded for this day." : "Project attribution is not available for this provider.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Text(self.historySelectedDay?.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()) ?? "No day selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("No recorded activity for this day.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var historyMonthTitle: String {
        self.historyMonthStart.formatted(.dateTime.month(.wide).year())
    }

    private var canShiftHistoryForward: Bool {
        self.historyMonthStart < Self.monthStart(for: Date())
    }

    private var historyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    private var weekdaySymbols: [String] {
        let symbols = self.historyCalendar.veryShortStandaloneWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let start = max(0, min(symbols.count - 1, self.historyCalendar.firstWeekday - 1))
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var calendarDaysForMonth: [Date] {
        guard let monthInterval = self.historyCalendar.dateInterval(of: .month, for: self.historyMonthStart),
              let firstWeek = self.historyCalendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastDayOfMonth = self.historyCalendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeek = self.historyCalendar.dateInterval(of: .weekOfMonth, for: lastDayOfMonth)
        else {
            return []
        }

        var days: [Date] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            days.append(cursor)
            guard let next = self.historyCalendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    private var historySummaryByDay: [Date: ProviderHistoryDaySnapshot] {
        guard let snapshot = self.historySnapshot else { return [:] }
        var map: [Date: ProviderHistoryDaySnapshot] = [:]
        for day in snapshot.days {
            map[self.historyCalendar.startOfDay(for: day.dayStart)] = day
        }
        return map
    }

    private var selectedHistoryDaySummary: ProviderHistoryDaySnapshot? {
        guard let snapshot = self.historySnapshot else { return nil }
        guard let selectedDay = self.historySelectedDay else { return snapshot.days.last }
        return snapshot.days.first { self.historyCalendar.isDate($0.dayStart, inSameDayAs: selectedDay) }
    }

    private var historyMaxMetricValue: Double {
        guard let snapshot = self.historySnapshot, !snapshot.days.isEmpty else { return 0 }
        return snapshot.days.reduce(0) { max($0, self.historyMetricValue(for: $1)) }
    }

    private func historyMetricValue(for day: ProviderHistoryDaySnapshot) -> Double {
        switch self.historyMetricMode {
        case .tokens:
            return Double(day.totals.totalTokens)
        case .cost:
            return max(0, day.totals.costUSD ?? 0)
        case .requests:
            return Double(day.requestCount)
        }
    }

    private func historyIntensity(for day: ProviderHistoryDaySnapshot?) -> Double {
        guard let day else { return 0 }
        let maxValue = self.historyMaxMetricValue
        guard maxValue > 0 else { return 0.15 }
        return min(1, max(0.15, self.historyMetricValue(for: day) / maxValue))
    }

    private func historyDayHelp(for day: Date, summary: ProviderHistoryDaySnapshot?) -> String {
        var lines: [String] = [day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())]
        guard let summary else {
            lines.append("No recorded activity")
            return lines.joined(separator: "\n")
        }
        lines.append("Requests: \(self.decimalString(summary.requestCount))")
        lines.append("Tokens: \(UsageFormatter.tokenSummaryString(summary.totals))")
        if let spend = summary.totals.costUSD {
            lines.append("Spend: \(UsageFormatter.usdString(spend))")
        }
        if self.supportsModelBreakdown, let topModel = summary.topModel {
            var modelLine = "Top model: \(UsageFormatter.modelDisplayName(topModel.model))"
            if let context = UsageFormatter.modelContextLabel(for: topModel.model) {
                modelLine += " · \(context)"
            }
            lines.append(modelLine)
        }
        if self.supportsModelBreakdown, !summary.modelSummaries.isEmpty {
            let modelCount = min(3, summary.modelSummaries.count)
            for summary in summary.modelSummaries.prefix(modelCount) {
                var line = "Model: \(UsageFormatter.modelDisplayName(summary.model)) · \(UsageFormatter.tokenCountString(summary.totals.totalTokens)) tok"
                if let context = UsageFormatter.modelContextLabel(for: summary.model) {
                    line += " · \(context)"
                }
                lines.append(line)
            }
        }
        if self.supportsProjectAttribution, let topProject = summary.topProject {
            var projectLine = "Top project: \(self.projectDisplay(topProject).title)"
            if let cost = topProject.totals.costUSD {
                projectLine += " · \(UsageFormatter.usdString(cost))"
            }
            lines.append(projectLine)
        }
        return lines.joined(separator: "\n")
    }

    private func renderedModelsList(_ modelsUsed: [String]) -> [String] {
        var seen: Set<String> = []
        var rendered: [String] = []
        for model in modelsUsed {
            let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            var text = UsageFormatter.modelDisplayName(trimmed)
            if let context = UsageFormatter.modelContextLabel(for: trimmed) {
                text += " \(context)"
            }
            rendered.append(text)
        }
        return rendered
    }

    private func historyModelLine(_ summary: UsageLedgerModelSummary) -> String {
        self.usageLine(
            title: UsageFormatter.modelDisplayName(summary.model),
            totals: summary.totals,
            requests: summary.entryCount,
            model: summary.model)
    }

    private func historyProjectLine(_ summary: UsageLedgerProjectSummary) -> String {
        let project = self.projectDisplay(summary)
        return self.usageLine(
            title: project.title,
            totals: summary.totals,
            requests: summary.entryCount)
    }

    private func shiftHistoryMonth(by delta: Int) {
        guard delta != 0 else { return }
        guard let shifted = self.historyCalendar.date(byAdding: .month, value: delta, to: self.historyMonthStart) else {
            return
        }
        let candidate = Self.monthStart(for: shifted)
        if delta > 0, candidate > Self.monthStart(for: Date()) {
            return
        }
        self.historyMonthStart = candidate
        self.historySnapshot = nil
        self.historySelectedDay = nil
        self.historyError = nil
    }

    private static func monthStart(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func loadHistoryMonth(forceRefresh: Bool = false) async {
        guard !self.historyIsLoading else { return }
        self.historyIsLoading = true
        self.historyError = nil
        let snapshot = await self.store.providerHistoryMonth(
            provider: self.provider,
            monthStart: self.historyMonthStart,
            forceRefresh: forceRefresh)
        self.historySnapshot = snapshot
        self.historyError = snapshot.error
        self.historyIsLoading = false
        self.selectDefaultHistoryDay(from: snapshot)
    }

    private func selectDefaultHistoryDay(from snapshot: ProviderHistoryMonthSnapshot) {
        guard !snapshot.days.isEmpty else {
            self.historySelectedDay = self.historyCalendar.startOfDay(for: self.historyMonthStart)
            return
        }
        if let selected = self.historySelectedDay,
           snapshot.days.contains(where: { self.historyCalendar.isDate($0.dayStart, inSameDayAs: selected) })
        {
            self.historySelectedDay = self.historyCalendar.startOfDay(for: selected)
            return
        }
        self.historySelectedDay = snapshot.days.map(\.dayStart).max()
    }

    private struct ProjectDisplay {
        let title: String
        let helpText: String?
    }

    private func projectDisplay(_ summary: UsageLedgerProjectSummary) -> ProjectDisplay {
        let displayName = summary.displayProjectName
        let source = summary.projectNameSource ?? .unknown
        let confidence = summary.projectNameConfidence ?? .none
        let shouldAnnotateSource = source != .projectName && source != .budgetOverride
        let shouldAnnotateConfidence = confidence != .high
        let isUnknown = displayName == "Unknown project"

        var details: [String] = []
        if shouldAnnotateSource {
            details.append("source: \(self.projectSourceLabel(source))")
        }
        if shouldAnnotateConfidence {
            details.append("confidence: \(self.projectConfidenceLabel(confidence))")
        }
        if isUnknown, let fingerprint = self.projectIDFingerprint(summary.projectID) {
            details.append("id: \(fingerprint)")
        }
        if let provenance = self.trimmed(summary.projectNameProvenance) {
            details.append("via: \(provenance)")
        }
        return ProjectDisplay(
            title: displayName,
            helpText: details.isEmpty ? nil : details.joined(separator: "\n"))
    }

    private func projectSourceLabel(_ source: UsageLedgerProjectNameSource) -> String {
        switch source {
        case .projectName: return "project name"
        case .projectID: return "project id"
        case .inferredFromPath: return "path-derived"
        case .inferredFromName: return "name-derived"
        case .budgetOverride: return "budget override"
        case .unknown: return "unknown"
        }
    }

    private func projectConfidenceLabel(_ confidence: UsageLedgerProjectNameConfidence) -> String {
        switch confidence {
        case .high: return "high"
        case .medium: return "medium"
        case .low: return "low"
        case .none: return "none"
        }
    }

    private func projectIDFingerprint(_ projectID: String?) -> String? {
        guard let projectID = projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !projectID.isEmpty else {
            return nil
        }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in projectID.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%08llx", hash)
    }

    @ViewBuilder
    private func fieldActions(_ actions: [ProviderSettingsActionDescriptor]) -> some View {
        let visible = actions.filter { $0.isVisible?() ?? true }
        if !visible.isEmpty {
            HStack(spacing: RunicSpacing.xs) {
                ForEach(visible) { action in
                    Button(action.title) {
                        Task { @MainActor in await action.perform() }
                    }
                    .applyProviderSettingsButtonStyle(action.style)
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private func toggleActions(_ actions: [ProviderSettingsActionDescriptor]) -> some View {
        let visible = actions.filter { $0.isVisible?() ?? true }
        if !visible.isEmpty {
            HStack(spacing: RunicSpacing.xs) {
                ForEach(visible) { action in
                    Button(action.title) {
                        Task { @MainActor in await action.perform() }
                    }
                    .applyProviderSettingsButtonStyle(action.style)
                    .controlSize(.small)
                }
            }
        }
    }

    private struct QuickMetricItem: Identifiable {
        let id: String
        let title: String
        let value: String
        let helpText: String?
    }

    private var quickMetrics: [QuickMetricItem] {
        var items: [QuickMetricItem] = []
        let snapshot = self.store.snapshot(for: self.provider)
        let tokenSnapshot = self.store.tokenSnapshot(for: self.provider)
        let metadata = self.store.metadata(for: self.provider)
        let hasModelBreakdown = metadata.usageCoverage.supportsModelBreakdown
        let hasProjectAttribution = metadata.usageCoverage.supportsProjectAttribution

        if let today = self.tokenWindowValue(tokens: tokenSnapshot?.sessionTokens, cost: tokenSnapshot?.sessionCostUSD) {
            items.append(QuickMetricItem(id: "today", title: "Today", value: today, helpText: "Session cost and tokens."))
        }
        if let last30 = self.tokenWindowValue(
            tokens: tokenSnapshot?.last30DaysTokens,
            cost: tokenSnapshot?.last30DaysCostUSD)
        {
            items.append(QuickMetricItem(id: "30d", title: "30d", value: last30, helpText: "Last 30 days cost and tokens."))
        }
        if let spend = self.providerSpendValue(snapshot?.providerCost) {
            items.append(QuickMetricItem(id: "spend", title: "Spend", value: spend, helpText: "Provider billing usage."))
        }
        if hasModelBreakdown, let topModel = self.store.ledgerTopModel(for: self.provider) {
            let modelName = UsageFormatter.modelDisplayName(topModel.model)
            var value = self.modelLineValue(
                title: modelName,
                totals: topModel.totals,
                requests: topModel.entryCount)
            if let context = UsageFormatter.modelContextLabel(for: topModel.model) {
                value += " · \(context)"
            }
            items.append(QuickMetricItem(
                id: "top-model",
                title: "Top model",
                value: value,
                helpText: "Highest token usage model in the active insights window."))
        } else if !hasModelBreakdown, let windowModel = self.topWindowModel {
            let modelName = UsageFormatter.modelDisplayName(windowModel.label)
            let used = Int(windowModel.window.usedPercent.rounded())
            items.append(QuickMetricItem(
                id: "top-model-window",
                title: hasModelBreakdown ? "Top model" : "Top window",
                value: "\(modelName) · \(used)% used",
                helpText: hasModelBreakdown ?
                    "Most constrained model/category from live quota windows."
                    : "Top quota window from live fetch response."))
        }
        if hasProjectAttribution, let topProject = self.store.ledgerTopProject(for: self.provider) {
            let project = self.projectDisplay(topProject)
            let value = self.topProjectSummaryValue(topProject)
            items.append(QuickMetricItem(
                id: "top-project",
                title: "Top project",
                value: "\(project.title) · \(value)",
                helpText: "Highest token usage project in the active insights window."))
        }
        if let coverage = metadata.usageCoverage.summaryLabel {
            let value = coverage.replacingOccurrences(of: "usage: ", with: "")
            items.append(QuickMetricItem(
                id: "coverage",
                title: "Data",
                value: value,
                helpText: "Provider coverage for model-level usage, token metrics, and project attribution."))
        }
        return items
    }

    private func tokenWindowValue(tokens: Int?, cost: Double?) -> String? {
        var parts: [String] = []
        if let cost, cost.isFinite, cost >= 0 {
            parts.append(UsageFormatter.usdString(cost))
        }
        if let tokens, tokens >= 0 {
            parts.append("\(UsageFormatter.tokenCountString(tokens)) tok")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private func providerSpendValue(_ providerCost: ProviderCostSnapshot?) -> String? {
        guard let providerCost else { return nil }
        let used = UsageFormatter.currencyString(providerCost.used, currencyCode: providerCost.currencyCode)
        if providerCost.limit > 0 {
            let limitText = UsageFormatter.currencyString(providerCost.limit, currencyCode: providerCost.currencyCode)
            return "\(used) / \(limitText)"
        }
        return used
    }

    private var topModelLines: [String] {
        let metadata = self.store.metadata(for: self.provider)
        let coverage = metadata.usageCoverage
        let ranked = self.store.ledgerModelBreakdown(for: self.provider).sorted { lhs, rhs in
            if lhs.totals.totalTokens == rhs.totals.totalTokens {
                return UsageFormatter.modelDisplayName(lhs.model) < UsageFormatter.modelDisplayName(rhs.model)
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        if !ranked.isEmpty {
            guard coverage.supportsModelBreakdown else {
                return []
            }
            return ranked.prefix(3).map { summary in
                let name = UsageFormatter.modelDisplayName(summary.model)
                return self.usageLine(
                    title: name,
                    totals: summary.totals,
                    requests: summary.entryCount,
                    model: summary.model)
            }
        }
        guard !coverage.supportsModelBreakdown else {
            return []
        }
        return self.windowModelLines
    }

    private var modelSectionTitle: String {
        self.store.metadata(for: self.provider).usageCoverage.supportsModelBreakdown ? "Models" : "Quota windows"
    }

    private var supportsModelBreakdown: Bool {
        self.store.metadata(for: self.provider).usageCoverage.supportsModelBreakdown
    }

    private var supportsProjectAttribution: Bool {
        self.store.metadata(for: self.provider).usageCoverage.supportsProjectAttribution
    }

    private var topProjectLines: [String] {
        guard self.supportsProjectAttribution else {
            return []
        }
        let ranked = self.store.ledgerProjectBreakdown(for: self.provider).sorted { lhs, rhs in
            if lhs.totals.totalTokens == rhs.totals.totalTokens {
                return lhs.displayProjectName < rhs.displayProjectName
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        return ranked.prefix(3).map { summary in
            let project = summary.displayProjectName
            return self.usageLine(title: project, totals: summary.totals, requests: summary.entryCount)
        }
    }

    private func usageLine(
        title: String,
        totals: UsageLedgerTotals,
        requests: Int,
        model: String? = nil) -> String
    {
        let tokens = UsageFormatter.tokenSummaryString(totals)
        var parts = ["\(title)", "\(tokens)", "\(requests) req"]
        if let cost = totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: totals.totalTokens) {
                parts.append("~\(per1K)")
            }
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: requests) {
                parts.append("~\(perReq)")
            }
        }
        if let model, let context = UsageFormatter.modelContextLabel(for: model) {
            parts.append(context)
        }
        return parts.joined(separator: " · ")
    }

    private func topProjectSummaryValue(_ summary: UsageLedgerProjectSummary) -> String {
        var parts: [String] = []
        parts.append(UsageFormatter.tokenSummaryString(summary.totals))
        parts.append("\(summary.entryCount) req")
        if let cost = summary.totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: summary.entryCount) {
                parts.append("~\(perReq)")
            }
        }
        return parts.joined(separator: " · ")
    }

    private func modelLineValue(title: String, totals: UsageLedgerTotals, requests: Int) -> String {
        var parts: [String] = [title]
        parts.append(UsageFormatter.tokenSummaryString(totals))
        parts.append("\(requests) req")
        if let cost = totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: totals.totalTokens) {
                parts.append("~\(per1K)")
            }
            if let perReq = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: requests) {
                parts.append("~\(perReq)")
            }
        }
        return parts.joined(separator: " · ")
    }

    private var windowModelLines: [String] {
        self.labeledQuotaWindows(from: self.store.snapshot(for: self.provider)).prefix(3).map { item in
            let modelName = UsageFormatter.modelDisplayName(item.label)
            let used = Int(item.window.usedPercent.rounded())
            let remaining = Int(item.window.remainingPercent.rounded())
            var parts = [modelName, "\(used)% used", "\(remaining)% left"]
            if let resetsAt = item.window.resetsAt {
                parts.append("reset \(UsageFormatter.resetCountdownDescription(from: resetsAt))")
            } else if let resetDescription = item.window.resetDescription?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !resetDescription.isEmpty
            {
                parts.append(resetDescription)
            }
            return parts.joined(separator: " · ")
        }
    }

    private var topWindowModel: (label: String, window: RateWindow)? {
        self.labeledQuotaWindows(from: self.store.snapshot(for: self.provider)).first
    }

    private func labeledQuotaWindows(from snapshot: UsageSnapshot?) -> [(label: String, window: RateWindow)] {
        guard let snapshot else { return [] }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap { $0 }
        var seen: Set<String> = []
        var labeled: [(label: String, window: RateWindow)] = []

        for window in windows {
            guard let label = window.label?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !label.isEmpty
            else {
                continue
            }
            let normalized = label.lowercased()
            guard seen.insert(normalized).inserted else { continue }
            labeled.append((label, window))
        }

        return labeled.sorted { lhs, rhs in
            if lhs.window.usedPercent == rhs.window.usedPercent {
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            }
            return lhs.window.usedPercent > rhs.window.usedPercent
        }
    }

    private func decimalString(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private struct RuntimeMetricsData {
        let lineText: String
        let hoverText: String?
    }

    private var runtimeMetrics: RuntimeMetricsData? {
        let attempts = self.store.fetchAttempts(for: self.provider)
        guard !attempts.isEmpty || self.store.snapshot(for: self.provider) != nil else {
            return nil
        }

        var parts: [String] = []
        if let updatedAt = self.store.snapshot(for: self.provider)?.updatedAt {
            parts.append("success \(updatedAt.relativeDescription())")
        } else {
            parts.append("no success yet")
        }

        var hoverText: String?
        if !attempts.isEmpty {
            let retryCount = self.retryCount(from: attempts)
            if retryCount > 0 {
                parts.append("retry \(retryCount)")
            }
            if let activeAttempt = self.activeAttempt(from: attempts) {
                parts.append(Self.fetchKindLabel(activeAttempt.kind))
                if let strategyID = self.trimmed(activeAttempt.strategyID) {
                    hoverText = "Strategy: \(strategyID)"
                }
            }
        }

        return RuntimeMetricsData(
            lineText: parts.joined(separator: " · "),
            hoverText: hoverText)
    }

    private func retryCount(from attempts: [ProviderFetchAttempt]) -> Int {
        guard !attempts.isEmpty else { return 0 }
        if let successIndex = attempts.firstIndex(where: { $0.wasAvailable && self.trimmed($0.errorDescription) == nil }) {
            return max(0, successIndex)
        }
        return max(0, attempts.count - 1)
    }

    private func activeAttempt(from attempts: [ProviderFetchAttempt]) -> ProviderFetchAttempt? {
        guard !attempts.isEmpty else { return nil }
        return attempts.first(where: { $0.wasAvailable && self.trimmed($0.errorDescription) == nil }) ??
            attempts.last(where: { $0.wasAvailable }) ??
            attempts.last
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func fetchKindLabel(_ kind: ProviderFetchKind) -> String {
        switch kind {
        case .cli: return "cli"
        case .web: return "web"
        case .oauth: return "oauth"
        case .apiToken: return "api"
        case .api: return "api"
        case .localProbe: return "local"
        case .webDashboard: return "web"
        }
    }

    private func copyDiagnostics() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(self.diagnosticsReport, forType: .string)
        self.diagnosticsCopyStatus = "Copied"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.diagnosticsCopyStatus = nil
        }
    }

    private var diagnosticsReport: String {
        let metadata = self.store.metadata(for: self.provider)
        let attempts = self.store.fetchAttempts(for: self.provider)
        let snapshot = self.store.snapshot(for: self.provider)
        let forecast = self.store.ledgerSpendForecast(for: self.provider)
        let topProjectForecast = self.store.ledgerTopProjectSpendForecast(for: self.provider)
        let reliability = self.store.ledgerReliabilityScore(for: self.provider)
        let anomaly = self.store.ledgerAnomalySummary(for: self.provider)
        let iso = ISO8601DateFormatter()

        var lines: [String] = []
        lines.append("# \(metadata.displayName) Diagnostics")
        lines.append("provider: \(self.provider.rawValue)")
        lines.append("generated_at: \(iso.string(from: Date()))")
        lines.append("enabled: \(self.isEnabled ? "true" : "false")")
        lines.append("source: \(self.sourceLabel)")
        lines.append("updated: \(self.statusLabel)")
        if let runtime = self.runtimeMetrics?.lineText {
            lines.append("runtime: \(runtime)")
        }

        if let snapshot {
            lines.append("")
            lines.append("usage_snapshot:")
            lines.append("- updated_at: \(iso.string(from: snapshot.updatedAt))")
            lines.append("- primary_used_percent: \(Int(snapshot.primary.usedPercent.rounded()))")
            if let minutes = snapshot.primary.windowMinutes, minutes > 0 {
                lines.append("- primary_window_minutes: \(minutes)")
            }
            if let reset = snapshot.primary.resetsAt {
                lines.append("- primary_resets_at: \(iso.string(from: reset))")
            }
            if let cost = snapshot.providerCost {
                lines.append("- provider_spend_used: \(UsageFormatter.currencyString(cost.used, currencyCode: cost.currencyCode))")
                if cost.limit > 0 {
                    lines.append("- provider_spend_limit: \(UsageFormatter.currencyString(cost.limit, currencyCode: cost.currencyCode))")
                }
                if let period = self.trimmed(cost.period) {
                    lines.append("- provider_spend_period: \(period)")
                }
            }
        }

        lines.append("")
        lines.append("fetch_path:")
        if attempts.isEmpty {
            lines.append("- none")
        } else {
            for attempt in attempts {
                let state: String
                if !attempt.wasAvailable {
                    state = "unavailable"
                } else if let error = self.trimmed(attempt.errorDescription) {
                    state = "failed: \(error)"
                } else {
                    state = "ok"
                }
                lines.append("- \(attempt.strategyID) [\(Self.fetchKindLabel(attempt.kind))] \(state)")
            }
        }

        if let forecast {
            lines.append("")
            lines.append("provider_forecast:")
            lines.append("- projected_30d: \(UsageFormatter.usdString(forecast.projected30DayCostUSD))")
            lines.append("- average_daily: \(UsageFormatter.usdString(forecast.averageDailyCostUSD))")
            if let p50 = forecast.projectedCostP50USD {
                lines.append("- p50: \(UsageFormatter.usdString(p50))")
            }
            if let p80 = forecast.projectedCostP80USD {
                lines.append("- p80: \(UsageFormatter.usdString(p80))")
            }
            if let p95 = forecast.projectedCostP95USD {
                lines.append("- p95: \(UsageFormatter.usdString(p95))")
            }
            if let limit = forecast.budgetLimitUSD, limit > 0 {
                lines.append("- budget_limit: \(UsageFormatter.usdString(limit))")
                lines.append("- budget_status: \(self.budgetStatusText(forecast))")
            }
        }

        if let topProjectForecast {
            lines.append("")
            lines.append("top_project_forecast:")
            if let name = self.trimmed(topProjectForecast.projectName) {
                lines.append("- project: \(name)")
            }
            lines.append("- projected_30d: \(UsageFormatter.usdString(topProjectForecast.projected30DayCostUSD))")
            if let limit = topProjectForecast.budgetLimitUSD, limit > 0 {
                lines.append("- budget_limit: \(UsageFormatter.usdString(limit))")
                lines.append("- budget_status: \(self.budgetStatusText(topProjectForecast))")
            }
        }

        if let reliability {
            lines.append("")
            lines.append("reliability:")
            lines.append("- score: \(reliability.score)/100")
            lines.append("- grade: \(reliability.grade)")
            lines.append("- summary: \(reliability.summary)")
            if let signal = self.trimmed(reliability.primarySignal) {
                lines.append("- signal: \(signal)")
            }
        }

        if let anomaly {
            lines.append("")
            lines.append("anomaly:")
            if let spend = anomaly.spendAnomaly {
                lines.append("- spend: \(spend.severity.label) +\(Int((spend.percentIncrease * 100).rounded()))%")
            }
            if let token = anomaly.tokenAnomaly {
                lines.append("- tokens: \(token.severity.label) +\(Int((token.percentIncrease * 100).rounded()))%")
            }
            if let explanation = anomaly.explanation {
                lines.append("- headline: \(explanation.headline)")
                for detail in explanation.details {
                    lines.append("- detail: \(detail)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private func budgetStatusText(_ forecast: UsageLedgerSpendForecast) -> String {
        if let eta = forecast.budgetETAInDays {
            return self.budgetBreachETAText(days: eta)
        }
        if forecast.budgetWillBreach {
            return "Breach risk"
        }
        return "On track"
    }

    private func budgetBreachETAText(days: Double) -> String {
        guard days.isFinite else { return "Breach ETA unavailable" }
        if days <= 0 { return "Breach now" }
        let now = Date()
        let etaDate = now.addingTimeInterval(days * 24 * 60 * 60)
        let countdown = UsageFormatter.resetCountdownDescription(from: etaDate, now: now)
        if countdown == "now" { return "Breach now" }
        return "Breach \(countdown)"
    }
}
