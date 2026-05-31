import Foundation

extension ClaudeStatusProbe {
    static func extractUsageError(text: String) -> String? {
        if let jsonHint = self.extractUsageErrorJSON(text: text) { return jsonHint }

        let lower = text.lowercased()
        if lower.contains("do you trust the files in this folder?"), !lower.contains("current session") {
            let folder = self.extractFirstUsageError(
                pattern: #"Do you trust the files in this folder\?\s*(?:\r?\n)+\s*([^\r\n]+)"#,
                text: text)
            let folderHint = folder.flatMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            if let folderHint {
                return """
                Claude CLI is waiting for a folder trust prompt (\(folderHint)). Runic tries to auto-accept this, \
                but if it keeps appearing run: `cd "\(folderHint)" && claude` and choose “Yes, proceed”, then retry.
                """
            }
            return """
            Claude CLI is waiting for a folder trust prompt. Runic tries to auto-accept this, but if it keeps \
            appearing open `claude` once, choose “Yes, proceed”, then retry.
            """
        }
        if lower.contains("token_expired") || lower.contains("token has expired") {
            return "Claude CLI token expired. Run `claude login` to refresh."
        }
        if lower.contains("authentication_error") {
            return "Claude CLI authentication error. Run `claude login`."
        }
        if lower.contains("failed to load usage data") {
            return "Claude CLI could not load usage data. Open the CLI and retry `/usage`."
        }
        return nil
    }

    private static func extractFirstUsageError(pattern: String, text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractUsageErrorJSON(text: String) -> String? {
        let pattern = #"Failed to load usage data:\s*(\{.*\})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let jsonRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let jsonString = String(text[jsonRange])
        guard let data = jsonString.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = payload["error"] as? [String: Any]
        else {
            return nil
        }

        let message = (error["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = error["details"] as? [String: Any]
        let code = (details?["error_code"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if let message, !message.isEmpty { parts.append(message) }
        if let code, !code.isEmpty { parts.append("(\(code))") }

        guard !parts.isEmpty else { return nil }
        let hint = parts.joined(separator: " ")

        if let code, code.lowercased().contains("token") {
            return "\(hint). Run `claude login` to refresh."
        }
        return "Claude CLI error: \(hint)"
    }
}
