import Foundation

/// Ledger source for the opencode CLI. Unlike Codex/Claude (day-partitioned
/// session dirs), opencode stores one JSON file per message at
/// `~/.local/share/opencode/storage/message/<sessionID>/<messageID>.json`, each
/// assistant message carrying `time.created`, `modelID`, `path.cwd`, an advertised
/// `cost`, and a `tokens` block. We discover files by modification time (like the
/// Claude source) and reuse the shared relay machinery (catch-up, self-heal,
/// additive today-clear, busy-file tolerance) verbatim.
public struct OpencodeUsageLogSource: UsageLedgerSource, @unchecked Sendable {
    public enum OpencodeUsageLogError: LocalizedError, Sendable {
        case noStorageDirectory
        case readFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noStorageDirectory:
                "No opencode storage directory found."
            case let .readFailed(reason):
                "Failed to read opencode usage logs: \(reason)"
            }
        }
    }

    private let environment: [String: String]
    private let fileManager: FileManager
    private let storageRoot: URL?
    private let now: Date
    private let log: RunicLogger
    private let cache: LedgerCache
    private let scanMode: UsageLedgerLogScanMode
    private let maxAgeDays: Int?

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        storageRoot: URL? = nil,
        maxAgeDays: Int? = 3,
        now: Date = Date(),
        log: RunicLogger = RunicLog.logger("opencode-usage-ledger"),
        cache: LedgerCache = .shared,
        scanMode: UsageLedgerLogScanMode = .refreshToday)
    {
        self.environment = environment
        self.fileManager = fileManager
        self.storageRoot = storageRoot
        self.now = now
        self.log = log
        self.cache = cache
        self.scanMode = scanMode
        self.maxAgeDays = maxAgeDays
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        let root = try self.resolveMessagesRoot()
        let todayKey = LedgerCache.dayKey(for: self.now)
        let healing = await self.cache.needsCatchUpHeal(provider: "opencode")
        let scanMode = await self.resolvedScanMode(healing: healing)
        let catchUpDays = await self.catchUpDays(scanMode: scanMode)
        let window = self.scanWindow(todayKey: todayKey, scanMode: scanMode, catchUpDays: catchUpDays)
        let isRebuild = if case .rebuildHistory = scanMode { true } else { false }
        let markHealed = healing || isRebuild

        let cache = self.cache
        // On rebuild, skip the mtime pre-filter entirely and rely on the per-entry
        // timestamp filter: a backup/restore or `rsync -a` can preserve an old file
        // mtime on a message whose `created` is within the window, and rebuild is
        // the repair path that must still find it. refreshToday keeps the mtime
        // prune for speed.
        let files = self.listMessageFiles(root: root, minDate: isRebuild ? nil : window.minDate)

        if files.isEmpty {
            await cache.mergeEntries(
                provider: "opencode",
                entries: [],
                scanDate: self.now,
                todayKey: window.relayTodayKey,
                coveredMaxAgeDays: window.coveredMaxAgeDays,
                sourceWatermarks: window.completionWatermarks)
            if markHealed { await cache.markCatchUpHealed(provider: "opencode") }
            return []
        }

        var entries: [UsageLedgerEntry] = []
        var seenKeys = Set<String>()
        var readFailures: [String] = []

        for file in files {
            do {
                if let entry = try self.parseMessage(file, minDate: window.minDate, seenKeys: &seenKeys) {
                    entries.append(entry)
                }
            } catch {
                self.log.warning("opencode usage log read failed", metadata: [
                    "file": file.path,
                    "error": error.localizedDescription,
                ])
                readFailures.append(file.path)
            }
        }

        var sourceWatermarks = window.completionWatermarks
        if !readFailures.isEmpty {
            // A live opencode session can rewrite a message file mid-scan. Keep what
            // parsed; only fail when nothing could be read. On a partial scan keep
            // watermarks only for days that produced entries, so untouched/busy days
            // retain their cached history (mirrors Codex/Claude).
            self.log.warning("opencode usage log: skipped busy file(s) during scan", metadata: [
                "skipped": "\(readFailures.count)",
                "parsedEntries": "\(entries.count)",
            ])
            if entries.isEmpty {
                throw OpencodeUsageLogError.readFailed(readFailures.joined(separator: ", "))
            }
            let daysWithEntries = Set(entries.map { LedgerCache.dayKey(for: $0.timestamp) })
            sourceWatermarks = sourceWatermarks.filter { watermark in
                guard let dayKey = watermark.dayKey else { return true }
                return daysWithEntries.contains(dayKey)
            }
        }

        await cache.mergeEntries(
            provider: "opencode",
            entries: entries,
            scanDate: self.now,
            todayKey: window.relayTodayKey,
            coveredMaxAgeDays: window.coveredMaxAgeDays,
            sourceWatermarks: sourceWatermarks)

        if markHealed { await cache.markCatchUpHealed(provider: "opencode") }
        return entries
    }

    // MARK: - Scan window (mirrors Codex/Claude)

    private struct ScanWindow {
        let minDate: Date
        let relayTodayKey: String?
        let coveredMaxAgeDays: Int?
        let completionWatermarks: [UsageRelaySourceWatermark]
    }

    private func resolvedScanMode(healing: Bool) async -> UsageLedgerLogScanMode {
        if case .rebuildHistory = self.scanMode { return self.scanMode }
        let requested = max(1, self.maxAgeDays ?? 1)
        guard requested > 1 else { return self.scanMode }
        if await self.cache.effectiveCoveredMaxAgeDays(provider: "opencode") == nil {
            return .rebuildHistory(maxAgeDays: requested)
        }
        // One-time legacy repair runs as a deterministic rebuild, not an additive
        // refresh that could stamp done having captured nothing if interrupted.
        if healing {
            return .rebuildHistory(maxAgeDays: requested)
        }
        return self.scanMode
    }

    private func catchUpDays(scanMode: UsageLedgerLogScanMode) async -> Int {
        guard case .refreshToday = scanMode else { return 1 }
        let requested = max(1, self.maxAgeDays ?? 1)
        guard requested > 1 else { return 1 }
        let gap = await self.cache.scanGapDays(provider: "opencode", now: self.now) ?? 1
        return min(max(1, gap), requested)
    }

    private func scanWindow(todayKey: String, scanMode: UsageLedgerLogScanMode, catchUpDays: Int) -> ScanWindow {
        let calendar = Calendar.current
        switch scanMode {
        case .refreshToday:
            // Additive: only TODAY carries a completion watermark (always
            // re-materialized / cleared when zero); historical gap days are touched
            // only when they produce entries, so a pruned day keeps its aggregate.
            let days = max(1, catchUpDays)
            let todayStart = calendar.startOfDay(for: self.now)
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart
            return ScanWindow(
                minDate: start,
                relayTodayKey: todayKey,
                coveredMaxAgeDays: nil,
                completionWatermarks: [
                    UsageRelaySourceWatermark(
                        dayKey: todayKey,
                        sourceKind: "opencode-today",
                        sourceID: "today:opencode:\(todayKey)",
                        sourceFingerprint: "today:opencode:\(todayKey):\(Int(self.now.timeIntervalSince1970))"),
                ])
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
                    sourceKind: "opencode-rebuild",
                    sourceID: "rebuild:opencode:\(dayKey)",
                    sourceFingerprint: "rebuild:opencode:\(dayKey):\(Int(self.now.timeIntervalSince1970))")
            }
            return ScanWindow(
                minDate: start,
                relayTodayKey: nil,
                coveredMaxAgeDays: days,
                completionWatermarks: watermarks)
        }
    }

    // MARK: - File discovery & parsing

    private func resolveMessagesRoot() throws -> URL {
        if let storageRoot, self.fileManager.opencodeDirectoryExists(at: storageRoot) {
            return storageRoot.standardizedFileURL
        }
        let env = self.environment["OPENCODE_DATA"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true)
                .appendingPathComponent("storage/message", isDirectory: true)
            if self.fileManager.opencodeDirectoryExists(at: url) { return url.standardizedFileURL }
        }
        let home = self.fileManager.homeDirectoryForCurrentUser
        let url = home
            .appendingPathComponent(".local/share/opencode/storage/message", isDirectory: true)
        if self.fileManager.opencodeDirectoryExists(at: url) { return url.standardizedFileURL }
        throw OpencodeUsageLogError.noStorageDirectory
    }

    /// opencode lays out messages as `message/<sessionID>/<messageID>.json` (one
    /// level deep). Listing session dirs first lets us prune an entire idle
    /// session by its directory mtime — appending a message bumps the dir mtime,
    /// so an old session whose dir predates `minDate` is skipped wholesale instead
    /// of stat-ing every file in it on the hot refresh path. `minDate == nil`
    /// (rebuild) scans everything.
    private func listMessageFiles(root: URL, minDate: Date?) -> [URL] {
        var results: [URL] = []
        let sessionDirs = (try? self.fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles])) ?? []

        for dir in sessionDirs {
            let dirValues = try? dir.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
            guard dirValues?.isDirectory != false else { continue }
            if let minDate, let dirModified = dirValues?.contentModificationDate, dirModified < minDate {
                continue // whole session untouched since the window start
            }

            let files = (try? self.fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles])) ?? []
            for item in files where item.pathExtension.lowercased() == "json" {
                if let minDate {
                    let values = try? item.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modifiedAt = values?.contentModificationDate, modifiedAt < minDate { continue }
                }
                results.append(item)
            }
        }
        return results
    }

    private func parseMessage(_ file: URL, minDate: Date?, seenKeys: inout Set<String>) throws -> UsageLedgerEntry? {
        let data = try Data(contentsOf: file)
        let message: OpencodeMessage
        do {
            message = try JSONDecoder().decode(OpencodeMessage.self, from: data)
        } catch {
            // A non-message JSON (or a half-written file) is not a read failure —
            // just skip it.
            return nil
        }
        guard message.role == "assistant", let tokens = message.tokens, let created = message.time?.created else {
            return nil
        }
        let timestamp = Date(timeIntervalSince1970: TimeInterval(created) / 1000.0)
        if let minDate, timestamp < minDate { return nil }

        let input = max(0, tokens.input ?? 0)
        // Reasoning tokens are output-side; fold them in so totals stay accurate.
        let output = max(0, tokens.output ?? 0) + max(0, tokens.reasoning ?? 0)
        let cacheRead = max(0, tokens.cache?.read ?? 0)
        let cacheWrite = max(0, tokens.cache?.write ?? 0)
        guard input + output + cacheRead + cacheWrite > 0 else { return nil }

        let key = message.id ?? "\(file.lastPathComponent)"
        guard seenKeys.insert(key).inserted else { return nil }

        let projectName = message.path?.cwd
            .map { URL(fileURLWithPath: $0).lastPathComponent }
            .flatMap { $0 == "/" || $0.isEmpty ? nil : $0 }

        return UsageLedgerEntry(
            provider: .opencode,
            timestamp: timestamp,
            sessionID: message.sessionID,
            projectID: message.path?.cwd,
            projectName: projectName,
            model: message.modelID,
            inputTokens: input,
            outputTokens: output,
            cacheCreationTokens: cacheWrite,
            cacheReadTokens: cacheRead,
            costUSD: message.cost,
            requestID: message.id,
            messageID: message.id,
            version: nil,
            source: .opencodeLog,
            tokenProvenance: MetricProvenance(
                confidence: .exact,
                source: .localLog,
                detail: "opencode message tokens"),
            costProvenance: message.cost.map { _ in
                MetricProvenance(
                    confidence: .providerReported,
                    source: .localLog,
                    detail: "opencode message cost")
            },
            sourceFingerprint: key)
    }
}

private struct OpencodeMessage: Decodable {
    struct Time: Decodable { let created: Int64? }
    struct Path: Decodable { let cwd: String? }
    struct Cache: Decodable { let read: Int?; let write: Int? }
    struct Tokens: Decodable {
        let input: Int?
        let output: Int?
        let reasoning: Int?
        let cache: Cache?
    }

    let id: String?
    let sessionID: String?
    let role: String?
    let time: Time?
    let modelID: String?
    let cost: Double?
    let path: Path?
    let tokens: Tokens?
}

extension FileManager {
    fileprivate func opencodeDirectoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return self.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
