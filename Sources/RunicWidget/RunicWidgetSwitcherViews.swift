import RunicCore
import SwiftUI

struct ProviderSwitcherRow: View {
    let providers: [UsageProvider]
    let selected: UsageProvider
    let updatedAt: Date
    let compact: Bool
    let showsTimestamp: Bool

    var body: some View {
        HStack(spacing: self.compact ? 4 : 6) {
            ForEach(self.providers, id: \.self) { provider in
                ProviderSwitchChip(
                    provider: provider,
                    selected: provider == self.selected,
                    compact: self.compact)
            }
            if self.showsTimestamp {
                Spacer(minLength: 6)
                Text(WidgetFormat.relativeDate(self.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProviderSwitchChip: View {
    let provider: UsageProvider
    let selected: Bool
    let compact: Bool

    var body: some View {
        let label = self.compact ? self.shortLabel : self.longLabel
        let background = self.selected
            ? WidgetColors.color(for: self.provider).opacity(0.2)
            : Color.primary.opacity(0.08)

        if let choice = ProviderChoice(provider: self.provider) {
            Button(intent: SwitchWidgetProviderIntent(provider: choice)) {
                Text(label)
                    .font(self.compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(self.selected ? Color.primary : Color.secondary)
                    .padding(.horizontal, self.compact ? 6 : 8)
                    .padding(.vertical, self.compact ? 3 : 4)
                    .background(Capsule().fill(background))
            }
            .buttonStyle(.plain)
        } else {
            Text(label)
                .font(self.compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(self.selected ? Color.primary : Color.secondary)
                .padding(.horizontal, self.compact ? 6 : 8)
                .padding(.vertical, self.compact ? 3 : 4)
                .background(Capsule().fill(background))
        }
    }

    private var longLabel: String {
        ProviderDefaults.metadata[self.provider]?.displayName ?? self.provider.rawValue.capitalized
    }

    private var shortLabel: String {
        switch self.provider {
        case .codex: "Codex"
        case .claude: "Claude"
        case .gemini: "Gemini"
        case .antigravity: "Anti"
        case .cursor: "Cursor"
        case .zai: "z.ai"
        case .factory: "Droid"
        case .copilot: "Copilot"
        case .minimax: "MiniMax"
        case .openrouter: "OR"
        case .vercelai: "Vercel"
        case .groq: "Groq"
        case .deepseek: "DeepSeek"
        case .fireworks: "Fireworks"
        case .mistral: "Mistral"
        case .perplexity: "PPLX"
        case .kimi: "Kimi"
        case .auggie: "Auggie"
        case .together: "Together"
        case .cohere: "Cohere"
        case .xai: "xAI"
        case .cerebras: "Cerebras"
        case .sambanova: "SambaNova"
        case .azure: "Azure"
        case .bedrock: "Bedrock"
        case .vertexai: "Vertex"
        case .qwen: "Qwen"
        case .localLLM: "Local"
        }
    }
}

struct SwitcherSmallUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            UsageBarRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.sessionLabel ?? "Session",
                percentLeft: self.entry.primary?.remainingPercent,
                color: WidgetColors.color(for: self.entry.provider))
            UsageBarRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.weeklyLabel ?? "Weekly",
                percentLeft: self.entry.secondary?.remainingPercent,
                color: WidgetColors.color(for: self.entry.provider))
            if let codeReview = entry.codeReviewRemainingPercent {
                UsageBarRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    color: WidgetColors.color(for: self.entry.provider))
            }
        }
    }
}

struct SwitcherMediumUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            UsageBarRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.sessionLabel ?? "Session",
                percentLeft: self.entry.primary?.remainingPercent,
                color: WidgetColors.color(for: self.entry.provider))
            UsageBarRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.weeklyLabel ?? "Weekly",
                percentLeft: self.entry.secondary?.remainingPercent,
                color: WidgetColors.color(for: self.entry.provider))
            if let credits = entry.creditsRemaining {
                ValueLine(title: "Credits", value: WidgetFormat.credits(credits))
            }
            if let token = entry.tokenUsage {
                ValueLine(
                    title: "Today",
                    value: WidgetFormat.costAndTokens(cost: token.sessionCostUSD, tokens: token.sessionTokens))
            }
        }
    }
}

struct SwitcherLargeUsageView: View {
    let entry: WidgetSnapshot.ProviderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UsageBarRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.sessionLabel ?? "Session",
                percentLeft: self.entry.primary?.remainingPercent,
                color: WidgetColors.color(for: self.entry.provider))
            UsageBarRow(
                title: ProviderDefaults.metadata[self.entry.provider]?.weeklyLabel ?? "Weekly",
                percentLeft: self.entry.secondary?.remainingPercent,
                color: WidgetColors.color(for: self.entry.provider))
            if let codeReview = entry.codeReviewRemainingPercent {
                UsageBarRow(
                    title: "Code review",
                    percentLeft: codeReview,
                    color: WidgetColors.color(for: self.entry.provider))
            }
            if let credits = entry.creditsRemaining {
                ValueLine(title: "Credits", value: WidgetFormat.credits(credits))
            }
            if let token = entry.tokenUsage {
                VStack(alignment: .leading, spacing: 4) {
                    ValueLine(
                        title: "Today",
                        value: WidgetFormat.costAndTokens(cost: token.sessionCostUSD, tokens: token.sessionTokens))
                    ValueLine(
                        title: "30d",
                        value: WidgetFormat.costAndTokens(
                            cost: token.last30DaysCostUSD,
                            tokens: token.last30DaysTokens))
                }
            }
            UsageHistoryChart(points: self.entry.dailyUsage, color: WidgetColors.color(for: self.entry.provider))
                .frame(height: 50)
        }
    }
}
