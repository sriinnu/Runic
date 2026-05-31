import Foundation

extension ClaudeStatusProbe {
    public static func parseIdentity(usageText: String?, statusText: String?) -> ClaudeAccountIdentity {
        let usageClean = usageText.map(TextParsing.stripANSICodes) ?? ""
        let statusClean = statusText.map(TextParsing.stripANSICodes)
        return self.extractIdentity(usageText: usageClean, statusText: statusClean)
    }

    private static func extractIdentity(usageText: String, statusText: String?) -> ClaudeAccountIdentity {
        let emailPatterns = [
            #"(?i)Account:\s+([^\s@]+@[^\s@]+)"#,
            #"(?i)Email:\s+([^\s@]+@[^\s@]+)"#,
        ]
        let looseEmailPatterns = [
            #"(?i)Account:\s+(\S+)"#,
            #"(?i)Email:\s+(\S+)"#,
        ]
        let email = emailPatterns
            .compactMap { self.extractFirstIdentity(pattern: $0, text: usageText) }
            .first
            ?? emailPatterns
            .compactMap { self.extractFirstIdentity(pattern: $0, text: statusText ?? "") }
            .first
            ?? looseEmailPatterns
            .compactMap { self.extractFirstIdentity(pattern: $0, text: usageText) }
            .first
            ?? looseEmailPatterns
            .compactMap { self.extractFirstIdentity(pattern: $0, text: statusText ?? "") }
            .first
            ?? self.extractFirstIdentity(
                pattern: #"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
                text: usageText)
            ?? self.extractFirstIdentity(
                pattern: #"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
                text: statusText ?? "")
        let orgPatterns = [
            #"(?i)Org:\s*(.+)"#,
            #"(?i)Organization:\s*(.+)"#,
        ]
        let orgRaw = orgPatterns
            .compactMap { self.extractFirstIdentity(pattern: $0, text: usageText) }
            .first
            ?? orgPatterns
            .compactMap { self.extractFirstIdentity(pattern: $0, text: statusText ?? "") }
            .first
        let org: String? = {
            guard let orgText = orgRaw?.trimmingCharacters(in: .whitespacesAndNewlines), !orgText.isEmpty else {
                return nil
            }
            // Suppress org if it is just the email prefix (common in CLI panels).
            if let email, orgText.lowercased().hasPrefix(email.lowercased()) { return nil }
            return orgText
        }()
        // Prefer explicit login method from /status, then fall back to /usage header heuristics.
        let login = self.extractLoginMethod(text: statusText ?? "") ?? self.extractLoginMethod(text: usageText)
        return ClaudeAccountIdentity(accountEmail: email, accountOrganization: org, loginMethod: login)
    }

    private static func extractFirstIdentity(pattern: String, text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract login/plan string from CLI output.
    private static func extractLoginMethod(text: String) -> String? {
        guard !text.isEmpty else { return nil }
        if let explicit = self.extractFirstIdentity(pattern: #"(?i)login\s+method:\s*(.+)"#, text: text) {
            return self.cleanPlan(explicit)
        }
        // Capture any "Claude <...>" phrase (e.g., Max/Pro/Ultra/Team) to avoid future plan-name churn.
        let planPattern = #"(?i)(claude\s+[a-z0-9][a-z0-9\s._-]{0,24})"#
        var candidates: [String] = []
        if let regex = try? NSRegularExpression(pattern: planPattern, options: []) {
            let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
            regex.enumerateMatches(in: text, options: [], range: nsrange) { match, _, _ in
                guard let match,
                      match.numberOfRanges >= 2,
                      let r = Range(match.range(at: 1), in: text) else { return }
                let raw = String(text[r])
                let val = Self.cleanPlan(raw)
                candidates.append(val)
            }
        }
        if let plan = candidates.first(where: { cand in
            let lower = cand.lowercased()
            return !lower.contains("code v") && !lower.contains("code version") && !lower.contains("code")
        }) {
            return plan
        }
        return nil
    }

    /// Strips ANSI and stray bracketed codes like "[22m" that can survive CLI output.
    private static func cleanPlan(_ text: String) -> String {
        UsageFormatter.cleanPlanName(text)
    }
}
