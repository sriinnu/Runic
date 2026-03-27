import Foundation

public enum UsagePolicyAction: String, Sendable, Codable, Hashable, CaseIterable {
    case none
    case warn
    case softLimit
    case hardStop

    var severityRank: Int {
        switch self {
        case .none: 0
        case .warn: 1
        case .softLimit: 2
        case .hardStop: 3
        }
    }
}

public enum UsagePolicyAnomalySeverity: Int, Sendable, Codable, Hashable {
    case elevated = 1
    case high = 2
    case critical = 3
}

public struct UsagePolicyContext: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let observedSpendUSD: Double?
    public let projectedSpendUSD: Double?
    public let budgetLimitUSD: Double?
    public let anomalySeverity: UsagePolicyAnomalySeverity?

    public init(
        provider: UsageProvider,
        observedSpendUSD: Double?,
        projectedSpendUSD: Double?,
        budgetLimitUSD: Double?,
        anomalySeverity: UsagePolicyAnomalySeverity? = nil)
    {
        self.provider = provider
        self.observedSpendUSD = observedSpendUSD
        self.projectedSpendUSD = projectedSpendUSD
        self.budgetLimitUSD = budgetLimitUSD
        self.anomalySeverity = anomalySeverity
    }
}

public enum UsagePolicyCondition: Sendable, Codable, Hashable {
    case projectedBudgetOverrun(minimumPercent: Double)
    case actualBudgetOverrun
    case anomalySeverityAtLeast(UsagePolicyAnomalySeverity)
}

public struct UsagePolicyRule: Sendable, Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let enabled: Bool
    public let condition: UsagePolicyCondition
    public let action: UsagePolicyAction

    public init(
        id: String = UUID().uuidString,
        name: String,
        enabled: Bool = true,
        condition: UsagePolicyCondition,
        action: UsagePolicyAction)
    {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.condition = condition
        self.action = action
    }
}

public struct UsagePolicyRuleMatch: Sendable, Codable, Hashable {
    public let ruleID: String
    public let ruleName: String
    public let action: UsagePolicyAction
    public let reason: String

    public init(ruleID: String, ruleName: String, action: UsagePolicyAction, reason: String) {
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.action = action
        self.reason = reason
    }
}

public struct UsagePolicyDecision: Sendable, Codable, Hashable {
    public let action: UsagePolicyAction
    public let matches: [UsagePolicyRuleMatch]
    public let reasons: [String]

    public init(action: UsagePolicyAction, matches: [UsagePolicyRuleMatch], reasons: [String]) {
        self.action = action
        self.matches = matches
        self.reasons = reasons
    }

    public var shouldThrottle: Bool {
        self.action.severityRank >= UsagePolicyAction.softLimit.severityRank
    }

    public var shouldBlock: Bool {
        self.action == .hardStop
    }
}

public enum UsagePolicyEngine {
    public static func evaluate(
        context: UsagePolicyContext,
        rules: [UsagePolicyRule]) -> UsagePolicyDecision
    {
        var matches: [UsagePolicyRuleMatch] = []
        matches.reserveCapacity(rules.count)

        for rule in rules where rule.enabled {
            guard let reason = self.matchReason(for: rule.condition, context: context) else { continue }
            matches.append(UsagePolicyRuleMatch(
                ruleID: rule.id,
                ruleName: rule.name,
                action: rule.action,
                reason: reason))
        }

        guard !matches.isEmpty else {
            return UsagePolicyDecision(
                action: .none,
                matches: [],
                reasons: ["No policy rules matched."])
        }

        let strongestAction = matches
            .map(\.action)
            .max { $0.severityRank < $1.severityRank } ?? .none

        return UsagePolicyDecision(
            action: strongestAction,
            matches: matches,
            reasons: matches.map(\.reason))
    }

    private static func matchReason(
        for condition: UsagePolicyCondition,
        context: UsagePolicyContext) -> String?
    {
        switch condition {
        case let .projectedBudgetOverrun(minimumPercent):
            guard let budget = context.budgetLimitUSD, budget > 0 else { return nil }
            guard let projected = context.projectedSpendUSD, projected.isFinite else { return nil }
            let overrunUSD = projected - budget
            guard overrunUSD > 0 else { return nil }
            let overrunPercent = overrunUSD / budget
            guard overrunPercent >= max(0, minimumPercent) else { return nil }
            let percentText = "\(Int((overrunPercent * 100).rounded()))%"
            return "Projected spend \(UsageFormatter.usdString(projected)) is \(percentText) over budget \(UsageFormatter.usdString(budget))."

        case .actualBudgetOverrun:
            guard let budget = context.budgetLimitUSD, budget > 0 else { return nil }
            guard let observed = context.observedSpendUSD, observed.isFinite else { return nil }
            guard observed >= budget else { return nil }
            return "Observed spend \(UsageFormatter.usdString(observed)) reached budget \(UsageFormatter.usdString(budget))."

        case let .anomalySeverityAtLeast(required):
            guard let observed = context.anomalySeverity else { return nil }
            guard observed.rawValue >= required.rawValue else { return nil }
            return "Anomaly severity \(self.severityLabel(observed)) meets threshold \(self.severityLabel(required))."
        }
    }

    private static func severityLabel(_ severity: UsagePolicyAnomalySeverity) -> String {
        switch severity {
        case .elevated: "Elevated"
        case .high: "High"
        case .critical: "Critical"
        }
    }
}
