import Foundation
import OSLog

/// Persistent cache for aggregated ledger data. Stores daily summaries per provider
/// so the app never re-scans old JSONL files. Works like a deque — new days are
/// appended, historical days are immutable.
///
/// Storage: `~/Library/Application Support/Runic/ledger-cache/`
///   - `claude-daily.json`, `codex-daily.json`, etc.
///   - Each file: `{ "lastScanDate": "...", "dailies": [...] }`
public actor LedgerCache {
    public static let shared = LedgerCache()

    private static let log = Logger(subsystem: "com.sriinnu.athena.Runic", category: "ledger-cache")
    private let cacheDir: URL

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDir = appSupport.appendingPathComponent("Runic/ledger-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Load cached daily summaries for a provider. Returns instantly.
    public func loadCachedDailies(provider: String) -> CachedLedger? {
        let url = self.fileURL(provider: provider)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedLedger.self, from: data)
    }

    /// Save aggregated daily summaries for a provider.
    public func saveDailies(provider: String, ledger: CachedLedger) {
        let url = self.fileURL(provider: provider)
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        try? data.write(to: url, options: .atomic)
        Self.log.debug("Saved \(ledger.dailies.count) days for \(provider)")
    }

    /// Merge new daily entries into existing cache. Deque behavior:
    /// - Existing days are NOT overwritten (immutable history)
    /// - Today's entry is ACCUMULATED (adds to existing totals for partial scans)
    /// - New days are appended
    public func mergeDailies(provider: String, newDailies: [CachedDaily], scanDate: Date, todayKey: String? = nil) {
        var ledger = self.loadCachedDailies(provider: provider) ?? CachedLedger(
            lastScanDate: scanDate,
            lastFullScanDate: nil,
            dailies: [])

        let resolvedTodayKey = todayKey ?? Self.dayKey(for: Date())
        var existingByKey: [String: CachedDaily] = [:]
        for daily in ledger.dailies {
            existingByKey[daily.dayKey] = daily
        }

        for newDaily in newDailies {
            if newDaily.dayKey == resolvedTodayKey, let existing = existingByKey[newDaily.dayKey] {
                // Accumulate today's partial scan results onto existing totals.
                var mergedModels = Set(existing.modelsUsed)
                mergedModels.formUnion(newDaily.modelsUsed)
                existingByKey[newDaily.dayKey] = CachedDaily(
                    dayKey: newDaily.dayKey,
                    inputTokens: existing.inputTokens + newDaily.inputTokens,
                    outputTokens: existing.outputTokens + newDaily.outputTokens,
                    cacheCreationTokens: existing.cacheCreationTokens + newDaily.cacheCreationTokens,
                    cacheReadTokens: existing.cacheReadTokens + newDaily.cacheReadTokens,
                    costUSD: (existing.costUSD ?? 0) + (newDaily.costUSD ?? 0) > 0
                        ? (existing.costUSD ?? 0) + (newDaily.costUSD ?? 0) : nil,
                    requestCount: existing.requestCount + newDaily.requestCount,
                    modelsUsed: Array(mergedModels))
            } else if existingByKey[newDaily.dayKey] == nil {
                existingByKey[newDaily.dayKey] = newDaily
            }
        }

        ledger.dailies = existingByKey.values.sorted { $0.dayKey < $1.dayKey }
        ledger.lastScanDate = scanDate
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Mark that a full historical scan has been completed.
    public func markFullScanComplete(provider: String) {
        guard var ledger = self.loadCachedDailies(provider: provider) else { return }
        ledger.lastFullScanDate = Date()
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Whether a full historical scan has been done for this provider.
    public func hasFullScan(provider: String) -> Bool {
        self.loadCachedDailies(provider: provider)?.lastFullScanDate != nil
    }

    /// Date of last incremental scan (to know which files to scan next).
    public func lastScanDate(provider: String) -> Date? {
        self.loadCachedDailies(provider: provider)?.lastScanDate
    }

    // MARK: - Internal

    private func fileURL(provider: String) -> URL {
        self.cacheDir.appendingPathComponent("\(provider)-daily.json")
    }

    static func dayKey(for date: Date) -> String {
        self.dayKeyFormatter.string(from: date)
    }
}

// MARK: - Models

public struct CachedLedger: Codable, Sendable {
    public var lastScanDate: Date
    public var lastFullScanDate: Date?
    public var dailies: [CachedDaily]
}

public struct CachedDaily: Codable, Sendable {
    public let dayKey: String // "2026-03-23"
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let costUSD: Double?
    public let requestCount: Int
    public let modelsUsed: [String]

    private static let dayKeyParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    public var totalTokens: Int {
        self.inputTokens + self.outputTokens + self.cacheCreationTokens + self.cacheReadTokens
    }

    /// Convert to a UsageLedgerDailySummary for immediate display from cache.
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
