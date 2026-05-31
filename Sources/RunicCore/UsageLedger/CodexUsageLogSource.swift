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
        _ = maxAgeDays // Retained for source compatibility; scanMode controls history reads.
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        let root = try self.resolveSessionsRoot()
        let todayKey = LedgerCache.dayKey(for: self.now)
        let window = self.scanWindow(todayKey: todayKey)

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
            throw CodexUsageLogError.readFailed(readFailures.joined(separator: ", "))
        }

        await cache.mergeEntries(
            provider: "codex",
            entries: entries,
            scanDate: self.now,
            todayKey: window.relayTodayKey,
            coveredMaxAgeDays: window.coveredMaxAgeDays,
            sourceWatermarks: sourceWatermarks)

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

    private func scanWindow(todayKey: String) -> ScanWindow {
        let calendar = Calendar.current
        switch self.scanMode {
        case .refreshToday:
            return ScanWindow(
                minDate: calendar.startOfDay(for: self.now),
                fileMaxAgeDays: 1,
                relayTodayKey: todayKey,
                coveredMaxAgeDays: nil,
                completionWatermarks: [],
                fileWatermarkDayKey: todayKey)
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
