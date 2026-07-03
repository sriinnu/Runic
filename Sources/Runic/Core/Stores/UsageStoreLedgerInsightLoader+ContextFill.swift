import Foundation
import RunicCore

// MARK: - Live context-window fill

extension UsageStoreLedgerInsightLoader {
    /// Computes the REAL live context-window fill for providers whose local
    /// transcripts expose per-request context state (Claude JSONLs, Codex
    /// rollouts). Runs on the ledger refresh path — off the main thread,
    /// never synchronously on menu open. Providers without transcript-backed
    /// samples keep the disclaimed block-volume heuristic on their cards.
    func refreshLiveContextFill(
        providers: [UsageProvider],
        now: Date,
        registry: ProviderContextWindowRegistry = .shared,
        store: ProviderContextFillStore = .shared)
    {
        let maxSampleAge = ProviderContextFillStore.maxSampleAge
        for provider in providers {
            let sample: ProviderContextFillSample?
            switch provider {
            case .claude:
                sample = ClaudeContextFillSource(maxSampleAge: maxSampleAge).latestSample(now: now)
            case .codex:
                sample = CodexContextFillSource(maxSampleAge: maxSampleAge).latestSample(now: now)
            default:
                continue
            }
            store.update(
                Self.resolvedContextFill(sample: sample, provider: provider, registry: registry),
                for: provider)
        }
    }

    /// Denominator resolution: the transcript's own report wins (Codex
    /// rollouts carry `model_context_window`), otherwise the registry chain
    /// (Kosha manifest → model heuristic → static fallback).
    static func resolvedContextFill(
        sample: ProviderContextFillSample?,
        provider: UsageProvider,
        registry: ProviderContextWindowRegistry) -> ResolvedContextFill?
    {
        guard let sample else { return nil }
        let maxTokens = sample.transcriptContextWindow
            ?? registry.contextLabel(for: provider, model: sample.model)?.maxTokens
        return ResolvedContextFill(
            occupiedTokens: sample.occupiedTokens,
            maxTokens: maxTokens,
            model: sample.model,
            sampledAt: sample.timestamp)
    }
}
