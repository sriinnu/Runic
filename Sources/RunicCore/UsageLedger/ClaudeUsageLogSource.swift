import Foundation

public struct ClaudeUsageLogSource: UsageLedgerSource, @unchecked Sendable {
    public enum ClaudeUsageLogError: LocalizedError, Sendable {
        case noProjectsDirectory
        case readFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noProjectsDirectory:
                "No Claude projects directory found."
            case let .readFailed(reason):
                "Failed to read Claude usage logs: \(reason)"
            }
        }
    }

    let environment: [String: String]
    let fileManager: FileManager
    let basePaths: [URL]?
    let now: Date
    let log: RunicLogger
    let cache: LedgerCache
    let scanMode: UsageLedgerLogScanMode
    let maxAgeDays: Int?

    struct DedupeTokens {
        let input: Int
        let output: Int
        let cacheCreation: Int
        let cacheRead: Int
    }

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        basePaths: [URL]? = nil,
        maxAgeDays: Int? = 3,
        now: Date = Date(),
        log: RunicLogger = RunicLog.logger("claude-usage-ledger"),
        cache: LedgerCache = .shared,
        scanMode: UsageLedgerLogScanMode = .refreshToday)
    {
        self.environment = environment
        self.fileManager = fileManager
        self.basePaths = basePaths
        self.now = now
        self.log = log
        self.cache = cache
        self.scanMode = scanMode
        self.maxAgeDays = maxAgeDays
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        let projectsDirs = try self.resolveProjectsDirectories()
        if projectsDirs.isEmpty {
            throw ClaudeUsageLogError.noProjectsDirectory
        }

        // Relay contract: normal refresh never reopens historical provider
        // JSONLs. Explicit rebuild mode is the repair path that opts into
        // historical reads and commits empty day snapshots for missing raw data.
        let cache = self.cache
        let todayKey = LedgerCache.dayKey(for: self.now)
        let scanMode = await self.resolvedScanMode()
        let healing = await self.cache.needsCatchUpHeal(provider: "claude")
        let catchUpDays = await self.catchUpDays(scanMode: scanMode, healing: healing)
        let window = self.scanWindow(todayKey: todayKey, scanMode: scanMode, catchUpDays: catchUpDays)
        // A rebuild (fresh install or explicit) already fully covers the window, so
        // stamp the heal too — otherwise the next refresh would redundantly heal.
        let isRebuild: Bool = if case .rebuildHistory = scanMode { true } else { false }
        let markHealed = healing || isRebuild
        let allFiles = self.findUsageFiles(in: projectsDirs, minDate: window.fileMinModificationDate)

        // Claude keeps long-lived project JSONLs. Normal refresh opens only
        // files touched today, then line-filters by timestamp so old rows stay
        // historical relay data.
        let filesToScan = if window.requireTouchedAfterMinDate {
            allFiles.filter { file in
                guard let modDate = (try? self.fileManager
                    .attributesOfItem(atPath: file.url.path))?[.modificationDate] as? Date
                else {
                    return true
                }
                return modDate >= window.minDate
            }
        } else {
            allFiles
        }

        if filesToScan.isEmpty {
            await cache.mergeEntries(
                provider: "claude",
                entries: [],
                scanDate: self.now,
                todayKey: window.relayTodayKey,
                coveredMaxAgeDays: window.coveredMaxAgeDays,
                sourceWatermarks: window.completionWatermarks)
            if markHealed { await cache.markCatchUpHealed(provider: "claude") }
            return []
        }

        self.log
            .info(
                "Scanning \(filesToScan.count) of \(allFiles.count) JSONL files touched today")

        // Parse files concurrently (max 16 at a time).
        let maxConcurrency = 16
        let parsedFiles = try await withThrowingTaskGroup(
            of: ParsedUsageFile.self,
            returning: [ParsedUsageFile].self)
        { group in
            var all: [ParsedUsageFile] = []
            var inflight = 0
            for file in filesToScan {
                if inflight >= maxConcurrency {
                    if let parsed = try await group.next() {
                        all.append(parsed)
                        inflight -= 1
                    }
                }
                group.addTask {
                    try self.parseFile(file, minDate: window.minDate, dayKey: window.fileWatermarkDayKey)
                }
                inflight += 1
            }
            while let parsed = try await group.next() {
                all.append(parsed)
            }
            return all
        }
        let fileEntries = parsedFiles.flatMap(\.entries)

        // Deduplicate across files using the same composite key as per-file dedup.
        var seenKeys = Set<String>()
        var entries: [UsageLedgerEntry] = []
        entries.reserveCapacity(fileEntries.count)
        for entry in fileEntries {
            let key = self.dedupeKey(
                requestID: entry.requestID,
                messageID: entry.messageID,
                sessionID: entry.sessionID,
                timestamp: entry.timestamp,
                tokens: .init(
                    input: entry.inputTokens,
                    output: entry.outputTokens,
                    cacheCreation: entry.cacheCreationTokens,
                    cacheRead: entry.cacheReadTokens))
            if seenKeys.insert(key).inserted {
                entries.append(entry)
            }
        }

        let sourceWatermarks = window.completionWatermarks + parsedFiles.map(\.watermark)
        await cache.mergeEntries(
            provider: "claude",
            entries: entries,
            scanDate: self.now,
            todayKey: window.relayTodayKey,
            coveredMaxAgeDays: window.coveredMaxAgeDays,
            sourceWatermarks: sourceWatermarks)

        if markHealed { await cache.markCatchUpHealed(provider: "claude") }
        return entries
    }

    struct UsageFile {
        let url: URL
        let projectID: String?
        let projectName: String?
        let sessionID: String?
    }

    struct ParsedUsageFile {
        let entries: [UsageLedgerEntry]
        let watermark: UsageRelaySourceWatermark
    }

    struct SourceFileMetadata: Equatable {
        let path: String
        let modifiedAt: Date?
        let sizeBytes: Int64?
    }

    struct ScanWindow {
        let minDate: Date
        let fileMinModificationDate: Date?
        let requireTouchedAfterMinDate: Bool
        let relayTodayKey: String?
        let coveredMaxAgeDays: Int?
        let completionWatermarks: [UsageRelaySourceWatermark]
        let fileWatermarkDayKey: String?
    }
}
