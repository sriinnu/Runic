import Foundation

/// Extracts the live context-window occupancy of the CURRENT Codex session.
///
/// The most recently modified rollout under the Codex sessions directory is
/// the live session (mtime selection, matching `CodexUsageLogSource` — a
/// resumed rollout stays filed under its start date). Each `token_count`
/// event carries per-request state: `last_token_usage.input_tokens` is the
/// full prompt of the most recent request (cached tokens are a SUBSET of
/// input for OpenAI), i.e. what was in the context window. Modern rollouts
/// also report `model_context_window` — the exact denominator.
///
/// Only the tail of the rollout is read; long-lived rollouts reach GBs.
public struct CodexContextFillSource: @unchecked Sendable {
    private let environment: [String: String]
    private let fileManager: FileManager
    private let sessionsRoot: URL?
    /// Rollouts whose file mtime is older than this are ignored: an idle
    /// session's context occupancy is noise, not signal.
    private let maxSampleAge: TimeInterval
    private let tailBytes: Int

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        sessionsRoot: URL? = nil,
        maxSampleAge: TimeInterval = 30 * 60,
        tailBytes: Int = 256 * 1024)
    {
        self.environment = environment
        self.fileManager = fileManager
        self.sessionsRoot = sessionsRoot
        self.maxSampleAge = maxSampleAge
        self.tailBytes = tailBytes
    }

    public func latestSample(now: Date = Date()) -> ProviderContextFillSample? {
        guard let root = self.resolveSessionsRoot() else { return nil }
        let minDate = now.addingTimeInterval(-self.maxSampleAge)

        var newest: (url: URL, modifiedAt: Date)?
        let enumerator = self.fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles])
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension.lowercased() == "jsonl" else { continue }
            let values = try? item.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modifiedAt = values?.contentModificationDate, modifiedAt >= minDate else { continue }
            if newest.map({ modifiedAt > $0.modifiedAt }) ?? true {
                newest = (item, modifiedAt)
            }
        }

        guard let newest else { return nil }
        return self.latestTokenCount(
            in: newest.url,
            sessionID: newest.url.deletingPathExtension().lastPathComponent)
    }

    private func latestTokenCount(in url: URL, sessionID: String?) -> ProviderContextFillSample? {
        let lines = ContextFillTailReader.tailLines(of: url, tailBytes: self.tailBytes)
        var pending: ProviderContextFillSample?
        // Walk backwards: the newest token_count is the current context state.
        // Its `info` block usually omits the model, which lives on the nearest
        // PRECEDING turn_context line — keep walking older lines to find it.
        for lineData in lines.reversed() {
            guard let object = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any],
                  let type = object["type"] as? String
            else { continue }

            if let pending {
                guard type == "turn_context" else { continue }
                let payload = object["payload"] as? [String: Any]
                let info = payload?["info"] as? [String: Any]
                guard let model = (payload?["model"] as? String) ?? (info?["model"] as? String) else { continue }
                return ProviderContextFillSample(
                    occupiedTokens: pending.occupiedTokens,
                    model: model,
                    transcriptContextWindow: pending.transcriptContextWindow,
                    timestamp: pending.timestamp,
                    sessionID: pending.sessionID)
            }

            guard let sample = self.tokenCountSample(object: object, type: type, sessionID: sessionID) else {
                continue
            }
            if sample.model != nil {
                return sample
            }
            pending = sample
        }
        return pending
    }

    private func tokenCountSample(
        object: [String: Any],
        type: String,
        sessionID: String?) -> ProviderContextFillSample?
    {
        guard type == "event_msg",
              let payload = object["payload"] as? [String: Any],
              (payload["type"] as? String) == "token_count",
              let info = payload["info"] as? [String: Any],
              let timestampText = object["timestamp"] as? String,
              let timestamp = Self.parseTimestamp(timestampText)
        else { return nil }

        // Only the self-contained per-request state is a valid occupancy
        // reading. `total_token_usage.input_tokens` is a CUMULATIVE session
        // counter (the usage parser deltas it for exactly that reason), so a
        // long-lived legacy session would peg the context gauge at 100%.
        // Legacy lines that predate `last_token_usage` therefore yield no live
        // context sample — the heuristic fallback still covers those sessions.
        guard let usage = info["last_token_usage"] as? [String: Any] else { return nil }
        let occupied = Self.intValue(usage["input_tokens"])
        guard occupied > 0 else { return nil }

        let window = Self.intValue(info["model_context_window"])
        let model = (info["model"] as? String)
            ?? (info["model_name"] as? String)
            ?? (payload["model"] as? String)
        return ProviderContextFillSample(
            occupiedTokens: occupied,
            model: model,
            transcriptContextWindow: window > 0 ? window : nil,
            timestamp: timestamp,
            sessionID: sessionID)
    }

    private func resolveSessionsRoot() -> URL? {
        if let sessionsRoot, self.directoryExists(at: sessionsRoot) {
            return sessionsRoot.standardizedFileURL
        }

        let env = self.environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let env, !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true)
                .appendingPathComponent("sessions", isDirectory: true)
            if self.directoryExists(at: url) {
                return url.standardizedFileURL
            }
        }

        let url = self.fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        return self.directoryExists(at: url) ? url.standardizedFileURL : nil
    }

    private func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return self.fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }

    private static func intValue(_ value: Any?) -> Int {
        if let num = value as? NSNumber { return num.intValue }
        return 0
    }
}
