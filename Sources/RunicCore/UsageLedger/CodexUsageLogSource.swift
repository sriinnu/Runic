import Foundation

public struct CodexUsageLogSource: UsageLedgerSource, @unchecked Sendable {
    public enum CodexUsageLogError: LocalizedError, Sendable {
        case noSessionsDirectory
        case readFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noSessionsDirectory:
                "No Codex sessions directory found."
            case let .readFailed(reason):
                "Failed to read Codex usage logs: \(reason)"
            }
        }
    }

    private let environment: [String: String]
    private let fileManager: FileManager
    private let sessionsRoot: URL?
    private let now: Date
    private let log: RunicLogger
    private let cache: LedgerCache
    private let scanMode: UsageLedgerLogScanMode
    private let maxAgeDays: Int?

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        sessionsRoot: URL? = nil,
        maxAgeDays: Int? = 3,
        now: Date = Date(),
        log: RunicLogger = RunicLog.logger("codex-usage-ledger"),
        cache: LedgerCache = .shared,
        scanMode: UsageLedgerLogScanMode = .refreshToday)
    {
        self.environment = environment
        self.fileManager = fileManager
        self.sessionsRoot = sessionsRoot
        self.now = now
        self.log = log
        self.cache = cache
        self.scanMode = scanMode
        self.maxAgeDays = maxAgeDays
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        let root = try self.resolveSessionsRoot()
        let todayKey = LedgerCache.dayKey(for: self.now)
        let healing = await self.cache.needsCatchUpHeal(provider: "codex")
        let scanMode = await self.resolvedScanMode(healing: healing)
        let catchUpDays = await self.catchUpDays(scanMode: scanMode)
        let window = self.scanWindow(todayKey: todayKey, scanMode: scanMode, catchUpDays: catchUpDays)
        // A rebuild (fresh install, explicit, or the one-time heal) fully covers the
        // window, so stamp the heal too — otherwise the next refresh would heal again.
        let isRebuild: Bool = if case .rebuildHistory = scanMode { true } else { false }
        let markHealed = healing || isRebuild

        // Relay contract: normal refresh never reopens historical provider
        // JSONLs. Explicit rebuild mode is the repair path that opts into
        // historical reads and commits empty day snapshots for missing raw data.
        let cache = self.cache
        let filesToScan = self.listSessionFiles(
            root: root,
            minDate: window.minDate,
            maxAgeDays: window.fileMaxAgeDays)

        if filesToScan.isEmpty {
            await cache.mergeEntries(
                provider: "codex",
                entries: [],
                scanDate: self.now,
                todayKey: window.relayTodayKey,
                coveredMaxAgeDays: window.coveredMaxAgeDays,
                sourceWatermarks: window.completionWatermarks)
            if markHealed { await cache.markCatchUpHealed(provider: "codex") }
            return []
        }

        var entries: [UsageLedgerEntry] = []
        var seenKeys = Set<String>()
        var sourceWatermarks = window.completionWatermarks
        var readFailures: [String] = []

        let parser = CodexUsageLogParser()
        for file in filesToScan {
            do {
                let parsed = try parser.parseFile(
                    file,
                    minDate: window.minDate,
                    dayKey: window.fileWatermarkDayKey,
                    seenKeys: &seenKeys)
                entries.append(contentsOf: parsed.entries)
                sourceWatermarks.append(parsed.watermark)
            } catch {
                self.log.warning("Codex usage log read failed", metadata: [
                    "file": file.url.path,
                    "error": error.localizedDescription,
                ])
                readFailures.append(file.url.path)
            }
        }

        if !readFailures.isEmpty {
            // A live Codex session can rewrite a rollout file mid-scan. Don't throw
            // away every other file's history because one was busy — keep what
            // parsed; the busy file is re-read on the next refresh. Only fail when
            // nothing could be read at all.
            self.log.warning("Codex usage log: skipped busy file(s) during scan", metadata: [
                "skipped": "\(readFailures.count)",
                "parsedEntries": "\(entries.count)",
            ])
            if entries.isEmpty {
                throw CodexUsageLogError.readFailed(readFailures.joined(separator: ", "))
            }

            // A partial scan must NOT seal any day as empty: a day that produced no
            // entries may only look empty because its file was busy, and an empty
            // snapshot tells the relay to clear that day. Keep watermarks only for
            // days that actually produced entries, so untouched days retain their
            // cached history instead of being silently erased. (On a clean scan
            // this block doesn't run, so genuine empty-day clears still work.)
            let daysWithEntries = Set(entries.map { LedgerCache.dayKey(for: $0.timestamp) })
            sourceWatermarks = sourceWatermarks.filter { watermark in
                guard let dayKey = watermark.dayKey else { return true }
                return daysWithEntries.contains(dayKey)
            }
        }

        await cache.mergeEntries(
            provider: "codex",
            entries: entries,
            scanDate: self.now,
            todayKey: window.relayTodayKey,
            coveredMaxAgeDays: window.coveredMaxAgeDays,
            sourceWatermarks: sourceWatermarks)

        if markHealed { await cache.markCatchUpHealed(provider: "codex") }
        return entries
    }

    private struct ScanWindow {
        let minDate: Date
        let fileMaxAgeDays: Int?
        let relayTodayKey: String?
        let coveredMaxAgeDays: Int?
        let completionWatermarks: [UsageRelaySourceWatermark]
        let fileWatermarkDayKey: String?
    }

    /// Explicit rebuild always wins; otherwise rebuild once when no history is
    /// cached at all (fresh install / cleared cache), then stay today-only.
    private func resolvedScanMode(healing: Bool) async -> UsageLedgerLogScanMode {
        if case .rebuildHistory = self.scanMode { return self.scanMode }
        let requested = max(1, self.maxAgeDays ?? 1)
        guard requested > 1 else { return self.scanMode }
        if await self.cache.effectiveCoveredMaxAgeDays(provider: "codex") == nil {
            return .rebuildHistory(maxAgeDays: requested)
        }
        // The one-time legacy repair runs as a real rebuild, not an additive
        // refresh: a rebuild deterministically backfills the whole retention window
        // (and seals genuinely-empty days), whereas an interrupted additive heal
        // could stamp itself done having captured nothing, then never retry.
        if healing {
            return .rebuildHistory(maxAgeDays: requested)
        }
        return self.scanMode
    }

    /// How many days back a normal (`.refreshToday`) scan should reach.
    ///
    /// A today-only refresh silently loses any day the app was closed during: if
    /// Codex was used while Runic wasn't refreshing, that day is never scanned
    /// and never reaches the relay, blanking the recent timeline. Widening the
    /// window back to the last scan date backfills exactly the missed days. In
    /// steady state the last scan is today, so this is 1 (today-only) and costs
    /// nothing. Bounded by the retention window. Unlike `.rebuildHistory`, this
    /// catch-up is *additive*: the wider window in `scanWindow` seals no empty
    /// days, so a gap day whose raw logs have since rotated away keeps its
    /// existing relay aggregate instead of being erased. `retention == 1`
    /// intentionally has no catch-up (today is the only renderable day anyway).
    private func catchUpDays(scanMode: UsageLedgerLogScanMode) async -> Int {
        guard case .refreshToday = scanMode else { return 1 }
        let requested = max(1, self.maxAgeDays ?? 1)
        guard requested > 1 else { return 1 }
        let gap = await self.cache.scanGapDays(provider: "codex", now: self.now) ?? 1
        return min(max(1, gap), requested)
    }

    private func scanWindow(todayKey: String, scanMode: UsageLedgerLogScanMode, catchUpDays: Int) -> ScanWindow {
        let calendar = Calendar.current
        switch scanMode {
        case .refreshToday:
            // Widen the file window back over any gap (app closed while Codex was
            // used) so missed days are backfilled. Additive on purpose: no
            // completion watermarks and a nil file-watermark day key mean only
            // days that actually produced entries (plus today, the mutable day)
            // are touched — a gap day whose raw logs have rotated away keeps its
            // existing relay aggregate rather than being sealed empty.
            let days = max(1, catchUpDays)
            let todayStart = calendar.startOfDay(for: self.now)
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart
            return ScanWindow(
                minDate: start,
                fileMaxAgeDays: days,
                relayTodayKey: todayKey,
                coveredMaxAgeDays: nil,
                // Only TODAY carries a completion watermark, so today is always
                // re-materialized — cleared when it has genuinely gone to zero,
                // even on a multi-day catch-up where another day has usage.
                // Historical gap days deliberately get none (additive: untouched
                // days keep their relay aggregate). On a partial scan the busy-file
                // filter drops this watermark when today produced no entries, so a
                // merely-busy today is preserved rather than wrongly cleared.
                completionWatermarks: [
                    UsageRelaySourceWatermark(
                        dayKey: todayKey,
                        sourceKind: "codex-today",
                        sourceID: "today:codex:\(todayKey)",
                        sourceFingerprint: "today:codex:\(todayKey):\(Int(self.now.timeIntervalSince1970))"),
                ],
                fileWatermarkDayKey: nil)
        case let .rebuildHistory(maxAgeDays):
            let days = max(1, maxAgeDays)
            let todayStart = calendar.startOfDay(for: self.now)
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart
            let dayKeys = (0..<days).compactMap { offset -> String? in
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                return LedgerCache.dayKey(for: date)
            }
            let watermarks = dayKeys.map { dayKey in
                UsageRelaySourceWatermark(
                    dayKey: dayKey,
                    sourceKind: "codex-jsonl-rebuild",
                    sourceID: "rebuild:codex:\(dayKey)",
                    sourceFingerprint: "rebuild:codex:\(dayKey):\(Int(self.now.timeIntervalSince1970))")
            }
            return ScanWindow(
                minDate: start,
                fileMaxAgeDays: days,
                relayTodayKey: nil,
                coveredMaxAgeDays: days,
                completionWatermarks: watermarks,
                fileWatermarkDayKey: nil)
        }
    }

    private func resolveSessionsRoot() throws -> URL {
        if let sessionsRoot, self.fileManager.directoryExists(at: sessionsRoot) {
            return sessionsRoot.standardizedFileURL
        }

        let env = self.environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true).appendingPathComponent("sessions", isDirectory: true)
            if self.fileManager.directoryExists(at: url) {
                return url.standardizedFileURL
            }
        }

        let home = self.fileManager.homeDirectoryForCurrentUser
        let url = home
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        if self.fileManager.directoryExists(at: url) {
            return url.standardizedFileURL
        }

        throw CodexUsageLogError.noSessionsDirectory
    }

    private func listSessionFiles(root: URL, minDate: Date?, maxAgeDays: Int?) -> [CodexUsageSessionFile] {
        var results: [CodexUsageSessionFile] = []

        let calendar = Calendar.current
        if let maxAgeDays, maxAgeDays > 0 {
            let scanDays = max(1, maxAgeDays)
            let start = calendar.startOfDay(for: self.now)

            for offset in 0..<scanDays {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: start) else { continue }
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                let year = String(format: "%04d", components.year ?? 1970)
                let month = String(format: "%02d", components.month ?? 1)
                let day = String(format: "%02d", components.day ?? 1)

                let dayDir = root
                    .appendingPathComponent(year, isDirectory: true)
                    .appendingPathComponent(month, isDirectory: true)
                    .appendingPathComponent(day, isDirectory: true)

                guard let items = try? self.fileManager.contentsOfDirectory(
                    at: dayDir,
                    includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles])
                else {
                    continue
                }

                for item in items where item.pathExtension.lowercased() == "jsonl" {
                    let values = try? item.resourceValues(forKeys: [.contentModificationDateKey])
                    let modifiedAt = values?.contentModificationDate
                    if let minDate, let modifiedAt, modifiedAt < minDate { continue }
                    let sessionID = item.deletingPathExtension().lastPathComponent
                    results.append(CodexUsageSessionFile(url: item, sessionID: sessionID, modifiedAt: modifiedAt))
                }
            }
        } else {
            let enumerator = self.fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles])
            while let item = enumerator?.nextObject() as? URL {
                guard item.pathExtension.lowercased() == "jsonl" else { continue }
                let values = try? item.resourceValues(forKeys: [.contentModificationDateKey])
                let modifiedAt = values?.contentModificationDate
                if let minDate, let modifiedAt, modifiedAt < minDate { continue }
                let sessionID = item.deletingPathExtension().lastPathComponent
                results.append(CodexUsageSessionFile(url: item, sessionID: sessionID, modifiedAt: modifiedAt))
            }
        }

        return results
    }
}

extension FileManager {
    fileprivate func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return self.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
