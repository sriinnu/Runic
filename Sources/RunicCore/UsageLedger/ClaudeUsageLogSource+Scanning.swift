import Foundation

extension ClaudeUsageLogSource {
    func scanWindow(todayKey: String) -> ScanWindow {
        let calendar = Calendar.current
        switch self.scanMode {
        case .refreshToday:
            let todayStart = calendar.startOfDay(for: self.now)
            return ScanWindow(
                minDate: todayStart,
                fileMinModificationDate: todayStart,
                requireTouchedAfterMinDate: true,
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
        return UsageRelaySourceWatermark(
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
