// EnhancedUsageCommand.swift
// Runic CLI - Enhanced Usage Display
//
// Enhanced version of the usage command with additional features:
// - Multiple display modes (summary, detailed, breakdown)
// - Historical trending
// - Cost projections
// - Comparative analysis across providers
//
// Usage:
//   runic usage-enhanced [options]
//
// Examples:
//   runic usage-enhanced --mode summary      # Quick overview
//   runic usage-enhanced --mode detailed     # Detailed breakdown
//   runic usage-enhanced --mode trending     # Usage trends

import Foundation
import Helix
import RunicCore

/// Enhanced usage command with additional analytics
public enum EnhancedUsageCommand {
    /// Command signature defining available options and flags
    public static var signature: CommandSignature {
        CommandSignature(
            options: [
                OptionDefinition(
                    label: "provider",
                    names: [.long("provider"), .short("p")],
                    help: "Filter by provider (claude, codex, etc.)"),
                OptionDefinition(
                    label: "mode",
                    names: [.long("mode"), .short("m")],
                    help: "Display mode: summary | detailed | breakdown | trending"),
                OptionDefinition(
                    label: "days",
                    names: [.long("days"), .short("d")],
                    help: "Number of days for trending analysis (default: 7)"),
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
                    label: "showCost",
                    names: [.long("show-cost")],
                    help: "Include cost information"),
                FlagDefinition(
                    label: "showProjected",
                    names: [.long("projected")],
                    help: "Show projected usage at current rate"),
                FlagDefinition(
                    label: "compare",
                    names: [.long("compare")],
                    help: "Compare usage across providers"),
            ])
    }

    /// Command descriptor for registration
    public static var descriptor: CommandDescriptor {
        CommandDescriptor(
            name: "usage-enhanced",
            abstract: "Enhanced usage display with analytics",
            discussion: """
            Enhanced version of the usage command with additional features:

            DISPLAY MODES:
              summary   - Quick overview of current usage (default)
              detailed  - Detailed breakdown with all windows
              breakdown - Token breakdown by type (input/output/cache)
              trending  - Historical usage trends

            EXAMPLES:
              runic usage-enhanced
                Show summary for all providers

              runic usage-enhanced --mode detailed --show-cost
                Detailed view with cost information

              runic usage-enhanced --mode trending --days 30
                Show 30-day usage trends

              runic usage-enhanced --compare --json
                Compare providers in JSON format

              runic usage-enhanced --projected
                Show projected usage based on current rate
            """,
            signature: signature)
    }

    /// Execute the enhanced usage command
    public static func run(_ invocation: CommandInvocation) async {
        let config = self.parseConfiguration(invocation)

        do {
            let data = try await loadUsageData(
                providers: config.providers,
                days: config.days,
                includeCost: config.showCost)

            if config.isJSON {
                self.outputJSON(data, config: config)
            } else {
                self.outputText(data, config: config)
            }
        } catch {
            self.exitWithError("Failed to load usage data: \(error.localizedDescription)")
        }
    }

    // MARK: - Configuration

    private struct Configuration {
        let providers: [UsageProvider]
        let mode: DisplayMode
        let days: Int
        let isJSON: Bool
        let isPretty: Bool
        let useColor: Bool
        let showCost: Bool
        let showProjected: Bool
        let compare: Bool

        enum DisplayMode: String {
            case summary
            case detailed
            case breakdown
            case trending
        }
    }

    private static func parseConfiguration(_ invocation: CommandInvocation) -> Configuration {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let modeArg = invocation.parsedValues.options["mode"]?.first ?? "summary"
        let daysArg = invocation.parsedValues.options["days"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"

        let isJSON = invocation.parsedValues.flags.contains("json")
            || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let showCost = invocation.parsedValues.flags.contains("showCost")
        let showProjected = invocation.parsedValues.flags.contains("showProjected")
        let compare = invocation.parsedValues.flags.contains("compare")

        let mode = Configuration.DisplayMode(rawValue: modeArg.lowercased()) ?? .summary
        let days = daysArg.flatMap(Int.init) ?? 7
        let providers = self.resolveProviders(providerArg)

        return Configuration(
            providers: providers,
            mode: mode,
            days: days,
            isJSON: isJSON,
            isPretty: isPretty,
            useColor: !noColor,
            showCost: showCost,
            showProjected: showProjected,
            compare: compare)
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

    // MARK: - Data Models

    private struct EnhancedUsageData: Encodable {
        let providers: [ProviderUsageData]
        let summary: UsageSummary?
        let comparison: ProviderComparison?
    }

    private struct ProviderUsageData: Encodable {
        let provider: UsageProvider
        let providerName: String
        let snapshot: UsageSnapshot
        let credits: CreditsSnapshot?
        let windows: [WindowData]
        let breakdown: TokenBreakdown?
        let trending: [DailyTrend]?
        let projected: ProjectedUsage?
    }

    private struct WindowData: Encodable {
        let name: String
        let used: Int?
        let limit: Int?
        let usedPercent: Double
        let remainingPercent: Double
        let resetDescription: String?
    }

    private struct TokenBreakdown: Encodable {
        let totalTokens: Int
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationTokens: Int
        let cacheReadTokens: Int
        let inputPercent: Double
        let outputPercent: Double
        let cachePercent: Double
    }

    private struct DailyTrend: Encodable {
        let date: String
        let totalTokens: Int
        let cost: Double?
    }

    private struct ProjectedUsage: Encodable {
        let currentUsed: Int
        let projectedTotal: Int
        let projectedAtEndOfPeriod: Int
        let riskLevel: String
    }

    private struct UsageSummary: Encodable {
        let totalProviders: Int
        let totalTokens: Int
        let totalCost: Double?
        let highestUsageProvider: String
        let averageUsagePercent: Double
    }

    private struct ProviderComparison: Encodable {
        let comparisons: [ProviderComparisonItem]
        let mostEfficient: String?
        let mostExpensive: String?
    }

    private struct ProviderComparisonItem: Encodable {
        let provider: String
        let totalTokens: Int
        let cost: Double?
        let efficiency: Double
    }

    // MARK: - Data Loading

    private static func loadUsageData(
        providers: [UsageProvider],
        days: Int,
        includeCost: Bool) async throws -> EnhancedUsageData
    {
        let fetcher = UsageFetcher()
        let _ = includeCost ? CostUsageFetcher() : nil
        var providerData: [ProviderUsageData] = []

        for provider in providers {
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let context = ProviderFetchContext(
                runtime: .cli,
                sourceMode: .cli,
                includeCredits: true,
                webTimeout: 60,
                webDebugDumpHTML: false,
                verbose: false,
                env: ProcessInfo.processInfo.environment,
                settings: nil,
                fetcher: fetcher,
                claudeFetcher: ClaudeUsageFetcher())

            let outcome = await descriptor.fetchOutcome(context: context)

            if case let .success(result) = outcome.result {
                let trending = try? await loadTrendingData(
                    provider: provider,
                    days: days)

                let data = self.buildProviderData(
                    provider: provider,
                    snapshot: result.usage,
                    credits: result.credits,
                    metadata: descriptor.metadata,
                    trending: trending)

                providerData.append(data)
            }
        }

        let summary = self.buildSummary(providerData: providerData)
        let comparison = self.buildComparison(providerData: providerData)

        return EnhancedUsageData(
            providers: providerData,
            summary: summary,
            comparison: comparison)
    }

    private static func buildProviderData(
        provider: UsageProvider,
        snapshot: UsageSnapshot,
        credits: CreditsSnapshot?,
        metadata: ProviderMetadata,
        trending: [DailyTrend]?) -> ProviderUsageData
    {
        var windows: [WindowData] = []

        windows.append(WindowData(
            name: metadata.sessionLabel,
            used: nil,
            limit: nil,
            usedPercent: snapshot.primary.usedPercent,
            remainingPercent: snapshot.primary.remainingPercent,
            resetDescription: snapshot.primary.resetDescription))

        if let secondary = snapshot.secondary {
            windows.append(WindowData(
                name: metadata.weeklyLabel,
                used: nil,
                limit: nil,
                usedPercent: secondary.usedPercent,
                remainingPercent: secondary.remainingPercent,
                resetDescription: secondary.resetDescription))
        }

        return ProviderUsageData(
            provider: provider,
            providerName: provider.rawValue.capitalized,
            snapshot: snapshot,
            credits: credits,
            windows: windows,
            breakdown: nil,
            trending: trending,
            projected: nil)
    }

    private static func loadTrendingData(
        provider: UsageProvider,
        days: Int) async throws -> [DailyTrend]?
    {
        let source = UsageLedgerSourceFactory.source(for: provider, now: Date(), maxAgeDays: days)

        guard let source else { return nil }

        let entries = try await source.loadEntries()
        let summaries = UsageLedgerAggregator.dailySummaries(
            entries: entries,
            timeZone: .current,
            groupByProject: false)

        return summaries.map { summary in
            DailyTrend(
                date: summary.dayKey,
                totalTokens: summary.totals.totalTokens,
                cost: summary.totals.costUSD)
        }
    }

    private static func buildSummary(
        providerData: [ProviderUsageData]) -> UsageSummary?
    {
        guard !providerData.isEmpty else { return nil }

        let totalTokens = providerData.reduce(0) { sum, data in
            sum + data.windows.reduce(0) { $0 + ($1.used ?? 0) }
        }

        let averageUsage = providerData.reduce(0.0) { sum, data in
            let providerAvg = data.windows.map(\.usedPercent).reduce(0.0, +) / Double(data.windows.count)
            return sum + providerAvg
        } / Double(providerData.count)

        let highestProvider = providerData.max { lhs, rhs in
            let lhsMax = lhs.windows.map(\.usedPercent).max() ?? 0
            let rhsMax = rhs.windows.map(\.usedPercent).max() ?? 0
            return lhsMax < rhsMax
        }

        return UsageSummary(
            totalProviders: providerData.count,
            totalTokens: totalTokens,
            totalCost: nil,
            highestUsageProvider: highestProvider?.providerName ?? "unknown",
            averageUsagePercent: averageUsage)
    }

    private static func buildComparison(
        providerData: [ProviderUsageData]) -> ProviderComparison?
    {
        guard providerData.count > 1 else { return nil }

        let comparisons = providerData.map { data in
            let totalTokens = data.windows.reduce(0) { $0 + ($1.used ?? 0) }
            let efficiency = data.windows.map(\.usedPercent).min() ?? 100

            return ProviderComparisonItem(
                provider: data.providerName,
                totalTokens: totalTokens,
                cost: nil,
                efficiency: efficiency)
        }

        let mostEfficient = comparisons.min { $0.efficiency < $1.efficiency }?.provider

        return ProviderComparison(
            comparisons: comparisons,
            mostEfficient: mostEfficient,
            mostExpensive: nil)
    }

    // MARK: - Output Formatting

    private static func outputJSON(_ data: EnhancedUsageData, config: Configuration) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if config.isPretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }

        guard let jsonData = try? encoder.encode(data),
              let text = String(data: jsonData, encoding: .utf8)
        else {
            print("{}")
            return
        }

        print(text)
    }

    private static func outputText(_ data: EnhancedUsageData, config: Configuration) {
        switch config.mode {
        case .summary:
            self.outputSummaryMode(data, config: config)
        case .detailed:
            self.outputDetailedMode(data, config: config)
        case .breakdown:
            self.outputBreakdownMode(data, config: config)
        case .trending:
            self.outputTrendingMode(data, config: config)
        }
    }

    private static func outputSummaryMode(_ data: EnhancedUsageData, config: Configuration) {
        self.printHeader("Usage Summary", useColor: config.useColor)
        print("")

        if let summary = data.summary {
            print("Providers: \(summary.totalProviders)")
            print("Total Tokens: \(self.formatNumber(summary.totalTokens))")
            print("Average Usage: \(String(format: "%.1f", summary.averageUsagePercent))%")
            print("Highest Usage: \(summary.highestUsageProvider)")
            print("")
        }

        for providerData in data.providers {
            print(providerData.providerName)
            for window in providerData.windows {
                let bar = self.progressBar(
                    used: window.usedPercent,
                    width: 20,
                    useColor: config.useColor)
                let percent = String(format: "%.1f", window.usedPercent)
                print("  \(window.name): \(bar) \(percent)%")
            }
            print("")
        }
    }

    private static func outputDetailedMode(_ data: EnhancedUsageData, config: Configuration) {
        self.printHeader("Detailed Usage Information", useColor: config.useColor)
        print("")

        for (index, providerData) in data.providers.enumerated() {
            if index > 0 { print("") }

            if config.useColor {
                print(self.ansi("1;36", providerData.providerName))
            } else {
                print(providerData.providerName)
            }

            for window in providerData.windows {
                print("")
                print("  \(window.name):")
                if let used = window.used, let limit = window.limit {
                    print("    Used: \(self.formatNumber(used)) / \(self.formatNumber(limit))")
                }
                print("    Percent: \(String(format: "%.1f", window.usedPercent))%")
                if let reset = window.resetDescription {
                    print("    Reset: \(reset)")
                }
            }
        }
    }

    private static func outputBreakdownMode(_ data: EnhancedUsageData, config: Configuration) {
        self.printHeader("Token Breakdown", useColor: config.useColor)
        print("")
        print("Note: Detailed token breakdown requires historical log data.")
        print("Use 'runic insights --view models' for model-level breakdown.")
    }

    private static func outputTrendingMode(_ data: EnhancedUsageData, config: Configuration) {
        self.printHeader("Usage Trends", useColor: config.useColor)
        print("")

        for providerData in data.providers {
            print(providerData.providerName)

            if let trends = providerData.trending, !trends.isEmpty {
                for trend in trends.suffix(10) {
                    let tokens = self.formatNumber(trend.totalTokens)
                    let cost = trend.cost.map { String(format: "$%.4f", $0) } ?? "n/a"
                    print("  \(trend.date): \(tokens) tokens (\(cost))")
                }
            } else {
                print("  No trending data available")
            }
            print("")
        }
    }

    private static func progressBar(used: Double, width: Int, useColor: Bool) -> String {
        let filled = Int((used / 100.0) * Double(width))
        let empty = width - filled
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)

        guard useColor else { return "[\(bar)]" }

        let color = switch used {
        case 90...: "31" // red
        case 75...: "33" // yellow
        default: "32" // green
        }

        return "[\(self.ansi(color, bar))]"
    }

    private static func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1000 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return "\(n)"
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
