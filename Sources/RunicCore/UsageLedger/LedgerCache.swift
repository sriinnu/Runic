import Foundation
import OSLog

/// Persistent cache for aggregated ledger data. Stores daily summaries per provider
/// so the app does not need to re-scan old JSONL files on every refresh.
/// Normal menu refreshes treat existing historical days as frozen and replace
/// only today's aggregate; explicit full scans can still rebuild old days.
///
/// Storage:
///   - `~/Library/Application Support/Runic/ledger-cache/{provider}-daily.json`
///   - `~/Library/Application Support/Runic/relay/{provider}-events.jsonl`
///
/// The JSON cache is a materialized view. The relay JSONL is Runic-owned
/// normalized event memory with scan watermarks, so provider JSONLs only need
/// to be read for today's live deltas.
public actor LedgerCache {
    public static let shared = LedgerCache()

    static let cacheSchemaVersion = 3
    static let relaySchemaVersion = 3
    static let maxTrustedLegacyDailyTokens = 100_000_000
    static let maxTrustedLegacyDailyRequests = 50000
    static let log = Logger(subsystem: "com.sriinnu.athena.Runic", category: "ledger-cache")
    let cacheDir: URL
    let relayDir: URL
    let legacyCostCacheRoot: URL?

    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    public init(cacheDir: URL? = nil, relayDir: URL? = nil, legacyCostCacheRoot: URL? = nil) {
        if let cacheDir {
            self.legacyCostCacheRoot = legacyCostCacheRoot
                ?? cacheDir.appendingPathComponent("legacy-cost-cache", isDirectory: true)
            self.cacheDir = cacheDir
            self.relayDir = relayDir ?? cacheDir.appendingPathComponent("relay", isDirectory: true)
        } else {
            self.legacyCostCacheRoot = legacyCostCacheRoot
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let runicRoot = appSupport.appendingPathComponent("Runic", isDirectory: true)
            self.cacheDir = runicRoot.appendingPathComponent("ledger-cache", isDirectory: true)
            self.relayDir = relayDir ?? runicRoot.appendingPathComponent("relay", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: self.relayDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Load cached daily summaries for a provider. Returns instantly.
    public func loadCachedDailies(provider: String) -> CachedLedger? {
        let url = self.fileURL(provider: provider)
        let decoded: CachedLedger? = if let data = try? Data(contentsOf: url) {
            try? JSONDecoder().decode(CachedLedger.self, from: data)
        } else {
            nil
        }

        let relayState = self.materializedRelayState(provider: provider)
        guard decoded != nil || !relayState.touchedDayKeys.isEmpty else { return nil }

        var ledger = decoded ?? CachedLedger(
            lastScanDate: .distantPast,
            lastFullScanDate: nil,
            coveredMaxAgeDays: nil,
            dailies: [])

        if (ledger.schemaVersion ?? 0) < Self.cacheSchemaVersion {
            ledger.dailies = ledger.dailies.filter {
                Self.isTrustedLegacyDaily(provider: provider, daily: $0)
            }
        }

        if !relayState.touchedDayKeys.isEmpty {
            var byDay = Dictionary(uniqueKeysWithValues: ledger.dailies.map { ($0.dayKey, $0) })
            for dayKey in relayState.touchedDayKeys {
                byDay.removeValue(forKey: dayKey)
            }
            for daily in relayState.dailies {
                byDay[daily.dayKey] = daily
            }
            ledger.dailies = byDay.values.sorted { $0.dayKey < $1.dayKey }
        }

        return ledger
    }

    /// Save aggregated daily summaries for a provider.
    public func saveDailies(provider: String, ledger: CachedLedger) {
        let url = self.fileURL(provider: provider)
        var versionedLedger = ledger
        versionedLedger.schemaVersion = Self.cacheSchemaVersion
        do {
            let data = try JSONEncoder().encode(versionedLedger)
            try data.write(to: url, options: .atomic)
            Self.log.debug("Saved \(ledger.dailies.count) days for \(provider)")
        } catch {
            // A silently-dropped write loses freshly-merged coverage and forces an
            // expensive rebuild next launch; surface it so it's diagnosable.
            Self.log.warning("Failed to save daily cache for \(provider): \(error.localizedDescription)")
        }
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
        self.archiveDailySummariesAsRelayEvents(
            provider: provider,
            dailies: todayKey.map { key in ledger.dailies.filter { $0.dayKey < key } } ?? ledger.dailies,
            writtenAt: scanDate)
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Merge normalized usage events into the relay and refresh the daily materialized view.
    public func mergeEntries(
        provider: String,
        entries: [UsageLedgerEntry],
        scanDate: Date,
        todayKey: String? = nil,
        coveredMaxAgeDays: Int? = nil,
        sourceWatermarks: [UsageRelaySourceWatermark] = [])
    {
        self.seedRelayFromLegacyCacheIfNeeded(provider: provider, todayKey: todayKey, writtenAt: scanDate)
        guard self.archiveEntriesAsRelayEvents(
            provider: provider,
            entries: entries,
            scanDate: scanDate,
            todayKey: todayKey,
            sourceWatermarks: sourceWatermarks)
        else {
            return
        }

        var ledger = self.loadCacheFileLedger(provider: provider) ?? CachedLedger(
            lastScanDate: scanDate,
            lastFullScanDate: nil,
            coveredMaxAgeDays: nil,
            dailies: [])
        let relayState = self.materializedRelayState(provider: provider)
        var existingByKey = Dictionary(uniqueKeysWithValues: ledger.dailies.map { ($0.dayKey, $0) })
        let touchedDayKeys = relayState.touchedDayKeys.union(Self.touchedDayKeys(
            entries: entries,
            todayKey: todayKey,
            sourceWatermarks: sourceWatermarks))
        for dayKey in touchedDayKeys {
            existingByKey.removeValue(forKey: dayKey)
        }
        for daily in relayState.dailies {
            existingByKey[daily.dayKey] = daily
        }
        ledger.dailies = existingByKey.values.sorted { $0.dayKey < $1.dayKey }
        self.updateScanMetadata(&ledger, scanDate: scanDate, coveredMaxAgeDays: coveredMaxAgeDays)
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Seed the event relay from legacy daily/cache stores without marking new coverage.
    public func migrateLegacyRelaySeedsIfNeeded(provider: String, scanDate: Date, todayKey: String? = nil) {
        self.seedRelayFromLegacyCacheIfNeeded(provider: provider, todayKey: todayKey, writtenAt: scanDate)
    }

    /// Record that a provider was scanned even if it produced no new entries.
    public func markScanComplete(
        provider: String,
        scanDate: Date,
        coveredMaxAgeDays: Int? = nil,
        todayKey: String? = nil)
    {
        var ledger = self.loadCachedDailies(provider: provider) ?? CachedLedger(
            lastScanDate: scanDate,
            lastFullScanDate: nil,
            coveredMaxAgeDays: nil,
            dailies: [])
        self.updateScanMetadata(&ledger, scanDate: scanDate, coveredMaxAgeDays: coveredMaxAgeDays)
        self.seedRelayFromLegacyCacheIfNeeded(provider: provider, todayKey: todayKey, writtenAt: scanDate)
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

    /// Location of Runic's append-only relay history for diagnostics/tests.
    public func relayHistoryFileURL(provider: String) -> URL {
        self.relayFileURL(provider: provider)
    }

    public static func dayKey(for date: Date) -> String {
        self.dayKeyFormatter.string(from: date)
    }
}
