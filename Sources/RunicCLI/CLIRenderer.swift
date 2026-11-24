import Foundation
import RunicCore

enum CLIRenderer {
    static func renderText(
        provider: UsageProvider,
        snapshot: UsageSnapshot,
        credits: CreditsSnapshot?,
        context: RenderContext) -> String
    {
        let meta = ProviderDescriptorRegistry.descriptor(for: provider).metadata
        var lines: [String] = []
        lines.append(self.headerLine(context.header, useColor: context.useColor))

        let primaryTitle = UsageFormatter.windowTitle(
            for: snapshot.primary,
            fallback: meta.primaryWindowTitle(for: snapshot.primary))
        lines.append(self.rateLine(title: primaryTitle, window: snapshot.primary, useColor: context.useColor))
        if let reset = snapshot.primary.resetDescription {
            lines.append(self.resetLine(reset))
        }

        if let weekly = snapshot.secondary {
            let weeklyTitle = UsageFormatter.windowTitle(for: weekly, fallback: meta.weeklyLabel)
            lines.append(self.rateLine(title: weeklyTitle, window: weekly, useColor: context.useColor))
            if let reset = weekly.resetDescription {
                lines.append(self.resetLine(reset))
            }
        }

        if let tertiary = snapshot.tertiary {
            let tertiaryTitle = UsageFormatter.windowTitle(
                for: tertiary,
                fallback: meta.opusLabel ?? "Sonnet")
            lines.append(self.rateLine(title: tertiaryTitle, window: tertiary, useColor: context.useColor))
            if let reset = tertiary.resetDescription {
                lines.append(self.resetLine(reset))
            }
        }

        if let additional = snapshot.additionalWindows {
            for (index, extra) in additional.enumerated() {
                let extraTitle = UsageFormatter.windowTitle(for: extra, fallback: "Quota \(index + 4)")
                lines.append(self.rateLine(title: extraTitle, window: extra, useColor: context.useColor))
                if let reset = extra.resetDescription {
                    lines.append(self.resetLine(reset))
                }
            }
        }

        if provider == .codex, let credits {
            lines.append("Credits: \(UsageFormatter.creditsString(from: credits.remaining))")
        }

        if let email = snapshot.accountEmail(for: provider), !email.isEmpty {
            lines.append("Account: \(email)")
        }
        if let plan = snapshot.loginMethod(for: provider), !plan.isEmpty {
            lines.append("Plan: \(UsageFormatter.cleanPlanName(plan))")
        }

        return lines.joined(separator: "\n")
    }

    static func rateLine(title: String, window: RateWindow, useColor: Bool) -> String {
        let text = UsageFormatter.usageLine(remaining: window.remainingPercent, used: window.usedPercent)
        let colored = self.colorizeUsage(text, remainingPercent: window.remainingPercent, useColor: useColor)
        return "\(title): \(colored)"
    }

    private static func resetLine(_ reset: String) -> String {
        UsageFormatter.formattedWindowDescription(reset)
    }

    private static func headerLine(_ header: String, useColor: Bool) -> String {
        guard useColor else { return header }
        return self.ansi("1;36", header)
    }

    private static func colorizeUsage(_ text: String, remainingPercent: Double, useColor: Bool) -> String {
        guard useColor else { return text }

        let code = switch remainingPercent {
        case ..<10:
            "31" // red
        case ..<25:
            "33" // yellow
        default:
            "32" // green
        }
        return self.ansi(code, text)
    }

    private static func ansi(_ code: String, _ text: String) -> String {
        "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }
}

struct RenderContext {
    let header: String
    let useColor: Bool
}
