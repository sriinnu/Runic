import Foundation

// MARK: - TeamUsageSummary

/// Aggregated usage statistics for a team
public struct TeamUsageSummary: Codable, Sendable {
    public let teamID: String
    public let period: DateInterval
    public var totalTokens: Int
    public var totalCost: Double
    public var memberUsage: [String: MemberUsage] // UserID -> usage
    public var quotaUsedPercent: Double

    public init(
        teamID: String,
        period: DateInterval,
        totalTokens: Int = 0,
        totalCost: Double = 0.0,
        memberUsage: [String: MemberUsage] = [:],
        quotaUsedPercent: Double = 0.0)
    {
        self.teamID = teamID
        self.period = period
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.memberUsage = memberUsage
        self.quotaUsedPercent = quotaUsedPercent
    }
}

extension TeamUsageSummary {
    /// Get usage for a specific member
    public func usage(for userID: String) -> MemberUsage? {
        self.memberUsage[userID]
    }

    /// Top users by token consumption
    public func topUsers(limit: Int = 5) -> [(userID: String, usage: MemberUsage)] {
        self.memberUsage
            .sorted { $0.value.tokens > $1.value.tokens }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    /// Average tokens per member
    public var averageTokensPerMember: Int {
        guard !self.memberUsage.isEmpty else { return 0 }
        return self.totalTokens / self.memberUsage.count
    }

    /// Average cost per member
    public var averageCostPerMember: Double {
        guard !self.memberUsage.isEmpty else { return 0.0 }
        return self.totalCost / Double(self.memberUsage.count)
    }

    /// Check if team is approaching quota limit
    public var isApproachingQuota: Bool {
        self.quotaUsedPercent >= 80.0
    }

    /// Check if team has exceeded quota
    public var hasExceededQuota: Bool {
        self.quotaUsedPercent >= 100.0
    }

    /// Add or update member usage
    public mutating func updateUsage(for userID: String, usage: MemberUsage) {
        self.memberUsage[userID] = usage
        self.recalculateTotals()
    }

    /// Recalculate total tokens and cost from member usage
    private mutating func recalculateTotals() {
        self.totalTokens = self.memberUsage.values.reduce(0) { $0 + $1.tokens }
        self.totalCost = self.memberUsage.values.reduce(0.0) { $0 + $1.cost }
    }
}

// MARK: - MemberUsage

/// Usage statistics for an individual team member
public struct MemberUsage: Codable, Sendable {
    public let userID: String
    public var tokens: Int
    public var cost: Double
    public var requests: Int

    public init(
        userID: String,
        tokens: Int = 0,
        cost: Double = 0.0,
        requests: Int = 0)
    {
        self.userID = userID
        self.tokens = tokens
        self.cost = cost
        self.requests = requests
    }
}

extension MemberUsage {
    /// Average cost per request
    public var averageCostPerRequest: Double {
        guard self.requests > 0 else { return 0.0 }
        return self.cost / Double(self.requests)
    }

    /// Average tokens per request
    public var averageTokensPerRequest: Int {
        guard self.requests > 0 else { return 0 }
        return self.tokens / self.requests
    }

    /// Check if member has quota limit and percentage used
    public func quotaUsedPercent(limit: Int?) -> Double? {
        guard let limit, limit > 0 else { return nil }
        return (Double(self.tokens) / Double(limit)) * 100.0
    }

    /// Combine with another usage record
    public mutating func merge(with other: MemberUsage) {
        self.tokens += other.tokens
        self.cost += other.cost
        self.requests += other.requests
    }
}

// MARK: - TeamQuotaAllocation

/// Helper for managing quota allocation across team members
public struct TeamQuotaAllocation: Sendable {
    public let team: Team
    public let usage: TeamUsageSummary

    public init(team: Team, usage: TeamUsageSummary) {
        self.team = team
        self.usage = usage
    }

    /// Get remaining quota for a specific member
    public func remainingQuota(for userID: String) -> Int? {
        guard let membership = team.membership(for: userID),
              let limit = membership.quotaLimit
        else {
            return nil
        }

        let used = self.usage.usage(for: userID)?.tokens ?? 0
        return max(0, limit - used)
    }

    /// Check if a member can use more tokens
    public func canUseTokens(_ tokens: Int, userID: String) -> Bool {
        guard let remaining = remainingQuota(for: userID) else {
            // No individual limit, check team limit
            return self.usage.totalTokens + tokens <= self.team.totalQuota
        }
        return remaining >= tokens
    }

    /// Get members who have exceeded their quota
    public func membersExceedingQuota() -> [TeamMembership] {
        self.team.members.filter { membership in
            guard let limit = membership.quotaLimit else { return false }
            let used = self.usage.usage(for: membership.userID)?.tokens ?? 0
            return used > limit
        }
    }

    /// Get members approaching their quota (>80%)
    public func membersApproachingQuota() -> [TeamMembership] {
        self.team.members.filter { membership in
            guard let limit = membership.quotaLimit else { return false }
            let used = self.usage.usage(for: membership.userID)?.tokens ?? 0
            let percent = (Double(used) / Double(limit)) * 100.0
            return percent >= 80.0 && percent < 100.0
        }
    }
}
