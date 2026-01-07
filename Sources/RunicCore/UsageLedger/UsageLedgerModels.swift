import Foundation

public struct UsageLedgerEntry: Sendable, Codable, Hashable {
    public enum Source: String, Sendable, Codable {
        case claudeLog
        case codexLog
        case api
        case cli
        case unknown
    }

    public let provider: UsageProvider
    public let timestamp: Date
    public let sessionID: String?
    public let projectID: String?
    public let model: String?
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let costUSD: Double?
    public let requestID: String?
    public let messageID: String?
    public let version: String?
    public let source: Source

    public init(
        provider: UsageProvider,
        timestamp: Date,
        sessionID: String?,
        projectID: String?,
        model: String?,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double?,
        requestID: String?,
        messageID: String?,
        version: String?,
        source: Source)
    {
        self.provider = provider
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.projectID = projectID
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
        self.requestID = requestID
        self.messageID = messageID
        self.version = version
        self.source = source
    }

    public var totalTokens: Int {
        self.inputTokens + self.outputTokens + self.cacheCreationTokens + self.cacheReadTokens
    }

    public var nonCacheTokens: Int {
        self.inputTokens + self.outputTokens
    }
}

public struct UsageLedgerTotals: Sendable, Codable, Hashable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let costUSD: Double?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double?)
    {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
    }

    public var totalTokens: Int {
        self.inputTokens + self.outputTokens + self.cacheCreationTokens + self.cacheReadTokens
    }

    public var nonCacheTokens: Int {
        self.inputTokens + self.outputTokens
    }
}

public struct UsageLedgerDailySummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let projectID: String?
    public let dayStart: Date
    public let dayKey: String
    public let totals: UsageLedgerTotals
    public let modelsUsed: [String]

    public init(
        provider: UsageProvider,
        projectID: String?,
        dayStart: Date,
        dayKey: String,
        totals: UsageLedgerTotals,
        modelsUsed: [String])
    {
        self.provider = provider
        self.projectID = projectID
        self.dayStart = dayStart
        self.dayKey = dayKey
        self.totals = totals
        self.modelsUsed = modelsUsed
    }
}

public struct UsageLedgerSessionSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let sessionID: String
    public let projectID: String?
    public let firstActivity: Date
    public let lastActivity: Date
    public let totals: UsageLedgerTotals
    public let modelsUsed: [String]
    public let versions: [String]

    public init(
        provider: UsageProvider,
        sessionID: String,
        projectID: String?,
        firstActivity: Date,
        lastActivity: Date,
        totals: UsageLedgerTotals,
        modelsUsed: [String],
        versions: [String])
    {
        self.provider = provider
        self.sessionID = sessionID
        self.projectID = projectID
        self.firstActivity = firstActivity
        self.lastActivity = lastActivity
        self.totals = totals
        self.modelsUsed = modelsUsed
        self.versions = versions
    }
}

public struct UsageLedgerBlockSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let sessionID: String?
    public let projectID: String?
    public let start: Date
    public let end: Date
    public let isActive: Bool
    public let entryCount: Int
    public let totals: UsageLedgerTotals
    public let tokensPerMinute: Double?
    public let projectedTotalTokens: Int?

    public init(
        provider: UsageProvider,
        sessionID: String?,
        projectID: String?,
        start: Date,
        end: Date,
        isActive: Bool,
        entryCount: Int,
        totals: UsageLedgerTotals,
        tokensPerMinute: Double?,
        projectedTotalTokens: Int?)
    {
        self.provider = provider
        self.sessionID = sessionID
        self.projectID = projectID
        self.start = start
        self.end = end
        self.isActive = isActive
        self.entryCount = entryCount
        self.totals = totals
        self.tokensPerMinute = tokensPerMinute
        self.projectedTotalTokens = projectedTotalTokens
    }
}

public struct UsageLedgerModelSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let projectID: String?
    public let model: String
    public let entryCount: Int
    public let totals: UsageLedgerTotals

    public init(
        provider: UsageProvider,
        projectID: String?,
        model: String,
        entryCount: Int,
        totals: UsageLedgerTotals)
    {
        self.provider = provider
        self.projectID = projectID
        self.model = model
        self.entryCount = entryCount
        self.totals = totals
    }
}

public struct UsageLedgerProjectSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let projectID: String?
    public let entryCount: Int
    public let totals: UsageLedgerTotals
    public let modelsUsed: [String]

    public init(
        provider: UsageProvider,
        projectID: String?,
        entryCount: Int,
        totals: UsageLedgerTotals,
        modelsUsed: [String])
    {
        self.provider = provider
        self.projectID = projectID
        self.entryCount = entryCount
        self.totals = totals
        self.modelsUsed = modelsUsed
    }
}
