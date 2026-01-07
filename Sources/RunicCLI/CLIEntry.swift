import RunicCore
import Helix
import Foundation

@main
enum RunicCLI {
    static func main() async {
        let rawArgv = Array(CommandLine.arguments.dropFirst())
        let argv = Self.effectiveArgv(rawArgv)

        // Handle help/version
        if argv.contains("-h") || argv.contains("--help") {
            let command = argv.first { $0 != "-h" && $0 != "--help" && !$0.hasPrefix("-") }
            Self.printHelp(for: command)
        }
        if argv.contains("-V") || argv.contains("--version") {
            Self.printVersion()
        }

        // Create command signatures using Helix
        let usageSignature = CommandSignature(
            options: [
                OptionDefinition(label: "provider", names: [.long("provider")], help: "Provider to show usage for"),
                OptionDefinition(label: "format", names: [.long("format")], help: "Output format: text | json"),
            ],
            flags: [
                FlagDefinition(label: "verbose", names: [.short("v"), .long("verbose")], help: "Enable verbose logging"),
                FlagDefinition(label: "json", names: [.long("json")], help: "Output JSON format"),
                FlagDefinition(label: "pretty", names: [.long("pretty")], help: "Pretty-print output"),
                FlagDefinition(label: "noColor", names: [.long("no-color")], help: "Disable ANSI colors"),
            ])

        let costSignature = CommandSignature(
            options: [
                OptionDefinition(label: "provider", names: [.long("provider")], help: "Provider to show cost for"),
                OptionDefinition(label: "format", names: [.long("format")], help: "Output format: text | json"),
            ],
            flags: [
                FlagDefinition(label: "verbose", names: [.short("v"), .long("verbose")], help: "Enable verbose logging"),
                FlagDefinition(label: "json", names: [.long("json")], help: "Output JSON format"),
                FlagDefinition(label: "pretty", names: [.long("pretty")], help: "Pretty-print output"),
                FlagDefinition(label: "noColor", names: [.long("no-color")], help: "Disable ANSI colors"),
                FlagDefinition(label: "refresh", names: [.long("refresh")], help: "Force refresh cached data"),
            ])

        let insightsSignature = CommandSignature(
            options: [
                OptionDefinition(label: "provider", names: [.long("provider")], help: "Provider to analyze (claude, codex, or all)"),
                OptionDefinition(label: "view", names: [.long("view")], help: "View: daily | session | blocks | models | projects"),
                OptionDefinition(label: "project", names: [.long("project")], help: "Filter to a specific project"),
                OptionDefinition(label: "timezone", names: [.long("timezone")], help: "Timezone identifier (defaults to local)"),
            ],
            flags: [
                FlagDefinition(label: "json", names: [.long("json")], help: "Output JSON format"),
                FlagDefinition(label: "pretty", names: [.long("pretty")], help: "Pretty-print output"),
                FlagDefinition(label: "noColor", names: [.long("no-color")], help: "Disable ANSI colors"),
            ])

        let usageDescriptor = CommandDescriptor(
            name: "usage",
            abstract: "Print usage as text or JSON",
            discussion: nil,
            signature: usageSignature)

        let costDescriptor = CommandDescriptor(
            name: "cost",
            abstract: "Print local cost usage as text or JSON",
            discussion: nil,
            signature: costSignature)

        let insightsDescriptor = CommandDescriptor(
            name: "insights",
            abstract: "Analyze local usage logs (daily/session/blocks)",
            discussion: nil,
            signature: insightsSignature)

        let program = Program(descriptors: [usageDescriptor, costDescriptor, insightsDescriptor])

        do {
            let invocation = try program.resolve(argv: argv)
            switch invocation.descriptor.name {
            case "usage":
                await self.runUsage(invocation)
            case "cost":
                await self.runCost(invocation)
            case "insights":
                await self.runInsights(invocation)
            default:
                Self.exit(code: 1, message: "Unknown command")
            }
        } catch {
            Self.exit(code: 1, message: error.localizedDescription)
        }
    }

    // MARK: - Commands

    private static func runUsage(_ invocation: CommandInvocation) async {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"
        let isJson = invocation.parsedValues.flags.contains("json") || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let useColor = !noColor

        let providers: [UsageProvider]
        if let providerName = providerArg?.lowercased() {
            guard let p = UsageProvider(rawValue: providerName) else {
                Self.exit(code: 1, message: "Unknown provider: \(providerName)")
            }
            providers = [p]
        } else {
            providers = ProviderDescriptorRegistry.all.map(\.id)
        }

        let fetcher = UsageFetcher()
        var output: String = ""

        for provider in providers {
            do {
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
                let result = try outcome.result.get()

                let header = "\(descriptor.metadata.sessionLabel)"
                let text = Self.renderUsageText(
                    provider: provider,
                    snapshot: result.usage,
                    credits: result.credits,
                    header: header,
                    useColor: useColor)

                if !output.isEmpty { output += "\n" }
                output += text
            } catch {
                let errorMsg = "Error fetching \(provider.rawValue): \(error.localizedDescription)"
                if !output.isEmpty { output += "\n" }
                output += errorMsg
            }
        }

        if isPretty && isJson {
            if let data = output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let pretty = String(data: prettyData, encoding: .utf8) {
                print(pretty)
            } else {
                print(output)
            }
        } else {
            print(output)
        }
    }

    private static func runCost(_ invocation: CommandInvocation) async {
        let providerArg = invocation.parsedValues.options["provider"]?.first
        let formatArg = invocation.parsedValues.options["format"]?.first ?? "text"
        let isJson = invocation.parsedValues.flags.contains("json") || formatArg.lowercased() == "json"
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let noColor = invocation.parsedValues.flags.contains("noColor")
        let useColor = !noColor
        let refresh = invocation.parsedValues.flags.contains("refresh")

        let providers: [UsageProvider]
        if let providerName = providerArg?.lowercased() {
            guard let p = UsageProvider(rawValue: providerName) else {
                Self.exit(code: 1, message: "Unknown provider: \(providerName)")
            }
            if p != .claude && p != .codex {
                Self.exit(code: 1, message: "Cost is only supported for claude and codex")
            }
            providers = [p]
        } else {
            providers = [.claude, .codex]
        }

        let fetcher = CostUsageFetcher()
        var output: String = ""

        for provider in providers {
            do {
                let snapshot = try await fetcher.loadTokenSnapshot(provider: provider, forceRefresh: refresh)
                let text = Self.renderCostText(provider: provider, snapshot: snapshot, useColor: useColor)
                if !output.isEmpty { output += "\n" }
                output += text
            } catch {
                let errorMsg = "Error fetching cost for \(provider.rawValue): \(error.localizedDescription)"
                if !output.isEmpty { output += "\n" }
                output += errorMsg
            }
        }

        if isPretty && isJson {
            print("{\"cost\": \"output available in text format\"}")
        } else {
            print(output)
        }
    }

    private static func runInsights(_ invocation: CommandInvocation) async {
        let providerArg = invocation.parsedValues.options["provider"]?.first?.lowercased()
        let viewArg = invocation.parsedValues.options["view"]?.first?.lowercased() ?? "daily"
        let projectFilter = invocation.parsedValues.options["project"]?.first
        let timezoneArg = invocation.parsedValues.options["timezone"]?.first
        let isJson = invocation.parsedValues.flags.contains("json")
        let isPretty = invocation.parsedValues.flags.contains("pretty")

        let timeZone = timezoneArg.flatMap(TimeZone.init(identifier:)) ?? .current
        let providers = Self.resolveInsightsProviders(providerArg)
        let now = Date()
        let sources = Self.insightsSources(for: providers, now: now)

        var entries: [UsageLedgerEntry] = []
        var errors: [String] = []
        for (provider, source) in sources {
            do {
                let loaded = try await source.loadEntries()
                entries.append(contentsOf: loaded)
            } catch {
                errors.append("Error reading \(provider.rawValue) logs: \(error.localizedDescription)")
            }
        }

        if entries.isEmpty {
            if errors.isEmpty {
                Self.exit(code: 1, message: "No insights available.")
            }
            Self.exit(code: 1, message: errors.joined(separator: "\n"))
        }

        if !errors.isEmpty, !isJson {
            for err in errors {
                Self.printError(err)
            }
        }

        if let projectFilter, !projectFilter.isEmpty {
            entries = entries.filter { $0.projectID == projectFilter }
        }

        switch viewArg {
        case "daily":
            let summaries = UsageLedgerAggregator.dailySummaries(entries: entries, timeZone: timeZone)
            Self.renderInsightsOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "session":
            let summaries = UsageLedgerAggregator.sessionSummaries(entries: entries)
            Self.renderInsightsOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "blocks":
            let summaries = UsageLedgerAggregator.blockSummaries(entries: entries, blockHours: 5, now: now)
            Self.renderInsightsOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "models":
            let summaries = UsageLedgerAggregator.modelSummaries(entries: entries, groupByProject: true)
            Self.renderInsightsOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "projects":
            let summaries = UsageLedgerAggregator.projectSummaries(entries: entries)
            Self.renderInsightsOutput(summaries, isJson: isJson, isPretty: isPretty)
        default:
            Self.exit(code: 1, message: "Unknown insights view: \(viewArg)")
        }
    }

    private static func resolveInsightsProviders(_ raw: String?) -> [UsageProvider] {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "claude"
        let lowered = trimmed.lowercased()
        if lowered == "all" {
            return [.claude, .codex]
        }

        let parts = lowered.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var providers: [UsageProvider] = []
        for part in parts {
            switch part {
            case "claude":
                providers.append(.claude)
            case "codex":
                providers.append(.codex)
            default:
                Self.exit(code: 1, message: "Insights unsupported provider: \(part)")
            }
        }

        return providers
    }

    private static func insightsSources(
        for providers: [UsageProvider],
        now: Date) -> [(UsageProvider, any UsageLedgerSource)]
    {
        var sources: [(UsageProvider, any UsageLedgerSource)] = []
        for provider in providers {
            switch provider {
            case .claude:
                sources.append((provider, ClaudeUsageLogSource(maxAgeDays: nil, now: now)))
            case .codex:
                sources.append((provider, CodexUsageLogSource(maxAgeDays: nil, now: now)))
            default:
                continue
            }
        }
        return sources
    }

    private static func printError(_ message: String) {
        if let data = (message + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    private static func renderInsightsOutput<T: Encodable>(_ payload: T, isJson: Bool, isPretty: Bool) {
        if isJson {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if isPretty {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            if let data = try? encoder.encode(payload),
               let text = String(data: data, encoding: .utf8)
            {
                print(text)
            } else {
                print("{}")
            }
            return
        }

        if let summaries = payload as? [UsageLedgerDailySummary] {
            for summary in summaries {
                let project = summary.projectID ?? "all"
                let costText = summary.totals.costUSD.map { String(format: "$%.2f", $0) } ?? "n/a"
                print("\(summary.dayKey) - \(summary.provider.rawValue) - \(project) - \(summary.totals.totalTokens) tokens - \(costText)")
            }
            return
        }

        if let summaries = payload as? [UsageLedgerSessionSummary] {
            for summary in summaries {
                let project = summary.projectID ?? "all"
                let costText = summary.totals.costUSD.map { String(format: "$%.2f", $0) } ?? "n/a"
                print("\(summary.sessionID) - \(summary.provider.rawValue) - \(project) - \(summary.totals.totalTokens) tokens - \(costText)")
            }
            return
        }

        if let summaries = payload as? [UsageLedgerBlockSummary] {
            for summary in summaries {
                let project = summary.projectID ?? "all"
                let costText = summary.totals.costUSD.map { String(format: "$%.2f", $0) } ?? "n/a"
                print("\(summary.start) - \(summary.provider.rawValue) - \(project) - \(summary.totals.totalTokens) tokens - \(costText)")
            }
            return
        }

        if let summaries = payload as? [UsageLedgerModelSummary] {
            for summary in summaries {
                let project = summary.projectID ?? "all"
                let costText = summary.totals.costUSD.map { String(format: "$%.2f", $0) } ?? "n/a"
                print("\(summary.model) - \(summary.provider.rawValue) - \(project) - \(summary.totals.totalTokens) tokens - \(costText)")
            }
            return
        }

        if let summaries = payload as? [UsageLedgerProjectSummary] {
            for summary in summaries {
                let project = summary.projectID ?? "unknown"
                let costText = summary.totals.costUSD.map { String(format: "$%.2f", $0) } ?? "n/a"
                let models = summary.modelsUsed.isEmpty ? "no models" : summary.modelsUsed.joined(separator: ", ")
                print("\(project) - \(summary.provider.rawValue) - \(summary.totals.totalTokens) tokens - \(costText) - \(models)")
            }
            return
        }

        print("No insights available.")
    }

    // MARK: - Rendering

    private static func renderUsageText(
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
        if let reset = snapshot.primary.resetDescription {
            lines.append(Self.resetLine(reset))
        }

        if let secondary = snapshot.secondary {
            lines.append(Self.rateLine(title: meta.weeklyLabel, window: secondary, useColor: useColor))
            if let reset = secondary.resetDescription {
                lines.append(Self.resetLine(reset))
            }
        }

        if meta.supportsOpus, let tertiary = snapshot.tertiary {
            lines.append(Self.rateLine(title: meta.opusLabel ?? "Sonnet", window: tertiary, useColor: useColor))
            if let reset = tertiary.resetDescription {
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

    private static func renderCostText(
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
        let filled = Int(used / 100.0 * Double(barLength))
        let empty = barLength - filled
        let filledBar = String(repeating: "█", count: filled)
        let emptyBar = String(repeating: "░", count: empty)
        return "[\(filledBar)\(emptyBar)] \(String(format: "%.1f", used))% used"
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
        } else if remaining >= 1_000 {
            return String(format: "%.1fK", remaining / 1_000)
        }
        return String(format: "%.0f", remaining)
    }

    private static func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }

    // MARK: - Helpers

    private static func effectiveArgv(_ argv: [String]) -> [String] {
        var effective = [String]()
        var i = 0
        while i < argv.count {
            let arg = argv[i]
            if arg == "--" {
                effective.append(contentsOf: argv[(i + 1)...])
                break
            }
            effective.append(arg)
            i += 1
        }
        return effective
    }

    private static func printHelp(for command: String?) {
        if command == "usage" || command == nil {
            print("usage - Print usage as text or JSON")
            print("  Options:")
            print("    --provider PROVIDER    Provider to show usage for")
            print("    --format FORMAT        Output format: text | json")
            print("    --json                 Output JSON format")
            print("    --pretty               Pretty-print output")
            print("    --no-color             Disable ANSI colors")
            print("")
            print("  Providers: codex, claude, cursor, gemini, factory, copilot, zai, antigravity, minimax, openrouter, groq")
        }
        if command == "cost" || command == nil {
            print("cost - Print local cost usage as text or JSON")
            print("  Options:")
            print("    --provider PROVIDER    Provider to show cost for (claude, codex)")
            print("    --format FORMAT        Output format: text | json")
            print("    --json                 Output JSON format")
            print("    --pretty               Pretty-print output")
            print("    --no-color             Disable ANSI colors")
            print("    --refresh              Force refresh cached data")
        }
        if command == "insights" || command == nil {
            print("insights - Analyze local usage logs")
            print("  Options:")
            print("    --provider PROVIDER    Provider to analyze (claude, codex, all)")
            print("    --view VIEW            daily | session | blocks | models | projects")
            print("    --project PROJECT      Filter to a specific project")
            print("    --timezone TZ          Timezone identifier (defaults to local)")
            print("    --json                 Output JSON format")
            print("    --pretty               Pretty-print output")
            print("    --no-color             Disable ANSI colors")
        }
        if command != nil && command != "usage" && command != "cost" && command != "insights" {
            print("Unknown command: \(command ?? "")")
        }
        Foundation.exit(0)
    }

    private static func printVersion() {
        print("Runic CLI - Version 1.0.0")
        Foundation.exit(0)
    }

    private static func exit(code: Int32, message: String? = nil) -> Never {
        if let message = message {
            FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
        }
        Foundation.exit(code)
    }
}

// MARK: - Helix Command Types

struct UsageCommand {
    var verbose: Bool = false
    var json: Bool = false
    var pretty: Bool = false
    var noColor: Bool = false
    var provider: String? = nil
    var format: String = "text"
}

struct CostCommand {
    var verbose: Bool = false
    var json: Bool = false
    var pretty: Bool = false
    var noColor: Bool = false
    var provider: String? = nil
    var format: String = "text"
    var refresh: Bool = false
}

struct InsightsCommand {
    var json: Bool = false
    var pretty: Bool = false
    var noColor: Bool = false
    var provider: String? = nil
    var view: String = "daily"
    var project: String? = nil
    var timezone: String? = nil
}
