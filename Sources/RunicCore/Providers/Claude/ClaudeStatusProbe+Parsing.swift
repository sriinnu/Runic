import Foundation

extension ClaudeStatusProbe {
    private struct LabelSearchContext {
        let lines: [String]
        let normalizedLines: [String]
        let normalizedData: Data

        init(text: String) {
            self.lines = text.components(separatedBy: .newlines)
            self.normalizedLines = self.lines.map { ClaudeStatusProbe.normalizedForLabelSearch($0) }
            let normalized = ClaudeStatusProbe.normalizedForLabelSearch(text)
            self.normalizedData = Data(normalized.utf8)
        }

        func contains(_ needle: Data) -> Bool {
            self.normalizedData.range(of: needle) != nil
        }
    }

    private static let weeklyLabelNeedle = Data("current week".utf8)
    private static let opusLabelNeedle = Data("opus".utf8)
    private static let sonnetLabelNeedle = Data("sonnet".utf8)

    public static func parse(text: String, statusText: String? = nil) throws -> ClaudeStatusSnapshot {
        let clean = TextParsing.stripANSICodes(text)
        let statusClean = statusText.map(TextParsing.stripANSICodes)
        guard !clean.isEmpty else { throw ClaudeStatusProbeError.timedOut }

        let shouldDump = ProcessInfo.processInfo.environment["DEBUG_CLAUDE_DUMP"] == "1"

        if let usageError = self.extractUsageError(text: clean) {
            Self.dumpIfNeeded(
                enabled: shouldDump,
                reason: "usageError: \(usageError)",
                usage: clean,
                status: statusText)
            throw ClaudeStatusProbeError.parseFailed(usageError)
        }

        let labelContext = LabelSearchContext(text: clean)

        var sessionPct = self.extractPercent(labelSubstring: "Current session", context: labelContext)
        var weeklyPct = self.extractPercent(labelSubstring: "Current week (all models)", context: labelContext)
        var opusPct = self.extractPercent(
            labelSubstrings: [
                "Current week (Opus)",
                "Current week (Sonnet only)",
                "Current week (Sonnet)",
            ],
            context: labelContext)

        // Fallback: order-based percent scraping when labels are present but the surrounding layout moved.
        // Only apply the fallback when the corresponding label exists in the rendered panel; enterprise accounts
        // may omit the weekly panel entirely, and we should treat that as "unavailable" rather than guessing.
        let hasWeeklyLabel = labelContext.contains(Self.weeklyLabelNeedle)
        let hasOpusLabel = labelContext.contains(Self.opusLabelNeedle) || labelContext.contains(Self.sonnetLabelNeedle)

        if sessionPct == nil || (hasWeeklyLabel && weeklyPct == nil) || (hasOpusLabel && opusPct == nil) {
            let ordered = self.allPercents(clean)
            if sessionPct == nil, ordered.indices.contains(0) { sessionPct = ordered[0] }
            if hasWeeklyLabel, weeklyPct == nil, ordered.indices.contains(1) { weeklyPct = ordered[1] }
            if hasOpusLabel, opusPct == nil, ordered.indices.contains(2) { opusPct = ordered[2] }
        }

        let identity = Self.parseIdentity(usageText: clean, statusText: statusClean)

        guard let sessionPct else {
            Self.dumpIfNeeded(
                enabled: shouldDump,
                reason: "missing session label",
                usage: clean,
                status: statusText)
            throw ClaudeStatusProbeError.parseFailed("Missing Current session")
        }

        let sessionReset = self.extractReset(labelSubstring: "Current session", context: labelContext)
        let weeklyReset = hasWeeklyLabel
            ? self.extractReset(labelSubstring: "Current week (all models)", context: labelContext)
            : nil
        let opusReset = hasOpusLabel
            ? self.extractReset(
                labelSubstrings: [
                    "Current week (Opus)",
                    "Current week (Sonnet only)",
                    "Current week (Sonnet)",
                ],
                context: labelContext)
            : nil

        return ClaudeStatusSnapshot(
            sessionPercentLeft: sessionPct,
            weeklyPercentLeft: weeklyPct,
            opusPercentLeft: opusPct,
            accountEmail: identity.accountEmail,
            accountOrganization: identity.accountOrganization,
            loginMethod: identity.loginMethod,
            primaryResetDescription: sessionReset,
            secondaryResetDescription: weeklyReset,
            opusResetDescription: opusReset,
            rawText: text + (statusText ?? ""))
    }

    private static func extractPercent(labelSubstring: String, context: LabelSearchContext) -> Int? {
        let lines = context.lines
        let label = self.normalizedForLabelSearch(labelSubstring)
        for (idx, normalizedLine) in context.normalizedLines.enumerated() where normalizedLine.contains(label) {
            // Claude's usage panel can take a moment to render percentages (especially on enterprise accounts),
            // so scan a larger window than the original 3–4 lines.
            let window = lines.dropFirst(idx).prefix(12)
            for candidate in window {
                if let pct = percentFromLine(candidate) { return pct }
            }
        }
        return nil
    }

    private static func extractPercent(labelSubstrings: [String], context: LabelSearchContext) -> Int? {
        for label in labelSubstrings {
            if let value = self.extractPercent(labelSubstring: label, context: context) { return value }
        }
        return nil
    }

    private static func percentFromLine(_ line: String) -> Int? {
        // Allow optional Unicode whitespace before % to handle CLI formatting changes.
        let pattern = #"([0-9]{1,3})\p{Zs}*%\s*(used|left)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges >= 3,
              let valRange = Range(match.range(at: 1), in: line),
              let kindRange = Range(match.range(at: 2), in: line)
        else { return nil }
        let rawVal = Int(line[valRange]) ?? 0
        let isUsed = line[kindRange].lowercased().contains("used")
        return isUsed ? max(0, 100 - rawVal) : rawVal
    }

    /// Collect remaining percentages in the order they appear; used as a backup when labels move/rename.
    private static func allPercents(_ text: String) -> [Int] {
        let pat = #"([0-9]{1,3})\p{Zs}*%\s*(left|used)"#
        guard let regex = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]) else { return [] }
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        var results: [Int] = []
        regex.enumerateMatches(in: text, options: [], range: nsrange) { match, _, _ in
            guard let match,
                  match.numberOfRanges >= 3,
                  let valRange = Range(match.range(at: 1), in: text),
                  let kindRange = Range(match.range(at: 2), in: text),
                  let val = Int(text[valRange]) else { return }
            let kind = text[kindRange].lowercased()
            let remaining = kind.contains("used") ? max(0, 100 - val) : max(0, min(val, 100))
            results.append(remaining)
        }
        return results
    }

    private static func extractReset(labelSubstring: String, context: LabelSearchContext) -> String? {
        let lines = context.lines
        let label = self.normalizedForLabelSearch(labelSubstring)
        for (idx, normalizedLine) in context.normalizedLines.enumerated() where normalizedLine.contains(label) {
            let window = lines.dropFirst(idx).prefix(14)
            for candidate in window {
                let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized = self.normalizedForLabelSearch(trimmed)
                if normalized.hasPrefix("current "), !normalized.contains(label) { break }
                if let reset = self.resetFromLine(candidate) { return reset }
            }
        }
        return nil
    }

    private static func extractReset(labelSubstrings: [String], context: LabelSearchContext) -> String? {
        for label in labelSubstrings {
            if let value = self.extractReset(labelSubstring: label, context: context) { return value }
        }
        return nil
    }

    private static func resetFromLine(_ line: String) -> String? {
        guard let range = line.range(of: "Resets", options: [.caseInsensitive]) else { return nil }
        let raw = String(line[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return self.cleanResetLine(raw)
    }

    private static func normalizedForLabelSearch(_ text: String) -> String {
        text.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func cleanResetLine(_ raw: String) -> String {
        // TTY capture sometimes appends a stray ")" at line ends; trim it to keep snapshots stable.
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " )"))
        let openCount = cleaned.count(where: { $0 == "(" })
        let closeCount = cleaned.count(where: { $0 == ")" })
        if openCount > closeCount { cleaned.append(")") }
        return cleaned
    }

    private static func dumpIfNeeded(enabled: Bool, reason: String, usage: String, status: String?) {
        guard enabled else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        var parts = [
            "=== Claude parse dump @ \(stamp) ===",
            "Reason: \(reason)",
            "",
            "--- usage (clean) ---",
            usage,
            "",
        ]
        if let status {
            parts.append(contentsOf: [
                "--- status (raw/optional) ---",
                status,
                "",
            ])
        }
        let body = parts.joined(separator: "\n")
        Task { @MainActor in self.recordDump(body) }
    }
}
