/// ProjectsCommand.swift
/// Runic CLI - Project Usage Tracking
///
/// Lists projects and displays usage statistics for specific projects,
/// helping you understand token consumption across different codebases.
///
/// Usage:
///   runic projects [--list | --stats <project-id>] [--json] [--pretty] [--no-color]
///
/// Examples:
///   runic projects --list                  # List all projects
///   runic projects --stats my-project      # Show stats for specific project
///   runic projects --json --pretty         # JSON output of all projects

import RunicCore
import Helix
import Foundation

/// Main entry point for the projects command
public enum ProjectsCommand {

    /// Command signature defining available options and flags
    public static var signature: CommandSignature {
        CommandSignature(
            options: [
                OptionDefinition(
                    label: "stats",
                    names: [.long("stats"), .short("s")],
                    help: "Show detailed stats for a specific project ID"),
                OptionDefinition(
                    label: "provider",
                    names: [.long("provider"), .short("p")],
                    help: "Filter by provider (claude, codex, etc.)"),
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
                    label: "list",
                    names: [.long("list"), .short("l")],
                    help: "List all projects (default behavior)"),
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
                    label: "sortByTokens",
                    names: [.long("sort-tokens")],
                    help: "Sort projects by token usage (default)"),
                FlagDefinition(
                    label: "sortByName",
                    names: [.long("sort-name")],
                    help: "Sort projects alphabetically by name"),
            ])
    }

    /// Command descriptor for registration
    public static var descriptor: CommandDescriptor {
        CommandDescriptor(
            name: "projects",
            abstract: "Track usage across different projects",
            discussion: """
            Lists projects and shows detailed usage statistics per project.
            Projects are identified from local usage logs.

            By default, shows a list of all projects sorted by token usage.

            EXAMPLES:
              runic projects
                List all projects with summary stats

              runic projects --stats my-project-id
                Show detailed statistics for a specific project

              runic projects --provider claude --days 7
                Show Claude projects from last 7 days

              runic projects --sort-name --json
                List projects alphabetically in JSON format
            """,
            signature: signature)
    }

    /// Execute the projects command
    public static func run(_ invocation: CommandInvocation) async {
        let config = parseConfiguration(invocation)

        do {
            let entries = try await loadUsageEntries(
                providers: config.providers,
                maxAgeDays: config.days)

            guard !entries.isEmpty else {
                exitWithError("No project usage data found for the specified criteria.")
            }

            if let projectID = config.statsProjectID {
                await showProjectStats(projectID, entries: entries, config: config)
            } else {
                await showProjectList(entries: entries, config: config)
            }
        } catch {
            exitWithError("Failed to load usage data: \(error.localizedDescription)")
        }
    }

    // MARK: - Configuration

    private struct Configuration {
        let providers: [UsageProvider]
        let days: Int
        let isJSON: Bool
        let isPretty: Bool
        let useColor: Bool
        let sortByName: Bool
        let statsProjectID: String?
    }

    private static func parseConfiguration(_ invocation: CommandInvocation) -> Configuration {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let daysArg = invocation.parsedValues.options["days"]?.first
        let statsArg = invocation.parsedValues.options["stats"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"

        let isJSON = invocation.parsedValues.flags.contains("json")
            || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let sortByName = invocation.parsedValues.flags.contains("sortByName")

        let days = daysArg.flatMap(Int.init) ?? 30
        let providers = resolveProviders(providerArg)

        return Configuration(
            providers: providers,
            days: days,
            isJSON: isJSON,
            isPretty: isPretty,
            useColor: !noColor,
            sortByName: sortByName,
            statsProjectID: statsArg)
    }

    private static func resolveProviders(_ arg: String?) -> [UsageProvider] {
        guard let arg = arg?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return [.claude, .codex]
        }

        if arg == "all" {
            return [.claude, .codex]
        }

        guard let provider = UsageProvider(rawValue: arg) else {
            exitWithError("Unknown provider: \(arg)")
        }

        return [provider]
    }

    // MARK: - Data Loading

    private static func loadUsageEntries(
        providers: [UsageProvider],
        maxAgeDays: Int
    ) async throws -> [UsageLedgerEntry] {
        let now = Date()
        var allEntries: [UsageLedgerEntry] = []

        for provider in providers {
            let source: (any UsageLedgerSource)? = switch provider {
            case .claude:
                ClaudeUsageLogSource(maxAgeDays: maxAgeDays, now: now)
            case .codex:
                CodexUsageLogSource(maxAgeDays: maxAgeDays, now: now)
            default:
                nil
            }

            if let source {
                let entries = try await source.loadEntries()
                allEntries.append(contentsOf: entries)
            }
        }

        return allEntries
    }

    // MARK: - Project List Display

    private static func showProjectList(
        entries: [UsageLedgerEntry],
        config: Configuration
    ) async {
        var summaries = UsageLedgerAggregator.projectSummaries(entries: entries)

        if config.sortByName {
            summaries.sort { (lhs, rhs) in
                (lhs.projectID ?? "unknown") < (rhs.projectID ?? "unknown")
            }
        }

        if config.isJSON {
            outputJSON(summaries, pretty: config.isPretty)
        } else {
            outputProjectListText(summaries, useColor: config.useColor)
        }
    }

    private static func outputProjectListText(
        _ summaries: [UsageLedgerProjectSummary],
        useColor: Bool
    ) {
        if summaries.isEmpty {
            print("No projects found.")
            return
        }

        printHeader("Projects (\(summaries.count) total)", useColor: useColor)
        print("")

        // Calculate column widths
        let maxProjectWidth = summaries.map { ($0.projectID ?? "unknown").count }.max() ?? 20
        let projectWidth = min(max(maxProjectWidth, 20), 50)

        // Print table header
        let header = String(format: "%-\(projectWidth)s  %-12s  %-15s  %-12s  %-10s",
                           "PROJECT ID", "PROVIDER", "TOKENS", "REQUESTS", "COST")
        if useColor {
            print(ansi("1;37", header))
            print(String(repeating: "-", count: projectWidth + 55))
        } else {
            print(header)
            print(String(repeating: "-", count: projectWidth + 55))
        }

        var totalTokens = 0
        var totalRequests = 0
        var totalCost = 0.0

        for summary in summaries {
            let projectID = truncate(summary.projectID ?? "unknown", maxWidth: projectWidth)
            let provider = summary.provider.rawValue
            let tokens = formatNumber(summary.totals.totalTokens)
            let requests = "\(summary.entryCount)"
            let cost = formatCost(summary.totals.costUSD)

            let line = String(format: "%-\(projectWidth)s  %-12s  %15s  %12s  %10s",
                             projectID, provider, tokens, requests, cost)

            if useColor {
                print(colorizeByUsage(line, tokens: summary.totals.totalTokens))
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
        print(String(repeating: "-", count: projectWidth + 55))
        let totalLine = String(format: "%-\(projectWidth)s  %-12s  %15s  %12s  %10s",
                              "TOTAL", "", formatNumber(totalTokens), "\(totalRequests)",
                              formatCost(totalCost > 0 ? totalCost : nil))

        if useColor {
            print(ansi("1;36", totalLine))
        } else {
            print(totalLine)
        }
    }

    // MARK: - Project Stats Display

    private static func showProjectStats(
        _ projectID: String,
        entries: [UsageLedgerEntry],
        config: Configuration
    ) async {
        let projectEntries = entries.filter { $0.projectID == projectID }

        guard !projectEntries.isEmpty else {
            exitWithError("No usage data found for project: \(projectID)")
        }

        let summaries = UsageLedgerAggregator.projectSummaries(entries: projectEntries)
        let modelSummaries = UsageLedgerAggregator.modelSummaries(entries: projectEntries)
        let dailySummaries = UsageLedgerAggregator.dailySummaries(
            entries: projectEntries,
            timeZone: .current,
            groupByProject: false)

        let stats = ProjectStats(
            projectID: projectID,
            summaries: summaries,
            modelSummaries: modelSummaries,
            dailySummaries: dailySummaries)

        if config.isJSON {
            outputJSON(stats, pretty: config.isPretty)
        } else {
            outputProjectStatsText(stats, useColor: config.useColor)
        }
    }

    private struct ProjectStats: Encodable {
        let projectID: String
        let summaries: [UsageLedgerProjectSummary]
        let modelSummaries: [UsageLedgerModelSummary]
        let dailySummaries: [UsageLedgerDailySummary]
    }

    private static func outputProjectStatsText(_ stats: ProjectStats, useColor: Bool) {
        printHeader("Project: \(stats.projectID)", useColor: useColor)
        print("")

        // Overall stats
        let totalTokens = stats.summaries.reduce(0) { $0 + $1.totals.totalTokens }
        let totalRequests = stats.summaries.reduce(0) { $0 + $1.entryCount }
        let totalCost = stats.summaries.reduce(0.0) { $0 + ($1.totals.costUSD ?? 0) }

        print("Overall Statistics:")
        print("  Total Tokens:   \(formatNumber(totalTokens))")
        print("  Total Requests: \(totalRequests)")
        print("  Total Cost:     \(formatCost(totalCost > 0 ? totalCost : nil))")
        print("")

        // Models used
        if !stats.modelSummaries.isEmpty {
            print("Models Used:")
            for model in stats.modelSummaries.prefix(10) {
                let tokens = formatNumber(model.totals.totalTokens)
                let cost = formatCost(model.totals.costUSD)
                print("  \(model.model): \(tokens) tokens, \(cost)")
            }
            if stats.modelSummaries.count > 10 {
                print("  ... and \(stats.modelSummaries.count - 10) more")
            }
            print("")
        }

        // Daily breakdown
        if !stats.dailySummaries.isEmpty {
            print("Recent Activity (last 10 days):")
            for daily in stats.dailySummaries.suffix(10) {
                let tokens = formatNumber(daily.totals.totalTokens)
                let cost = formatCost(daily.totals.costUSD)
                print("  \(daily.dayKey): \(tokens) tokens, \(cost)")
            }
            print("")
        }
    }

    // MARK: - Output Formatting

    private static func outputJSON<T: Encodable>(_ data: T, pretty: Bool) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        guard let jsonData = try? encoder.encode(data),
              let text = String(data: jsonData, encoding: .utf8) else {
            print("{}")
            return
        }

        print(text)
    }

    // MARK: - Formatting Helpers

    private static func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }

    private static func formatCost(_ cost: Double?) -> String {
        guard let cost = cost, cost > 0 else {
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
            print(ansi("1;36", text))
        } else {
            print(text)
        }
    }

    private static func colorizeByUsage(_ text: String, tokens: Int) -> String {
        let code = switch tokens {
        case 1_000_000...: "35"  // magenta - very high
        case 500_000...: "33"    // yellow - high
        case 100_000...: "32"    // green - medium
        default: "0"             // default
        }
        return ansi(code, text)
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
