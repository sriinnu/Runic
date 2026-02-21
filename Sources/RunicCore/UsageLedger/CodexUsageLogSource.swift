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

    private struct SessionFile {
        let url: URL
        let sessionID: String?
        let modifiedAt: Date?
    }

    private struct CodexTotals {
        var input: Int
        var cached: Int
        var output: Int
    }

    private let environment: [String: String]
    private let fileManager: FileManager
    private let sessionsRoot: URL?
    private let maxAgeDays: Int?
    private let now: Date
    private let log: RunicLogger

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        sessionsRoot: URL? = nil,
        maxAgeDays: Int? = 3,
        now: Date = Date(),
        log: RunicLogger = RunicLog.logger("codex-usage-ledger"))
    {
        self.environment = environment
        self.fileManager = fileManager
        self.sessionsRoot = sessionsRoot
        self.maxAgeDays = maxAgeDays
        self.now = now
        self.log = log
    }

    public func loadEntries() async throws -> [UsageLedgerEntry] {
        let root = try self.resolveSessionsRoot()
        let minDate = self.minDate()
        let files = self.listSessionFiles(root: root, minDate: minDate)
        if files.isEmpty {
            return []
        }

        var entries: [UsageLedgerEntry] = []
        var seenKeys = Set<String>()

        for file in files {
            do {
                try self.parseFile(file, minDate: minDate, seenKeys: &seenKeys, entries: &entries)
            } catch {
                self.log.warning("Codex usage log read failed", metadata: [
                    "file": file.url.path,
                    "error": error.localizedDescription,
                ])
            }
        }

        return entries
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

    private func listSessionFiles(root: URL, minDate: Date?) -> [SessionFile] {
        var results: [SessionFile] = []

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
                    results.append(SessionFile(url: item, sessionID: sessionID, modifiedAt: modifiedAt))
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
                results.append(SessionFile(url: item, sessionID: sessionID, modifiedAt: modifiedAt))
            }
        }

        return results
    }

    private func parseFile(
        _ file: SessionFile,
        minDate: Date?,
        seenKeys: inout Set<String>,
        entries: inout [UsageLedgerEntry]) throws
    {
        var currentModel: String?
        var previousTotals: CodexTotals?

        let maxLineBytes = 256 * 1024
        let prefixBytes = 32 * 1024

        _ = try CostUsageJsonl.scan(
            fileURL: file.url,
            offset: 0,
            maxLineBytes: maxLineBytes,
            prefixBytes: prefixBytes,
            onLine: { line in
                guard !line.bytes.isEmpty else { return }
                guard !line.wasTruncated else { return }
                guard
                    line.bytes.containsAscii(#""type":"event_msg""#)
                    || line.bytes.containsAscii(#""type":"turn_context""#)
                else { return }

                if line.bytes.containsAscii(#""type":"event_msg""#),
                   !line.bytes.containsAscii(#""token_count""#)
                {
                    return
                }

                guard
                    let obj = (try? JSONSerialization.jsonObject(with: line.bytes)) as? [String: Any],
                    let type = obj["type"] as? String
                else { return }

                guard let tsText = obj["timestamp"] as? String else { return }
                guard let timestamp = self.parseTimestamp(tsText) else { return }
                if let minDate, timestamp < minDate { return }

                let payload = obj["payload"] as? [String: Any]

                if type == "turn_context" {
                    if let payload {
                        if let model = payload["model"] as? String {
                            currentModel = model
                        } else if let info = payload["info"] as? [String: Any],
                                  let model = info["model"] as? String
                        {
                            currentModel = model
                        }
                    }
                    return
                }

                guard type == "event_msg" else { return }
                guard (payload?["type"] as? String) == "token_count" else { return }
                guard let info = payload?["info"] as? [String: Any] else { return }

                let modelFromInfo = (info["model"] as? String)
                    ?? (info["model_name"] as? String)
                    ?? (payload?["model"] as? String)
                    ?? (obj["model"] as? String)
                let model = modelFromInfo ?? currentModel ?? "gpt-5"

                let total = info["total_token_usage"] as? [String: Any]
                let last = info["last_token_usage"] as? [String: Any]

                var deltaInput = 0
                var deltaCached = 0
                var deltaOutput = 0

                if let total {
                    let input = self.toInt(total["input_tokens"])
                    let cached = self.toInt(total["cached_input_tokens"] ?? total["cache_read_input_tokens"])
                    let output = self.toInt(total["output_tokens"])

                    let prev = previousTotals
                    deltaInput = max(0, input - (prev?.input ?? 0))
                    deltaCached = max(0, cached - (prev?.cached ?? 0))
                    deltaOutput = max(0, output - (prev?.output ?? 0))
                    previousTotals = CodexTotals(input: input, cached: cached, output: output)
                } else if let last {
                    deltaInput = max(0, self.toInt(last["input_tokens"]))
                    deltaCached = max(0, self.toInt(last["cached_input_tokens"] ?? last["cache_read_input_tokens"]))
                    deltaOutput = max(0, self.toInt(last["output_tokens"]))
                } else {
                    return
                }

                if deltaInput == 0, deltaCached == 0, deltaOutput == 0 { return }
                let cachedClamp = min(deltaCached, deltaInput)

                let sessionID = self.firstString(
                    from: info,
                    keys: ["session_id", "sessionId"])
                    ?? self.firstString(from: payload, keys: ["session_id", "sessionId"])
                    ?? self.firstString(from: obj, keys: ["session_id", "sessionId"])
                    ?? file.sessionID

                let infoProject = info["project"] as? [String: Any]
                let payloadProject = payload?["project"] as? [String: Any]
                let rootProject = obj["project"] as? [String: Any]
                let projectID = self.firstString(from: info, keys: ["project_id", "projectId"])
                    ?? self.firstString(from: payload, keys: ["project_id", "projectId"])
                    ?? self.firstString(from: obj, keys: ["project_id", "projectId"])
                    ?? self.firstString(from: infoProject, keys: ["id", "project_id", "projectId"])
                    ?? self.firstString(from: payloadProject, keys: ["id", "project_id", "projectId"])
                    ?? self.firstString(from: rootProject, keys: ["id", "project_id", "projectId"])
                let projectName = self.firstString(
                    from: info,
                    keys: ["project_name", "projectName", "workspace_name", "workspaceName"])
                    ?? self.firstString(
                        from: payload,
                        keys: ["project_name", "projectName", "workspace_name", "workspaceName"])
                    ?? self.firstString(
                        from: obj,
                        keys: ["project_name", "projectName", "workspace_name", "workspaceName"])
                    ?? self.firstString(from: infoProject, keys: ["name", "project_name", "projectName", "title"])
                    ?? self.firstString(from: payloadProject, keys: ["name", "project_name", "projectName", "title"])
                    ?? self.firstString(from: rootProject, keys: ["name", "project_name", "projectName", "title"])
                let requestID = self.firstString(
                    from: info,
                    keys: ["request_id", "requestId", "event_id", "eventId"])
                    ?? self.firstString(from: payload, keys: ["request_id", "requestId"])
                    ?? self.firstString(from: obj, keys: ["request_id", "requestId"])
                let version = self.firstString(from: info, keys: ["client_version", "version"])
                    ?? self.firstString(from: obj, keys: ["version"])

                let key = self.dedupeKey(
                    requestID: requestID,
                    sessionID: sessionID,
                    timestamp: timestamp,
                    inputTokens: deltaInput,
                    outputTokens: deltaOutput,
                    cacheReadTokens: cachedClamp)
                if seenKeys.contains(key) { return }
                seenKeys.insert(key)

                let cost = CostUsagePricing.codexCostUSD(
                    model: model,
                    inputTokens: deltaInput,
                    cachedInputTokens: cachedClamp,
                    outputTokens: deltaOutput)

                entries.append(UsageLedgerEntry(
                    provider: .codex,
                    timestamp: timestamp,
                    sessionID: sessionID,
                    projectID: projectID,
                    projectName: projectName,
                    model: model,
                    inputTokens: deltaInput,
                    outputTokens: deltaOutput,
                    cacheCreationTokens: 0,
                    cacheReadTokens: cachedClamp,
                    costUSD: cost,
                    requestID: requestID,
                    messageID: nil,
                    version: version,
                    source: .codexLog))
            })
    }

    private func minDate() -> Date? {
        guard let maxAgeDays, maxAgeDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -maxAgeDays, to: self.now)
    }

    private func parseTimestamp(_ value: String) -> Date? {
        let box = codexISOFormatterBox
        box.lock.lock()
        defer { box.lock.unlock() }
        return box.iso.date(from: value) ?? box.fractional.date(from: value)
    }

    private func toInt(_ value: Any?) -> Int {
        if let num = value as? NSNumber { return num.intValue }
        return 0
    }

    private func firstString(from dict: [String: Any]?, keys: [String]) -> String? {
        guard let dict else { return nil }
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func dedupeKey(
        requestID: String?,
        sessionID: String?,
        timestamp: Date,
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int) -> String
    {
        if let requestID, !requestID.isEmpty {
            return "req:\(requestID)"
        }
        return "ts:\(timestamp.timeIntervalSince1970)|\(sessionID ?? "-")|\(inputTokens)|\(outputTokens)|\(cacheReadTokens)"
    }
}

private final class CodexISO8601FormatterBox: @unchecked Sendable {
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

private let codexISOFormatterBox = CodexISO8601FormatterBox()

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return self.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
