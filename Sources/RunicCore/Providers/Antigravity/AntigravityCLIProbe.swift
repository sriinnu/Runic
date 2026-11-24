import Foundation

/// Reads Antigravity model quotas and account metadata from the official `agy` CLI
/// by opening an interactive TTY session, waiting for the prompt to settle, and
/// invoking `/usage` (`Models & Quota`).
public struct AntigravityCLIProbe: Sendable {
    public var timeout: TimeInterval = 20.0
    public var agyBinary: String?
    private static let log = RunicLog.logger("antigravity-cli")

    public init(timeout: TimeInterval = 20.0, agyBinary: String? = nil) {
        self.timeout = timeout
        self.agyBinary = agyBinary
    }

    public static func resolveBinary(
        env: [String: String] = ProcessInfo.processInfo.environment,
        loginPATH: [String]? = LoginShellPathCache.shared.current,
        fileManager: FileManager = .default,
        home: String = NSHomeDirectory()) -> String?
    {
        if let override = env["ANTIGRAVITY_CLI_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty,
           fileManager.isExecutableFile(atPath: override)
        {
            return override
        }

        if let hit = TTYCommandRunner.which("agy"), fileManager.isExecutableFile(atPath: hit) {
            return hit
        }

        var candidates: [String] = [
            URL(fileURLWithPath: home).appendingPathComponent(".local/bin/agy").path,
            "/opt/homebrew/bin/agy",
            "/usr/local/bin/agy",
        ]
        if let loginPATH {
            candidates.insert(contentsOf: loginPATH.map {
                URL(fileURLWithPath: $0).appendingPathComponent("agy").path
            }, at: 0)
        }
        if let pathEnv = env["PATH"] {
            for component in pathEnv.split(separator: ":") {
                candidates.append(URL(fileURLWithPath: String(component)).appendingPathComponent("agy").path)
            }
        }

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }

    public static func detectVersion(timeout: TimeInterval = 2.0) async -> String? {
        guard let binary = resolveBinary() else { return nil }
        do {
            let result = try await SubprocessRunner.run(
                binary: binary,
                arguments: ["--version"],
                environment: TTYCommandRunner.enrichedEnvironment(),
                timeout: timeout,
                label: "antigravity-cli-version")
            return result.stdout
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
        } catch {
            return nil
        }
    }

    public func fetch(now: Date = Date()) async throws -> AntigravityStatusSnapshot {
        let resolved = self.agyBinary ?? Self.resolveBinary()
        guard let binary = resolved, FileManager.default.isExecutableFile(atPath: binary) else {
            throw AntigravityStatusProbeError.standaloneTokenUnavailable(version: nil)
        }

        let workDir = Self.probeWorkingDirectoryURL()
        let timeout = self.timeout
        let rawText: String = try await Task.detached(priority: .userInitiated) {
            let scriptPath = "/usr/bin/script"
            let useScript = FileManager.default.isExecutableFile(atPath: scriptPath)
            let launchBinary = useScript ? scriptPath : binary
            let launchArgs = useScript ? ["-q", "/dev/null", binary] : []
            let options = TTYCommandRunner.Options(
                rows: 45,
                cols: 140,
                timeout: timeout,
                idleTimeout: 10.0,
                workingDirectory: workDir,
                extraArgs: launchArgs,
                initialDelay: 0.3,
                sendEnterEvery: nil,
                sendOnSubstrings: [
                    "Do you trust the contents of this project?": "\r",
                    "? for shortcuts": "/usage\r",
                ],
                stopOnURL: false,
                stopOnSubstrings: ["Within each group"],
                settleAfterStop: 1.5)
            let result = try TTYCommandRunner().run(binary: launchBinary, send: "", options: options)
            return result.text
        }.value

        let snapshot = try Self.parse(rawText: rawText, now: now)
        Self.log.info("Antigravity CLI scrape ok", metadata: [
            "windows": "\(snapshot.modelQuotas.count)",
        ])
        return snapshot
    }

    static func probeWorkingDirectoryURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let dir = base
            .appendingPathComponent("Runic", isDirectory: true)
            .appendingPathComponent("AntigravityProbe", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return fm.temporaryDirectory
        }
    }

    // MARK: - Parsing

    public static func parse(rawText: String, now: Date = Date()) throws -> AntigravityStatusSnapshot {
        let clean = Self.stripTerminalSequences(rawText)
        let lines = clean
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { line in
                line.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let email = Self.extractEmail(from: lines)
        let plan = Self.extractPlan(from: lines)
        let quotas = Self.extractQuotas(from: lines, now: now)

        guard !quotas.isEmpty else {
            let joined = lines.joined(separator: "\n")
            let lower = joined.lowercased()
            if !joined.contains("Models & Quota"),
               lower.contains("not signed in") || lower.contains("sign in to") || lower.contains("run /login")
            {
                throw AntigravityStatusProbeError.apiError(
                    "Antigravity CLI isn't signed in. Run 'agy' in Terminal to sign in.")
            }
            throw AntigravityStatusProbeError.parseFailed("Could not read Models & Quota from agy /usage.")
        }

        return AntigravityStatusSnapshot(
            modelQuotas: quotas,
            accountEmail: email,
            accountPlan: plan)
    }

    static func stripTerminalSequences(_ text: String) -> String {
        // Strip OSC sequences first (`ESC ] ... BEL` or `ESC ] ... ESC \`),
        // then let `TextParsing.stripANSICodes` convert cursor movements and drop CSI codes,
        // then remove any stray 2-byte ESC sequences.
        let withoutOSC = text.replacingOccurrences(
            of: #"\u001B\][^\u0007\u001B]*(?:\u0007|\u001B\\)"#,
            with: "",
            options: .regularExpression)
        let withoutCSI = TextParsing.stripANSICodes(withoutOSC)
        return withoutCSI.replacingOccurrences(
            of: #"\u001B[@-Z\\-_]"#,
            with: "",
            options: .regularExpression)
    }

    private static func extractEmail(from lines: [String]) -> String? {
        for line in lines {
            if let match = line.firstMatch(of: /(?i)^account:\s*([A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,})/) {
                return String(match.1)
            }
        }
        for line in lines {
            if let match = line.firstMatch(of: /(?i)([A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,})/) {
                return String(match.1)
            }
        }
        return nil
    }

    static func extractPlan(from lines: [String]) -> String? {
        let ignored: Set = [
            "high",
            "xhigh",
            "medium",
            "low",
            "neon",
            "carbon",
            "argon",
            "hydrogen",
            "shift+tab to cycle",
        ]
        for line in lines {
            for match in line.matches(of: /\(([^()]{2,48})\)/) {
                let candidate = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
                let lower = candidate.lowercased()
                if ignored.contains(lower) { continue }
                if lower.contains("of ") && lower.contains("lines") { continue }
                if lower.contains("ctrl+") || lower.contains("shift+") { continue }
                if lower.contains("ai ") || lower.contains("pro") || lower.contains("ultra")
                    || lower.contains("enterprise") || lower.contains("team") || lower.contains("free")
                    || lower.contains("plus") || lower.contains("max") || lower.contains("workspace")
                {
                    return candidate
                }
            }
        }
        for line in lines {
            if let match = line.firstMatch(of: /(?i)\b(?:plan|tier|subscription)\s*:\s*([^\n(|]+)/) {
                let candidate = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty { return candidate }
            }
        }
        for line in lines {
            if let match = line.firstMatch(
                of: /(?i)\b(Google\s+(?:One\s+)?AI\s+(?:Ultra|Pro)|AI\s+(?:Ultra|Pro))\b/)
            {
                return String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private enum WindowKind {
        case fiveHour
        case weekly

        var suffix: String {
            switch self {
            case .fiveHour: "5h"
            case .weekly: "Weekly"
            }
        }

        var windowMinutes: Int {
            switch self {
            case .fiveHour: 300
            case .weekly: 10080
            }
        }

        var modelIdPrefix: String {
            switch self {
            case .fiveHour: "5h"
            case .weekly: "weekly"
            }
        }
    }

    private static func extractQuotas(from lines: [String], now: Date) -> [AntigravityModelQuota] {
        var quotas: [AntigravityModelQuota] = []
        var currentGroupName: String?
        var idx = 0

        while idx < lines.count {
            let line = lines[idx]

            if let group = Self.parseGroupHeading(line) {
                currentGroupName = group
                idx += 1
                continue
            }

            guard let windowKind = Self.parseWindowKind(line) else {
                idx += 1
                continue
            }

            var remainingPercent: Double?
            var resetTime: Date?
            var resetDescription: String?

            var lookahead = idx + 1
            while lookahead < lines.count, lookahead <= idx + 5 {
                let candidate = lines[lookahead]
                if Self.parseGroupHeading(candidate) != nil || Self.parseWindowKind(candidate) != nil {
                    break
                }
                if candidate.hasPrefix("│") || candidate.hasPrefix("↑/") || candidate.hasPrefix("press ") {
                    break
                }

                if remainingPercent == nil,
                   let match = candidate.firstMatch(of: /([0-9]+(?:\.[0-9]+)?)\s*%/)
                {
                    remainingPercent = Double(match.1)
                } else if resetDescription == nil {
                    if let parsedReset = Self.parseRefreshLine(candidate, now: now) {
                        resetTime = parsedReset.date
                        resetDescription = parsedReset.description
                    } else if candidate.localizedCaseInsensitiveContains("Quota available") {
                        resetDescription = "Quota available"
                    }
                }

                lookahead += 1
            }

            if let remainingPercent {
                let group = currentGroupName ?? "Antigravity"
                let clampedRemaining = max(0, min(100, remainingPercent))
                let slug = group
                    .lowercased()
                    .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                quotas.append(AntigravityModelQuota(
                    label: "\(group) \(windowKind.suffix)",
                    modelId: "antigravity-\(slug)-\(windowKind.modelIdPrefix)",
                    remainingFraction: clampedRemaining / 100.0,
                    resetTime: resetTime,
                    resetDescription: resetDescription,
                    windowMinutes: windowKind.windowMinutes))
            }

            idx = lookahead
        }

        return quotas
    }

    private static func parseGroupHeading(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == trimmed.uppercased(),
              trimmed.hasSuffix(" MODELS"),
              !trimmed.contains(":")
        else {
            return nil
        }

        let rawGroup = String(trimmed.dropLast(" MODELS".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch rawGroup {
        case "GEMINI":
            return "Gemini"
        case "CLAUDE AND GPT":
            return "Claude & GPT"
        default:
            guard !rawGroup.isEmpty else { return nil }
            return rawGroup
                .split(separator: " ")
                .map { word in
                    let lower = word.lowercased()
                    if lower == "and" { return "&" }
                    if lower == "gpt" { return "GPT" }
                    return lower.prefix(1).uppercased() + lower.dropFirst()
                }
                .joined(separator: " ")
        }
    }

    private static func parseWindowKind(_ line: String) -> WindowKind? {
        let lower = line.lowercased()
        if lower.contains("five hour limit remaining") || lower.contains("5 hour limit remaining") {
            return .fiveHour
        }
        if lower.contains("weekly limit remaining") {
            return .weekly
        }
        return nil
    }

    private static func parseRefreshLine(_ line: String, now: Date) -> (date: Date, description: String)? {
        guard let match = line.firstMatch(of: /(?i)refreshes\s+in\s+(.+)$/) else { return nil }
        let rawDuration = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawDuration.isEmpty else { return nil }

        var totalSeconds: TimeInterval = 0
        var matchedUnit = false

        if let days = rawDuration.firstMatch(of: /(?i)(\d+)\s*d/), let val = Double(days.1) {
            totalSeconds += val * 86400
            matchedUnit = true
        }
        if let hours = rawDuration.firstMatch(of: /(?i)(\d+)\s*h/), let val = Double(hours.1) {
            totalSeconds += val * 3600
            matchedUnit = true
        }
        if let mins = rawDuration.firstMatch(of: /(?i)(\d+)\s*m(?!s)/), let val = Double(mins.1) {
            totalSeconds += val * 60
            matchedUnit = true
        }
        if let secs = rawDuration.firstMatch(of: /(?i)(\d+)\s*s/), let val = Double(secs.1) {
            totalSeconds += val
            matchedUnit = true
        }

        guard matchedUnit else { return nil }
        let resetDate = now.addingTimeInterval(totalSeconds)
        return (date: resetDate, description: "Resets in \(rawDuration)")
    }
}
