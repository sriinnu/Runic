import Foundation

public enum UsageLedgerOperationKind: String, Sendable, Codable, Hashable, CaseIterable {
    case inference
    case compaction
    case tool
    case unknown
}

public enum UsageLedgerLogScanMode: Sendable, Equatable {
    case refreshToday
    case rebuildHistory(maxAgeDays: Int)
}

public struct UsageLedgerEntry: Sendable, Codable, Hashable {
    public enum Source: String, Sendable, Codable {
        case claudeLog
        case codexLog
        case api
        case cli
        case openTelemetry
        case localProbe
        case unknown
    }

    public let provider: UsageProvider
    public let timestamp: Date
    public let sessionID: String?
    public let projectID: String?
    public let projectName: String?
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
    public let operationKind: UsageLedgerOperationKind?
    public let tokenProvenance: MetricProvenance?
    public let costProvenance: MetricProvenance?
    public let sourceFingerprint: String?

    public init(
        provider: UsageProvider,
        timestamp: Date,
        sessionID: String?,
        projectID: String?,
        projectName: String? = nil,
        model: String?,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double?,
        requestID: String?,
        messageID: String?,
        version: String?,
        source: Source,
        operationKind: UsageLedgerOperationKind? = nil,
        tokenProvenance: MetricProvenance? = nil,
        costProvenance: MetricProvenance? = nil,
        sourceFingerprint: String? = nil)
    {
        self.provider = provider
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.projectID = projectID
        self.projectName = projectName
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
        self.operationKind = operationKind
        self.tokenProvenance = tokenProvenance
        self.costProvenance = costProvenance
        self.sourceFingerprint = sourceFingerprint
    }

    public var totalTokens: Int {
        self.inputTokens + self.outputTokens + self.cacheCreationTokens + self.cacheReadTokens
    }

    public var nonCacheTokens: Int {
        self.inputTokens + self.outputTokens
    }

    public var resolvedOperationKind: UsageLedgerOperationKind {
        self.operationKind ?? .inference
    }

    public var isCompaction: Bool {
        self.resolvedOperationKind == .compaction
    }
}

public struct UsageLedgerTotals: Sendable, Codable, Hashable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let costUSD: Double?
    public let tokenProvenance: MetricProvenance?
    public let costProvenance: MetricProvenance?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double?,
        tokenProvenance: MetricProvenance? = nil,
        costProvenance: MetricProvenance? = nil)
    {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
        self.tokenProvenance = tokenProvenance
        self.costProvenance = costProvenance
    }

    public var totalTokens: Int {
        self.inputTokens + self.outputTokens + self.cacheCreationTokens + self.cacheReadTokens
    }

    public var nonCacheTokens: Int {
        self.inputTokens + self.outputTokens
    }
}

public struct UsageLedgerCompactionSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let eventCount: Int
    public let totals: UsageLedgerTotals
    public let lastEventAt: Date

    public init(provider: UsageProvider, eventCount: Int, totals: UsageLedgerTotals, lastEventAt: Date) {
        self.provider = provider
        self.eventCount = eventCount
        self.totals = totals
        self.lastEventAt = lastEventAt
    }
}
