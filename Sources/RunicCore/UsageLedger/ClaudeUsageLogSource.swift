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

    private let environment: [String: String]
    private let fileManager: FileManager
    private let basePaths: [URL]?
    private let maxAgeDays: Int?
    private let now: Date
    private let log: RunicLogger

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        basePaths: [URL]? = nil,
        maxAgeDays: Int? = 3,
        now: Date = Date(),
        log: RunicLogger = RunicLog.logger("claude-usage-ledger"))
    {
        self.environment = environment
        self.fileManager = fileManager
        self.basePaths = basePaths
        self.maxAgeDays = maxAgeDays
        self.now = now
        self.log = log
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        let projectsDirs = try self.resolveProjectsDirectories()
        if projectsDirs.isEmpty {
            throw ClaudeUsageLogError.noProjectsDirectory
        }

        let minDate = self.minDate()
        let files = self.findUsageFiles(in: projectsDirs, minDate: minDate)
        if files.isEmpty {
            return []
        }

        var entries: [UsageLedgerEntry] = []
        var seenKeys = Set<String>()

        for file in files {
            do {
                let data = try Data(contentsOf: file.url)
                guard let content = String(data: data, encoding: .utf8) else { continue }
                let lines = content.split(whereSeparator: \.isNewline)
                for line in lines {
                    if let entry = self.parseLine(line, file: file, minDate: minDate, seenKeys: &seenKeys) {
                        entries.append(entry)
                    }
                }
            } catch {
                self.log.warning("Claude usage log read failed", metadata: [
                    "file": file.url.path,
                    "error": error.localizedDescription,
                ])
            }
        }

        return entries
    }

    private struct UsageFile {
        let url: URL
        let projectID: String?
        let sessionID: String?
    }

    private func resolveProjectsDirectories() throws -> [URL] {
        if let basePaths { return self.normalizePaths(basePaths) }

        let envPaths = self.environment["CLAUDE_CONFIG_DIR"]?.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []

        var candidates: [URL] = []
        if !envPaths.isEmpty {
            candidates = envPaths.map { expandTilde(path: String($0)) }
        } else {
            let home = fileManager.homeDirectoryForCurrentUser
            candidates = [
                home.appendingPathComponent(".config/claude", isDirectory: true),
                home.appendingPathComponent(".claude", isDirectory: true),
            ]
        }

        let projectsDirs = candidates
            .map { $0.appendingPathComponent("projects", isDirectory: true) }
            .filter { self.fileManager.directoryExists(at: $0) }

        return projectsDirs
    }

    private func normalizePaths(_ urls: [URL]) -> [URL] {
        urls.map { $0.standardizedFileURL }
            .filter { self.fileManager.directoryExists(at: $0) }
            .map { $0.appendingPathComponent("projects", isDirectory: true) }
            .filter { self.fileManager.directoryExists(at: $0) }
    }

    private func findUsageFiles(in projectsDirs: [URL], minDate: Date?) -> [UsageFile] {
        var results: [UsageFile] = []

        for projectsDir in projectsDirs {
            let enumerator = self.fileManager.enumerator(
                at: projectsDir,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles])

            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.lastPathComponent == "usage.jsonl" else { continue }
                if let minDate {
                    let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modifiedAt = values?.contentModificationDate, modifiedAt < minDate { continue }
                }
                let pathComponents = fileURL.pathComponents
                guard let projectsIndex = pathComponents.lastIndex(of: "projects"),
                      projectsIndex + 2 < pathComponents.count
                else {
                    results.append(UsageFile(url: fileURL, projectID: nil, sessionID: nil))
                    continue
                }
                let projectID = pathComponents[projectsIndex + 1]
                let sessionID = pathComponents[projectsIndex + 2]
                results.append(UsageFile(url: fileURL, projectID: projectID, sessionID: sessionID))
            }
        }

        return results
    }

    private func parseLine(
        _ line: Substring,
        file: UsageFile,
        minDate: Date?,
        seenKeys: inout Set<String>) -> UsageLedgerEntry?
    {
        let text = String(line)
        guard let data = text.data(using: .utf8) else { return nil }
        do {
            let payload = try JSONDecoder().decode(ClaudeUsageLogLine.self, from: data)
            if payload.isApiErrorMessage == true { return nil }
            guard let timestamp = parseTimestamp(payload.timestamp) else { return nil }
            if let minDate, timestamp < minDate { return nil }
            let usage = payload.message.usage
            let input = max(0, usage.inputTokens)
            let output = max(0, usage.outputTokens)
            let cacheCreation = max(0, usage.cacheCreationInputTokens ?? 0)
            let cacheRead = max(0, usage.cacheReadInputTokens ?? 0)
            let total = input + output + cacheCreation + cacheRead
            guard total > 0 else { return nil }

            let sessionID = payload.sessionId ?? file.sessionID
            let computedCost = payload.costUSD ?? payload.message.model.flatMap { model in
                CostUsagePricing.claudeCostUSD(
                    model: model,
                    inputTokens: input,
                    cacheReadInputTokens: cacheRead,
                    cacheCreationInputTokens: cacheCreation,
                    outputTokens: output)
            }
            let key = self.dedupeKey(
                requestID: payload.requestId,
                messageID: payload.message.id,
                sessionID: sessionID,
                timestamp: timestamp,
                inputTokens: input,
                outputTokens: output,
                cacheCreationTokens: cacheCreation,
                cacheReadTokens: cacheRead)
            if seenKeys.contains(key) { return nil }
            seenKeys.insert(key)

            return UsageLedgerEntry(
                provider: .claude,
                timestamp: timestamp,
                sessionID: sessionID,
                projectID: file.projectID,
                model: payload.message.model,
                inputTokens: input,
                outputTokens: output,
                cacheCreationTokens: cacheCreation,
                cacheReadTokens: cacheRead,
                costUSD: computedCost,
                requestID: payload.requestId,
                messageID: payload.message.id,
                version: payload.version,
                source: .claudeLog)
        } catch {
            return nil
        }
    }

    private func dedupeKey(
        requestID: String?,
        messageID: String?,
        sessionID: String?,
        timestamp: Date,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int) -> String
    {
        if let requestID, !requestID.isEmpty {
            return "req:\(requestID)"
        }
        if let messageID, !messageID.isEmpty {
            return "msg:\(messageID)"
        }
        return "ts:\(timestamp.timeIntervalSince1970)|\(sessionID ?? "-")|\(inputTokens)|\(outputTokens)|\(cacheCreationTokens)|\(cacheReadTokens)"
    }

    private func minDate() -> Date? {
        guard let maxAgeDays, maxAgeDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: self.now)
    }

    private func parseTimestamp(_ value: String) -> Date? {
        let box = claudeISOFormatterBox
        box.lock.lock()
        defer { box.lock.unlock() }
        return box.iso.date(from: value) ?? box.fractional.date(from: value)
    }

    private func expandTilde(path: String) -> URL {
        if path.hasPrefix("~/") {
            let home = fileManager.homeDirectoryForCurrentUser
            let trimmed = String(path.dropFirst(2))
            return home.appendingPathComponent(trimmed, isDirectory: true)
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}

private struct ClaudeUsageLogLine: Decodable {
    struct Message: Decodable {
        struct Usage: Decodable {
            let inputTokens: Int
            let outputTokens: Int
            let cacheCreationInputTokens: Int?
            let cacheReadInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
                case cacheReadInputTokens = "cache_read_input_tokens"
            }
        }

        let usage: Usage
        let model: String?
        let id: String?
    }

    let timestamp: String
    let sessionId: String?
    let version: String?
    let message: Message
    let costUSD: Double?
    let requestId: String?
    let isApiErrorMessage: Bool?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case sessionId
        case version
        case message
        case costUSD
        case requestId
        case isApiErrorMessage
    }
}

private final class ClaudeISO8601FormatterBox: @unchecked Sendable {
    let lock = NSLock()
    let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private let claudeISOFormatterBox = ClaudeISO8601FormatterBox()

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return self.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
