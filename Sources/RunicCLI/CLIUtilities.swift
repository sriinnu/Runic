import Foundation
import RunicCore

extension RunicCLI {
    static func effectiveArgv(_ argv: [String]) -> [String] {
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

    static func resolveProviderList(
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

    static func resolveProvider(_ raw: String) -> UsageProvider {
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

    static func expandedFileURL(_ rawPath: String) -> URL {
        if rawPath.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(rawPath.dropFirst(2)))
        }
        return URL(fileURLWithPath: rawPath)
    }

    static func printError(_ message: String) {
        if let data = (message + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    static func printHelp(for command: String?) {
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

    static func printVersion() {
        print("Runic CLI - Version 1.0.0")
        Foundation.exit(0)
    }

    static func exit(code: Int32, message: String? = nil) -> Never {
        if let message {
            FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
        }
        Foundation.exit(code)
    }
}
