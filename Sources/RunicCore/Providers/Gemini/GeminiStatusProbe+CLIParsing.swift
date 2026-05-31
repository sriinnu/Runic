import Foundation

extension GeminiStatusProbe {
    // MARK: - Legacy CLI parsing (kept for fallback)

    public static func parse(text: String) throws -> GeminiStatusSnapshot {
        let clean = TextParsing.stripANSICodes(text)
        guard !clean.isEmpty else { throw GeminiStatusProbeError.timedOut }

        let quotas = Self.parseModelUsageTable(clean)

        if quotas.isEmpty {
            if clean.contains("Login with Google") || clean.contains("Use Gemini API key") {
                throw GeminiStatusProbeError.notLoggedIn
            }
            if clean.contains("Waiting for auth"), !clean.contains("Usage") {
                throw GeminiStatusProbeError.notLoggedIn
            }
            throw GeminiStatusProbeError.parseFailed("No usage data found in /stats output")
        }

        return GeminiStatusSnapshot(
            modelQuotas: quotas,
            rawText: text,
            accountEmail: nil,
            accountPlan: nil)
    }

    private static func parseModelUsageTable(_ text: String) -> [GeminiModelQuota] {
        let lines = text.components(separatedBy: .newlines)
        var quotas: [GeminiModelQuota] = []

        let pattern = #"(gemini[-\w.]+)\s+[\d-]+\s+([0-9]+(?:\.[0-9]+)?)\s*%\s*\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        for line in lines {
            let cleanLine = line.replacingOccurrences(of: "│", with: " ")
            let range = NSRange(cleanLine.startIndex..<cleanLine.endIndex, in: cleanLine)
            guard let match = regex.firstMatch(in: cleanLine, options: [], range: range),
                  match.numberOfRanges >= 4 else { continue }

            guard let modelRange = Range(match.range(at: 1), in: cleanLine),
                  let pctRange = Range(match.range(at: 2), in: cleanLine),
                  let pct = Double(cleanLine[pctRange])
            else { continue }

            let modelId = String(cleanLine[modelRange])
            var resetDesc: String?
            if let resetRange = Range(match.range(at: 3), in: cleanLine) {
                resetDesc = String(cleanLine[resetRange]).trimmingCharacters(in: .whitespaces)
            }

            quotas.append(GeminiModelQuota(
                modelId: modelId,
                percentLeft: pct,
                resetTime: nil,
                resetDescription: resetDesc))
        }

        return quotas
    }
}
