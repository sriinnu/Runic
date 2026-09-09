import Foundation

/// Turns the loose reset text some providers hand us ("resets in 3h 12m",
/// "in 2d", "resets at 4:30 PM") into a concrete `Date`, so every window
/// that *knows* when it resets can show a countdown and an expiry time,
/// not just a sentence. Anything that isn't a reset phrase (balances,
/// counters, "Monthly") returns nil and is left alone.
public enum UsageResetParsing {
    /// Parse a relative reset phrase. Accepts an optional "resets"/"reset"
    /// prefix, an optional "in", then any combination of `Nd`, `Nh`, `Nm`
    /// (also "days"/"hours"/"minutes" spelled out). Returns nil when no
    /// duration component is present.
    public static func date(fromRelative text: String?, now: Date = .init()) -> Date? {
        guard let text else { return nil }
        let lowered = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowered.isEmpty else { return nil }
        // Balance / counter descriptions contain currency or "left"; bail early.
        if lowered.contains("$") || lowered.contains("balance") || lowered.contains("remaining") { return nil }
        guard let regex = Self.relativeRegex else { return nil }
        var seconds: TimeInterval = 0
        var matched = false
        let range = NSRange(lowered.startIndex..<lowered.endIndex, in: lowered)
        regex.enumerateMatches(in: lowered, options: [], range: range) { match, _, _ in
            guard let match,
                  let valueRange = Range(match.range(at: 1), in: lowered),
                  let unitRange = Range(match.range(at: 2), in: lowered),
                  let value = Double(lowered[valueRange]) else { return }
            let unit = lowered[unitRange]
            matched = true
            if unit.hasPrefix("d") {
                seconds += value * 86400
            } else if unit.hasPrefix("h") {
                seconds += value * 3600
            } else if unit.hasPrefix("m") {
                seconds += value * 60
            } else if unit.hasPrefix("s") {
                seconds += value
            }
        }
        guard matched, seconds > 0 else { return nil }
        return now.addingTimeInterval(seconds)
    }

    private static let relativeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*(d(?:ays?)?|h(?:ours?|rs?)?|m(?:in(?:ute)?s?)?|s(?:ec(?:ond)?s?)?)\b"#,
        options: [])
}

extension UsageFormatter {
    /// Short absolute expiry: "4:30 PM" today, "tomorrow 9:00 AM", a
    /// weekday for the coming week ("Thu 9:00 AM"), otherwise "Sep 14, 9:00 AM".
    /// This is the "when does it actually flip" half of a reset line; pair it
    /// with `resetCountdownDescription` for the "how long" half.
    public static func resetExpiryString(from date: Date, now: Date = .init()) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) {
            return time
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow)
        {
            return "tomorrow \(time)"
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)).day ?? 0
        if days > 0, days < 7 {
            let weekday = date.formatted(.dateTime.weekday(.abbreviated))
            return "\(weekday) \(time)"
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    /// One-line reset summary for a window: "Resets in 2h 14m · 4:30 PM".
    /// Falls back to the provider's own text when there's no date, and to
    /// nil when there's nothing reset-shaped to say.
    public static func resetSummary(for window: RateWindow, now: Date = .init()) -> String? {
        if let date = window.resetsAt ?? UsageResetParsing.date(fromRelative: window.resetDescription, now: now) {
            let countdown = self.resetCountdownDescription(from: date, now: now)
            return "Resets \(countdown) · \(self.resetExpiryString(from: date, now: now))"
        }
        guard let desc = window.resetDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty else {
            return nil
        }
        return desc
    }
}
