import Foundation
import RunicCore

enum RunicCLIInsightsRenderer {
    static func renderWithCommits(
        _ entriesWithCommits: [UsageWithCommit],
        isJson: Bool,
        isPretty: Bool)
    {
        if isJson {
            self.renderJSON(entriesWithCommits, isPretty: isPretty)
            return
        }

        for item in entriesWithCommits {
            let entry = item.entry
            let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
            let provider = entry.provider.rawValue
            let tokens = entry.totalTokens
            let costText = entry.costUSD.map { String(format: "$%.4f", $0) } ?? "n/a"
            var line = "\(timestamp) - \(provider) - \(tokens) tokens - \(costText)"

            if let commit = item.commit {
                line += " - [\(commit.shortSha)] \(commit.message)"
            } else {
                line += " - [no commit]"
            }

            print(line)
        }
    }

    static func renderOutput(
        _ payload: some Encodable,
        isJson: Bool,
        isPretty: Bool)
    {
        if isJson {
            self.renderJSON(payload, isPretty: isPretty)
            return
        }

        if self.renderDailySummaries(payload) { return }
        if self.renderSessionSummaries(payload) { return }
        if self.renderBlockSummaries(payload) { return }
        if self.renderModelSummaries(payload) { return }
        if self.renderProjectSummaries(payload) { return }
        if self.renderHourlySummaries(payload) { return }
        if self.renderProjectBudgetSummaries(payload) { return }
        if self.renderModelComparisons(payload) { return }
        if self.renderEfficiencyMetrics(payload) { return }

        print("No insights available.")
    }

    private static func renderJSON(_ payload: some Encodable, isPretty: Bool) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if isPretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        if let data = try? encoder.encode(payload),
           let text = String(data: data, encoding: .utf8)
        {
            print(text)
        } else {
            print("{}")
        }
    }

    private static func renderDailySummaries(_ payload: some Encodable) -> Bool {
        guard let summaries = payload as? [UsageLedgerDailySummary] else { return false }
        for summary in summaries {
            self.printInsightLine([
                summary.dayKey,
                summary.provider.rawValue,
                summary.projectID ?? "all",
                "\(summary.totals.totalTokens) tokens",
                self.costText(summary.totals.costUSD),
            ])
        }
        return true
    }

    private static func renderSessionSummaries(_ payload: some Encodable) -> Bool {
        guard let summaries = payload as? [UsageLedgerSessionSummary] else { return false }
        for summary in summaries {
            self.printInsightLine([
                summary.sessionID,
                summary.provider.rawValue,
                summary.projectID ?? "all",
                "\(summary.totals.totalTokens) tokens",
                self.costText(summary.totals.costUSD),
            ])
        }
        return true
    }

    private static func renderBlockSummaries(_ payload: some Encodable) -> Bool {
        guard let summaries = payload as? [UsageLedgerBlockSummary] else { return false }
        for summary in summaries {
            self.printInsightLine([
                "\(summary.start)",
                summary.provider.rawValue,
                summary.projectID ?? "all",
                "\(summary.totals.totalTokens) tokens",
                self.costText(summary.totals.costUSD),
            ])
        }
        return true
    }

    private static func renderModelSummaries(_ payload: some Encodable) -> Bool {
        guard let summaries = payload as? [UsageLedgerModelSummary] else { return false }
        for summary in summaries {
            self.printInsightLine([
                summary.model,
                summary.provider.rawValue,
                summary.projectID ?? "all",
                "\(summary.totals.totalTokens) tokens",
                self.costText(summary.totals.costUSD),
            ])
        }
        return true
    }

    private static func renderProjectSummaries(_ payload: some Encodable) -> Bool {
        guard let summaries = payload as? [UsageLedgerProjectSummary] else { return false }
        for summary in summaries {
            self.printInsightLine([
                summary.projectID ?? "unknown",
                summary.provider.rawValue,
                "\(summary.totals.totalTokens) tokens",
                self.costText(summary.totals.costUSD),
                self.modelsText(summary.modelsUsed),
            ])
        }
        return true
    }

    private static func renderHourlySummaries(_ payload: some Encodable) -> Bool {
        guard let summaries = payload as? [UsageLedgerHourlySummary] else { return false }
        for summary in summaries {
            self.printInsightLine([
                summary.hourKey,
                summary.provider.rawValue,
                summary.projectID ?? "all",
                "\(summary.totals.totalTokens) tokens",
                self.costText(summary.totals.costUSD),
                "\(summary.requestCount) requests",
            ])
        }
        return true
    }

    private static func renderProjectBudgetSummaries(_ payload: some Encodable) -> Bool {
        guard let summaries = payload as? [ProjectBudgetSummary] else { return false }
        for summary in summaries {
            var parts = [
                summary.projectID ?? "unknown",
                summary.provider.rawValue,
                "\(summary.totals.totalTokens) tokens",
                self.costText(summary.totals.costUSD),
                self.modelsText(summary.modelsUsed),
            ]
            if let budget = summary.budgetInfo {
                parts.append(self.budgetInsightText(budget))
            }
            self.printInsightLine(parts)
        }
        return true
    }

    private static func renderModelComparisons(_ payload: some Encodable) -> Bool {
        guard let comparisons = payload as? [ModelCostComparison] else { return false }
        for comparison in comparisons {
            self.printInsightLine([
                "#\(comparison.rank ?? 0) \(comparison.model)",
                "\(String(format: "$%.6f", comparison.costPerToken))/token",
                "Total: \(String(format: "$%.2f", comparison.totalCost))",
                "Tokens: \(comparison.totalTokens)",
                "Requests: \(comparison.requestCount)",
            ])
        }
        return true
    }

    private static func renderEfficiencyMetrics(_ payload: some Encodable) -> Bool {
        guard let metrics = payload as? [ModelEfficiencyMetrics] else { return false }
        for metric in metrics {
            self.printInsightLine([
                metric.model,
                "\(metric.requestCount) reqs",
                "\(String(format: "%.0f", metric.tokensPerRequest)) tok/req",
                "\(metric.costPerRequest.map { String(format: "$%.4f", $0) } ?? "n/a")/req",
                "Cache: \(String(format: "%.1f%%", metric.cacheHitRate))",
                "Total: \(self.costText(metric.totalCost))",
            ])
        }
        return true
    }

    private static func printInsightLine(_ parts: [String]) {
        print(parts.joined(separator: " - "))
    }

    private static func budgetInsightText(_ budget: BudgetInfo) -> String {
        let spent = String(format: "$%.2f", budget.spent)
        let limit = String(format: "$%.2f", budget.limit)
        let percentage = String(format: "%.1f", budget.percentage)
        return "Budget: \(spent)/\(limit) (\(percentage)%) [\(budget.status.rawValue)]"
    }

    private static func costText(_ cost: Double?) -> String {
        cost.map { String(format: "$%.2f", $0) } ?? "n/a"
    }

    private static func modelsText(_ models: [String]) -> String {
        models.isEmpty ? "no models" : models.joined(separator: ", ")
    }
}
