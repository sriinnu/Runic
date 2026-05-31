import Foundation

public struct CachedLedger: Codable, Sendable {
    public var schemaVersion: Int?
    public var lastScanDate: Date
    public var lastFullScanDate: Date?
    public var coveredMaxAgeDays: Int?
    public var dailies: [CachedDaily]

    public init(
        schemaVersion: Int? = nil,
        lastScanDate: Date,
        lastFullScanDate: Date?,
        coveredMaxAgeDays: Int? = nil,
        dailies: [CachedDaily])
    {
        self.schemaVersion = schemaVersion
        self.lastScanDate = lastScanDate
        self.lastFullScanDate = lastFullScanDate
        self.coveredMaxAgeDays = coveredMaxAgeDays
        self.dailies = dailies
    }
}

public struct CachedDaily: Codable, Sendable {
    public let dayKey: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let costUSD: Double?
    public let requestCount: Int
    public let modelsUsed: [String]

    private static let dayKeyParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    public init(
        dayKey: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int,
        costUSD: Double?,
        requestCount: Int,
        modelsUsed: [String])
    {
        self.dayKey = dayKey
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
        self.requestCount = requestCount
        self.modelsUsed = modelsUsed
    }

    public var totalTokens: Int {
        self.inputTokens + self.outputTokens + self.cacheCreationTokens + self.cacheReadTokens
    }

    public func toLedgerDailySummary(provider: UsageProvider) -> UsageLedgerDailySummary? {
        guard let dayStart = Self.dayKeyParser.date(from: self.dayKey) else { return nil }
        return UsageLedgerDailySummary(
            provider: provider,
            projectID: nil,
            dayStart: dayStart,
            dayKey: self.dayKey,
            totals: UsageLedgerTotals(
                inputTokens: self.inputTokens,
                outputTokens: self.outputTokens,
                cacheCreationTokens: self.cacheCreationTokens,
                cacheReadTokens: self.cacheReadTokens,
                costUSD: self.costUSD),
            modelsUsed: self.modelsUsed)
    }
}

public struct UsageRelaySourceWatermark: Codable, Sendable, Hashable {
    public let dayKey: String?
    public let sourceKind: String
    public let sourceID: String
    public let sourceFingerprint: String
    public let path: String?
    public let modifiedAt: Date?
    public let sizeBytes: Int64?

    public init(
        dayKey: String? = nil,
        sourceKind: String,
        sourceID: String,
        sourceFingerprint: String,
        path: String? = nil,
        modifiedAt: Date? = nil,
        sizeBytes: Int64? = nil)
    {
        self.dayKey = dayKey
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.sourceFingerprint = sourceFingerprint
        self.path = path
        self.modifiedAt = modifiedAt
        self.sizeBytes = sizeBytes
    }
}

enum UsageRelayRecordType: String {
    case event
    case watermark
}

struct UsageRelayRecord: Codable {
    let schemaVersion: Int
    let recordType: String
    let provider: String
    let writtenAt: Date
    let event: UsageRelayEvent?
    let watermark: UsageRelayWatermark?
}

struct UsageRelayEvent: Codable {
    let eventID: String
    let snapshotID: String
    let provider: String
    let timestamp: Date
    let dayKey: String
    let sessionID: String?
    let projectID: String?
    let projectName: String?
    let model: String?
    let modelsUsed: [String]?
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
    let costUSD: Double?
    let requestCount: Int?
    let requestID: String?
    let messageID: String?
    let version: String?
    let source: String
    let operationKind: String?
    let tokenProvenance: MetricProvenance?
    let costProvenance: MetricProvenance?
    let sourceFingerprint: String?
}

struct UsageRelayWatermark: Codable {
    let snapshotID: String
    let dayKey: String
    let sourceKind: String
    let sourceID: String
    let sourceFingerprint: String
    let path: String?
    let modifiedAt: Date?
    let sizeBytes: Int64?
    let scannedAt: Date
}

struct UsageRelayMaterializedState {
    let dailies: [CachedDaily]
    let touchedDayKeys: Set<String>
}

struct UsageRelaySnapshotMarker {
    let snapshotID: String
    let writtenAt: Date
    let sequence: Int

    func isNewer(than other: UsageRelaySnapshotMarker?) -> Bool {
        guard let other else { return true }
        if self.writtenAt != other.writtenAt {
            return self.writtenAt > other.writtenAt
        }
        return self.sequence > other.sequence
    }
}
