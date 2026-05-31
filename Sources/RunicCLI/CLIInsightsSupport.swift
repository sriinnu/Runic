import Foundation
import RunicCore

extension RunicCLI {
    static func enrichProjectsWithBudget(_ summaries: [UsageLedgerProjectSummary]) -> [ProjectBudgetSummary] {
        let budgetsData = ProjectBudgetStore.load()
        let now = Date()
        let calendar = Calendar.current
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        return summaries.map { summary in
            guard let projectID = summary.projectID,
                  let budget = budgetsData.budgets[projectID],
                  budget.enabled
            else {
                return ProjectBudgetSummary(
                    provider: summary.provider,
                    projectID: summary.projectID,
                    entryCount: summary.entryCount,
                    totals: summary.totals,
                    modelsUsed: summary.modelsUsed,
                    budgetInfo: nil)
            }

            let spent = summary.totals.costUSD ?? 0.0
            let limit = budget.monthlyLimit
            let percentage = limit > 0 ? (spent / limit) * 100.0 : 0.0
            let status: BudgetStatus = {
                if percentage >= 100.0 { return .critical }
                if percentage >= budget.alertThreshold * 100.0 { return .warning }
                return .ok
            }()

            let budgetInfo = BudgetInfo(
                spent: spent,
                limit: limit,
                percentage: percentage,
                status: status,
                monthStart: currentMonthStart)

            return ProjectBudgetSummary(
                provider: summary.provider,
                projectID: summary.projectID,
                entryCount: summary.entryCount,
                totals: summary.totals,
                modelsUsed: summary.modelsUsed,
                budgetInfo: budgetInfo)
        }
    }

    static func modelCostComparison(entries: [UsageLedgerEntry]) -> [ModelCostComparison] {
        var modelStats: [String: ModelStatsAccumulator] = [:]

        for entry in entries {
            guard let model = entry.model, !model.isEmpty,
                  let cost = entry.costUSD, cost > 0 else { continue }

            let totalTokens = entry.totalTokens
            guard totalTokens > 0 else { continue }

            modelStats[model, default: ModelStatsAccumulator()].add(
                cost: cost,
                tokens: totalTokens)
        }

        let comparisons = modelStats.map { model, stats in
            ModelCostComparison(
                model: model,
                totalCost: stats.totalCost,
                totalTokens: stats.totalTokens,
                costPerToken: stats.totalCost / Double(stats.totalTokens),
                requestCount: stats.requestCount)
        }
        .sorted { $0.costPerToken > $1.costPerToken }

        return comparisons.enumerated().map { index, comparison in
            var ranked = comparison
            ranked.rank = index + 1
            return ranked
        }
    }

    static func modelEfficiencyMetrics(entries: [UsageLedgerEntry]) -> [ModelEfficiencyMetrics] {
        var modelStats: [String: EfficiencyStatsAccumulator] = [:]

        for entry in entries {
            guard let model = entry.model, !model.isEmpty else { continue }
            modelStats[model, default: EfficiencyStatsAccumulator()].add(entry)
        }

        return modelStats.map { model, stats in
            let tokensPerRequest = stats.requestCount > 0
                ? Double(stats.totalTokens) / Double(stats.requestCount)
                : 0.0
            let costPerRequest = stats.requestCount > 0 && stats.hasCost
                ? stats.totalCost / Double(stats.requestCount)
                : nil
            let cacheHitRate = stats.totalCacheableTokens > 0
                ? (Double(stats.cacheReadTokens) / Double(stats.totalCacheableTokens)) * 100.0
                : 0.0

            return ModelEfficiencyMetrics(
                model: model,
                requestCount: stats.requestCount,
                tokensPerRequest: tokensPerRequest,
                costPerRequest: costPerRequest,
                cacheHitRate: cacheHitRate,
                totalCost: stats.hasCost ? stats.totalCost : nil)
        }
        .sorted { $0.requestCount > $1.requestCount }
    }
}

enum BudgetStatus: String, Codable {
    case ok
    case warning
    case critical
}

struct BudgetInfo: Codable {
    let spent: Double
    let limit: Double
    let percentage: Double
    let status: BudgetStatus
    let monthStart: Date
}

struct ProjectBudgetSummary: Codable {
    let provider: UsageProvider
    let projectID: String?
    let entryCount: Int
    let totals: UsageLedgerTotals
    let modelsUsed: [String]
    let budgetInfo: BudgetInfo?
}

struct ModelCostComparison: Codable {
    let model: String
    let totalCost: Double
    let totalTokens: Int
    let costPerToken: Double
    let requestCount: Int
    var rank: Int?
}

struct ModelStatsAccumulator {
    var totalCost: Double = 0.0
    var totalTokens: Int = 0
    var requestCount: Int = 0

    mutating func add(cost: Double, tokens: Int) {
        self.totalCost += cost
        self.totalTokens += tokens
        self.requestCount += 1
    }
}

struct ModelEfficiencyMetrics: Codable {
    let model: String
    let requestCount: Int
    let tokensPerRequest: Double
    let costPerRequest: Double?
    let cacheHitRate: Double
    let totalCost: Double?
}

struct EfficiencyStatsAccumulator {
    var requestCount: Int = 0
    var totalTokens: Int = 0
    var totalCost: Double = 0.0
    var hasCost: Bool = false
    var cacheReadTokens: Int = 0
    var totalCacheableTokens: Int = 0

    mutating func add(_ entry: UsageLedgerEntry) {
        self.requestCount += 1
        self.totalTokens += entry.totalTokens
        if let cost = entry.costUSD {
            self.totalCost += cost
            self.hasCost = true
        }
        self.cacheReadTokens += entry.cacheReadTokens
        self.totalCacheableTokens += entry.cacheCreationTokens + entry.cacheReadTokens
    }
}
