import Foundation

public struct UsageLedgerReliabilityScore: Sendable, Codable, Hashable {
    public let score: Int
    public let grade: String
    public let summary: String
    public let primarySignal: String?
    public let signals: [String]

    public init(
        score: Int,
        grade: String,
        summary: String,
        primarySignal: String?,
        signals: [String])
    {
        self.score = score
        self.grade = grade
        self.summary = summary
        self.primarySignal = primarySignal
        self.signals = signals
    }
}

public struct UsageLedgerRoutingRecommendation: Sendable, Codable, Hashable {
    public let fromModel: String
    public let toModel: String
    public let shiftPercent: Int
    public let estimatedSavingsUSD: Double
    public let baselineCostPer1KUSD: Double
    public let candidateCostPer1KUSD: Double
    public let confidence: Double
    public let rationale: String

    public init(
        fromModel: String,
        toModel: String,
        shiftPercent: Int,
        estimatedSavingsUSD: Double,
        baselineCostPer1KUSD: Double,
        candidateCostPer1KUSD: Double,
        confidence: Double,
        rationale: String)
    {
        self.fromModel = fromModel
        self.toModel = toModel
        self.shiftPercent = shiftPercent
        self.estimatedSavingsUSD = estimatedSavingsUSD
        self.baselineCostPer1KUSD = baselineCostPer1KUSD
        self.candidateCostPer1KUSD = candidateCostPer1KUSD
        self.confidence = confidence
        self.rationale = rationale
    }
}

public enum UsageLedgerInsightsAdvisor {
    public static func reliabilityScore(
        provider _: UsageProvider,
        daily: UsageLedgerDailySummary?,
        activeBlock: UsageLedgerBlockSummary?,
        modelBreakdown: [UsageLedgerModelSummary],
        projectBreakdown: [UsageLedgerProjectSummary],
        providerError: String?,
        ledgerError: String?) -> UsageLedgerReliabilityScore?
    {
        let hasAnyData = daily != nil || activeBlock != nil || !modelBreakdown.isEmpty || !projectBreakdown.isEmpty
        let hasProviderError = !(providerError?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasLedgerError = !(ledgerError?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        if !hasAnyData, !hasProviderError, !hasLedgerError {
            return nil
        }

        var score = 100
        var signals: [String] = []

        if hasProviderError {
            score -= 35
            signals.append("Provider fetch errors detected.")
        }

        if hasLedgerError {
            score -= 25
            signals.append("Local ledger parsing/loading errors detected.")
        }

        if daily == nil {
            score -= 10
            signals.append("No stable daily usage snapshot yet.")
        }

        if activeBlock == nil {
            score -= 5
            signals.append("No active session block observed.")
        }

        if projectBreakdown.isEmpty {
            score -= 10
            signals.append("No project-level grouping is available.")
        } else {
            let unknownProjects = projectBreakdown.filter { $0.displayProjectName == "Unknown project" }.count
            let unknownRatio = Double(unknownProjects) / Double(max(1, projectBreakdown.count))
            if unknownRatio > 0.40 {
                score -= 10
                signals.append("Many entries cannot be mapped to stable project names.")
            } else if unknownRatio > 0.15 {
                score -= 5
                signals.append("Some entries still have weak project naming confidence.")
            }
        }

        if let daily, daily.totals.totalTokens > 0 {
            let cache = daily.totals.cacheCreationTokens + daily.totals.cacheReadTokens
            let cacheRatio = Double(cache) / Double(daily.totals.totalTokens)
            if cacheRatio >= 0.20 {
                score += 3
                signals.append("Healthy cache participation in daily traffic.")
            }
        }

        if modelBreakdown.count >= 2 {
            score += 2
            signals.append("Multiple active models provide routing flexibility.")
        }

        score = max(0, min(100, score))
        let grade: String
        let summary: String
        switch score {
        case 90...:
            grade = "A"
            summary = "Strong reliability."
        case 80...89:
            grade = "B"
            summary = "Good reliability with minor risk."
        case 70...79:
            grade = "C"
            summary = "Moderate reliability; monitor closely."
        case 60...69:
            grade = "D"
            summary = "Fragile reliability; remediation recommended."
        default:
            grade = "F"
            summary = "Unreliable state; immediate fixes recommended."
        }

        return UsageLedgerReliabilityScore(
            score: score,
            grade: grade,
            summary: summary,
            primarySignal: signals.first,
            signals: signals)
    }

    public static func routingRecommendation(
        modelBreakdown: [UsageLedgerModelSummary],
        shiftPercent: Double = 0.20) -> UsageLedgerRoutingRecommendation?
    {
        struct CostPoint {
            let model: String
            let tokens: Int
            let requests: Int
            let costPer1K: Double
        }

        let points: [CostPoint] = modelBreakdown.compactMap { summary in
            guard let cost = summary.totals.costUSD, cost > 0 else { return nil }
            let tokens = summary.totals.totalTokens
            guard tokens >= 500 else { return nil }
            let costPer1K = cost / (Double(tokens) / 1000.0)
            guard costPer1K.isFinite, costPer1K > 0 else { return nil }
            return CostPoint(
                model: summary.model,
                tokens: tokens,
                requests: summary.entryCount,
                costPer1K: costPer1K)
        }

        guard points.count >= 2 else { return nil }
        let sorted = points.sorted { $0.costPer1K < $1.costPer1K }
        guard let cheapest = sorted.first else { return nil }
        guard let mostExpensive = sorted.last, mostExpensive.model != cheapest.model else { return nil }

        let unitDelta = mostExpensive.costPer1K - cheapest.costPer1K
        guard unitDelta > 0.05 else { return nil }

        let effectiveShift = max(0.05, min(0.40, shiftPercent))
        let shiftedTokens = Int(Double(mostExpensive.tokens) * effectiveShift)
        guard shiftedTokens >= 250 else { return nil }

        let estimatedSavings = unitDelta * (Double(shiftedTokens) / 1000.0)
        guard estimatedSavings >= 0.01 else { return nil }

        let totalCostedTokens = points.reduce(0) { $0 + $1.tokens }
        let coverage = min(1.0, Double(totalCostedTokens) / 100_000.0)
        let confidence = max(0.30, min(0.95, 0.40 + (coverage * 0.55)))
        let shiftLabel = Int((effectiveShift * 100).rounded())

        let rationale = "Shift \(shiftLabel)% of \(mostExpensive.model) volume to \(cheapest.model) based on observed cost-per-1K."
        return UsageLedgerRoutingRecommendation(
            fromModel: mostExpensive.model,
            toModel: cheapest.model,
            shiftPercent: shiftLabel,
            estimatedSavingsUSD: estimatedSavings,
            baselineCostPer1KUSD: mostExpensive.costPer1K,
            candidateCostPer1KUSD: cheapest.costPer1K,
            confidence: confidence,
            rationale: rationale)
    }
}
