import Foundation

extension ClaudeStatusProbe {
    /// Attempts to parse a Claude reset string into a Date, using the current year and handling optional timezones.
    public static func parseResetDate(from text: String?, now: Date = .init()) -> Date? {
        guard let normalized = self.normalizeResetInput(text) else { return nil }
        let (raw, timeZone) = normalized

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone ?? TimeZone.current
        formatter.defaultDate = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone

        if let date = self.parseDate(raw, formats: Self.resetDateTimeWithMinutes, formatter: formatter) {
            var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            comps.second = 0
            return calendar.date(from: comps)
        }
        if let date = self.parseDate(raw, formats: Self.resetDateTimeHourOnly, formatter: formatter) {
            var comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            comps.minute = 0
            comps.second = 0
            return calendar.date(from: comps)
        }

        if let time = self.parseDate(raw, formats: Self.resetTimeWithMinutes, formatter: formatter) {
            let comps = calendar.dateComponents([.hour, .minute], from: time)
            guard let anchored = calendar.date(
                bySettingHour: comps.hour ?? 0,
                minute: comps.minute ?? 0,
                second: 0,
                of: now) else { return nil }
            if anchored >= now { return anchored }
            return calendar.date(byAdding: .day, value: 1, to: anchored)
        }

        guard let time = self.parseDate(raw, formats: Self.resetTimeHourOnly, formatter: formatter) else { return nil }
        let comps = calendar.dateComponents([.hour], from: time)
        guard let anchored = calendar.date(
            bySettingHour: comps.hour ?? 0,
            minute: 0,
            second: 0,
            of: now) else { return nil }
        if anchored >= now { return anchored }
        return calendar.date(byAdding: .day, value: 1, to: anchored)
    }

    private static let resetTimeWithMinutes = ["h:mma", "h:mm a", "HH:mm", "H:mm"]
    private static let resetTimeHourOnly = ["ha", "h a"]

    private static let resetDateTimeWithMinutes = [
        "MMM d, h:mma",
        "MMM d, h:mm a",
        "MMM d h:mma",
        "MMM d h:mm a",
        "MMM d, HH:mm",
        "MMM d HH:mm",
    ]

    private static let resetDateTimeHourOnly = [
        "MMM d, ha",
        "MMM d, h a",
        "MMM d ha",
        "MMM d h a",
    ]

    private static func normalizeResetInput(_ text: String?) -> (String, TimeZone?)? {
        guard var raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        raw = raw.replacingOccurrences(of: #"(?i)^resets?:?\s*"#, with: "", options: .regularExpression)
        raw = raw.replacingOccurrences(of: " at ", with: " ", options: .caseInsensitive)
        raw = raw.replacingOccurrences(
            of: #"(?<=\d)\.(\d{2})\b"#,
            with: ":$1",
            options: .regularExpression)

        let timeZone = self.extractTimeZone(from: &raw)
        raw = raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : (raw, timeZone)
    }

    private static func extractTimeZone(from text: inout String) -> TimeZone? {
        guard let tzRange = text.range(of: #"\(([^)]+)\)"#, options: .regularExpression) else { return nil }
        let tzID = String(text[tzRange]).trimmingCharacters(in: CharacterSet(charactersIn: "() "))
        text.removeSubrange(tzRange)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return TimeZone(identifier: tzID)
    }

    private static func parseDate(_ text: String, formats: [String], formatter: DateFormatter) -> Date? {
        for pattern in formats {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
