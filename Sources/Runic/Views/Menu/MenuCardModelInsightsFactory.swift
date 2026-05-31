import Foundation
import RunicCore

// MARK: - Insights section factory

extension UsageMenuCardView.Model {
    static func insightsSection(input: Input) -> InsightsSection? {
        let error = input.ledgerError?.trimmingCharacters(in: .whitespacesAndNewlines)
        let daily = input.ledgerDaily?.provider == input.provider ? input.ledgerDaily : nil
        let block = input.ledgerActiveBlock?.provider == input.provider ? input.ledgerActiveBlock : nil
        let topModel = input.ledgerTopModel?.provider == input.provider ? input.ledgerTopModel : nil
        let topProject = input.ledgerTopProject?.provider == input.provider ? input.ledgerTopProject : nil
        let spendForecast = input.ledgerSpendForecast?.provider == input.provider ? input.ledgerSpendForecast : nil
        let topProjectSpendForecast = input.ledgerTopProjectSpendForecast?.provider == input.provider
            ? input.ledgerTopProjectSpendForecast
            : nil
        let anomaly = input.ledgerAnomaly?.provider == input.provider ? input.ledgerAnomaly : nil
        let compaction = input.ledgerCompaction?.provider == input.provider ? input.ledgerCompaction : nil
        let connection = Self.connectionLines(input: input)
        let context = Self.contextHealthLines(input: input, daily: daily, block: block, topModel: topModel)
        let compactionLines = Self.compactionLines(compaction)
        let hasData = connection.line != nil || context.line != nil || compactionLines.line != nil || daily != nil ||
            block != nil || topModel != nil || topProject != nil || spendForecast != nil || anomaly != nil
        if !hasData, error?.isEmpty ?? true {
            return nil
        }

        let today = Self.todayInsightLines(daily)
        let forecastLine = Self.forecastInsightLine(spendForecast)
        let activeBlock = Self.activeBlockInsightLines(block, now: input.now)
        let modelLine = Self.modelInsightLine(topModel, contextLabel: input.ledgerTopModelContextLabel)
        let project = Self.projectInsightLines(topProject, forecast: topProjectSpendForecast, now: input.now)
        let anomalyLines = Self.anomalyInsightLines(anomaly)
        let reliability = Self.reliabilityInsightLines(input.ledgerReliability)
        let routing = Self.routingInsightLines(input.ledgerRouting)
        let updatedLine = input.ledgerUpdatedAt.map { UsageFormatter.updatedString(from: $0, now: input.now) }

        return InsightsSection(
            title: "Insights",
            connectionLine: connection.line,
            connectionDetail: connection.detail,
            contextLine: context.line,
            contextDetail: context.detail,
            compactionLine: compactionLines.line,
            compactionDetail: compactionLines.detail,
            todayLine: today.line,
            todayDetail: today.detail,
            forecastLine: forecastLine,
            blockLine: activeBlock.line,
            blockDetail: activeBlock.detail,
            modelLine: modelLine,
            projectLine: project.line,
            projectDetail: project.detail,
            anomalyLine: anomalyLines.line,
            anomalyDetail: anomalyLines.detail,
            reliabilityLine: reliability.line,
            reliabilityDetail: reliability.detail,
            routingLine: routing.line,
            routingDetail: routing.detail,
            updatedLine: updatedLine,
            errorLine: (error?.isEmpty ?? true) ? nil : error)
    }

    private static func todayInsightLines(_ daily: UsageLedgerDailySummary?) -> (line: String?, detail: String?) {
        guard let daily else { return (nil, nil) }
        let tokens = UsageFormatter.tokenCountString(daily.totals.totalTokens)
        let line = "Today: \(tokens) tokens"
        var details: [String] = []
        let input = UsageFormatter.tokenCountString(daily.totals.inputTokens)
        let output = UsageFormatter.tokenCountString(daily.totals.outputTokens)
        var flowParts = ["In \(input)", "Out \(output)"]
        if daily.totals.cacheReadTokens > 0 {
            let cacheRead = UsageFormatter.tokenCountString(daily.totals.cacheReadTokens)
            flowParts.append("Cache read \(cacheRead)")
        }
        if daily.totals.cacheCreationTokens > 0 {
            let cacheWrite = UsageFormatter.tokenCountString(daily.totals.cacheCreationTokens)
            flowParts.append("Cache write \(cacheWrite)")
        }
        details.append(flowParts.joined(separator: " · "))
        if let cost = daily.totals.costUSD {
            details.append(Self.spendDetailLine(cost: cost, tokens: daily.totals.totalTokens))
        }
        return (line, details.isEmpty ? nil : details.joined(separator: "\n"))
    }

    private static func forecastInsightLine(_ forecast: UsageLedgerSpendForecast?) -> String? {
        guard let forecast else { return nil }
        let projected = UsageFormatter.usdString(forecast.projected30DayCostUSD)
        let observedDayLabel = forecast.observedDays == 1 ? "day" : "days"
        var parts = ["Month-end forecast: \(projected)"]
        if let p50 = forecast.projectedCostP50USD,
           let p80 = forecast.projectedCostP80USD,
           let p95 = forecast.projectedCostP95USD
        {
            let p50Text = UsageFormatter.usdString(p50)
            let p80Text = UsageFormatter.usdString(p80)
            let p95Text = UsageFormatter.usdString(p95)
            parts.append("p50 \(p50Text) · p80 \(p80Text) · p95 \(p95Text)")
        }
        parts.append("\(forecast.observedDays) observed \(observedDayLabel)")
        return parts.joined(separator: " · ")
    }

    private static func activeBlockInsightLines(
        _ block: UsageLedgerBlockSummary?,
        now: Date) -> (line: String?, detail: String?)
    {
        guard let block, block.isActive else { return (nil, nil) }
        let tokens = UsageFormatter.tokenCountString(block.totals.totalTokens)
        let line = "Active block: \(tokens) tokens · \(block.entryCount) req"
        var details: [String] = []
        details.append("Ends \(UsageFormatter.resetCountdownDescription(from: block.end, now: now))")
        if let rate = block.tokensPerMinute {
            let rateText = UsageFormatter.tokenCountString(Int(rate.rounded()))
            details.append("\(rateText) tok/min")
        }
        if let projected = block.projectedTotalTokens {
            details.append("Proj \(UsageFormatter.tokenCountString(projected))")
        }
        let inputTokens = UsageFormatter.tokenCountString(block.totals.inputTokens)
        let outputTokens = UsageFormatter.tokenCountString(block.totals.outputTokens)
        details.append("In \(inputTokens) · Out \(outputTokens)")
        if let cost = block.totals.costUSD {
            var spendParts = Self.spendDetailParts(cost: cost, tokens: block.totals.totalTokens)
            if let perRequest = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: block.entryCount) {
                spendParts.append(perRequest)
            }
            if let burnPerHour = UsageFormatter.usdPerHourFromTokensString(
                costUSD: cost,
                tokenCount: block.totals.totalTokens,
                tokensPerMinute: block.tokensPerMinute)
            {
                spendParts.append("Burn \(burnPerHour)")
            }
            details.append(spendParts.joined(separator: " · "))
        }
        return (line, details.joined(separator: "\n"))
    }

    private static func modelInsightLine(
        _ summary: UsageLedgerModelSummary?,
        contextLabel: String?) -> String?
    {
        guard let summary else { return nil }
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        let modelName = UsageFormatter.modelDisplayName(summary.model)
        var parts = ["Top model: \(modelName) · \(tokens) tokens · \(summary.entryCount) req"]
        if let contextLabel {
            parts.append(contextLabel)
        }
        if let cost = summary.totals.costUSD {
            parts.append(contentsOf: Self.costInsightParts(cost: cost, tokens: summary.totals.totalTokens))
        }
        return parts.joined(separator: " · ")
    }

    private static func projectInsightLines(
        _ summary: UsageLedgerProjectSummary?,
        forecast: UsageLedgerSpendForecast?,
        now: Date) -> (line: String?, detail: String?)
    {
        guard let summary else { return (nil, nil) }
        let name = Self.insightsProjectDisplayName(summary)
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        var parts = ["Top project: \(name) · \(tokens) tokens · \(summary.entryCount) req"]
        if let cost = summary.totals.costUSD {
            parts.append(contentsOf: Self.costInsightParts(cost: cost, tokens: summary.totals.totalTokens))
        }
        let detail = forecast.flatMap { Self.projectForecastDetail($0, now: now) }
        return (parts.joined(separator: " · "), detail)
    }

    private static func projectForecastDetail(_ forecast: UsageLedgerSpendForecast, now: Date) -> String {
        var parts = ["30d forecast \(UsageFormatter.usdString(forecast.projected30DayCostUSD))"]
        if let budgetLimit = forecast.budgetLimitUSD {
            parts.append("Budget \(UsageFormatter.usdString(budgetLimit))")
            if let budgetETAInDays = forecast.budgetETAInDays {
                parts.append(Self.budgetBreachETAText(days: budgetETAInDays, now: now))
            } else if !forecast.budgetWillBreach {
                parts.append("No breach at current pace")
            }
        }
        return parts.joined(separator: " · ")
    }

    private static func anomalyInsightLines(
        _ anomaly: UsageLedgerAnomalySummary?) -> (line: String?, detail: String?)
    {
        guard let anomaly, let primary = anomaly.primaryAnomaly else { return (nil, nil) }
        let line = "Anomaly: \(primary.severity.label) \(primary.metric.label) spike"
        var details = [Self.anomalyMetricDetail(primary, baselineDays: anomaly.baselineDays)]
        if let secondary = anomaly.secondaryAnomaly(excluding: primary.metric) {
            details.append(Self.anomalyMetricDetail(secondary, baselineDays: anomaly.baselineDays))
        }
        return (line, details.joined(separator: "\n"))
    }

    private static func reliabilityInsightLines(
        _ reliability: UsageLedgerReliabilityScore?) -> (line: String?, detail: String?)
    {
        guard let reliability else { return (nil, nil) }
        let line = "Reliability: \(reliability.score)/100 · \(reliability.grade)"
        return (line, reliability.primarySignal ?? reliability.summary)
    }

    private static func routingInsightLines(
        _ routing: UsageLedgerRoutingRecommendation?) -> (line: String?, detail: String?)
    {
        guard let routing else { return (nil, nil) }
        let from = UsageFormatter.modelDisplayName(routing.fromModel)
        let to = UsageFormatter.modelDisplayName(routing.toModel)
        let line = "Routing advisor: shift \(routing.shiftPercent)% \(from) -> \(to)"
        let confidenceText = "\(Int((routing.confidence * 100).rounded()))%"
        let savings = UsageFormatter.usdString(routing.estimatedSavingsUSD)
        return (line, "Estimated savings: \(savings) · confidence \(confidenceText)")
    }

    private static func spendDetailLine(cost: Double, tokens: Int) -> String {
        Self.spendDetailParts(cost: cost, tokens: tokens).joined(separator: " · ")
    }

    private static func spendDetailParts(cost: Double, tokens: Int) -> [String] {
        var parts = ["Spend \(UsageFormatter.usdString(cost))"]
        if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: tokens) {
            parts.append(per1K)
        }
        return parts
    }

    private static func costInsightParts(cost: Double, tokens: Int) -> [String] {
        var parts = [UsageFormatter.usdString(cost)]
        if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: tokens) {
            parts.append(per1K)
        }
        return parts
    }

    private static func anomalyMetricDetail(
        _ anomaly: UsageLedgerAnomalySummary.MetricAnomaly,
        baselineDays: Int) -> String
    {
        let percentText = "\(Int((anomaly.percentIncrease * 100).rounded()))%"
        let baselineLabel = "\(baselineDays)d avg"
        switch anomaly.metric {
        case .tokens:
            let todayTokens = UsageFormatter.tokenCountString(Int(anomaly.todayValue.rounded()))
            let baselineTokens = UsageFormatter.tokenCountString(Int(anomaly.baselineAverage.rounded()))
            return "Tokens \(todayTokens) today · +\(percentText) vs \(baselineLabel) \(baselineTokens)"
        case .spend:
            let todaySpend = UsageFormatter.usdString(anomaly.todayValue)
            let baselineSpend = UsageFormatter.usdString(anomaly.baselineAverage)
            return "Spend \(todaySpend) today · +\(percentText) vs \(baselineLabel) \(baselineSpend)"
        }
    }

    private static func connectionLines(input: Input) -> (line: String?, detail: String?) {
        let status: String = if input.isRefreshing {
            "refreshing"
        } else if let lastError = input.lastError?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !lastError.isEmpty
        {
            "issue"
        } else if input.snapshot != nil {
            "connected"
        } else {
            "waiting for first fetch"
        }

        var detailParts: [String] = []
        let email = Self.email(
            for: input.provider,
            snapshot: input.snapshot,
            account: input.account,
            metadata: input.metadata)
        if !email.isEmpty {
            detailParts.append("Account \(email)")
        }
        if let updatedAt = input.snapshot?.updatedAt {
            detailParts.append("Last fetch \(UsageFormatter.updatedString(from: updatedAt, now: input.now))")
        } else if let ledgerUpdatedAt = input.ledgerUpdatedAt {
            detailParts.append("Ledger \(UsageFormatter.updatedString(from: ledgerUpdatedAt, now: input.now))")
        }
        if let coverage = input.metadata.usageCoverage.summaryLabel {
            detailParts.append(coverage)
        }
        let detail = detailParts.isEmpty ? nil : detailParts.joined(separator: " · ")
        return ("Connection: \(status)", detail)
    }

    private static func contextHealthLines(
        input: Input,
        daily: UsageLedgerDailySummary?,
        block: UsageLedgerBlockSummary?,
        topModel: UsageLedgerModelSummary?) -> (line: String?, detail: String?)
    {
        guard input.providerContextStatus != nil || topModel != nil || daily != nil || block != nil else {
            return (nil, nil)
        }

        let status = input.providerContextStatus
        let maxContext = status?.text ?? "unknown"
        let observedTokens = block?.totals.totalTokens ?? daily?.totals.totalTokens ?? topModel?.totals.totalTokens ?? 0
        let observed = observedTokens > 0 ? UsageFormatter.tokenCountString(observedTokens) : "no observed tokens"
        var parts: [String] = []
        if let block, block.isActive,
           let maxTokens = status?.maxTokens,
           maxTokens > 0
        {
            parts.append(Self.contextPressureText(observed: block.totals.totalTokens, maxTokens: maxTokens))
        }
        parts.append("max \(maxContext)")
        parts.append("observed \(observed)")
        let line = "Context health: \(parts.joined(separator: " · "))"

        var details: [String] = []
        if let status {
            let staleText = status.isStale ? " (stale)" : ""
            details.append("Capability source: \(Self.contextSourceText(status.source))\(staleText)")
        } else {
            details.append("Capability source: unavailable")
        }
        if let model = topModel?.model {
            details.append("Model \(UsageFormatter.modelDisplayName(model))")
        }
        if block?.isActive == true {
            details.append("Pressure uses active block token volume, not semantic retention.")
        } else {
            details.append("Observed tokens are usage volume, not active retained context.")
        }
        details.append("Effective retained context after compaction is not inferred.")
        return (line, details.joined(separator: " · "))
    }

    private static func contextPressureText(observed: Int, maxTokens: Int) -> String {
        guard observed > 0, maxTokens > 0 else { return "unknown pressure" }
        let ratio = Double(observed) / Double(maxTokens)
        let percent = Int((ratio * 100).rounded())
        switch ratio {
        case ..<0.35:
            return "low pressure \(percent)%"
        case ..<0.70:
            return "medium pressure \(percent)%"
        case ..<1.0:
            return "high pressure \(percent)%"
        default:
            return "over-window volume \(percent)%"
        }
    }

    private static func compactionLines(
        _ summary: UsageLedgerCompactionSummary?) -> (line: String?, detail: String?)
    {
        guard let summary else {
            return (nil, nil)
        }

        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        let eventLabel = summary.eventCount == 1 ? "event" : "events"
        let line = "Compaction tax: \(tokens) tokens · \(summary.eventCount) \(eventLabel)"

        var details: [String] = []
        if let cost = summary.totals.costUSD {
            details.append("Spend \(UsageFormatter.usdString(cost))")
        }
        if let provenance = summary.totals.tokenProvenance {
            details.append(provenance.displayText)
        } else {
            details.append("Source: observed compaction entries")
        }
        details.append("Last \(UsageFormatter.updatedString(from: summary.lastEventAt))")
        return (line, details.joined(separator: " · "))
    }

    private static func contextSourceText(_ source: ProviderContextWindowLabel.Source) -> String {
        switch source {
        case .kosha: "Kosha TTL registry"
        case .modelHeuristic: "model heuristic"
        case .staticFallback: "built-in fallback"
        }
    }

    private static func insightsProjectDisplayName(_ summary: UsageLedgerProjectSummary) -> String {
        let displayName = RunicProjectDisplay.name(for: summary)
        guard let annotation = self.projectIdentityAnnotation(
            displayName: displayName,
            projectID: summary.projectID,
            confidence: summary.projectNameConfidence,
            source: summary.projectNameSource)
        else {
            return displayName
        }
        return "\(displayName) [\(annotation)]"
    }

    private static func projectIdentityAnnotation(
        displayName: String,
        projectID: String?,
        confidence: UsageLedgerProjectNameConfidence?,
        source: UsageLedgerProjectNameSource?) -> String?
    {
        let normalizedSource = source ?? .unknown
        let normalizedConfidence = confidence ?? .none

        let shouldAnnotateSource = normalizedSource != .projectName && normalizedSource != .budgetOverride
        let shouldAnnotateConfidence = normalizedConfidence != .high
        let isUnknown = RunicProjectDisplay.isUnattributed(displayName)
        guard shouldAnnotateSource || shouldAnnotateConfidence || isUnknown else { return nil }

        var parts: [String] = []
        if shouldAnnotateSource {
            parts.append("source \(self.projectSourceLabel(normalizedSource))")
        }
        if shouldAnnotateConfidence {
            parts.append("confidence \(self.projectConfidenceLabel(normalizedConfidence))")
        }
        if isUnknown, let fingerprint = self.projectIDFingerprint(projectID) {
            parts.append("id \(fingerprint)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

    private static func budgetBreachETAText(days: Double, now: Date) -> String {
        guard days.isFinite else { return "Breach ETA unavailable" }
        if days <= 0 { return "Breach now" }
        let etaDate = now.addingTimeInterval(days * 24 * 60 * 60)
        let countdown = UsageFormatter.resetCountdownDescription(from: etaDate, now: now)
        if countdown == "now" { return "Breach now" }
        return "Breach \(countdown)"
    }
}
