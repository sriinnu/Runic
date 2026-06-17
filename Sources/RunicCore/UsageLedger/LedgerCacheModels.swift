import Foundation

public struct CachedLedger: Codable, Sendable {
    public var schemaVersion: Int?
    public var lastScanDate: Date
    public var lastFullScanDate: Date?
    public var coveredMaxAgeDays: Int?
    public var dailies: [CachedDaily]
    /// One-time repair stamp. Builds before the additive catch-up fix advanced
    /// `lastScanDate` to today on a today-only scan without backfilling the days
    /// the app was closed during, so those days are missing and the normal
    /// gap-detection (which keys off `lastScanDate`) can't see the gap anymore.
    /// When this stamp is below the current heal version, the source runs one
    /// full-retention additive backfill, then writes the current version so it
    /// never repeats. Absent (nil) on caches written by older builds.
    public var catchUpHealVersion: Int?

    public init(
        schemaVersion: Int? = nil,
        lastScanDate: Date,
        lastFullScanDate: Date?,
        coveredMaxAgeDays: Int? = nil,
        dailies: [CachedDaily],
        catchUpHealVersion: Int? = nil)
    {
        self.schemaVersion = schemaVersion
        self.lastScanDate = lastScanDate
        self.lastFullScanDate = lastFullScanDate
        self.coveredMaxAgeDays = coveredMaxAgeDays
        self.dailies = dailies
        self.catchUpHealVersion = catchUpHealVersion
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
        // The relay is append-only, so read-order `sequence` IS true append order:
        // a later-appended record always wins. This is immune to system-clock
        // jumps, unlike wall-clock `writtenAt` — a backward NTP/DST correction
        // between two same-day scans could otherwise let an older snapshot win and
        // silently regress that day's totals. `sequence` is strictly increasing
        // within a read, so it never ties.
        return self.sequence > other.sequence
    }
}
