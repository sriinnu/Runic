import Helix

extension RunicCLI {
    static var program: Program {
        Program(descriptors: [
            usageDescriptor,
            costDescriptor,
            insightsDescriptor,
            otelCollectDescriptor,
        ])
    }

    private static var usageDescriptor: CommandDescriptor {
        CommandDescriptor(
            name: "usage",
            abstract: "Print usage as text or JSON",
            discussion: nil,
            signature: usageSignature)
    }

    private static var costDescriptor: CommandDescriptor {
        CommandDescriptor(
            name: "cost",
            abstract: "Print local cost usage as text or JSON",
            discussion: nil,
            signature: costSignature)
    }

    private static var insightsDescriptor: CommandDescriptor {
        CommandDescriptor(
            name: "insights",
            abstract: "Analyze local usage logs (daily/session/blocks)",
            discussion: nil,
            signature: insightsSignature)
    }

    private static var otelCollectDescriptor: CommandDescriptor {
        CommandDescriptor(
            name: "otel-collect",
            abstract: "Collect OTLP/HTTP JSON GenAI usage into Runic's sanitized local ledger",
            discussion: nil,
            signature: otelCollectSignature)
    }

    private static var usageSignature: CommandSignature {
        CommandSignature(
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
    }

    private static var costSignature: CommandSignature {
        CommandSignature(
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
    }

    private static var insightsSignature: CommandSignature {
        CommandSignature(
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
    }

    private static var otelCollectSignature: CommandSignature {
        CommandSignature(
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
    }
}
