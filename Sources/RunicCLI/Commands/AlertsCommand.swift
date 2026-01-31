/// AlertsCommand.swift
/// Runic CLI - Usage Alerts Management
///
/// Manages usage threshold alerts to help you monitor and control
/// token consumption and costs across providers.
///
/// Usage:
///   runic alerts [--active | --history | --clear] [--json] [--pretty] [--no-color]
///
/// Examples:
///   runic alerts                           # Show active alerts
///   runic alerts --active                  # Show only active alerts
///   runic alerts --history                 # Show alert history
///   runic alerts --clear                   # Clear resolved alerts

import RunicCore
import Helix
import Foundation

/// Main entry point for the alerts command
public enum AlertsCommand {

    /// Command signature defining available options and flags
    public static var signature: CommandSignature {
        CommandSignature(
            options: [
                OptionDefinition(
                    label: "provider",
                    names: [.long("provider"), .short("p")],
                    help: "Filter alerts by provider"),
                OptionDefinition(
                    label: "threshold",
                    names: [.long("threshold"), .short("t")],
                    help: "Set alert threshold (percentage, e.g., 80)"),
                OptionDefinition(
                    label: "format",
                    names: [.long("format")],
                    help: "Output format: text | json"),
            ],
            flags: [
                FlagDefinition(
                    label: "active",
                    names: [.long("active"), .short("a")],
                    help: "Show only active alerts (default)"),
                FlagDefinition(
                    label: "history",
                    names: [.long("history"), .short("h")],
                    help: "Show alert history"),
                FlagDefinition(
                    label: "clear",
                    names: [.long("clear"), .short("c")],
                    help: "Clear resolved alerts from history"),
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
            ])
    }

    /// Command descriptor for registration
    public static var descriptor: CommandDescriptor {
        CommandDescriptor(
            name: "alerts",
            abstract: "Manage usage threshold alerts",
            discussion: """
            Tracks and manages usage alerts based on provider limits.
            Alerts trigger when usage exceeds configured thresholds.

            By default, shows active alerts that require attention.

            EXAMPLES:
              runic alerts
                Show all active usage alerts

              runic alerts --history
                View historical alerts

              runic alerts --provider claude
                Show alerts for Claude provider only

              runic alerts --threshold 90
                Set alert threshold to 90% (future feature)

              runic alerts --clear --history
                Clear resolved alerts from history
            """,
            signature: signature)
    }

    /// Execute the alerts command
    public static func run(_ invocation: CommandInvocation) async {
        let config = parseConfiguration(invocation)

        if config.shouldClear {
            clearResolvedAlerts(config: config)
            return
        }

        do {
            let alerts = try await loadAlerts(
                providers: config.providers,
                includeHistory: config.showHistory)

            if config.isJSON {
                outputJSON(alerts, pretty: config.isPretty)
            } else {
                outputText(alerts, config: config)
            }
        } catch {
            exitWithError("Failed to load alerts: \(error.localizedDescription)")
        }
    }

    // MARK: - Configuration

    private struct Configuration {
        let providers: [UsageProvider]?
        let threshold: Int?
        let showHistory: Bool
        let shouldClear: Bool
        let isJSON: Bool
        let isPretty: Bool
        let useColor: Bool
    }

    private static func parseConfiguration(_ invocation: CommandInvocation) -> Configuration {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let thresholdArg = invocation.parsedValues.options["threshold"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"

        let showHistory = invocation.parsedValues.flags.contains("history")
        let shouldClear = invocation.parsedValues.flags.contains("clear")
        let isJSON = invocation.parsedValues.flags.contains("json")
            || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")

        let threshold = thresholdArg.flatMap(Int.init)
        let providers = providerArg.map { resolveProviders($0) }

        return Configuration(
            providers: providers,
            threshold: threshold,
            showHistory: showHistory,
            shouldClear: shouldClear,
            isJSON: isJSON,
            isPretty: isPretty,
            useColor: !noColor)
    }

    private static func resolveProviders(_ arg: String) -> [UsageProvider] {
        let lowered = arg.lowercased().trimmingCharacters(in: .whitespaces)

        if lowered == "all" {
            return ProviderDescriptorRegistry.all.map(\.id)
        }

        guard let provider = UsageProvider(rawValue: lowered) else {
            exitWithError("Unknown provider: \(arg)")
        }

        return [provider]
    }

    // MARK: - Alert Models

    private struct UsageAlert: Encodable {
        let provider: UsageProvider
        let alertType: AlertType
        let severity: Severity
        let message: String
        let usedPercent: Double
        let remainingPercent: Double
        let resetDescription: String?
        let timestamp: Date

        enum AlertType: String, Encodable {
            case critical = "critical"    // >90%
            case warning = "warning"      // >75%
            case info = "info"           // >50%
        }

        enum Severity: Int, Encodable {
            case low = 1
            case medium = 2
            case high = 3
            case critical = 4
        }
    }

    // MARK: - Data Loading

    private static func loadAlerts(
        providers: [UsageProvider]?,
        includeHistory: Bool
    ) async throws -> [UsageAlert] {
        let providersToCheck = providers ?? ProviderDescriptorRegistry.all.map(\.id)
        let fetcher = UsageFetcher()
        var alerts: [UsageAlert] = []

        for provider in providersToCheck {
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

            if case .success(let result) = outcome.result {
                let providerAlerts = generateAlerts(
                    provider: provider,
                    snapshot: result.usage,
                    metadata: descriptor.metadata)
                alerts.append(contentsOf: providerAlerts)
            }
        }

        return alerts.sorted { $0.severity.rawValue > $1.severity.rawValue }
    }

    private static func generateAlerts(
        provider: UsageProvider,
        snapshot: UsageSnapshot,
        metadata: ProviderMetadata
    ) -> [UsageAlert] {
        var alerts: [UsageAlert] = []
        let now = Date()

        // Check primary window
        if let alert = createAlert(
            provider: provider,
            window: snapshot.primary,
            windowName: metadata.sessionLabel,
            timestamp: now)
        {
            alerts.append(alert)
        }

        // Check secondary window
        if let secondary = snapshot.secondary,
           let alert = createAlert(
               provider: provider,
               window: secondary,
               windowName: metadata.weeklyLabel,
               timestamp: now)
        {
            alerts.append(alert)
        }

        // Check tertiary window (Opus)
        if metadata.supportsOpus,
           let tertiary = snapshot.tertiary,
           let alert = createAlert(
               provider: provider,
               window: tertiary,
               windowName: metadata.opusLabel ?? "Opus",
               timestamp: now)
        {
            alerts.append(alert)
        }

        return alerts
    }

    private static func createAlert(
        provider: UsageProvider,
        window: RateWindow,
        windowName: String,
        timestamp: Date
    ) -> UsageAlert? {
        let used = window.usedPercent

        guard used >= 50 else {
            return nil  // Only alert when usage is >50%
        }

        let (type, severity) = determineAlertLevel(usedPercent: used)
        let message = generateAlertMessage(
            provider: provider.rawValue,
            windowName: windowName,
            usedPercent: used)

        return UsageAlert(
            provider: provider,
            alertType: type,
            severity: severity,
            message: message,
            usedPercent: used,
            remainingPercent: window.remainingPercent,
            resetDescription: window.resetDescription,
            timestamp: timestamp)
    }

    private static func determineAlertLevel(usedPercent: Double)
        -> (UsageAlert.AlertType, UsageAlert.Severity)
    {
        switch usedPercent {
        case 90...:
            return (.critical, .critical)
        case 75...:
            return (.warning, .high)
        default:
            return (.info, .medium)
        }
    }

    private static func generateAlertMessage(
        provider: String,
        windowName: String,
        usedPercent: Double
    ) -> String {
        let percent = String(format: "%.1f", usedPercent)
        return "\(provider.capitalized) \(windowName) usage at \(percent)%"
    }

    // MARK: - Clear Alerts

    private static func clearResolvedAlerts(config: Configuration) {
        if config.isJSON {
            print("{\"status\": \"cleared\"}")
        } else {
            print("Alert history cleared.")
            print("Note: This is a placeholder. Implement persistent storage for alerts.")
        }
    }

    // MARK: - Output Formatting

    private static func outputJSON(_ alerts: [UsageAlert], pretty: Bool) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        guard let data = try? encoder.encode(alerts),
              let text = String(data: data, encoding: .utf8) else {
            print("[]")
            return
        }

        print(text)
    }

    private static func outputText(_ alerts: [UsageAlert], config: Configuration) {
        if alerts.isEmpty {
            if config.useColor {
                print(ansi("32", "✓ No active alerts - all usage levels are healthy"))
            } else {
                print("No active alerts - all usage levels are healthy")
            }
            return
        }

        let title = config.showHistory ? "Usage Alert History" : "Active Usage Alerts"
        printHeader(title, useColor: config.useColor)
        print("")

        for alert in alerts {
            let icon = alertIcon(alert.alertType, useColor: config.useColor)
            let severity = "[\(alert.severity.rawValue)/4]"
            let message = alert.message
            let remaining = String(format: "%.1f", alert.remainingPercent)

            var line = "\(icon) \(severity) \(message) - \(remaining)% remaining"

            if config.useColor {
                line = colorizeAlert(line, type: alert.alertType)
            }

            print(line)

            if let reset = alert.resetDescription {
                let resetLine = "    \(reset)"
                if config.useColor {
                    print(ansi("90", resetLine))
                } else {
                    print(resetLine)
                }
            }

            print("")
        }

        // Summary
        let critical = alerts.filter { $0.alertType == .critical }.count
        let warning = alerts.filter { $0.alertType == .warning }.count
        let info = alerts.filter { $0.alertType == .info }.count

        print("Summary: \(critical) critical, \(warning) warnings, \(info) info")
    }

    private static func alertIcon(_ type: UsageAlert.AlertType, useColor: Bool) -> String {
        switch type {
        case .critical:
            return useColor ? ansi("31", "✗") : "✗"
        case .warning:
            return useColor ? ansi("33", "⚠") : "⚠"
        case .info:
            return useColor ? ansi("36", "ℹ") : "ℹ"
        }
    }

    private static func colorizeAlert(_ text: String, type: UsageAlert.AlertType) -> String {
        let code = switch type {
        case .critical: "31"  // red
        case .warning: "33"   // yellow
        case .info: "36"      // cyan
        }
        return ansi(code, text)
    }

    private static func printHeader(_ text: String, useColor: Bool) {
        if useColor {
            print(ansi("1;36", text))
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
