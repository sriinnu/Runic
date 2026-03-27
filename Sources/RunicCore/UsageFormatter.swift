import Foundation

public enum UsageFormatter {
    public static func usageLine(remaining: Double, used: Double) -> String {
        String(format: "%.0f%% left", remaining)
    }

    public static func resetCountdownDescription(from date: Date, now: Date = .init()) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        if seconds < 1 { return "now" }

        let totalMinutes = max(1, Int(ceil(seconds / 60.0)))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        if days > 0 {
            if hours > 0 { return "in \(days)d \(hours)h" }
            return "in \(days)d"
        }
        if hours > 0 {
            if minutes > 0 { return "in \(hours)h \(minutes)m" }
            return "in \(hours)h"
        }
        return "in \(totalMinutes)m"
    }

    public static func resetDescription(from date: Date, now: Date = .init()) -> String {
        // Human-friendly phrasing: today / tomorrow / date+time.
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow)
        {
            return "tomorrow, \(date.formatted(date: .omitted, time: .shortened))"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    public static func updatedString(from date: Date, now: Date = .init()) -> String {
        let delta = now.timeIntervalSince(date)
        if abs(delta) < 60 {
            return "Updated just now"
        }
        if let hours = Calendar.current.dateComponents([.hour], from: date, to: now).hour, hours < 24 {
            #if os(macOS)
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .abbreviated
            return "Updated \(rel.localizedString(for: date, relativeTo: now))"
            #else
            let seconds = max(0, Int(now.timeIntervalSince(date)))
            if seconds < 3600 {
                let minutes = max(1, seconds / 60)
                return "Updated \(minutes)m ago"
            }
            let wholeHours = max(1, seconds / 3600)
            return "Updated \(wholeHours)h ago"
            #endif
        } else {
            return "Updated \(date.formatted(date: .omitted, time: .shortened))"
        }
    }

    public static func creditsString(from value: Double) -> String {
        let number = NumberFormatter()
        number.numberStyle = .decimal
        number.maximumFractionDigits = 2
        let formatted = number.string(from: NSNumber(value: value)) ?? String(Int(value))
        return "\(formatted) left"
    }

    public static func usdString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    public static func usdRateString(_ value: Double) -> String {
        let normalized = max(0, value)
        if normalized >= 1 {
            return String(format: "$%.2f", normalized)
        }
        if normalized >= 0.01 {
            return String(format: "$%.3f", normalized)
        }
        return String(format: "$%.4f", normalized)
    }

    public static func usdPer1KTokensString(costUSD: Double?, tokenCount: Int) -> String? {
        guard let costUSD, costUSD >= 0 else { return nil }
        guard tokenCount > 0 else { return nil }
        let rate = costUSD / (Double(tokenCount) / 1000.0)
        guard rate.isFinite, rate >= 0 else { return nil }
        return "\(self.usdRateString(rate))/1K"
    }

    public static func usdPerRequestString(costUSD: Double?, requestCount: Int) -> String? {
        guard let costUSD, costUSD >= 0 else { return nil }
        guard requestCount > 0 else { return nil }
        let rate = costUSD / Double(requestCount)
        guard rate.isFinite, rate >= 0 else { return nil }
        return "\(self.usdRateString(rate))/req"
    }

    public static func usdPerHourFromTokensString(
        costUSD: Double?,
        tokenCount: Int,
        tokensPerMinute: Double?) -> String?
    {
        guard let tokensPerMinute, tokensPerMinute > 0 else { return nil }
        guard let costUSD, costUSD >= 0 else { return nil }
        guard tokenCount > 0 else { return nil }
        let per1KValue = costUSD / (Double(tokenCount) / 1000.0)
        guard per1KValue.isFinite, per1KValue >= 0 else { return nil }
        let hourly = per1KValue * (tokensPerMinute * 60.0 / 1000.0)
        guard hourly.isFinite, hourly >= 0 else { return nil }
        return "\(self.usdRateString(hourly))/hr"
    }

    public static func currencyString(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(String(format: "%.2f", value))"
    }

    public static func tokenCountString(_ value: Int) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        let units: [(threshold: Int, divisor: Double, suffix: String)] = [
            (1_000_000_000, 1_000_000_000, "B"),
            (1_000_000, 1_000_000, "M"),
            (1000, 1000, "K"),
        ]

        for unit in units where absValue >= unit.threshold {
            let scaled = Double(absValue) / unit.divisor
            let formatted: String
            if scaled >= 10 {
                formatted = String(format: "%.0f", scaled)
            } else {
                var s = String(format: "%.1f", scaled)
                if s.hasSuffix(".0") { s.removeLast(2) }
                formatted = s
            }
            return "\(sign)\(formatted)\(unit.suffix)"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    public static func tokenSummaryString(_ totals: UsageLedgerTotals, includeBreakdown: Bool = true) -> String {
        let total = self.tokenCountString(totals.totalTokens)
        guard includeBreakdown else {
            return "\(total) tok"
        }

        var parts: [String] = []
        if totals.inputTokens > 0 {
            parts.append("in \(self.tokenCountString(totals.inputTokens))")
        }
        if totals.outputTokens > 0 {
            parts.append("out \(self.tokenCountString(totals.outputTokens))")
        }
        let cached = totals.cacheCreationTokens + totals.cacheReadTokens
        if cached > 0 {
            parts.append("cache \(self.tokenCountString(cached))")
        }
        guard !parts.isEmpty else { return "\(total) tok" }
        return "\(total) tok (\(parts.joined(separator: ", ")))"
    }

    public static func creditEventSummary(_ event: CreditEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let number = NumberFormatter()
        number.numberStyle = .decimal
        number.maximumFractionDigits = 2
        let credits = number.string(from: NSNumber(value: event.creditsUsed)) ?? "0"
        return "\(formatter.string(from: event.date)) · \(event.service) · \(credits) credits"
    }

    public static func creditEventCompact(_ event: CreditEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let number = NumberFormatter()
        number.numberStyle = .decimal
        number.maximumFractionDigits = 2
        let credits = number.string(from: NSNumber(value: event.creditsUsed)) ?? "0"
        return "\(formatter.string(from: event.date)) — \(event.service): \(credits)"
    }

    public static func creditShort(_ value: Double) -> String {
        if value >= 1000 {
            let k = value / 1000
            return String(format: "%.1fk", k)
        }
        return String(format: "%.0f", value)
    }

    public static func truncatedSingleLine(_ text: String, max: Int = 80) -> String {
        let single = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard single.count > max else { return single }
        let idx = single.index(single.startIndex, offsetBy: max)
        return "\(single[..<idx])…"
    }

    public static func modelDisplayName(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return raw }

        let patterns = [
            #"(?:-|\s)\d{8}$"#,
            #"(?:-|\s)\d{4}-\d{2}-\d{2}$"#,
            #"\s\d{4}\s\d{4}$"#,
        ]

        for pattern in patterns {
            if let range = cleaned.range(of: pattern, options: .regularExpression) {
                cleaned.removeSubrange(range)
                break
            }
        }

        if let trailing = cleaned.range(of: #"[ \t-]+$"#, options: .regularExpression) {
            cleaned.removeSubrange(trailing)
        }

        return cleaned.isEmpty ? raw : cleaned
    }

    /// Returns a human-friendly context window label for a model when known.
    /// Examples: "ctx 128k", "ctx 1M".
    public static func modelContextLabel(for model: String) -> String? {
        guard let context = modelContextWindow(for: model) else { return nil }
        return "ctx \(self.tokenCountString(context))"
    }

    /// Resolves an approximate context window (in tokens) for common model families.
    /// Returns nil when the model is not recognized.
    public static func modelContextWindow(for model: String) -> Int? {
        let normalized = Self.normalizedModelIdentifier(for: model)

        if let exact = Self.modelContextExact[normalized] {
            return exact
        }

        if let inferred = Self.modelContextFromNameTokens(normalized) {
            return inferred
        }

        for (prefix, contextWindow) in Self.modelContextPrefixes where normalized.hasPrefix(prefix) {
            return contextWindow
        }

        return nil
    }

    private static let modelContextExact: [String: Int] = [
        "gpt-5": 400_000,
        "gpt-5-codex": 400_000,
        "gpt-5-mini": 400_000,
        "gpt-5-nano": 400_000,
        "gpt-5-thinking": 400_000,
        "gpt-5-thinking-mini": 400_000,
        "gpt-5-1": 400_000,
        "gpt-5-2": 400_000,
        "gpt-4o": 128_000,
        "gpt-4o-mini": 128_000,
        "gpt-4-turbo": 128_000,
        "gpt-4": 128_000,
        "gpt-3.5-turbo": 16385,
        "gpt-4.1": 1_000_000,
        "gpt-4.1-mini": 1_000_000,
        "gpt-4.1-nano": 1_000_000,
        "o1": 200_000,
        "o1-mini": 200_000,
        "o1-preview": 128_000,
        "o3-mini": 200_000,
        "o3-mini-high": 200_000,
        "o3-mini-low": 200_000,
        "claude-opus-4-5": 200_000,
        "claude-opus-4-0": 200_000,
        "claude-opus-4-1": 200_000,
        "claude-opus-4-6": 1_000_000,
        "claude-sonnet-4": 200_000,
        "claude-sonnet-4-6": 1_000_000,
        "claude-opus": 200_000,
        "claude-3-opus": 200_000,
        "claude-3-sonnet": 200_000,
        "claude-3-5-sonnet": 200_000,
        "claude-3-7-sonnet": 200_000,
        "claude-3-haiku": 200_000,
        "gemini-1-5-pro": 1_000_000,
        "gemini-1-5-flash": 1_000_000,
        "gemini-2-0-flash": 1_000_000,
        "gemini-2-5-pro": 1_000_000,
        "llama-3-1-70b": 128_000,
        "llama-3-1-8b": 128_000,
        "llama-3-3-70b": 128_000,
        "mistral-large": 128_000,
        "mistral-small": 32000,
        "mistral-medium": 131_072,
        "deepseek-chat": 64000,
        "deepseek-coder": 32000,
        "cohere-command": 128_000,
        "cohere-command-r": 128_000,
        "cohere-command-r-plus": 128_000,
        "qwen-2-5-72b": 128_000,
        "qwen-2-5-32b": 128_000,
        "qwen1-5-32b": 8192,
        "qwen1-5-14b": 8192,
        "grok-2": 128_000,
        "grok-2-mini": 131_072,
        "grok-2-vision": 131_072,
        "mixtral-8x7b": 32768,
        "mixtral-8x22b": 64000,
        "llama-3-8b": 8192,
        "llama-3-70b": 8192,
        "llama-2-70b": 4096,
        "llama-2-13b": 4096,
    ]

    private static let modelContextPrefixes: [(String, Int)] = [
        ("gpt-4.1", 1_000_000),
        ("gpt-4o", 128_000),
        ("gpt-4-", 128_000),
        ("gpt-3.5", 16385),
        ("gpt-5", 400_000),
        ("gpt-5-", 400_000),
        ("claude-3", 200_000),
        ("claude-4", 200_000),
        ("o1", 200_000),
        ("o3", 200_000),
        ("gemini-1-5", 1_000_000),
        ("gemini-2-0", 1_000_000),
        ("gemini-2-5", 1_000_000),
        ("llama-3", 8192),
        ("qwen-2-5", 128_000),
        ("qwen1-5", 8192),
    ]

    private static func normalizedModelIdentifier(for model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let withoutProvider = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
        return withoutProvider.replacingOccurrences(of: " ", with: "-")
    }

    private static func modelContextFromNameTokens(_ model: String) -> Int? {
        let tokens = model.replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map(String.init)

        for token in tokens.reversed() {
            let lower = token.lowercased()
            if lower.hasSuffix("k"), let numeric = Int(lower.dropLast()), numeric > 0 {
                return numeric * 1000
            }
            if lower.hasSuffix("m"), let numeric = Int(lower.dropLast()), numeric > 0 {
                return numeric * 1_000_000
            }
        }

        return nil
    }

    /// Cleans a provider plan string: strip ANSI/bracket noise, drop boilerplate words, collapse whitespace, and
    /// ensure a leading capital if the result starts lowercase.
    public static func cleanPlanName(_ text: String) -> String {
        let stripped = TextParsing.stripANSICodes(text)
        let withoutCodes = stripped.replacingOccurrences(
            of: #"^\s*(?:\[\d{1,3}m\s*)+"#,
            with: "",
            options: [.regularExpression])
        let withoutBoilerplate = withoutCodes.replacingOccurrences(
            of: #"(?i)\b(claude|codex|account|plan)\b"#,
            with: "",
            options: [.regularExpression])
        var cleaned = withoutBoilerplate
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            cleaned = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if cleaned.lowercased() == "oauth" {
            return "Ollama"
        }
        // Capitalize first letter only if lowercase, preserving acronyms like "AI"
        if let first = cleaned.first, first.isLowercase {
            return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }
        return cleaned
    }
}
