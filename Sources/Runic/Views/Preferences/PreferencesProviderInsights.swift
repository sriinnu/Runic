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

    private struct ProviderUsageCoverageEvidence {
        let metadataCoverage: ProviderUsageCoverage
        let topModel: UsageLedgerModelSummary?
        let topProject: UsageLedgerProjectSummary?
        let modelBreakdown: [UsageLedgerModelSummary]
        let projectBreakdown: [UsageLedgerProjectSummary]
        let snapshot: UsageSnapshot?
        let tokenSnapshot: CostUsageTokenSnapshot?
    }

    private static func effectiveCoverage(
        provider: UsageProvider,
        evidence: ProviderUsageCoverageEvidence) -> ProviderUsageCoverage
    {
        let metadataCoverage = evidence.metadataCoverage
        let topModel = evidence.topModel
        let topProject = evidence.topProject
        let modelBreakdown = evidence.modelBreakdown
        let projectBreakdown = evidence.projectBreakdown
        let snapshot = evidence.snapshot
        let tokenSnapshot = evidence.tokenSnapshot
        let hasModelBreakdown =
            metadataCoverage.supportsModelBreakdown
                || (topModel?.provider == provider)
                || !modelBreakdown.isEmpty

        let hasProjectAttribution =
            metadataCoverage.supportsProjectAttribution
                || (topProject?.provider == provider)
                || !projectBreakdown.isEmpty

        let hasTokenMetrics = metadataCoverage.supportsTokenMetrics
            || snapshot?.providerCost != nil
            || tokenSnapshot?.sessionTokens != nil
            || tokenSnapshot?.sessionCostUSD != nil
            || tokenSnapshot?.last30DaysTokens != nil
            || tokenSnapshot?.last30DaysCostUSD != nil

        return ProviderUsageCoverage(
            supportsModelBreakdown: hasModelBreakdown,
            supportsTokenMetrics: hasTokenMetrics,
            supportsProjectAttribution: hasProjectAttribution)
    }

    private static func actorValue(identity: ProviderIdentitySnapshot?) -> String? {
        let email = RunicScreenshotMode.sanitize(email: self.trimmed(identity?.accountEmail))
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
        let project = self.shortProjectName(RunicProjectDisplay.name(for: summary))
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
            if let context = UsageFormatter.modelContextLabel(for: item.model) {
                return "\(name) \(context) \(tokens)"
            }
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
                return RunicProjectDisplay.name(for: lhs) < RunicProjectDisplay.name(for: rhs)
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        let rendered = ranked.prefix(2).map { summary in
            let project = self.shortProjectName(RunicProjectDisplay.name(for: summary))
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
                return RunicProjectDisplay.name(for: lhs) < RunicProjectDisplay.name(for: rhs)
            }
            return lhs.totals.totalTokens > rhs.totals.totalTokens
        }
        let details = ranked.prefix(3).map { summary in
            let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
            let project = RunicProjectDisplay.name(for: summary)
            return "\(project): \(tokens) tok"
        }
        return details.isEmpty ? nil : details.joined(separator: "\n")
    }

    private static func projectIdentityHelpText(_ summary: UsageLedgerProjectSummary) -> String? {
        let displayName = RunicProjectDisplay.name(for: summary)
        let source = summary.projectNameSource ?? .unknown
        let confidence = summary.projectNameConfidence ?? .none
        let shouldAnnotateSource = source != .projectName && source != .budgetOverride
        let shouldAnnotateConfidence = confidence != .high
        let isUnknown = RunicProjectDisplay.isUnattributed(displayName)

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
        case .projectName: "project name"
        case .projectID: "project id"
        case .inferredFromPath: "path-derived"
        case .inferredFromName: "name-derived"
        case .budgetOverride: "budget override"
        case .unknown: "unknown"
        }
    }

    private static func projectConfidenceLabel(_ confidence: UsageLedgerProjectNameConfidence) -> String {
        switch confidence {
        case .high: "high"
        case .medium: "medium"
        case .low: "low"
        case .none: "none"
        }
    }

    private static func projectIDFingerprint(_ projectID: String?) -> String? {
        guard let projectID = projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !projectID.isEmpty else {
            return nil
        }

        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in projectID.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01B3
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
        let name = self
            .shortProjectName(forecast.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Top project")
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
            "Projected 30d: \(UsageFormatter.usdString(forecast.projected30DayCostUSD))",
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
            "Severity: \(spend.severity.label)",
        ]
        if let explanation = anomaly.explanation {
            lines.append(contentsOf: explanation.details.prefix(2))
        }
        return lines.joined(separator: "\n")
    }

    private static func fetchHealthValue(_ attempts: [ProviderFetchAttempt]) -> String? {
        guard !attempts.isEmpty else { return nil }
        let rendered = attempts.prefix(3).map { attempt in
            let status = if !attempt.wasAvailable {
                "unavailable"
            } else if self.trimmed(attempt.errorDescription) != nil {
                "failed"
            } else {
                "ok"
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
        case .cli: "cli"
        case .web: "web"
        case .oauth: "oauth"
        case .apiToken: "api"
        case .api: "api"
        case .localProbe: "local"
        case .webDashboard: "web"
        }
    }

    private static func truncated(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return "\(text[..<index])…"
    }

    private static func windowModelsValue(_ snapshot: UsageSnapshot?) -> String? {
        guard let snapshot else { return nil }
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary].compactMap(\.self)
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
