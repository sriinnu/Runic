// ModelsCommand.swift
// Runic CLI - Model Usage Breakdown
//
// Displays which AI models were used across different providers,
// showing token consumption and cost breakdown by model type.
//
// Usage:
//   runic models [--provider <name>] [--days <n>] [--json] [--pretty] [--no-color]
//
// Examples:
//   runic models                           # Show all models used
//   runic models --provider claude         # Claude models only
//   runic models --days 7                  # Last 7 days
//   runic models --json --pretty           # JSON output

import Foundation
import Helix
import RunicCore

/// Main entry point for the models command
public enum ModelsCommand {
    private struct EnrichedModelSummary: Codable {
        let provider: UsageProvider
        let projectKey: String?
        let projectID: String?
        let projectName: String?
        let projectNameConfidence: UsageLedgerProjectNameConfidence?
        let projectNameSource: UsageLedgerProjectNameSource?
        let projectNameProvenance: String?
        let model: String
        let modelContextWindow: Int?
        let modelContextLabel: String?
        let entryCount: Int
        let totals: UsageLedgerTotals

        init(summary: UsageLedgerModelSummary) {
            self.provider = summary.provider
            self.projectKey = summary.projectKey
            self.projectID = summary.projectID
            self.projectName = summary.projectName
            self.projectNameConfidence = summary.projectNameConfidence
            self.projectNameSource = summary.projectNameSource
            self.projectNameProvenance = summary.projectNameProvenance
            self.model = summary.model
            self.modelContextWindow = UsageFormatter.modelContextWindow(for: summary.model)
            self.modelContextLabel = UsageFormatter.modelContextLabel(for: summary.model)
            self.entryCount = summary.entryCount
            self.totals = summary.totals
        }
    }

    /// Command signature defining available options and flags
    public static var signature: CommandSignature {
        CommandSignature(
            options: [
                OptionDefinition(
                    label: "provider",
                    names: [.long("provider"), .short("p")],
                    help: "Filter by provider (claude, codex, gemini, etc.)"),
                OptionDefinition(
                    label: "days",
                    names: [.long("days"), .short("d")],
                    help: "Number of days to analyze (default: 30)"),
                OptionDefinition(
                    label: "format",
                    names: [.long("format")],
                    help: "Output format: text | json"),
            ],
            flags: [
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
                    label: "groupByProject",
                    names: [.long("by-project")],
                    help: "Group results by project"),
            ])
    }

    /// Command descriptor for registration
    public static var descriptor: CommandDescriptor {
        CommandDescriptor(
            name: "models",
            abstract: "Show model usage breakdown across providers",
            discussion: """
            Analyzes local usage logs to show which AI models were used,
            breaking down token consumption and costs by model type.

            Supported providers: claude, codex, gemini, cursor, and others.

            EXAMPLES:
              runic models
                Show all models used in the last 30 days

              runic models --provider claude --days 7
                Show Claude models used in the last 7 days

              runic models --by-project --json
                Show models grouped by project in JSON format
            """,
            signature: signature)
    }

    /// Execute the models command
    public static func run(_ invocation: CommandInvocation) async {
        let config = self.parseConfiguration(invocation)

        do {
            let entries = try await loadUsageEntries(
                providers: config.providers,
                maxAgeDays: config.days)

            guard !entries.isEmpty else {
                self.exitWithError("No model usage data found for the specified criteria.")
            }

            let summaries = UsageLedgerAggregator.modelSummaries(
                entries: entries,
                groupByProject: config.groupByProject)

            if config.isJSON {
                self.outputJSON(summaries, pretty: config.isPretty)
            } else {
                self.outputText(summaries, useColor: config.useColor)
            }
        } catch {
            self.exitWithError("Failed to load usage data: \(error.localizedDescription)")
        }
    }

    // MARK: - Configuration

    private struct Configuration {
        let providers: [UsageProvider]
        let days: Int
        let isJSON: Bool
        let isPretty: Bool
        let useColor: Bool
        let groupByProject: Bool
    }

    private static func parseConfiguration(_ invocation: CommandInvocation) -> Configuration {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let daysArg = invocation.parsedValues.options["days"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"

        let isJSON = invocation.parsedValues.flags.contains("json")
            || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let groupByProject = invocation.parsedValues.flags.contains("groupByProject")

        let days = daysArg.flatMap(Int.init) ?? 30
        let providers = self.resolveProviders(providerArg)

        return Configuration(
            providers: providers,
            days: days,
            isJSON: isJSON,
            isPretty: isPretty,
            useColor: !noColor,
            groupByProject: groupByProject)
    }

    private static func resolveProviders(_ arg: String?) -> [UsageProvider] {
        guard let arg = arg?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return UsageProvider.allCases
        }

        if arg == "all" {
            return UsageProvider.allCases
        }

        guard let provider = UsageProvider(rawValue: arg) else {
            self.exitWithError("Unknown provider: \(arg)")
        }

        return [provider]
    }

    // MARK: - Data Loading

    private static func loadUsageEntries(
        providers: [UsageProvider],
        maxAgeDays: Int) async throws -> [UsageLedgerEntry]
    {
        let now = Date()
        var allEntries: [UsageLedgerEntry] = []

        for provider in providers {
            let source = UsageLedgerSourceFactory.source(for: provider, now: now, maxAgeDays: maxAgeDays)

            if let source {
                let entries = try await source.loadEntries()
                allEntries.append(contentsOf: entries)
            }
        }

        return allEntries
    }

    // MARK: - Output Formatting

    private static func outputJSON(_ summaries: [UsageLedgerModelSummary], pretty: Bool) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        let enriched = summaries.map(EnrichedModelSummary.init)

        guard let data = try? encoder.encode(enriched),
              let text = String(data: data, encoding: .utf8)
        else {
            print("[]")
            return
        }

        print(text)
    }

    private static func outputText(_ summaries: [UsageLedgerModelSummary], useColor: Bool) {
        if summaries.isEmpty {
            print("No model usage found.")
            return
        }

        self.printHeader("Model Usage Breakdown", useColor: useColor)
        print("")

        // Calculate column widths
        let maxModelWidth = summaries.map(\.model.count).max() ?? 20
        let modelWidth = min(max(maxModelWidth, 15), 40)
        let contextWidth = 11

        // Print table header
        let header = String(
            format: "%-\(modelWidth)s  %-12s  %-15s  %-12s  %-10s  %-\(contextWidth)s",
            "MODEL",
            "PROVIDER",
            "TOKENS",
            "REQUESTS",
            "COST",
            "CONTEXT")
        if useColor {
            print(self.ansi("1;37", header))
            print(String(repeating: "-", count: modelWidth + 58))
        } else {
            print(header)
            print(String(repeating: "-", count: modelWidth + 58))
        }

        var totalTokens = 0
        var totalRequests = 0
        var totalCost = 0.0

        for summary in summaries {
            let model = self.truncate(summary.model, maxWidth: modelWidth)
            let provider = summary.provider.rawValue
            let tokens = self.formatNumber(summary.totals.totalTokens)
            let requests = "\(summary.entryCount)"
            let cost = self.formatCost(summary.totals.costUSD)
            let context = UsageFormatter.modelContextLabel(for: summary.model) ?? "n/a"

            let line = String(
                format: "%-\(modelWidth)s  %-12s  %15s  %12s  %10s  %-\(contextWidth)s",
                model, provider, tokens, requests, cost, context)

            if useColor {
                print(self.colorizeByUsage(line, tokens: summary.totals.totalTokens))
            } else {
                print(line)
            }

            totalTokens += summary.totals.totalTokens
            totalRequests += summary.entryCount
            if let c = summary.totals.costUSD {
                totalCost += c
            }
        }

        // Print totals
        print(String(repeating: "-", count: modelWidth + 58))
        let totalLine = String(
            format: "%-\(modelWidth)s  %-12s  %15s  %12s  %10s  %-\(contextWidth)s",
            "TOTAL", "", formatNumber(totalTokens), "\(totalRequests)",
            formatCost(totalCost > 0 ? totalCost : nil), " ")

        if useColor {
            print(self.ansi("1;36", totalLine))
        } else {
            print(totalLine)
        }
    }

    // MARK: - Formatting Helpers

    private static func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
    }

    private static func formatCost(_ cost: Double?) -> String {
        guard let cost, cost > 0 else {
            return "n/a"
        }
        return String(format: "$%.4f", cost)
    }

    private static func truncate(_ text: String, maxWidth: Int) -> String {
        if text.count <= maxWidth {
            return text
        }
        let index = text.index(text.startIndex, offsetBy: maxWidth - 3)
        return String(text[..<index]) + "..."
    }

    private static func printHeader(_ text: String, useColor: Bool) {
        if useColor {
            print(self.ansi("1;36", text))
        } else {
            print(text)
        }
    }

    private static func colorizeByUsage(_ text: String, tokens: Int) -> String {
        let code = switch tokens {
        case 1_000_000...: "35" // magenta - very high
        case 500_000...: "33" // yellow - high
        case 100_000...: "32" // green - medium
        default: "0" // default
        }
        return self.ansi(code, text)
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
