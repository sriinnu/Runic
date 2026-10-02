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

        public var errorDescription: String? {
            switch self {
            case .unavailable: "Muse Code CLI was not found. Install Muse Code and sign in to its subscription."
            case .noSubscriptionUsage:
                "Muse Code did not show subscription usage. Sign in to Muse Code and try /usage there."
            }
        }
    }

    public static func load(binary: String = "muse") async throws -> UsageSnapshot {
        guard let resolved = TTYCommandRunner.which(binary) else { throw Error.unavailable }
        let text = try await Task.detached(priority: .utility) {
            do {
                return try self.capture(binary: resolved, timeout: 30)
            } catch Error.noSubscriptionUsage {
                self.log.info("Retrying Muse Code usage card after an incomplete CLI response")
                return try self.capture(binary: resolved, timeout: 15)
            }
        }.value
        return try self.parse(text: text)
    }

    private static func capture(binary: String, timeout: TimeInterval) throws -> String {
        let options = TTYCommandRunner.Options(
            rows: 42,
            cols: 120,
            timeout: timeout,
            workingDirectory: FileManager.default.temporaryDirectory,
            extraArgs: ["--provider", "meta"])
        let context = try TTYCommandRunner.PTYRunContext(resolved: binary, options: options)
        defer { context.cleanup() }
        try context.launch()

        let started = Date()
        let deadline = started.addingTimeInterval(timeout)
        var commandSentAt: Date?
        var sentEnter = false
        var foundAt: Date?
        var cursorQueryBuffer = TTYCommandRunner.RollingBuffer(maxNeedle: TTYCommandRunner.cursorQuery.count)
        while Date() < deadline {
            let chunk = context.readChunk()
            if cursorQueryBuffer.append(chunk).range(of: TTYCommandRunner.cursorQuery) != nil {
                try context.send("\u{1b}[1;1R")
            }
            guard context.buffer.count <= 524_288 else { throw Error.noSubscriptionUsage }
            let elapsed = Date().timeIntervalSince(started)
            if elapsed > 3, commandSentAt == nil {
                let clean = TextParsing.stripANSICodes(String(bytes: context.buffer, encoding: .utf8) ?? "")
                if clean.localizedCaseInsensitiveContains("Muse Code") {
                    try context.send("/usage")
                    commandSentAt = Date()
                }
            }
            if let commandSentAt, Date().timeIntervalSince(commandSentAt) > 1, !sentEnter {
                try context.send("\r")
                sentEnter = true
            }
            if sentEnter {
                let clean = TextParsing.stripANSICodes(String(bytes: context.buffer, encoding: .utf8) ?? "")
                if self.percent(after: "Current", in: clean) != nil,
                   self.percent(after: "Weekly", in: clean) != nil
                {
                    foundAt = foundAt ?? Date()
                    if let foundAt, Date().timeIntervalSince(foundAt) >= 0.5 { return clean }
                }
            }
            if !context.proc.isRunning { break }
            usleep(100_000)
        }
        let clean = TextParsing.stripANSICodes(String(bytes: context.buffer, encoding: .utf8) ?? "")
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

    public static func parse(text: String, now: Date = Date()) throws -> UsageSnapshot {
        let clean = TextParsing.stripANSICodes(text)
        guard clean.localizedCaseInsensitiveContains("Muse Code"),
              let current = self.percent(after: "Current", in: clean),
              let weekly = self.percent(after: "Weekly", in: clean)
        else { throw Error.noSubscriptionUsage }

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: current,
                windowMinutes: 300,
                resetsAt: nil,
                resetDescription: self.resetDescription(after: "Current", in: clean),
                label: "Current",
                hasKnownLimit: true),
            secondary: RateWindow(
                usedPercent: weekly,
                windowMinutes: 10080,
                resetsAt: nil,
                resetDescription: self.resetDescription(after: "Weekly", in: clean),
                label: "Weekly",
                hasKnownLimit: true),
            tertiary: nil,
            updatedAt: now,
            identity: nil)
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
