// ResetCommand.swift
// Runic CLI - Usage Reset Timing Information
//
// Displays when usage limits reset for different providers,
// helping you plan usage and understand billing cycles.
//
// Usage:
//   runic reset [--when <provider>] [--all] [--json] [--pretty] [--no-color]
//
// Examples:
//   runic reset                            # Show reset times for all providers
//   runic reset --when claude              # Show Claude reset timings only
//   runic reset --all --json               # JSON output for all providers

import Foundation
import Helix
import RunicCore

/// Main entry point for the reset command
public enum ResetCommand {
    /// Command signature defining available options and flags
    public static var signature: CommandSignature {
        CommandSignature(
            options: [
                OptionDefinition(
                    label: "when",
                    names: [.long("when"), .short("w")],
                    help: "Show reset timing for specific provider"),
                OptionDefinition(
                    label: "format",
                    names: [.long("format")],
                    help: "Output format: text | json"),
            ],
            flags: [
                FlagDefinition(
                    label: "all",
                    names: [.long("all"), .short("a")],
                    help: "Show all providers (default)"),
                FlagDefinition(
                    label: "json",
                    names: [.long("json"), .short("j")],
                    help: "Output in JSON format"),
                FlagDefinition(
                    label: "pretty",
                    names: [.long("pretty")],
                    help: "Pretty-print JSON output"),
                FlagDefinition(
                    label: "noColor",
                    names: [.long("no-color")],
                    help: "Disable ANSI color codes"),
                FlagDefinition(
                    label: "compact",
                    names: [.long("compact"), .short("c")],
                    help: "Show compact output"),
            ])
    }

    /// Command descriptor for registration
    public static var descriptor: CommandDescriptor {
        CommandDescriptor(
            name: "reset",
            abstract: "Show when usage limits reset",
            discussion: """
            Displays reset timing information for provider usage limits.
            Shows when current usage windows expire and new limits begin.

            Supports all Runic providers including Claude, Codex, Gemini,
            Cursor, and others with usage-based billing.

            EXAMPLES:
              runic reset
                Show reset times for all active providers

              runic reset --when claude
                Show Claude-specific reset information

              runic reset --all --json
                Export all reset timings as JSON

              runic reset --compact
                Show compact, single-line output per provider
            """,
            signature: signature)
    }

    /// Execute the reset command
    public static func run(_ invocation: CommandInvocation) async {
        let config = self.parseConfiguration(invocation)

        do {
            let resetInfos = try await loadResetInformation(providers: config.providers)

            if resetInfos.isEmpty {
                self.exitWithError("No reset information available for the specified providers.")
            }

            if config.isJSON {
                self.outputJSON(resetInfos, pretty: config.isPretty)
            } else {
                self.outputText(resetInfos, config: config)
            }
        } catch {
            self.exitWithError("Failed to load reset information: \(error.localizedDescription)")
        }
    }

    // MARK: - Configuration

    private struct Configuration {
        let providers: [UsageProvider]
        let isJSON: Bool
        let isPretty: Bool
        let useColor: Bool
        let compact: Bool
    }

    private static func parseConfiguration(_ invocation: CommandInvocation) -> Configuration {
        let whenArg = invocation.parsedValues.options["when"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"

        let isJSON = invocation.parsedValues.flags.contains("json")
            || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let compact = invocation.parsedValues.flags.contains("compact")

        let providers = self.resolveProviders(whenArg)

        return Configuration(
            providers: providers,
            isJSON: isJSON,
            isPretty: isPretty,
            useColor: !noColor,
            compact: compact)
    }

    private static func resolveProviders(_ arg: String?) -> [UsageProvider] {
        guard let arg = arg?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return ProviderDescriptorRegistry.all.map(\.id)
        }

        if arg == "all" {
            return ProviderDescriptorRegistry.all.map(\.id)
        }

        guard let provider = UsageProvider(rawValue: arg) else {
            self.exitWithError("Unknown provider: \(arg)")
        }

        return [provider]
    }

    // MARK: - Reset Information Models

    private struct ProviderResetInfo: Encodable {
        let provider: UsageProvider
        let providerName: String
        let windows: [WindowResetInfo]
        let status: String
    }

    private struct WindowResetInfo: Encodable {
        let windowName: String
        let resetDescription: String?
        let resetAt: Date?
        let timeUntilReset: TimeInterval?
        let usedPercent: Double
        let remainingPercent: Double
        let isNearLimit: Bool
    }

    // MARK: - Data Loading

    private static func loadResetInformation(
        providers: [UsageProvider]) async throws -> [ProviderResetInfo]
    {
        let fetcher = UsageFetcher()
        var results: [ProviderResetInfo] = []

        for provider in providers {
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let context = ProviderFetchContext(
                runtime: .cli,
                sourceMode: .cli,
                includeCredits: false,
                webTimeout: 60,
                webDebugDumpHTML: false,
                verbose: false,
                env: ProcessInfo.processInfo.environment,
                settings: nil,
                fetcher: fetcher,
                claudeFetcher: ClaudeUsageFetcher())

            let outcome = await descriptor.fetchOutcome(context: context)

            if case let .success(result) = outcome.result {
                let info = self.buildResetInfo(
                    provider: provider,
                    snapshot: result.usage,
                    metadata: descriptor.metadata)
                results.append(info)
            }
        }

        return results
    }

    private static func buildResetInfo(
        provider: UsageProvider,
        snapshot: UsageSnapshot,
        metadata: ProviderMetadata) -> ProviderResetInfo
    {
        var windows: [WindowResetInfo] = []

        // Primary window
        windows.append(self.buildWindowInfo(
            windowName: metadata.sessionLabel,
            window: snapshot.primary))

        // Secondary window
        if let secondary = snapshot.secondary {
            windows.append(self.buildWindowInfo(
                windowName: metadata.weeklyLabel,
                window: secondary))
        }

        // Tertiary window (Opus)
        if metadata.supportsOpus, let tertiary = snapshot.tertiary {
            windows.append(self.buildWindowInfo(
                windowName: metadata.opusLabel ?? "Opus",
                window: tertiary))
        }

        let status = self.determineStatus(windows: windows)

        return ProviderResetInfo(
            provider: provider,
            providerName: provider.rawValue.capitalized,
            windows: windows,
            status: status)
    }

    private static func buildWindowInfo(
        windowName: String,
        window: RateWindow) -> WindowResetInfo
    {
        let resetAt = self.extractResetDate(from: window.resetDescription)
        let timeUntilReset = resetAt?.timeIntervalSinceNow

        return WindowResetInfo(
            windowName: windowName,
            resetDescription: window.resetDescription,
            resetAt: resetAt,
            timeUntilReset: timeUntilReset,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            isNearLimit: window.usedPercent >= 75)
    }

    private static func extractResetDate(from description: String?) -> Date? {
        // This is a simplified implementation
        // Real implementation would parse the reset description
        guard let description else { return nil }

        // Look for patterns like "in Xh Ym"
        let pattern = #"in (\d+)h(?: (\d+)m)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: description,
                  range: NSRange(description.startIndex..., in: description))
        else {
            return nil
        }

        var hours = 0
        var minutes = 0

        if let hoursRange = Range(match.range(at: 1), in: description) {
            hours = Int(description[hoursRange]) ?? 0
        }

        if match.numberOfRanges > 2, let minutesRange = Range(match.range(at: 2), in: description) {
            minutes = Int(description[minutesRange]) ?? 0
        }

        let seconds = TimeInterval(hours * 3600 + minutes * 60)
        return Date().addingTimeInterval(seconds)
    }

    private static func determineStatus(windows: [WindowResetInfo]) -> String {
        let maxUsed = windows.map(\.usedPercent).max() ?? 0

        switch maxUsed {
        case 90...:
            return "Critical - Near limit"
        case 75...:
            return "Warning - High usage"
        case 50...:
            return "Moderate usage"
        default:
            return "Healthy"
        }
    }

    // MARK: - Output Formatting

    private static func outputJSON(_ infos: [ProviderResetInfo], pretty: Bool) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        guard let data = try? encoder.encode(infos),
              let text = String(data: data, encoding: .utf8)
        else {
            print("[]")
            return
        }

        print(text)
    }

    private static func outputText(_ infos: [ProviderResetInfo], config: Configuration) {
        if config.compact {
            self.outputCompactText(infos, useColor: config.useColor)
        } else {
            self.outputDetailedText(infos, useColor: config.useColor)
        }
    }

    private static func outputCompactText(_ infos: [ProviderResetInfo], useColor: Bool) {
        self.printHeader("Usage Reset Times", useColor: useColor)
        print("")

        for info in infos {
            let status = self.statusIndicator(info.status, useColor: useColor)
            let provider = info.providerName.padding(toLength: 12, withPad: " ", startingAt: 0)

            var resetTimes: [String] = []
            for window in info.windows {
                if let description = window.resetDescription {
                    resetTimes.append(description)
                }
            }

            let resets = resetTimes.joined(separator: ", ")
            print("\(status) \(provider) \(resets)")
        }
    }

    private static func outputDetailedText(_ infos: [ProviderResetInfo], useColor: Bool) {
        self.printHeader("Usage Reset Information", useColor: useColor)
        print("")

        for (index, info) in infos.enumerated() {
            if index > 0 {
                print("")
            }

            let status = self.statusIndicator(info.status, useColor: useColor)
            let providerLine = "\(status) \(info.providerName) - \(info.status)"

            if useColor {
                print(self.ansi("1;37", providerLine))
            } else {
                print(providerLine)
            }

            for window in info.windows {
                print("")
                print("  \(window.windowName):")

                if let description = window.resetDescription {
                    print("    Reset: \(description)")
                }

                let used = String(format: "%.1f", window.usedPercent)
                let remaining = String(format: "%.1f", window.remainingPercent)
                print("    Usage: \(used)% used, \(remaining)% remaining")

                if window.isNearLimit {
                    let warning = "⚠ High usage - consider monitoring closely"
                    if useColor {
                        print("    \(self.ansi("33", warning))")
                    } else {
                        print("    \(warning)")
                    }
                }
            }
        }
    }

    private static func statusIndicator(_ status: String, useColor: Bool) -> String {
        let (icon, color) = switch status {
        case let s where s.contains("Critical"):
            ("✗", "31")
        case let s where s.contains("Warning"):
            ("⚠", "33")
        case let s where s.contains("Moderate"):
            ("◐", "36")
        default:
            ("✓", "32")
        }

        return useColor ? self.ansi(color, icon) : icon
    }

    private static func printHeader(_ text: String, useColor: Bool) {
        if useColor {
            print(self.ansi("1;36", text))
        } else {
            print(text)
        }
    }

    private static func ansi(_ code: String, _ text: String) -> String {
        "\u{001B}[\(code)m\(text)\u{001B}[0m"
    }

    // MARK: - Error Handling

    private static func exitWithError(_ message: String) -> Never {
        if let data = ("Error: " + message + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
        Foundation.exit(1)
    }
}
