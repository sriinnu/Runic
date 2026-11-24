import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Reads the signed-in Muse Code subscription card through its local `/usage`
/// command. No model prompt or Model API request is issued by Runic.
public enum MuseCodeCLIUsageFetcher {
    private static let log = RunicLog.logger("muse-code-cli")

    public enum Error: Swift.Error, LocalizedError {
        case unavailable
        case noSubscriptionUsage
        /// The CLI printed its usage card but the subscription block reads
        /// "Currently unavailable" (no plan on the account, or Muse's usage
        /// service is down). Waiting longer cannot change that.
        case subscriptionUnavailable

        public var errorDescription: String? {
            switch self {
            case .subscriptionUnavailable:
                "Muse Code reports its subscription usage as currently unavailable. " +
                    "Check the plan in Muse Code (/usage)."
            case .unavailable: "Muse Code CLI was not found. Install Muse Code and sign in to its subscription."
            case .noSubscriptionUsage:
                "Muse Code did not show subscription usage. Sign in to Muse Code and try /usage there."
            }
        }
    }

    public static func load(
        binary: String = "muse",
        env: [String: String] = ProcessInfo.processInfo.environment) async throws -> UsageSnapshot
    {
        try Task.checkCancellation()
        let resolved: String
        if binary == "muse", let located = BinaryLocator.resolveMuseBinary(env: env) {
            resolved = located
        } else if binary.contains("/"), FileManager.default.isExecutableFile(atPath: binary) {
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: binary, isDirectory: &isDirectory),
                  !isDirectory.boolValue
            else {
                throw Error.unavailable
            }
            resolved = binary
        } else if let hit = TTYCommandRunner.which(binary, env: env) {
            resolved = hit
        } else {
            throw Error.unavailable
        }
        let task = Task.detached(priority: .utility) {
            do {
                return try Self.capture(binary: resolved, env: env, timeout: 18)
            } catch Error.noSubscriptionUsage {
                try Task.checkCancellation()
                self.log.info("Retrying Muse Code usage card after an incomplete CLI response")
                return try Self.capture(binary: resolved, env: env, timeout: 10)
            }
        }
        let text = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
        return try self.parse(text: text)
    }

    private static func capture(binary: String, env: [String: String], timeout: TimeInterval) throws -> String {
        try Task.checkCancellation()
        let options = TTYCommandRunner.Options(
            rows: 42,
            cols: 120,
            timeout: timeout,
            workingDirectory: FileManager.default.temporaryDirectory,
            extraArgs: ["--provider", "meta"],
            env: env)
        let context = try TTYCommandRunner.PTYRunContext(resolved: binary, options: options)
        defer { context.cleanup() }
        try context.launch()

        let started = Date()
        let deadline = started.addingTimeInterval(timeout)
        var commandSentAt: Date?
        var sentEnter = false
        var foundAt: Date?
        var clean = ""
        var needsDecode = true
        var cursorQueryBuffer = TTYCommandRunner.RollingBuffer(maxNeedle: TTYCommandRunner.cursorQuery.count)
        while Date() < deadline {
            if Task.isCancelled { throw CancellationError() }
            let chunk = context.readChunk()
            if !chunk.isEmpty {
                needsDecode = true
                if cursorQueryBuffer.append(chunk).range(of: TTYCommandRunner.cursorQuery) != nil {
                    try context.send("\u{1b}[1;1R")
                }
            }
            guard context.buffer.count <= 524_288 else { throw Error.noSubscriptionUsage }
            let elapsed = Date().timeIntervalSince(started)
            let shouldInspectText = (elapsed > 3 && commandSentAt == nil) || sentEnter
            if shouldInspectText, needsDecode {
                clean = TextParsing.stripANSICodes(Self.decodeLossyText(context.buffer))
                needsDecode = false
            }
            if elapsed > 3, commandSentAt == nil {
                if clean.localizedCaseInsensitiveContains("Muse Code") {
                    try context.send("/usage")
                    commandSentAt = Date()
                }
            }
            if let commandSentAt, Date().timeIntervalSince(commandSentAt) > 1, !sentEnter {
                try context.send("\r")
                sentEnter = true
                if needsDecode {
                    clean = TextParsing.stripANSICodes(Self.decodeLossyText(context.buffer))
                    needsDecode = false
                }
            }
            if sentEnter {
                if self.subscriptionUnavailable(in: clean) { throw Error.subscriptionUnavailable }
                if self.percent(after: "Current", in: clean) != nil
                    || self.percent(after: "Weekly", in: clean) != nil
                {
                    foundAt = foundAt ?? Date()
                    if let foundAt, Date().timeIntervalSince(foundAt) >= 0.8 { return clean }
                }
            }
            if !context.proc.isRunning { break }
            usleep(100_000)
        }
        if needsDecode {
            clean = TextParsing.stripANSICodes(Self.decodeLossyText(context.buffer))
        }
        self.log.warning("Muse Code usage card unavailable", metadata: [
            "bytes": "\(context.buffer.count)",
            "elapsedSeconds": "\(Int(Date().timeIntervalSince(started)))",
            "processRunning": "\(context.proc.isRunning)",
            "titleSeen": "\(clean.localizedCaseInsensitiveContains("Muse Code"))",
            "commandSent": "\(commandSentAt != nil)",
            "enterSent": "\(sentEnter)",
            "currentSeen": "\(clean.contains("Current"))",
            "weeklySeen": "\(clean.contains("Weekly"))",
        ])
        throw Error.noSubscriptionUsage
    }

    static func decodeLossyText(_ buffer: Data) -> String {
        // PTY reads frequently end mid-glyph on box-drawing/spinner UTF-8 sequences;
        // lossy decoding keeps all complete text instead of discarding the entire capture.
        // swiftlint:disable:next optional_data_string_conversion
        String(decoding: buffer, as: UTF8.self)
    }

    /// True when the card's "Subscription" block says the usage is unavailable
    /// and carries no Current/Weekly numbers.
    public static func subscriptionUnavailable(in clean: String) -> Bool {
        guard let sub = clean.range(of: "Subscription", options: .caseInsensitive) else { return false }
        let tail = clean[sub.upperBound...]
        guard tail.localizedCaseInsensitiveContains("Currently unavailable") else { return false }
        return self.percent(after: "Current", in: clean) == nil
            && self.percent(after: "Weekly", in: clean) == nil
    }

    public static func parse(text: String, now: Date = Date()) throws -> UsageSnapshot {
        let clean = TextParsing.stripANSICodes(text)
        guard clean.localizedCaseInsensitiveContains("Muse Code") else {
            throw Error.noSubscriptionUsage
        }
        let current = self.percent(after: "Current", in: clean)
        let weekly = self.percent(after: "Weekly", in: clean)
        guard current != nil || weekly != nil else {
            throw Error.noSubscriptionUsage
        }

        let currentResetDesc = current != nil ? self.resetDescription(after: "Current", in: clean) : nil
        let weeklyResetDesc = weekly != nil ? self.resetDescription(after: "Weekly", in: clean) : nil

        let currentWindow = current.map {
            RateWindow(
                usedPercent: $0,
                windowMinutes: 300,
                resetsAt: Self.parseResetDate(currentResetDesc, now: now),
                resetDescription: currentResetDesc,
                label: "Current",
                hasKnownLimit: true)
        }
        let weeklyWindow = weekly.map {
            RateWindow(
                usedPercent: $0,
                windowMinutes: 10080,
                resetsAt: Self.parseResetDate(weeklyResetDesc, now: now),
                resetDescription: weeklyResetDesc,
                label: "Weekly",
                hasKnownLimit: true)
        }

        return UsageSnapshot(
            primary: currentWindow ?? weeklyWindow ?? .noLimitsReported,
            secondary: currentWindow == nil ? nil : weeklyWindow,
            tertiary: nil,
            updatedAt: now,
            identity: nil)
    }

    private static func parseResetDate(_ description: String?, now: Date) -> Date? {
        guard let description else { return nil }
        return UsageResetParsing.date(fromRelative: description, now: now)
            ?? ClaudeStatusProbe.parseResetDate(from: description, now: now)
    }

    private static func percent(after label: String, in text: String) -> Double? {
        let pattern = #"\b"# + label + #"\s*([0-9]{1,3})\s*%\s*used"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
              let number = text[range].range(of: #"[0-9]{1,3}"#, options: .regularExpression)
        else { return nil }
        return Double(text[range][number])
    }

    private static func resetDescription(after label: String, in text: String) -> String? {
        let pattern = #"\b"# + label + #"\s*[0-9]{1,3}\s*%\s*used\s*[·•]?\s*(Resets?[^\n│]{1,55})"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let matched = String(text[range])
        guard let reset = matched.range(of: "Reset", options: .caseInsensitive) else { return nil }
        return String(matched[reset.lowerBound...])
            .replacingOccurrences(of: #"(?i)\b(Resets?)(at|in|on)(?=\S)"#, with: "$1 $2 ", options: .regularExpression)
            .replacingOccurrences(of: #"\b(Resets?)(?=[A-Z])"#, with: "$1 ", options: .regularExpression)
            .replacingOccurrences(of: #"([0-9])(at)(?=[0-9])"#, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: #"([A-Za-z])([0-9])"#, with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: #"([0-9])(AM|PM)\b"#, with: "$1 $2", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
