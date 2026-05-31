import Foundation

public struct TeamShowbackTotals: Sendable, Codable, Hashable {
    public let totalTokens: Int
    public let totalCostUSD: Double
    public let totalRequests: Int
    public let memberCount: Int
    public let projectCount: Int

    public init(
        totalTokens: Int,
        totalCostUSD: Double,
        totalRequests: Int,
        memberCount: Int,
        projectCount: Int)
    {
        self.totalTokens = totalTokens
        self.totalCostUSD = totalCostUSD
        self.totalRequests = totalRequests
        self.memberCount = memberCount
        self.projectCount = projectCount
    }
}

public struct TeamShowbackProviderBreakdown: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let tokens: Int
    public let costUSD: Double
    public let requestCount: Int

    public init(provider: UsageProvider, tokens: Int, costUSD: Double, requestCount: Int) {
        self.provider = provider
        self.tokens = tokens
        self.costUSD = costUSD
        self.requestCount = requestCount
    }
}

public struct TeamShowbackMemberSummary: Sendable, Codable, Hashable {
    public let userID: String
    public let role: TeamRole?
    public let tokens: Int
    public let costUSD: Double
    public let requestCount: Int
    public let projectCount: Int

    public init(
        userID: String,
        role: TeamRole?,
        tokens: Int,
        costUSD: Double,
        requestCount: Int,
        projectCount: Int)
    {
        self.userID = userID
        self.role = role
        self.tokens = tokens
        self.costUSD = costUSD
        self.requestCount = requestCount
        self.projectCount = projectCount
    }
}

public struct TeamShowbackProjectSummary: Sendable, Codable, Hashable {
    public let projectID: String
    public let ownerUserID: String
    public let ownerRole: TeamRole?
    public let tokens: Int
    public let costUSD: Double
    public let requestCount: Int
    public let providers: [TeamShowbackProviderBreakdown]

    public init(
        projectID: String,
        ownerUserID: String,
        ownerRole: TeamRole?,
        tokens: Int,
        costUSD: Double,
        requestCount: Int,
        providers: [TeamShowbackProviderBreakdown])
    {
        self.projectID = projectID
        self.ownerUserID = ownerUserID
        self.ownerRole = ownerRole
        self.tokens = tokens
        self.costUSD = costUSD
        self.requestCount = requestCount
        self.providers = providers
    }
}

public struct TeamShowbackProviderSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let tokens: Int
    public let costUSD: Double
    public let requestCount: Int
    public let memberCount: Int
    public let projectCount: Int

    public init(
        provider: UsageProvider,
        tokens: Int,
        costUSD: Double,
        requestCount: Int,
        memberCount: Int,
        projectCount: Int)
    {
        self.provider = provider
        self.tokens = tokens
        self.costUSD = costUSD
        self.requestCount = requestCount
        self.memberCount = memberCount
        self.projectCount = projectCount
    }
}

public struct TeamShowbackReport: Sendable, Codable, Hashable {
    public let teamID: String
    public let teamName: String
    public let generatedAt: Date
    public let period: DateInterval
    public let totals: TeamShowbackTotals
    public let members: [TeamShowbackMemberSummary]
    public let projects: [TeamShowbackProjectSummary]
    public let providers: [TeamShowbackProviderSummary]

    public init(
        teamID: String,
        teamName: String,
        generatedAt: Date,
        period: DateInterval,
        totals: TeamShowbackTotals,
        members: [TeamShowbackMemberSummary],
        projects: [TeamShowbackProjectSummary],
        providers: [TeamShowbackProviderSummary])
    {
        self.teamID = teamID
        self.teamName = teamName
        self.generatedAt = generatedAt
        self.period = period
        self.totals = totals
        self.members = members
        self.projects = projects
        self.providers = providers
    }
}

public struct TeamShowbackExportBundle: Sendable, Hashable {
    public let report: TeamShowbackReport
    public let json: String
    public let csv: String

    public init(report: TeamShowbackReport, json: String, csv: String) {
        self.report = report
        self.json = json
        self.csv = csv
    }
}
