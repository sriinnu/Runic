import AppIntents
import RunicCore
import SwiftUI
import WidgetKit

// Structural lint debt: timeline provider branching should be split by data source.
enum ProviderChoice: String, AppEnum {
    case codex
    case claude
    case gemini
    case antigravity
    case cursor
    case zai
    case factory
    case copilot
    case minimax
    case openrouter
    case vercelai
    case groq
    case deepseek
    case fireworks
    case mistral
    case perplexity
    case kimi
    case auggie
    case together
    case cohere
    case xai
    case cerebras
    case sambanova
    case azure
    case bedrock
    case vertexai
    case qwen
    case localLLM

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Provider")

    static let caseDisplayRepresentations: [ProviderChoice: DisplayRepresentation] = [
        .codex: DisplayRepresentation(title: "Codex"),
        .claude: DisplayRepresentation(title: "Claude"),
        .gemini: DisplayRepresentation(title: "Gemini"),
        .antigravity: DisplayRepresentation(title: "Antigravity"),
        .cursor: DisplayRepresentation(title: "Cursor"),
        .zai: DisplayRepresentation(title: "z.ai"),
        .factory: DisplayRepresentation(title: "Droid"),
        .copilot: DisplayRepresentation(title: "Copilot"),
        .minimax: DisplayRepresentation(title: "MiniMax"),
        .openrouter: DisplayRepresentation(title: "OpenRouter"),
        .vercelai: DisplayRepresentation(title: "Vercel AI"),
        .groq: DisplayRepresentation(title: "Groq"),
        .deepseek: DisplayRepresentation(title: "DeepSeek"),
        .fireworks: DisplayRepresentation(title: "Fireworks"),
        .mistral: DisplayRepresentation(title: "Mistral"),
        .perplexity: DisplayRepresentation(title: "Perplexity"),
        .kimi: DisplayRepresentation(title: "Kimi"),
        .auggie: DisplayRepresentation(title: "Auggie"),
        .together: DisplayRepresentation(title: "Together"),
        .cohere: DisplayRepresentation(title: "Cohere"),
        .xai: DisplayRepresentation(title: "xAI"),
        .cerebras: DisplayRepresentation(title: "Cerebras"),
        .sambanova: DisplayRepresentation(title: "SambaNova"),
        .azure: DisplayRepresentation(title: "Azure OpenAI"),
        .bedrock: DisplayRepresentation(title: "Amazon Bedrock"),
        .vertexai: DisplayRepresentation(title: "Vertex AI"),
        .qwen: DisplayRepresentation(title: "Qwen"),
        .localLLM: DisplayRepresentation(title: "Local LLM"),
    ]

    var provider: UsageProvider {
        switch self {
        case .codex: .codex
        case .claude: .claude
        case .gemini: .gemini
        case .antigravity: .antigravity
        case .cursor: .cursor
        case .zai: .zai
        case .factory: .factory
        case .copilot: .copilot
        case .minimax: .minimax
        case .openrouter: .openrouter
        case .vercelai: .vercelai
        case .groq: .groq
        case .deepseek: .deepseek
        case .fireworks: .fireworks
        case .mistral: .mistral
        case .perplexity: .perplexity
        case .kimi: .kimi
        case .auggie: .auggie
        case .together: .together
        case .cohere: .cohere
        case .xai: .xai
        case .cerebras: .cerebras
        case .sambanova: .sambanova
        case .azure: .azure
        case .bedrock: .bedrock
        case .vertexai: .vertexai
        case .qwen: .qwen
        case .localLLM: .localLLM
        }
    }

    init?(provider: UsageProvider) { // swiftlint:disable:this cyclomatic_complexity
        switch provider {
        case .codex: self = .codex
        case .claude: self = .claude
        case .gemini: self = .gemini
        case .antigravity: self = .antigravity
        case .cursor: self = .cursor
        case .zai: self = .zai
        case .factory: self = .factory
        case .copilot: self = .copilot
        case .minimax: self = .minimax
        case .openrouter: self = .openrouter
        case .vercelai: self = .vercelai
        case .groq: self = .groq
        case .deepseek: self = .deepseek
        case .fireworks: self = .fireworks
        case .mistral: self = .mistral
        case .perplexity: self = .perplexity
        case .kimi: self = .kimi
        case .auggie: self = .auggie
        case .together: self = .together
        case .cohere: self = .cohere
        case .xai: self = .xai
        case .cerebras: self = .cerebras
        case .sambanova: self = .sambanova
        case .azure: self = .azure
        case .bedrock: self = .bedrock
        case .vertexai: self = .vertexai
        case .qwen: self = .qwen
        case .localLLM: self = .localLLM
        }
    }
}

enum CompactMetric: String, AppEnum {
    case credits
    case todayCost
    case last30DaysCost

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Metric")

    static let caseDisplayRepresentations: [CompactMetric: DisplayRepresentation] = [
        .credits: DisplayRepresentation(title: "Credits left"),
        .todayCost: DisplayRepresentation(title: "Today cost"),
        .last30DaysCost: DisplayRepresentation(title: "30d cost"),
    ]
}

struct ProviderSelectionIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Provider"
    static let description = IntentDescription("Select the provider to display in the widget.")

    @Parameter(title: "Provider")
    var provider: ProviderChoice

    init() {
        self.provider = .codex
    }
}

struct SwitchWidgetProviderIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Provider"
    static let description = IntentDescription("Switch the provider shown in the widget.")

    @Parameter(title: "Provider")
    var provider: ProviderChoice

    init() {}

    init(provider: ProviderChoice) {
        self.provider = provider
    }

    func perform() async throws -> some IntentResult {
        WidgetSelectionStore.saveSelectedProvider(self.provider.provider)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct CompactMetricSelectionIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Provider + Metric"
    static let description = IntentDescription("Select the provider and metric to display.")

    @Parameter(title: "Provider")
    var provider: ProviderChoice

    @Parameter(title: "Metric")
    var metric: CompactMetric

    init() {
        self.provider = .codex
        self.metric = .credits
    }
}

struct RunicWidgetEntry: TimelineEntry {
    let date: Date
    let provider: UsageProvider
    let snapshot: WidgetSnapshot
}

struct RunicCompactEntry: TimelineEntry {
    let date: Date
    let provider: UsageProvider
    let metric: CompactMetric
    let snapshot: WidgetSnapshot
}

struct RunicSwitcherEntry: TimelineEntry {
    let date: Date
    let provider: UsageProvider
    let availableProviders: [UsageProvider]
    let snapshot: WidgetSnapshot
}

struct RunicTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RunicWidgetEntry {
        RunicWidgetEntry(
            date: Date(),
            provider: .codex,
            snapshot: WidgetPreviewData.snapshot())
    }

    func snapshot(for configuration: ProviderSelectionIntent, in context: Context) async -> RunicWidgetEntry {
        let provider = configuration.provider.provider
        return RunicWidgetEntry(
            date: Date(),
            provider: provider,
            snapshot: WidgetSnapshotStore.load() ?? WidgetPreviewData.snapshot())
    }

    func timeline(
        for configuration: ProviderSelectionIntent,
        in context: Context) async -> Timeline<RunicWidgetEntry>
    {
        let provider = configuration.provider.provider
        let snapshot = WidgetSnapshotStore.load() ?? WidgetPreviewData.snapshot()
        let entry = RunicWidgetEntry(date: Date(), provider: provider, snapshot: snapshot)
        let refresh = Date().addingTimeInterval(30 * 60)
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

struct RunicSwitcherTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RunicSwitcherEntry {
        let snapshot = WidgetPreviewData.snapshot()
        let providers = self.availableProviders(from: snapshot)
        return RunicSwitcherEntry(
            date: Date(),
            provider: providers.first ?? .codex,
            availableProviders: providers,
            snapshot: snapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (RunicSwitcherEntry) -> Void) {
        completion(self.makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RunicSwitcherEntry>) -> Void) {
        let entry = self.makeEntry()
        let refresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> RunicSwitcherEntry {
        let snapshot = WidgetSnapshotStore.load() ?? WidgetPreviewData.snapshot()
        let providers = self.availableProviders(from: snapshot)
        let stored = WidgetSelectionStore.loadSelectedProvider()
        let selected = providers.first { $0 == stored } ?? providers.first ?? .codex
        if selected != stored {
            WidgetSelectionStore.saveSelectedProvider(selected)
        }
        return RunicSwitcherEntry(
            date: Date(),
            provider: selected,
            availableProviders: providers,
            snapshot: snapshot)
    }

    private func availableProviders(from snapshot: WidgetSnapshot) -> [UsageProvider] {
        let enabled = snapshot.enabledProviders
        let providers = enabled.isEmpty ? snapshot.entries.map(\.provider) : enabled
        return providers.isEmpty ? [.codex] : providers
    }
}

struct RunicCompactTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RunicCompactEntry {
        RunicCompactEntry(
            date: Date(),
            provider: .codex,
            metric: .credits,
            snapshot: WidgetPreviewData.snapshot())
    }

    func snapshot(for configuration: CompactMetricSelectionIntent, in context: Context) async -> RunicCompactEntry {
        let provider = configuration.provider.provider
        return RunicCompactEntry(
            date: Date(),
            provider: provider,
            metric: configuration.metric,
            snapshot: WidgetSnapshotStore.load() ?? WidgetPreviewData.snapshot())
    }

    func timeline(
        for configuration: CompactMetricSelectionIntent,
        in context: Context) async -> Timeline<RunicCompactEntry>
    {
        let provider = configuration.provider.provider
        let snapshot = WidgetSnapshotStore.load() ?? WidgetPreviewData.snapshot()
        let entry = RunicCompactEntry(
            date: Date(),
            provider: provider,
            metric: configuration.metric,
            snapshot: snapshot)
        let refresh = Date().addingTimeInterval(30 * 60)
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

enum WidgetPreviewData {
    static func snapshot() -> WidgetSnapshot {
        let primary = RateWindow(usedPercent: 35, windowMinutes: nil, resetsAt: nil, resetDescription: "Resets in 4h")
        let secondary = RateWindow(usedPercent: 60, windowMinutes: nil, resetsAt: nil, resetDescription: "Resets in 3d")
        let entry = WidgetSnapshot.ProviderEntry(
            provider: .codex,
            updatedAt: Date(),
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            creditsRemaining: 1243.4,
            codeReviewRemainingPercent: 78,
            tokenUsage: WidgetSnapshot.TokenUsageSummary(
                sessionCostUSD: 12.4,
                sessionTokens: 420_000,
                last30DaysCostUSD: 923.8,
                last30DaysTokens: 12_400_000),
            dailyUsage: [
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-01", totalTokens: 120_000, costUSD: 15.2),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-02", totalTokens: 80000, costUSD: 10.1),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-03", totalTokens: 140_000, costUSD: 17.9),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-04", totalTokens: 90000, costUSD: 11.4),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-05", totalTokens: 160_000, costUSD: 19.8),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-06", totalTokens: 70000, costUSD: 8.9),
                WidgetSnapshot.DailyUsagePoint(dayKey: "2025-12-07", totalTokens: 110_000, costUSD: 13.7),
            ])
        return WidgetSnapshot(entries: [entry], generatedAt: Date())
    }
}
