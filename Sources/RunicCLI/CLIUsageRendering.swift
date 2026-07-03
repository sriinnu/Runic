import Foundation
import RunicCore

extension RunicCLI {
    static func renderUsageText(
        provider: UsageProvider,
        snapshot: UsageSnapshot,
        credits: CreditsSnapshot?,
        header: String,
        useColor: Bool) -> String
    {
        var lines: [String] = []
        if useColor {
            lines.append("\u{001B}[1;36m\(header)\u{001B}[0m")
        } else {
            lines.append(header)
        }

        let meta = ProviderDescriptorRegistry.descriptor(for: provider).metadata
        lines.append(Self.rateLine(title: meta.sessionLabel, window: snapshot.primary, useColor: useColor))
        if snapshot.primary.hasKnownLimit != false, let reset = snapshot.primary.resetDescription {
            lines.append(Self.resetLine(reset))
        }

        if let secondary = snapshot.secondary {
            lines.append(Self.rateLine(title: meta.weeklyLabel, window: secondary, useColor: useColor))
            if secondary.hasKnownLimit != false, let reset = secondary.resetDescription {
                lines.append(Self.resetLine(reset))
            }
        }

        if meta.supportsOpus, let tertiary = snapshot.tertiary {
            lines.append(Self.rateLine(title: meta.opusLabel ?? "Sonnet", window: tertiary, useColor: useColor))
            if tertiary.hasKnownLimit != false, let reset = tertiary.resetDescription {
                lines.append(Self.resetLine(reset))
            }
        }

        if provider == .codex, let credits {
            lines.append("Credits: \(Self.creditsString(from: credits.remaining))")
        }

        if let email = snapshot.accountEmail(for: provider), !email.isEmpty {
            lines.append("Account: \(email)")
        }
        if let plan = snapshot.loginMethod(for: provider), !plan.isEmpty {
            lines.append("Plan: \(plan.capitalized)")
        }

        return lines.joined(separator: "\n")
    }

    static func renderCostText(
        provider: UsageProvider,
        snapshot: CostUsageTokenSnapshot,
        useColor: Bool) -> String
    {
        let providerName = provider.rawValue.capitalized
        var lines: [String] = []

        if useColor {
            lines.append("\u{001B}[1;36m\(providerName) Cost\u{001B}[0m")
        } else {
            lines.append("\(providerName) Cost")
        }

        if let tokens = snapshot.sessionTokens {
            lines.append("Session Tokens: \(Self.formatNumber(tokens))")
        }
        if let cost = snapshot.sessionCostUSD {
            lines.append("Session Cost: $\(String(format: "%.4f", cost))")
        }
        if let tokens = snapshot.last30DaysTokens {
            lines.append("30-Day Tokens: \(Self.formatNumber(tokens))")
        }
        if let cost = snapshot.last30DaysCostUSD {
            lines.append("30-Day Cost: $\(String(format: "%.2f", cost))")
        }

        return lines.joined(separator: "\n")
    }

    private static func rateLine(title: String, window: RateWindow, useColor: Bool) -> String {
        // Windows without a real limit have a placeholder percent; print
        // their summary text instead of a fake "0.0% used" bar.
        guard window.gaugePercent(showUsed: true) != nil else {
            let info = window.resetDescription ?? window.label ?? "No usage limit reported"
            return "\(title): \(info)"
        }
        let text = Self.usageLine(remaining: window.remainingPercent, used: window.usedPercent)
        let colored = Self.colorizeUsage(text, remainingPercent: window.remainingPercent, useColor: useColor)
        return "\(title): \(colored)"
    }

    private static func resetLine(_ reset: String) -> String {
        let trimmed = reset.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("resets") { return trimmed }
        return "Resets \(trimmed)"
    }

    private static func usageLine(remaining: Double, used: Double) -> String {
        let barLength = 20
        let (filled, empty) = Self.progressBarCounts(usedPercent: used, width: barLength)
        let filledBar = String(repeating: "█", count: filled)
        let emptyBar = String(repeating: "░", count: empty)
        return "[\(filledBar)\(emptyBar)] \(String(format: "%.1f", used))% used"
    }

    /// Filled/empty cell counts for a progress bar, clamped so out-of-range
    /// percents (e.g. 110 or -5) never produce negative repeat counts.
    static func progressBarCounts(usedPercent: Double, width: Int) -> (filled: Int, empty: Int) {
        let filled = min(max(Int(usedPercent / 100.0 * Double(width)), 0), width)
        return (filled, width - filled)
    }

    private static func colorizeUsage(_ text: String, remainingPercent: Double, useColor: Bool) -> String {
        guard useColor else { return text }
        let code = switch remainingPercent {
        case ..<10: "31"
        case ..<25: "33"
        default: "32"
        }
        return "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }

    private static func creditsString(from remaining: Double) -> String {
        if remaining >= 1_000_000 {
            return String(format: "%.1fM", remaining / 1_000_000)
        } else if remaining >= 1000 {
            return String(format: "%.1fK", remaining / 1000)
        }
        return String(format: "%.0f", remaining)
    }

    private static func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
    }
}
