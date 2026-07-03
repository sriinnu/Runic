import Foundation
import RunicCore

extension ProviderInsightsComposer {
    struct ProviderUsageCoverageEvidence {
        let metadataCoverage: ProviderUsageCoverage
        let topModel: UsageLedgerModelSummary?
        let topProject: UsageLedgerProjectSummary?
        let modelBreakdown: [UsageLedgerModelSummary]
        let projectBreakdown: [UsageLedgerProjectSummary]
        let snapshot: UsageSnapshot?
        let tokenSnapshot: CostUsageTokenSnapshot?
    }

    static func effectiveCoverage(
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

    static func actorValue(identity: ProviderIdentitySnapshot?) -> String? {
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

    static func planAuthValue(identity: ProviderIdentitySnapshot?) -> String? {
        guard let raw = self.trimmed(identity?.loginMethod) else { return nil }
        let cleaned = UsageFormatter.cleanPlanName(raw)
        return cleaned.isEmpty ? raw : cleaned
    }

    static func topModelValue(_ summary: UsageLedgerModelSummary) -> String {
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

    static func topProjectValue(_ summary: UsageLedgerProjectSummary) -> String {
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

    static func modelMixValue(_ summaries: [UsageLedgerModelSummary]) -> String? {
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

    static func projectMixValue(_ summaries: [UsageLedgerProjectSummary]) -> String? {
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

    static func shortProjectName(_ text: String) -> String {
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

    static func projectMixHelpText(_ summaries: [UsageLedgerProjectSummary]) -> String? {
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

    static func projectIdentityHelpText(_ summary: UsageLedgerProjectSummary) -> String? {
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

    static func projectSourceLabel(_ source: UsageLedgerProjectNameSource) -> String {
        switch source {
        case .projectName: "project name"
        case .projectID: "project id"
        case .inferredFromPath: "path-derived"
        case .inferredFromName: "name-derived"
        case .budgetOverride: "budget override"
        case .unknown: "unknown"
        }
    }

    static func projectConfidenceLabel(_ confidence: UsageLedgerProjectNameConfidence) -> String {
        switch confidence {
        case .high: "high"
        case .medium: "medium"
        case .low: "low"
        case .none: "none"
        }
    }

    static func projectIDFingerprint(_ projectID: String?) -> String? {
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

    static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func usageValue(_ window: RateWindow?) -> String? {
        guard let window else { return nil }
        // Windows without a real limit carry a placeholder percent; surface
        // their summary text instead of a fake "0% used".
        guard window.gaugePercent(showUsed: true) != nil else {
            return self.trimmed(window.resetDescription) ?? self.trimmed(window.label)
        }
        var parts = ["\(Int(window.usedPercent.rounded()))% used"]
        if let minutes = window.windowMinutes, minutes > 0 {
            parts.append("\(minutes)m window")
        }
        return parts.joined(separator: " · ")
    }

    static func spendValue(_ providerCost: ProviderCostSnapshot?) -> String? {
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

    static func forecastValue(_ forecast: UsageLedgerSpendForecast?) -> String? {
        guard let forecast else { return nil }
        var parts = [UsageFormatter.usdString(forecast.projected30DayCostUSD), "/ 30d"]
        if forecast.averageDailyCostUSD.isFinite, forecast.averageDailyCostUSD >= 0 {
            parts.append("· \(UsageFormatter.usdString(forecast.averageDailyCostUSD))/day")
        }
        return parts.joined(separator: " ")
    }

    static func budgetValue(_ forecast: UsageLedgerSpendForecast?) -> String? {
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

    static func projectBudgetValue(_ forecast: UsageLedgerSpendForecast?) -> String? {
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

    static func forecastHelpText(_ forecast: UsageLedgerSpendForecast?) -> String? {
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

    static func budgetHelpText(_ forecast: UsageLedgerSpendForecast?) -> String? {
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

    static func budgetBreachETAText(days: Double) -> String {
        guard days.isFinite else { return "Breach ETA unavailable" }
        if days <= 0 { return "Breach now" }
        let now = Date()
        let etaDate = now.addingTimeInterval(days * 24 * 60 * 60)
        let countdown = UsageFormatter.resetCountdownDescription(from: etaDate, now: now)
        if countdown == "now" { return "Breach now" }
        return "Breach \(countdown)"
    }

    static func resetValue(_ window: RateWindow?) -> String? {
        guard let window else { return nil }
        if let resetsAt = window.resetsAt {
            return UsageFormatter.resetCountdownDescription(from: resetsAt)
        }
        return self.trimmed(window.resetDescription)
    }

    static func tokenWindowValue(tokens: Int?, cost: Double?) -> String? {
        var parts: [String] = []
        if let cost, cost.isFinite, cost >= 0 {
            parts.append(UsageFormatter.usdString(cost))
        }
        if let tokens, tokens >= 0 {
            parts.append("\(UsageFormatter.tokenCountString(tokens)) tok")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
