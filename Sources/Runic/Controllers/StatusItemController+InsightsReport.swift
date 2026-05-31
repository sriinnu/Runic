import AppKit
import RunicCore

extension StatusItemController {
    @objc func openInsightsReport(_ sender: NSMenuItem) {
        let rawProvider = sender.representedObject as? String
        let provider = rawProvider.flatMap(UsageProvider.init(rawValue:)) ?? self.lastMenuProvider ?? .codex
        let days = max(1, self.settings.insightsReportDays)
        Task { [weak self] in
            guard let self else { return }
            let report = await self.buildInsightsReport(provider: provider, days: days)
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard let url = self.writeInsightsReport(report, provider: provider) else { return }
                NSWorkspace.shared.open(url)
            }
        }
    }

    private struct InsightsReportData {
        let provider: UsageProvider
        let metadata: ProviderMetadata
        let maxDays: Int
        let now: Date
        let dateFormatter: DateFormatter
        let hasSources: Bool
        let loadError: String?
        let daily: UsageLedgerDailySummary?
        let activeBlock: UsageLedgerBlockSummary?
        let topModel: UsageLedgerModelSummary?
        let topProject: UsageLedgerProjectSummary?
        let modelBreakdown: [UsageLedgerModelSummary]
        let projectBreakdown: [UsageLedgerProjectSummary]
    }

    private struct InsightsBreakdowns {
        let daily: UsageLedgerDailySummary?
        let activeBlock: UsageLedgerBlockSummary?
        let topModel: UsageLedgerModelSummary?
        let topProject: UsageLedgerProjectSummary?
        let modelBreakdown: [UsageLedgerModelSummary]
        let projectBreakdown: [UsageLedgerProjectSummary]
    }

    private func buildInsightsReport(provider: UsageProvider, days: Int) async -> String {
        let data = await self.makeInsightsReportData(provider: provider, days: days)
        guard data.hasSources else {
            return "# Runic Insights - \(data.metadata.displayName)\n\nNo insights available."
        }

        var lines = Self.insightsHeaderLines(for: data)
        self.appendTodaySection(to: &lines, data: data)
        Self.appendActiveBlockSection(to: &lines, data: data)
        self.appendTopModelSection(to: &lines, data: data)
        self.appendTopProjectSection(to: &lines, data: data)
        self.appendModelsByProjectSection(to: &lines, summaries: data.modelBreakdown)
        self.appendProjectsSection(to: &lines, summaries: data.projectBreakdown)
        self.appendReliabilitySection(to: &lines, data: data)
        Self.appendRoutingAdvisorSection(to: &lines, modelBreakdown: data.modelBreakdown)
        Self.appendLoadErrorSection(to: &lines, loadError: data.loadError)
        return lines.joined(separator: "\n")
    }

    private func makeInsightsReportData(provider: UsageProvider, days: Int) async -> InsightsReportData {
        let metadata = self.store.metadata(for: provider)
        let now = Date()
        let maxDays = max(1, days)
        let sources = Self.insightsSources(for: provider, maxDays: maxDays, now: now)
        let (entries, loadError) = await Self.loadInsightsEntries(from: sources)
        let dateFormatter = Self.makeInsightsDateFormatter()
        let breakdowns = Self.insightsBreakdowns(entries: entries, provider: provider, now: now)

        return InsightsReportData(
            provider: provider,
            metadata: metadata,
            maxDays: maxDays,
            now: now,
            dateFormatter: dateFormatter,
            hasSources: !sources.isEmpty,
            loadError: loadError,
            daily: breakdowns.daily,
            activeBlock: breakdowns.activeBlock,
            topModel: breakdowns.topModel,
            topProject: breakdowns.topProject,
            modelBreakdown: breakdowns.modelBreakdown,
            projectBreakdown: breakdowns.projectBreakdown)
    }

    private static func insightsSources(
        for provider: UsageProvider,
        maxDays: Int,
        now: Date) -> [any UsageLedgerSource]
    {
        switch provider {
        case .codex:
            [CodexUsageLogSource(maxAgeDays: maxDays, now: now)]
        case .claude:
            [ClaudeUsageLogSource(maxAgeDays: maxDays, now: now)]
        default:
            []
        }
    }

    private static func loadInsightsEntries(
        from sources: [any UsageLedgerSource]) async -> ([UsageLedgerEntry], String?)
    {
        guard !sources.isEmpty else { return ([], nil) }

        do {
            let ledger = UsageLedger(sources: sources)
            let entries = try await ledger.loadEntries()
            return (entries, nil)
        } catch {
            return ([], error.localizedDescription)
        }
    }

    private static func makeInsightsDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return dateFormatter
    }

    private static func insightsBreakdowns(
        entries: [UsageLedgerEntry],
        provider: UsageProvider,
        now: Date) -> InsightsBreakdowns
    {
        let timeZone = TimeZone.current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let todayStart = calendar.startOfDay(for: now)
        let daily = UsageLedgerAggregator.dailySummaries(
            entries: entries,
            timeZone: timeZone,
            groupByProject: false)
            .first { $0.provider == provider && $0.dayStart == todayStart }
        let activeBlock = UsageLedgerAggregator.blockSummaries(entries: entries, blockHours: 5, now: now)
            .first { $0.provider == provider && $0.isActive }

        return InsightsBreakdowns(
            daily: daily,
            activeBlock: activeBlock,
            topModel: UsageLedgerAggregator.modelSummaries(entries: entries).first { $0.provider == provider },
            topProject: UsageLedgerAggregator.projectSummaries(entries: entries).first { $0.provider == provider },
            modelBreakdown: UsageLedgerAggregator.modelSummaries(entries: entries, groupByProject: true)
                .filter { $0.provider == provider },
            projectBreakdown: UsageLedgerAggregator.projectSummaries(entries: entries)
                .filter { $0.provider == provider }
        )
    }

    private static func insightsHeaderLines(for data: InsightsReportData) -> [String] {
        [
            "# Runic Insights - \(data.metadata.displayName)",
            "",
            "Window: last \(data.maxDays) day\(data.maxDays == 1 ? "" : "s")",
            "Generated: \(data.dateFormatter.string(from: data.now))",
        ]
    }

    private func appendTodaySection(to lines: inout [String], data: InsightsReportData) {
        guard let daily = data.daily else { return }

        lines.append("")
        lines.append("## Today")
        lines.append("- Tokens: \(UsageFormatter.tokenCountString(daily.totals.totalTokens))")
        lines.append("- Input tokens: \(UsageFormatter.tokenCountString(daily.totals.inputTokens))")
        lines.append("- Output tokens: \(UsageFormatter.tokenCountString(daily.totals.outputTokens))")
        self.appendTodayRequestStats(to: &lines, daily: daily, modelBreakdown: data.modelBreakdown)
        Self.appendCostLines(
            to: &lines,
            costUSD: daily.totals.costUSD,
            tokenCount: daily.totals.totalTokens,
            requestCount: data.modelBreakdown.reduce(0) { $0 + $1.entryCount })
        Self.appendCacheAndModelLines(to: &lines, daily: daily)
    }

    private func appendTodayRequestStats(
        to lines: inout [String],
        daily: UsageLedgerDailySummary,
        modelBreakdown: [UsageLedgerModelSummary])
    {
        let requestCount = modelBreakdown.reduce(0) { $0 + $1.entryCount }
        guard requestCount > 0 else { return }

        lines.append("- Requests: \(requestCount)")
        let average = Int((Double(daily.totals.totalTokens) / Double(requestCount)).rounded())
        lines.append("- Avg tokens/request: \(UsageFormatter.tokenCountString(average))")
    }

    private static func appendCacheAndModelLines(
        to lines: inout [String],
        daily: UsageLedgerDailySummary)
    {
        let cacheTotal = daily.totals.cacheCreationTokens + daily.totals.cacheReadTokens
        if cacheTotal > 0 {
            lines.append("- Cache: \(UsageFormatter.tokenCountString(cacheTotal))")
        }
        if !daily.modelsUsed.isEmpty {
            let renderedModels = Self.renderedModelsLine(for: daily.modelsUsed)
            if !renderedModels.isEmpty {
                lines.append("- Models: \(renderedModels)")
            }
        }
    }

    private static func appendActiveBlockSection(to lines: inout [String], data: InsightsReportData) {
        guard let block = data.activeBlock, block.isActive else { return }

        lines.append("")
        lines.append("## Active block")
        lines.append("- Tokens: \(UsageFormatter.tokenCountString(block.totals.totalTokens))")
        lines.append("- Requests: \(block.entryCount)")
        lines.append("- Input tokens: \(UsageFormatter.tokenCountString(block.totals.inputTokens))")
        lines.append("- Output tokens: \(UsageFormatter.tokenCountString(block.totals.outputTokens))")
        lines.append("- Ends: \(data.dateFormatter.string(from: block.end))")
        if let rate = block.tokensPerMinute {
            let rateText = UsageFormatter.tokenCountString(Int(rate.rounded()))
            lines.append("- Rate: \(rateText) tok/min")
        }
        if let projected = block.projectedTotalTokens {
            lines.append("- Projected: \(UsageFormatter.tokenCountString(projected))")
        }
        Self.appendCostLines(
            to: &lines,
            costUSD: block.totals.costUSD,
            tokenCount: block.totals.totalTokens,
            requestCount: block.entryCount,
            tokensPerMinute: block.tokensPerMinute)
    }

    private func appendTopModelSection(to lines: inout [String], data: InsightsReportData) {
        guard let topModel = data.topModel else { return }

        lines.append("")
        lines.append("## Top model")
        let modelName = UsageFormatter.modelDisplayName(topModel.model)
        var line = Self.summaryLine(label: modelName, totals: topModel.totals, entryCount: topModel.entryCount)
        Self.appendModelContext(to: &line, model: topModel.model)
        Self.appendInlineCost(to: &line, totals: topModel.totals)
        lines.append(line)
    }

    private func appendTopProjectSection(to lines: inout [String], data: InsightsReportData) {
        guard let topProject = data.topProject else { return }

        lines.append("")
        lines.append("## Top project")
        let project = self.displayName(for: topProject)
        var line = Self.summaryLine(label: project, totals: topProject.totals, entryCount: topProject.entryCount)
        Self.appendInlineCost(to: &line, totals: topProject.totals)
        lines.append(line)
    }

    private func appendModelsByProjectSection(
        to lines: inout [String],
        summaries: [UsageLedgerModelSummary])
    {
        guard !summaries.isEmpty else { return }

        lines.append("")
        lines.append("## Models by project")
        for summary in summaries {
            let project = self.displayName(for: summary)
            let modelName = UsageFormatter.modelDisplayName(summary.model)
            var line = Self.summaryLine(
                label: "\(project) - \(modelName)",
                totals: summary.totals,
                entryCount: summary.entryCount)
            Self.appendModelContext(to: &line, model: summary.model)
            Self.appendInlineCost(to: &line, totals: summary.totals)
            lines.append(line)
        }
    }

    private func appendProjectsSection(
        to lines: inout [String],
        summaries: [UsageLedgerProjectSummary])
    {
        guard !summaries.isEmpty else { return }

        lines.append("")
        lines.append("## Projects")
        for summary in summaries {
            let project = self.displayName(for: summary)
            var line = Self.summaryLine(label: project, totals: summary.totals, entryCount: summary.entryCount)
            Self.appendInlineCost(to: &line, totals: summary.totals)
            if !summary.modelsUsed.isEmpty {
                line += " - models: \(Self.renderedModelsLine(for: summary.modelsUsed))"
            }
            lines.append(line)
        }
    }

    private func appendReliabilitySection(to lines: inout [String], data: InsightsReportData) {
        let reliability = UsageLedgerInsightsAdvisor.reliabilityScore(.init(
            provider: data.provider,
            daily: data.daily,
            activeBlock: data.activeBlock,
            breakdowns: .init(
                models: data.modelBreakdown,
                projects: data.projectBreakdown),
            errors: .init(
                provider: self.store.error(for: data.provider),
                ledger: data.loadError)))
        guard let reliability else { return }

        lines.append("")
        lines.append("## Reliability")
        lines.append("- Score: \(reliability.score)/100 (\(reliability.grade))")
        lines.append("- Summary: \(reliability.summary)")
        if let primary = reliability.primarySignal {
            lines.append("- Signal: \(primary)")
        }
    }

    private static func appendRoutingAdvisorSection(
        to lines: inout [String],
        modelBreakdown: [UsageLedgerModelSummary])
    {
        let routing = UsageLedgerInsightsAdvisor.routingRecommendation(modelBreakdown: modelBreakdown)
        guard let routing else { return }

        lines.append("")
        lines.append("## Routing advisor")
        let from = UsageFormatter.modelDisplayName(routing.fromModel)
        let to = UsageFormatter.modelDisplayName(routing.toModel)
        lines.append("- Suggestion: Shift \(routing.shiftPercent)% of \(from) traffic to \(to)")
        lines.append("- Estimated savings: \(UsageFormatter.usdString(routing.estimatedSavingsUSD))")
        lines.append("- Confidence: \(Int((routing.confidence * 100).rounded()))%")
        lines.append("- Rationale: \(routing.rationale)")
    }

    private static func appendLoadErrorSection(to lines: inout [String], loadError: String?) {
        guard let loadError else { return }

        lines.append("")
        lines.append("## Error")
        lines.append(loadError)
    }

    private static func appendCostLines(
        to lines: inout [String],
        costUSD: Double?,
        tokenCount: Int,
        requestCount: Int,
        tokensPerMinute: Double? = nil)
    {
        guard let costUSD else { return }

        lines.append("- Cost: \(UsageFormatter.usdString(costUSD))")
        if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: costUSD, tokenCount: tokenCount) {
            lines.append("- Cost per 1K tokens: \(per1K)")
        }
        if let perRequest = UsageFormatter.usdPerRequestString(
            costUSD: costUSD,
            requestCount: requestCount)
        {
            lines.append("- Cost per request: \(perRequest)")
        }
        if let burnPerHour = UsageFormatter.usdPerHourFromTokensString(
            costUSD: costUSD,
            tokenCount: tokenCount,
            tokensPerMinute: tokensPerMinute)
        {
            lines.append("- Estimated burn rate: \(burnPerHour)")
        }
    }

    private static func summaryLine(
        label: String,
        totals: UsageLedgerTotals,
        entryCount: Int) -> String
    {
        let tokens = UsageFormatter.tokenCountString(totals.totalTokens)
        return "- \(label): \(tokens) tokens · \(entryCount) req"
    }

    private static func appendModelContext(to line: inout String, model: String) {
        if let context = UsageFormatter.modelContextLabel(for: model) {
            line += " · \(context)"
        }
    }

    private static func appendInlineCost(to line: inout String, totals: UsageLedgerTotals) {
        guard let cost = totals.costUSD else { return }

        line += " (\(UsageFormatter.usdString(cost)))"
        if let per1K = UsageFormatter.usdPer1KTokensString(
            costUSD: cost,
            tokenCount: totals.totalTokens)
        {
            line += " · \(per1K)"
        }
    }

    private func displayName(for summary: UsageLedgerModelSummary) -> String {
        self.displayProjectName(
            projectID: summary.projectID,
            projectName: summary.projectName,
            confidence: summary.projectNameConfidence,
            source: summary.projectNameSource,
            provenance: summary.projectNameProvenance,
            includeAttribution: true)
    }

    private func displayName(for summary: UsageLedgerProjectSummary) -> String {
        self.displayProjectName(
            projectID: summary.projectID,
            projectName: summary.projectName,
            confidence: summary.projectNameConfidence,
            source: summary.projectNameSource,
            provenance: summary.projectNameProvenance,
            includeAttribution: true)
    }

    private func writeInsightsReport(_ report: String, provider: UsageProvider) -> URL? {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let root = base ?? fm.temporaryDirectory
        let folder = root.appendingPathComponent("Runic/Insights", isDirectory: true)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            RunicLog.logger("insights-report").error("Failed to create report folder: \(error)")
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = dateFormatter.string(from: Date())
        let filename = "insights-\(provider.rawValue)-\(stamp).md"
        let url = folder.appendingPathComponent(filename)
        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            RunicLog.logger("insights-report").error("Failed to write report: \(error)")
            return nil
        }
    }

    private static func renderedModelsLine(for modelsUsed: [String]) -> String {
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
        return rendered.joined(separator: ", ")
    }
}
