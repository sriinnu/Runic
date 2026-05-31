import Foundation
import Helix
import RunicCore

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
                FlagDefinition(
                    label: "verbose",
                    names: [.short("v"), .long("verbose")],
                    help: "Enable verbose logging"),
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
                FlagDefinition(
                    label: "verbose",
                    names: [.short("v"), .long("verbose")],
                    help: "Enable verbose logging"),
                FlagDefinition(label: "json", names: [.long("json")], help: "Output JSON format"),
                FlagDefinition(label: "pretty", names: [.long("pretty")], help: "Pretty-print output"),
                FlagDefinition(label: "noColor", names: [.long("no-color")], help: "Disable ANSI colors"),
                FlagDefinition(
                    label: "refresh",
                    names: [.long("refresh")],
                    help: "Compatibility flag; cost refreshes today's logs by default"),
                FlagDefinition(
                    label: "rebuild",
                    names: [.long("rebuild")],
                    help: "Repair the 30-day relay by scanning provider JSONL history"),
            ])

        let insightsSignature = CommandSignature(
            options: [
                OptionDefinition(
                    label: "provider",
                    names: [.long("provider")],
                    help: "Provider to analyze (claude, codex, local-llm, comma-list, both, or all)"),
                OptionDefinition(
                    label: "view",
                    names: [.long("view")],
                    help: "View: daily | session | blocks | models | projects | compaction | comparative | efficiency"),
                OptionDefinition(label: "project", names: [.long("project")], help: "Filter to a specific project"),
                OptionDefinition(
                    label: "timezone",
                    names: [.long("timezone")],
                    help: "Timezone identifier (defaults to local)"),
                OptionDefinition(
                    label: "granularity",
                    names: [.long("granularity")],
                    help: "Time granularity: hourly (for daily view)"),
                OptionDefinition(
                    label: "gitDirectory",
                    names: [.long("git-directory")],
                    help: "Path to .git directory (defaults to current directory)"),
            ],
            flags: [
                FlagDefinition(label: "json", names: [.long("json")], help: "Output JSON format"),
                FlagDefinition(label: "pretty", names: [.long("pretty")], help: "Pretty-print output"),
                FlagDefinition(label: "noColor", names: [.long("no-color")], help: "Disable ANSI colors"),
                FlagDefinition(label: "budget", names: [.long("budget")], help: "Include budget tracking information"),
                FlagDefinition(
                    label: "withCommits",
                    names: [.long("with-commits")],
                    help: "Link usage entries to git commits"),
            ])

        let otelCollectSignature = CommandSignature(
            options: [
                OptionDefinition(
                    label: "port",
                    names: [.long("port")],
                    help: "Local OTLP/HTTP JSON port (default: 4318)"),
                OptionDefinition(
                    label: "host",
                    names: [.long("host")],
                    help: "Local bind host (default: 127.0.0.1)"),
                OptionDefinition(
                    label: "output",
                    names: [.long("output")],
                    help: "Sanitized JSONL output path"),
                OptionDefinition(
                    label: "input",
                    names: [.long("input")],
                    help: "Read one OTLP JSON payload from a file; use - for stdin"),
                OptionDefinition(
                    label: "defaultProvider",
                    names: [.long("default-provider")],
                    help: "Provider used when telemetry omits gen_ai.system"),
            ],
            flags: [
                FlagDefinition(
                    label: "once",
                    names: [.long("once")],
                    help: "Ingest one payload and exit instead of starting the HTTP collector"),
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

        let otelCollectDescriptor = CommandDescriptor(
            name: "otel-collect",
            abstract: "Collect OTLP/HTTP JSON GenAI usage into Runic's sanitized local ledger",
            discussion: nil,
            signature: otelCollectSignature)

        let program = Program(descriptors: [usageDescriptor, costDescriptor, insightsDescriptor, otelCollectDescriptor])

        do {
            let invocation = try program.resolve(argv: argv)
            switch invocation.descriptor.name {
            case "usage":
                await self.runUsage(invocation)
            case "cost":
                await self.runCost(invocation)
            case "insights":
                await self.runInsights(invocation)
            case "otel-collect":
                await self.runOTelCollect(invocation)
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
            providers = Self.resolveProviderList(
                providerName,
                defaultProviders: ProviderDescriptorRegistry.all.map(\.id))
        } else {
            providers = ProviderDescriptorRegistry.all.map(\.id)
        }

        let fetcher = UsageFetcher()
        var output = ""

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

        if isPretty, isJson {
            if let data = output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let prettyData = try? JSONSerialization.data(
                   withJSONObject: json,
                   options: [.prettyPrinted, .sortedKeys]),
               let pretty = String(data: prettyData, encoding: .utf8)
            {
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
        let refreshRequested = invocation.parsedValues.flags.contains("refresh")
        let rebuild = invocation.parsedValues.flags.contains("rebuild")
        let mode: CostUsageLoadMode = rebuild ? .rebuildHistory : .refresh
        if refreshRequested, !rebuild {
            Self.printError(
                "runic cost: --refresh is accepted for compatibility; cost refreshes today's logs by default.")
        }

        let providers: [UsageProvider]
        if let providerName = providerArg?.lowercased() {
            providers = Self.resolveProviderList(providerName, defaultProviders: [.claude, .codex])
            if let unsupported = providers.first(where: { $0 != .claude && $0 != .codex }) {
                Self.exit(code: 1, message: "Cost is only supported for claude and codex, not \(unsupported.rawValue)")
            }
        } else {
            providers = [.claude, .codex]
        }

        let fetcher = CostUsageFetcher()
        var output = ""

        for provider in providers {
            do {
                let snapshot = try await fetcher.loadTokenSnapshot(provider: provider, mode: mode)
                let text = Self.renderCostText(provider: provider, snapshot: snapshot, useColor: useColor)
                if !output.isEmpty { output += "\n" }
                output += text
            } catch {
                let errorMsg = "Error fetching cost for \(provider.rawValue): \(error.localizedDescription)"
                if !output.isEmpty { output += "\n" }
                output += errorMsg
            }
        }

        if isPretty, isJson {
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
        let granularityArg = invocation.parsedValues.options["granularity"]?.first?.lowercased()
        let gitDirectoryArg = invocation.parsedValues.options["gitDirectory"]?.first
        let isJson = invocation.parsedValues.flags.contains("json")
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let includeBudget = invocation.parsedValues.flags.contains("budget")
        let withCommits = invocation.parsedValues.flags.contains("withCommits")

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

        // Link commits if requested
        if withCommits {
            let gitDirectory = gitDirectoryArg.map { URL(fileURLWithPath: $0) }
            let entriesWithCommits = GitHubIntegration.linkCommitsToUsage(entries: entries, gitDirectory: gitDirectory)
            RunicCLIInsightsRenderer.renderWithCommits(entriesWithCommits, isJson: isJson, isPretty: isPretty)
            return
        }

        switch viewArg {
        case "daily":
            if let granularity = granularityArg, granularity == "hourly" {
                let summaries = UsageLedgerAggregator.hourlySummaries(entries: entries, timeZone: timeZone)
                RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
            } else {
                let summaries = UsageLedgerAggregator.dailySummaries(entries: entries, timeZone: timeZone)
                RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
            }
        case "session":
            let summaries = UsageLedgerAggregator.sessionSummaries(entries: entries)
            RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "blocks":
            let summaries = UsageLedgerAggregator.blockSummaries(entries: entries, blockHours: 5, now: now)
            RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "models":
            let summaries = UsageLedgerAggregator.modelSummaries(entries: entries, groupByProject: true)
            RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "projects":
            let summaries = UsageLedgerAggregator.projectSummaries(entries: entries)
            if includeBudget {
                let budgetData = Self.enrichProjectsWithBudget(summaries)
                RunicCLIInsightsRenderer.renderOutput(budgetData, isJson: isJson, isPretty: isPretty)
            } else {
                RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
            }
        case "compaction":
            let summaries = UsageLedgerAggregator.compactionSummaries(entries: entries)
            RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "comparative":
            let comparisons = Self.modelCostComparison(entries: entries)
            RunicCLIInsightsRenderer.renderOutput(comparisons, isJson: isJson, isPretty: isPretty)
        case "efficiency":
            let efficiencies = Self.modelEfficiencyMetrics(entries: entries)
            RunicCLIInsightsRenderer.renderOutput(efficiencies, isJson: isJson, isPretty: isPretty)
        default:
            Self.exit(code: 1, message: "Unknown insights view: \(viewArg)")
        }
    }

    private static func runOTelCollect(_ invocation: CommandInvocation) async {
        let port = invocation.parsedValues.options["port"]?.first.flatMap(UInt16.init) ?? 4318
        let host = invocation.parsedValues.options["host"]?.first ?? "127.0.0.1"
        let output = invocation.parsedValues.options["output"]?.first
            .flatMap(Self.expandedFileURL)
            ?? OTelGenAICollectorConfiguration.defaultOutputFile()
        let defaultProvider = invocation.parsedValues.options["defaultProvider"]?.first
            .map(Self.resolveProvider)
        let configuration = OTelGenAICollectorConfiguration(
            host: host,
            port: port,
            outputFile: output,
            defaultProvider: defaultProvider)

        if invocation.parsedValues.flags.contains("once") {
            let input = invocation.parsedValues.options["input"]?.first
            do {
                let data: Data
                if let input, input != "-" {
                    data = try Data(contentsOf: Self.expandedFileURL(input))
                } else {
                    data = FileHandle.standardInput.readDataToEndOfFile()
                }
                let sink = OTelGenAIIngestionSink(configuration: configuration)
                let result = try await sink.ingest(data)
                print("Accepted \(result.acceptedEntries) GenAI usage entr\(result.acceptedEntries == 1 ? "y" : "ies")")
                print("Wrote sanitized ledger: \(result.outputFile.path)")
                return
            } catch {
                Self.exit(code: 1, message: error.localizedDescription)
            }
        }

        #if canImport(Network)
        do {
            let collector = try OTelGenAIHTTPCollector(configuration: configuration)
            collector.start()
            print("Runic OTLP JSON collector listening on http://\(host):\(port)/v1/traces")
            print("Writing sanitized metric JSONL to \(output.path)")
            print("Press Ctrl-C to stop.")
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
            }
            collector.cancel()
        } catch {
            Self.exit(code: 1, message: error.localizedDescription)
        }
        #else
        Self.exit(code: 1, message: "OTLP HTTP collection requires Network.framework on macOS.")
        #endif
    }

    private static func resolveInsightsProviders(_ raw: String?) -> [UsageProvider] {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "claude"
        return Self.resolveProviderList(trimmed, defaultProviders: ProviderDescriptorRegistry.all.map(\.id))
    }

    private static func insightsSources(
        for providers: [UsageProvider],
        now: Date) -> [(UsageProvider, any UsageLedgerSource)]
    {
        var sources: [(UsageProvider, any UsageLedgerSource)] = []
        for provider in providers {
            if let source = UsageLedgerSourceFactory.source(for: provider, now: now, maxAgeDays: nil) {
                sources.append((provider, source))
            }
        }
        return sources
    }

    private static func resolveProviderList(
        _ raw: String,
        defaultProviders: [UsageProvider]) -> [UsageProvider]
    {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered == "all" {
            return defaultProviders
        }
        if lowered == "both" {
            return [.codex, .claude]
        }

        let providers = lowered.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(Self.resolveProvider)

        guard !providers.isEmpty else {
            Self.exit(code: 1, message: "No provider specified")
        }
        return providers
    }

    private static func resolveProvider(_ raw: String) -> UsageProvider {
        switch raw {
        case "local", "localllm", "local_llm":
            return .localLLM
        case "vercel-ai", "vercel_ai":
            return .vercelai
        case "vertex-ai", "vertex_ai":
            return .vertexai
        case "z-ai", "z_ai":
            return .zai
        default:
            guard let provider = UsageProvider(rawValue: raw) else {
                Self.exit(code: 1, message: "Unknown provider: \(raw)")
            }
            return provider
        }
    }

    private static func expandedFileURL(_ rawPath: String) -> URL {
        if rawPath.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(rawPath.dropFirst(2)))
        }
        return URL(fileURLWithPath: rawPath)
    }

    private static func printError(_ message: String) {
        if let data = (message + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
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
            print(
                "  Providers: codex, claude, cursor, gemini, factory, copilot, zai, antigravity, minimax, " +
                    "openrouter, vercelai, groq, deepseek, fireworks, mistral, perplexity, kimi, auggie, together, " +
                    "cohere, xai, cerebras, sambanova, azure, bedrock, vertexai, qwen, local-llm")
        }
        if command == "cost" || command == nil {
            print("cost - Print local cost usage as text or JSON")
            print("  Options:")
            print("    --provider PROVIDER    Provider to show cost for (claude, codex)")
            print("    --format FORMAT        Output format: text | json")
            print("    --json                 Output JSON format")
            print("    --pretty               Pretty-print output")
            print("    --no-color             Disable ANSI colors")
            print("    --refresh              Compatibility flag; cost refreshes today's logs by default")
            print("    --rebuild              Repair the 30-day relay by scanning provider JSONL history")
        }
        if command == "insights" || command == nil {
            print("insights - Analyze local usage logs")
            print("  Options:")
            print("    --provider PROVIDER      Provider to analyze (provider, comma-list, both, all)")
            print("    --view VIEW              daily | session | blocks | models | projects")
            print("                             compaction | comparative | efficiency")
            print("    --project PROJECT        Filter to a specific project")
            print("    --timezone TZ            Timezone identifier (defaults to local)")
            print("    --granularity GRAN       Time granularity: hourly (for daily view)")
            print("    --git-directory PATH     Path to .git directory (defaults to current directory)")
            print("    --json                   Output JSON format")
            print("    --pretty                 Pretty-print output")
            print("    --no-color               Disable ANSI colors")
            print("    --budget                 Include budget tracking (for projects view)")
            print("    --with-commits           Link usage entries to git commits (5 minute window)")
            print("")
            print("  Views:")
            print("    daily                    Daily usage summaries")
            print("    session                  Per-session usage summaries")
            print("    blocks                   Activity block summaries")
            print("    models                   Per-model usage summaries")
            print("    projects                 Per-project usage summaries")
            print("    comparative              Model cost-per-token comparison with rankings")
            print("    efficiency               Efficiency metrics (tokens/request, cost/request, cache hit rate)")
        }
        if command == "otel-collect" || command == nil {
            print("otel-collect - Collect OTLP/HTTP JSON GenAI usage")
            print("  Options:")
            print("    --port PORT              Local collector port (default: 4318)")
            print("    --host HOST              Local bind host (default: 127.0.0.1)")
            print("    --output PATH            Sanitized JSONL output path")
            print("    --input PATH             One-shot input file; use - for stdin")
            print("    --default-provider NAME  Provider when telemetry omits gen_ai.system")
            print("    --once                   Ingest one payload and exit")
            print("")
            print("  Notes:")
            print("    Stores token/model/project metadata only; prompt and response content is not written.")
            print("    HTTP mode accepts OTLP JSON at /v1/traces and /v1/logs.")
            print("    Local event streams are available at /events and /v1/events with SSE or NDJSON Accept headers.")
        }
        if command != nil,
           command != "usage",
           command != "cost",
           command != "insights",
           command != "otel-collect"
        {
            print("Unknown command: \(command ?? "")")
        }
        Foundation.exit(0)
    }

    private static func printVersion() {
        print("Runic CLI - Version 1.0.0")
        Foundation.exit(0)
    }

    private static func exit(code: Int32, message: String? = nil) -> Never {
        if let message {
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
    var provider: String?
    var format: String = "text"
}

struct CostCommand {
    var verbose: Bool = false
    var json: Bool = false
    var pretty: Bool = false
    var noColor: Bool = false
    var provider: String?
    var format: String = "text"
    var refresh: Bool = false
}

struct InsightsCommand {
    var json: Bool = false
    var pretty: Bool = false
    var noColor: Bool = false
    var provider: String?
    var view: String = "daily"
    var project: String?
    var timezone: String?
    var granularity: String?
    var gitDirectory: String?
    var budget: Bool = false
    var withCommits: Bool = false
}
