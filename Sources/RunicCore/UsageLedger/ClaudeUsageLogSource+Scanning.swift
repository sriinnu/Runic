import Foundation

extension ClaudeUsageLogSource {
    /// Pick the scan window. An explicit rebuild always wins. Otherwise, with no
    /// cached history at all (fresh install / cleared cache), do a one-time
    /// history rebuild so the app isn't stuck showing only today; once any
    /// coverage exists, normal refresh stays today-only (the relay contract).
    func resolvedScanMode() async -> UsageLedgerLogScanMode {
        if case .rebuildHistory = self.scanMode { return self.scanMode }
        let requested = max(1, self.maxAgeDays ?? 1)
        guard requested > 1 else { return self.scanMode }
        if await self.cache.effectiveCoveredMaxAgeDays(provider: "claude") == nil {
            return .rebuildHistory(maxAgeDays: requested)
        }
        return self.scanMode
    }

    /// How many days back a normal (`.refreshToday`) scan should reach.
    ///
    /// A today-only refresh silently loses any day the app was closed during: if
    /// Claude was used while Runic wasn't refreshing, that day is never scanned
    /// and never reaches the relay, blanking the recent timeline. Widening the
    /// window back to the last scan date backfills exactly the missed days. In
    /// steady state the last scan is today, so this is 1 (today-only) and costs
    /// nothing. Bounded by the retention window. Unlike `.rebuildHistory`, this
    /// catch-up is *additive*: the wider window in `scanWindow` seals no empty
    /// days, so a gap day whose raw logs have since rotated away keeps its
    /// existing relay aggregate instead of being erased. `retention == 1`
    /// intentionally has no catch-up (today is the only renderable day anyway).
    func catchUpDays(scanMode: UsageLedgerLogScanMode, healing: Bool) async -> Int {
        guard case .refreshToday = scanMode else { return 1 }
        let requested = max(1, self.maxAgeDays ?? 1)
        guard requested > 1 else { return 1 }
        // One-time legacy repair: backfill the full retention window once, since
        // the gap that today-only builds skipped can be anywhere in it.
        if healing { return requested }
        let gap = await self.cache.scanGapDays(provider: "claude", now: self.now) ?? 1
        return min(max(1, gap), requested)
    }

    func scanWindow(todayKey: String, scanMode: UsageLedgerLogScanMode, catchUpDays: Int) -> ScanWindow {
        let calendar = Calendar.current
        switch scanMode {
        case .refreshToday:
            // Widen the window back over any gap (app closed while Claude was
            // used) so missed days are backfilled. Additive on purpose: a nil
            // file-watermark day key means historical gap days are touched only
            // when they actually produce entries, so a gap day whose long-lived
            // project JSONL was pruned keeps its relay aggregate. Only TODAY gets
            // a completion watermark, so today is always re-materialized (cleared
            // when it has gone to zero, even on a multi-day catch-up). On a
            // partial scan the busy-file filter drops it when today produced no
            // entries, preserving a merely-busy today.
            let days = max(1, catchUpDays)
            let todayStart = calendar.startOfDay(for: self.now)
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart
            return ScanWindow(
                minDate: start,
                fileMinModificationDate: start,
                requireTouchedAfterMinDate: true,
                relayTodayKey: todayKey,
                coveredMaxAgeDays: nil,
                completionWatermarks: [
                    UsageRelaySourceWatermark(
                        dayKey: todayKey,
                        sourceKind: "claude-today",
                        sourceID: "today:claude:\(todayKey)",
                        sourceFingerprint: "today:claude:\(todayKey):\(Int(self.now.timeIntervalSince1970))"),
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
                    sourceKind: "claude-jsonl-rebuild",
                    sourceID: "rebuild:claude:\(dayKey)",
                    sourceFingerprint: "rebuild:claude:\(dayKey):\(Int(self.now.timeIntervalSince1970))")
            }
            return ScanWindow(
                minDate: start,
                fileMinModificationDate: nil,
                requireTouchedAfterMinDate: false,
                relayTodayKey: nil,
                coveredMaxAgeDays: days,
                completionWatermarks: watermarks,
                fileWatermarkDayKey: nil)
        }
    }

    func resolveProjectsDirectories() throws -> [URL] {
        if let basePaths { return self.normalizePaths(basePaths) }

        let envPaths = self.environment["CLAUDE_CONFIG_DIR"]?.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        var candidates: [URL] = []
        if !envPaths.isEmpty {
            candidates = envPaths.map { self.expandTilde(path: String($0)) }
        } else {
            let home = self.fileManager.homeDirectoryForCurrentUser
            candidates = [
                home.appendingPathComponent(".config/claude", isDirectory: true),
                home.appendingPathComponent(".claude", isDirectory: true),
            ]
        }

        return candidates
            .map { $0.appendingPathComponent("projects", isDirectory: true) }
            .filter { self.fileManager.claudeLedgerDirectoryExists(at: $0) }
    }

    func findUsageFiles(in projectsDirs: [URL], minDate: Date?) -> [UsageFile] {
        var results: [UsageFile] = []

        for projectsDir in projectsDirs {
            let enumerator = self.fileManager.enumerator(
                at: projectsDir,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles])

            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.pathExtension == "jsonl" else { continue }
                if let minDate {
                    let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modifiedAt = values?.contentModificationDate, modifiedAt < minDate { continue }
                }
                let pathComponents = fileURL.pathComponents
                guard let projectsIndex = pathComponents.lastIndex(of: "projects"),
                      projectsIndex + 2 < pathComponents.count
                else {
                    results.append(UsageFile(url: fileURL, projectID: nil, projectName: nil, sessionID: nil))
                    continue
                }
                let projectID = pathComponents[projectsIndex + 1]
                let projectName = self.derivedProjectName(from: projectID)
                let sessionID = pathComponents[projectsIndex + 2]
                results.append(UsageFile(
                    url: fileURL,
                    projectID: projectID,
                    projectName: projectName,
                    sessionID: sessionID))
            }
        }

        return results
    }

    func sourceWatermark(for metadata: SourceFileMetadata, dayKey: String?) -> UsageRelaySourceWatermark {
        UsageRelaySourceWatermark(
            dayKey: dayKey,
            sourceKind: "claude-jsonl",
            sourceID: metadata.path,
            sourceFingerprint: self.sourceFingerprint(for: metadata),
            path: metadata.path,
            modifiedAt: metadata.modifiedAt,
            sizeBytes: metadata.sizeBytes)
    }

    func sourceFingerprint(for metadata: SourceFileMetadata) -> String {
        let modifiedMillis = metadata.modifiedAt.map { Int64($0.timeIntervalSince1970 * 1000) } ?? -1
        return "\(metadata.path)|\(metadata.sizeBytes ?? -1)|\(modifiedMillis)"
    }

    func sourceMetadata(for url: URL) -> SourceFileMetadata {
        let standardized = url.standardizedFileURL
        let values = try? standardized.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return SourceFileMetadata(
            path: standardized.path,
            modifiedAt: values?.contentModificationDate,
            sizeBytes: values?.fileSize.map { Int64($0) })
    }

    private func normalizePaths(_ urls: [URL]) -> [URL] {
        urls.map(\.standardizedFileURL)
            .filter { self.fileManager.claudeLedgerDirectoryExists(at: $0) }
            .map { $0.appendingPathComponent("projects", isDirectory: true) }
            .filter { self.fileManager.claudeLedgerDirectoryExists(at: $0) }
    }

    private func derivedProjectName(from projectID: String) -> String? {
        let trimmed = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let decoded = trimmed.removingPercentEncoding ?? trimmed
        let normalized = decoded.replacingOccurrences(of: "\\", with: "/")

        if normalized.contains("/") {
            let leaf = URL(fileURLWithPath: normalized).lastPathComponent
            if !leaf.isEmpty {
                return leaf
            }
        }
        return normalized
    }

    private func expandTilde(path: String) -> URL {
        if path.hasPrefix("~/") {
            let home = self.fileManager.homeDirectoryForCurrentUser
            let trimmed = String(path.dropFirst(2))
            return home.appendingPathComponent(trimmed, isDirectory: true)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}

extension FileManager {
    fileprivate func claudeLedgerDirectoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return self.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
