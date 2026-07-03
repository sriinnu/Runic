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

    /// Day-key formatting that always tracks the LIVE current timezone.
    ///
    /// This used to be a bare `static let DateFormatter` that froze
    /// `TimeZone.current` at first use, while scan windows are computed from a
    /// fresh `Calendar.current` per scan. After a timezone change mid-run the
    /// two disagreed: entries could be labeled with day keys shifted by a day
    /// relative to the scan window, and replace-semantics day aggregates could
    /// shrink yesterday. The box re-checks the current timezone on every use so
    /// keys and windows stay in lockstep.
    static let dayKeyFormatterBox = LedgerDayKeyFormatterBox()

    /// In-actor memo of the parsed relay state per provider, validated against
    /// the relay file's (size, mtime) so external writers are still observed.
    /// One `loadEntries` cycle used to re-parse the same multi-MB relay JSONL
    /// 4-5 times; steady state is now one parse per actual file change.
    var relayStateMemo: [String: RelayStateMemoEntry] = [:]

    struct RelayStateMemoEntry {
        let sizeBytes: Int64
        let modifiedAt: Date?
        let state: UsageRelayMaterializedState
    }

    /// Providers whose one-time legacy cost-cache relay seeding has completed
    /// (in-memory mirror of the persisted `{provider}.legacy-seeded` stamp).
    var legacyCostSeedStamped: Set<String> = []

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
            try self.withProviderFileLock(provider: provider) {
                try data.write(to: url, options: .atomic)
            }
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
    ///
    /// `archiveBoundaryDayKey` bounds relay archiving WITHOUT freezing days:
    /// the gap catch-up passes `todayKey: nil` (gap days must REPLACE their
    /// aggregates) plus the current day key here, so the still-partial current
    /// day is never sealed into the relay (see `mergeDailies` body).
    public func mergeDailies(
        provider: String,
        newDailies: [CachedDaily],
        scanDate: Date,
        todayKey: String? = nil,
        archiveBoundaryDayKey: String? = nil,
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

        // Track which days this merge actually changes. Archiving every cached
        // day on every refresh re-wrote the entire history to the relay each
        // cycle (~86K redundant records/day, driving repeated compactions);
        // unchanged days are already durable in the daily cache file and are
        // seeded into the relay by `seedRelayFromLegacyCacheIfNeeded` when
        // missing, so only genuinely changed aggregates need a new snapshot.
        var changedDailies: [CachedDaily] = []
        for newDaily in newDailies {
            if let todayKey,
               newDaily.dayKey != todayKey,
               existingByKey[newDaily.dayKey] != nil
            {
                continue
            }
            if existingByKey[newDaily.dayKey] != newDaily {
                changedDailies.append(newDaily)
            }
            existingByKey[newDaily.dayKey] = newDaily
        }

        ledger.dailies = existingByKey.values.sorted { $0.dayKey < $1.dayKey }
        self.updateScanMetadata(&ledger, scanDate: scanDate, coveredMaxAgeDays: coveredMaxAgeDays)
        // Replace semantics preserved: each changed day gets a fresh
        // event+watermark snapshot, and the materializer always selects the
        // newest snapshot per day.
        //
        // Days at/after the seal boundary (today) are NEVER archived: relay
        // snapshots take precedence over the daily cache for their day on
        // every load, and the steady-state merge never re-archives today — so
        // an archived partial "today" would pin the whole day at the count it
        // had at archive time. The gap catch-up passes `todayKey: nil` (gap
        // days must REPLACE their aggregates) and fires on every morning
        // rollover (`scanGapDays` returns 2), which used to seal today's
        // partial aggregate into the relay daily; it now supplies
        // `archiveBoundaryDayKey` instead. A fully-nil boundary keeps
        // archive-everything rebuild semantics for backfill tools/tests.
        let sealBoundaryKey = todayKey ?? archiveBoundaryDayKey
        self.archiveDailySummariesAsRelayEvents(
            provider: provider,
            dailies: sealBoundaryKey.map { key in changedDailies.filter { $0.dayKey < key } } ?? changedDailies,
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

    /// Current one-time catch-up repair version. Bump to force every existing
    /// install to run one more full-retention rebuild on next refresh.
    /// v2: re-run as a deterministic `.rebuildHistory` (v1's additive heal could
    /// stamp itself done having captured nothing if a long scan was interrupted).
    static let catchUpHealVersion = 2

    /// Whether this provider still needs the one-time legacy catch-up repair.
    ///
    /// Only established installs (an existing cache file with prior coverage) are
    /// healed — a fresh install has no file and already does a full rebuild, so
    /// there's nothing to repair. Idempotent: the heal is an additive backfill,
    /// so if it's interrupted before being marked, re-running it next launch is
    /// harmless. See `catchUpHealVersion` on `CachedLedger`.
    public func needsCatchUpHeal(provider: String) -> Bool {
        // The stamp lives on the cache file. Common path: file exists -> compare.
        if let ledger = self.loadCacheFileLedger(provider: provider) {
            return (ledger.catchUpHealVersion ?? 0) < Self.catchUpHealVersion
        }
        // Edge: the cache file was deleted but relay data survived. That's exactly
        // the kind of established install that may carry the legacy gap, so still
        // heal it (markCatchUpHealed recreates the file with the stamp, so this
        // can't loop). A truly fresh install has neither file nor relay and is
        // handled by the fresh-install rebuild instead. The relay scan only runs
        // in this rare no-file case, so steady-state refresh pays nothing extra.
        return !self.materializedRelayState(provider: provider).touchedDayKeys.isEmpty
    }

    /// Record that the one-time catch-up repair has completed for this provider.
    public func markCatchUpHealed(provider: String) {
        var ledger = self.loadCacheFileLedger(provider: provider) ?? CachedLedger(
            lastScanDate: .distantPast,
            lastFullScanDate: nil,
            dailies: [])
        ledger.catchUpHealVersion = Self.catchUpHealVersion
        self.saveDailies(provider: provider, ledger: ledger)
    }

    /// Whole-day span from the last recorded scan up to `now`, counting today.
    ///
    /// Returns `1` when the provider was already scanned today (no catch-up
    /// needed), `nil` when it was never scanned, and `N > 1` when the last scan
    /// was `N - 1` days ago. Log sources use this to widen a normal refresh back
    /// to the last scan: a today-only refresh silently loses any day the app was
    /// closed during, so when usage happened on those days it never reaches the
    /// relay and the recent timeline goes blank. Anchoring to the last scan date
    /// (not "today") backfills exactly the missed window. `.distantPast` (an
    /// uninitialized ledger) is treated as "never scanned" so callers fall back
    /// to their fresh-install rebuild instead of scanning thousands of days.
    public func scanGapDays(provider: String, now: Date) -> Int? {
        guard let lastScan = self.loadCachedDailies(provider: provider)?.lastScanDate,
              lastScan > .distantPast
        else { return nil }
        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: lastScan)
        let today = calendar.startOfDay(for: now)
        guard let days = calendar.dateComponents([.day], from: lastDay, to: today).day else { return nil }
        return max(1, days + 1)
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
        self.dayKeyFormatterBox.string(from: date)
    }

    static func dayDate(fromKey dayKey: String) -> Date? {
        self.dayKeyFormatterBox.date(from: dayKey)
    }
}

/// Serializes a `yyyy-MM-dd` day-key formatter behind a lock and refreshes its
/// timezone from `TimeZone.current` on every use, so a timezone change mid-run
/// can never leave day keys frozen in the launch-time zone. Thread-safe:
/// day keys are derived from nonisolated log-source code as well as the actor.
final class LedgerDayKeyFormatterBox: @unchecked Sendable {
    private let lock = NSLock()
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    func string(from date: Date, timeZone: TimeZone = .current) -> String {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.refreshIfNeeded(timeZone: timeZone)
        return self.formatter.string(from: date)
    }

    func date(from dayKey: String, timeZone: TimeZone = .current) -> Date? {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.refreshIfNeeded(timeZone: timeZone)
        return self.formatter.date(from: dayKey)
    }

    private func refreshIfNeeded(timeZone: TimeZone) {
        if self.formatter.timeZone != timeZone {
            self.formatter.timeZone = timeZone
        }
    }
}
