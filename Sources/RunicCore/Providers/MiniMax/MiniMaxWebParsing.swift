import Foundation

struct MiniMaxManualInput {
    let cookieHeader: String
    let accessToken: String?
    let groupID: String?
}

struct MiniMaxParsedUsage {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: Date?
    let resetDescription: String?
    let planName: String?
    let modelName: String?
    /// A second model's quota, when MiniMax reports more than one entry (for
    /// example a "spark"/preview tier alongside the standard model).
    let secondaryModel: MiniMaxWebParsing.ModelRemainsUsage?

    func toUsageSnapshot(updatedAt: Date) -> UsageSnapshot {
        let primary = RateWindow(
            usedPercent: min(100, max(0, self.usedPercent)),
            windowMinutes: self.windowMinutes,
            resetsAt: self.resetsAt,
            resetDescription: self.resetDescription,
            label: self.modelName)
        // Only one extra slot (tertiary) is available on UsageSnapshot, so a
        // third-plus model quota is not shown yet — surfacing at least the
        // second model beats always dropping it.
        let tertiary = self.secondaryModel.map { model in
            RateWindow(
                usedPercent: min(100, max(0, model.usedPercent)),
                windowMinutes: self.windowMinutes,
                resetsAt: self.resetsAt,
                resetDescription: self.resetDescription,
                label: model.modelName)
        }
        let identity = ProviderIdentitySnapshot(
            providerID: .minimax,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: self.planName)
        return UsageSnapshot(
            primary: primary,
            secondary: nil,
            tertiary: tertiary,
            providerCost: nil,
            updatedAt: updatedAt,
            identity: identity)
    }
}

enum MiniMaxWebParsing {
    static func parseManualInput(_ raw: String) -> MiniMaxManualInput? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cookieHeader = self.extractCookieHeader(from: trimmed)
            ?? (self.looksLikeCookieHeader(trimmed) ? trimmed : nil)
        guard let cookieHeader, !cookieHeader.isEmpty else { return nil }

        let accessToken = self.extractBearerToken(from: trimmed)
        let groupID = self.extractGroupID(from: trimmed)
        return MiniMaxManualInput(cookieHeader: cookieHeader, accessToken: accessToken, groupID: groupID)
    }

    static func parseHTMLUsage(_ html: String, now: Date = Date()) -> MiniMaxParsedUsage? {
        let planName = self.extractHTMLTitle(from: html)
        guard let usage = self.extractAvailableUsage(from: html) else { return nil }
        let resetLine = self.extractResetLine(from: html)
        let resetInfo = resetLine.flatMap { self.parseResetDescription($0, now: now) }
        let windowMinutes = self.extractWindowMinutes(from: html)
        return MiniMaxParsedUsage(
            usedPercent: usage,
            windowMinutes: windowMinutes,
            resetsAt: resetInfo?.resetsAt,
            resetDescription: resetInfo?.resetDescription,
            planName: planName,
            modelName: nil,
            secondaryModel: nil)
    }

    static func parseRemainsResponse(_ data: Data, now: Date = Date()) throws -> MiniMaxParsedUsage {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MiniMaxWebUsageError.parseFailed("Invalid JSON")
        }

        if let base = json["base_resp"] as? [String: Any] {
            let retcode = self.doubleValue(base["retcode"]).map(Int.init) ?? 0
            let success = base["success"] as? Bool
            if success == false || retcode != 0 {
                let msg = base["msg"] as? String ?? "unknown error"
                if retcode == 1004 {
                    throw MiniMaxWebUsageError.notLoggedIn(msg)
                }
                throw MiniMaxWebUsageError.apiError(msg)
            }
        }

        let payload = (json["data"] as? [String: Any]) ?? json
        let allModelRemains = self.extractAllModelRemains(from: payload)
        guard let modelRemains = allModelRemains.first else {
            throw MiniMaxWebUsageError.parseFailed("Missing model_remains usage")
        }
        let usage = modelRemains.usedPercent
        // MiniMax may report more than one model quota (for example a
        // "spark"/preview tier alongside the standard model) — keep the
        // second one instead of always dropping it. Require a real, distinct
        // name: an unnamed entry has nothing meaningful to label it with and
        // would otherwise render as a misleading "Sonnet"/"Opus" fallback
        // title downstream, and `nil != nil` would falsely look distinct.
        let secondaryModel = allModelRemains.dropFirst().first { candidate in
            guard let candidateName = candidate.modelName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !candidateName.isEmpty
            else { return false }
            let primaryName = modelRemains.modelName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return candidateName != primaryName
        }

        let startTime = self.timestamp(payload["start_time"])
        let endTime = self.timestamp(payload["end_time"])
        let remainsTime = self.doubleValue(payload["remains_time"])
        let resetsAt = self.resolveResetDate(remainsTime: remainsTime, endTime: endTime, now: now)
        let windowMinutes = self.windowMinutes(start: startTime, end: endTime)
        let resetDescription = resetsAt.map { UsageFormatter.resetDescription(from: $0, now: now) }
        let planName = self.firstString(in: payload, keys: ["plan_name", "plan", "tier", "plan_title", "planType"])

        return MiniMaxParsedUsage(
            usedPercent: usage,
            windowMinutes: windowMinutes,
            resetsAt: resetsAt,
            resetDescription: resetDescription,
            planName: planName,
            modelName: modelRemains.modelName,
            secondaryModel: secondaryModel)
    }

    private static func extractCookieHeader(from text: String) -> String? {
        let pattern = "(?i)(?:-H|--header)?\\s*['\\\"]?Cookie\\s*:\\s*([^'\\\"\\r\\n]+)"
        return self.firstCapture(in: text, pattern: pattern)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { self.stripCookiePrefix($0) }
    }

    private static func stripCookiePrefix(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("cookie:") {
            let stripped = String(trimmed.dropFirst("cookie:".count))
            return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func looksLikeCookieHeader(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("=") else { return false }
        return !trimmed.lowercased().contains("curl ")
    }

    private static func extractBearerToken(from text: String) -> String? {
        let pattern = "(?i)Authorization\\s*:\\s*Bearer\\s+([^'\\\"\\r\\n]+)"
        return self.firstCapture(in: text, pattern: pattern)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func extractGroupID(from text: String) -> String? {
        if let match = self.firstCapture(in: text, pattern: "(?i)GroupId\\s*[:=]\\s*([A-Za-z0-9_-]+)") {
            return match
        }
        if let match = self.firstCapture(in: text, pattern: "(?i)group_id\\s*[:=]\\s*([A-Za-z0-9_-]+)") {
            return match
        }
        if let match = self.firstCapture(in: text, pattern: "(?i)(?:GroupId|group_id)=([^&'\"\\s]+)") {
            return match
        }
        return nil
    }

    private static func extractHTMLTitle(from html: String) -> String? {
        guard let raw = self.firstCapture(in: html, pattern: "(?is)<title[^>]*>(.*?)</title>") else {
            return nil
        }
        let cleaned = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func extractAvailableUsage(from html: String) -> Double? {
        if let groups = self.captureGroups(
            in: html,
            pattern: "(?i)Available usage[^0-9]*([0-9]+(?:\\.[0-9]+)?)\\s*/\\s*([0-9]+(?:\\.[0-9]+)?)")
        {
            let remaining = self.doubleValue(groups[0]) ?? 0
            let total = self.doubleValue(groups[1]) ?? 0
            if total > 0 {
                return min(100, max(0, (total - remaining) / total * 100))
            }
        }

        if let percent = self.captureGroups(
            in: html,
            pattern: "(?i)Available usage[^0-9]*([0-9]+(?:\\.[0-9]+)?)\\s*%")?.first
        {
            let remaining = self.doubleValue(percent) ?? 0
            return min(100, max(0, 100 - remaining))
        }

        if let remaining = self.captureGroups(
            in: html,
            pattern: "(?i)Available usage[^0-9]*([0-9]+(?:\\.[0-9]+)?)")?.first,
            let total = self.captureGroups(
                in: html,
                pattern: "(?i)Total usage[^0-9]*([0-9]+(?:\\.[0-9]+)?)")?.first
        {
            let remainingValue = self.doubleValue(remaining) ?? 0
            let totalValue = self.doubleValue(total) ?? 0
            if totalValue > 0 {
                return min(100, max(0, (totalValue - remainingValue) / totalValue * 100))
            }
        }

        return nil
    }

    private static func extractResetLine(from html: String) -> String? {
        guard let line = self.firstCapture(in: html, pattern: "(?i)(Resets in[^<\\n\\r]*)") else {
            return nil
        }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseResetDescription(
        _ line: String,
        now: Date) -> (resetsAt: Date?, resetDescription: String?)
    {
        let cleaned = line.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        let minutes = self.parseDurationMinutes(from: trimmed)
        let resetsAt = minutes.map { now.addingTimeInterval(TimeInterval($0 * 60)) }
        return (resetsAt, trimmed)
    }

    private static func extractWindowMinutes(from html: String) -> Int? {
        guard let groups = self.captureGroups(
            in: html,
            pattern: "(?i)(?:cycle|duration|period)[^0-9]*([0-9]+)\\s*(day|hour|week|month)")
        else { return nil }

        guard let value = Int(groups[0]) else { return nil }
        let unit = groups[1].lowercased()
        switch unit {
        case "hour", "hours":
            return value * 60
        case "day", "days":
            return value * 24 * 60
        case "week", "weeks":
            return value * 7 * 24 * 60
        case "month", "months":
            return value * 30 * 24 * 60
        default:
            return nil
        }
    }

    struct ModelRemainsUsage {
        let usedPercent: Double
        let modelName: String?
    }

    /// Returns every model quota entry found under `model_remains` (or its
    /// aliases). MiniMax may report more than one model — for example a
    /// "spark"/preview tier alongside the standard model — so callers should
    /// not assume only the first entry matters.
    private static func extractAllModelRemains(from payload: [String: Any]) -> [ModelRemainsUsage] {
        if let model = payload["model_remains"] {
            return self.extractAllUsagePercents(from: model)
        }
        if let model = payload["model_remain"] {
            return self.extractAllUsagePercents(from: model)
        }
        if let model = payload["remains"] {
            return self.extractAllUsagePercents(from: model)
        }
        return []
    }

    private static func extractAllUsagePercents(from value: Any) -> [ModelRemainsUsage] {
        if let dicts = value as? [[String: Any]] {
            return dicts.compactMap { self.extractUsagePercent(from: $0) }
        }
        if let single = self.extractUsagePercent(from: value) {
            return [single]
        }
        return []
    }

    private static func extractUsagePercent(from value: Any) -> ModelRemainsUsage? {
        guard let dict = value as? [String: Any] else { return nil }
        let used = self.doubleValue(dict["used"] ?? dict["used_quota"] ?? dict["usedQuota"])
        let total = self.doubleValue(dict["total"] ?? dict["total_quota"] ?? dict["totalQuota"])
        let remaining = self.doubleValue(dict["remaining"] ?? dict["remaining_quota"] ?? dict["remainingQuota"])
        let modelName = self.firstString(in: dict, keys: ["model_name", "model", "name", "label"])

        if let used, let total, total > 0 {
            return ModelRemainsUsage(
                usedPercent: min(100, max(0, used / total * 100)),
                modelName: modelName)
        }
        if let remaining, let total, total > 0 {
            return ModelRemainsUsage(
                usedPercent: min(100, max(0, (total - remaining) / total * 100)),
                modelName: modelName)
        }
        return nil
    }

    private static func windowMinutes(start: Date?, end: Date?) -> Int? {
        guard let start, let end else { return nil }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        return minutes > 0 ? minutes : nil
    }

    private static func resolveResetDate(remainsTime: Double?, endTime: Date?, now: Date) -> Date? {
        if let remains = remainsTime {
            if remains > 1_000_000_000 {
                return self.timestamp(remains)
            }
            return now.addingTimeInterval(remains)
        }
        return endTime
    }

    private static func timestamp(_ value: Any?) -> Date? {
        guard let value else { return nil }
        if let number = self.doubleValue(value) {
            return self.timestamp(number)
        }
        return nil
    }

    private static func timestamp(_ number: Double) -> Date? {
        if number > 10_000_000_000 {
            return Date(timeIntervalSince1970: number / 1000)
        }
        if number > 1_000_000_000 {
            return Date(timeIntervalSince1970: number)
        }
        return nil
    }

    private static func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange])
    }

    private static func captureGroups(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1
        else {
            return nil
        }
        var groups: [String] = []
        for index in 1..<match.numberOfRanges {
            guard let range = Range(match.range(at: index), in: text) else { continue }
            groups.append(String(text[range]))
        }
        return groups.isEmpty ? nil : groups
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let number = value as? Int64 { return Double(number) }
        if let number = value as? String {
            return Double(number.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func parseDurationMinutes(from line: String) -> Int? {
        var minutes = 0
        let patterns: [(String, Int)] = [
            ("(?i)([0-9]+)\\s*d", 24 * 60),
            ("(?i)([0-9]+)\\s*h", 60),
            ("(?i)([0-9]+)\\s*m", 1),
        ]
        for (pattern, multiplier) in patterns {
            if let capture = self.firstCapture(in: line, pattern: pattern),
               let value = Int(capture)
            {
                minutes += value * multiplier
            }
        }
        return minutes > 0 ? minutes : nil
    }
}
