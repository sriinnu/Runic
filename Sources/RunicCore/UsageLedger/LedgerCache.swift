import Foundation
import OSLog

/// Persistent cache for aggregated ledger data. Stores daily summaries per provider
/// so the app does not need to re-scan old JSONL files on every refresh.
/// Normal menu refreshes treat existing historical days as frozen and replace
/// only today's aggregate; explicit full scans can still rebuild old days.
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

    public init(cacheDir: URL? = nil) {
        if let cacheDir {
            self.cacheDir = cacheDir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.cacheDir = appSupport.appendingPathComponent("Runic/ledger-cache", isDirectory: true)
        }
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

    /// Merge hot daily entries into the frozen daily cache.
    ///
    /// When `todayKey` is supplied, existing days before today are immutable:
    /// this is the fast relay path used by menu refreshes. Passing `nil`
    /// preserves full-rebuild behavior for tests and future backfill tools.
    public func mergeDailies(
        provider: String,
        newDailies: [CachedDaily],
        scanDate: Date,
        todayKey: String? = nil,
        coveredMaxAgeDays: Int? = nil)
    {
        var ledger = self.loadCachedDailies(provider: provider) ?? CachedLedger(
            lastScanDate: scanDate,
            lastFullScanDate: nil,
            coveredMaxAgeDays: nil,
            dailies: [])

        var existingByKey: [String: CachedDaily] = [:]
        for daily in ledger.dailies {
            existingByKey[daily.dayKey] = daily
        }

        for newDaily in newDailies {
            if let todayKey,
               newDaily.dayKey != todayKey,
               existingByKey[newDaily.dayKey] != nil
            {
                continue
            }
            existingByKey[newDaily.dayKey] = newDaily
        }

        ledger.dailies = existingByKey.values.sorted { $0.dayKey < $1.dayKey }
        self.updateScanMetadata(&ledger, scanDate: scanDate, coveredMaxAgeDays: coveredMaxAgeDays)
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Record that a provider was scanned even if it produced no new entries.
    public func markScanComplete(provider: String, scanDate: Date, coveredMaxAgeDays: Int? = nil) {
        var ledger = self.loadCachedDailies(provider: provider) ?? CachedLedger(
            lastScanDate: scanDate,
            lastFullScanDate: nil,
            coveredMaxAgeDays: nil,
            dailies: [])
        self.updateScanMetadata(&ledger, scanDate: scanDate, coveredMaxAgeDays: coveredMaxAgeDays)
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

    /// Largest bounded history window that has already been scanned.
    public func coveredMaxAgeDays(provider: String) -> Int? {
        self.loadCachedDailies(provider: provider)?.coveredMaxAgeDays
    }

    /// Best available coverage for old and new cache files.
    ///
    /// Older cache files do not have `coveredMaxAgeDays`; using their cached
    /// day count avoids one expensive post-upgrade rescan for established users.
    public func effectiveCoveredMaxAgeDays(provider: String) -> Int? {
        guard let ledger = self.loadCachedDailies(provider: provider) else { return nil }
        let covered = max(ledger.coveredMaxAgeDays ?? 0, ledger.dailies.count)
        return covered > 0 ? covered : nil
    }

    // MARK: - Internal

    private func fileURL(provider: String) -> URL {
        self.cacheDir.appendingPathComponent("\(provider)-daily.json")
    }

    private func updateScanMetadata(
        _ ledger: inout CachedLedger,
        scanDate: Date,
        coveredMaxAgeDays: Int?)
    {
        ledger.lastScanDate = scanDate
        if let coveredMaxAgeDays {
            ledger.coveredMaxAgeDays = max(ledger.coveredMaxAgeDays ?? 0, coveredMaxAgeDays)
            ledger.lastFullScanDate = scanDate
        }
    }

    static func dayKey(for date: Date) -> String {
        self.dayKeyFormatter.string(from: date)
    }
}

// MARK: - Models

public struct CachedLedger: Codable, Sendable {
    public var lastScanDate: Date
    public var lastFullScanDate: Date?
    public var coveredMaxAgeDays: Int?
    public var dailies: [CachedDaily]

    public init(
        lastScanDate: Date,
        lastFullScanDate: Date?,
        coveredMaxAgeDays: Int? = nil,
        dailies: [CachedDaily])
    {
        self.lastScanDate = lastScanDate
        self.lastFullScanDate = lastFullScanDate
        self.coveredMaxAgeDays = coveredMaxAgeDays
        self.dailies = dailies
    }
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
