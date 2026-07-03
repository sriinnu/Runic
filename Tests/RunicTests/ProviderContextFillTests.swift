import Foundation
import RunicCore
import Testing
@testable import Runic

// MARK: - Denominator resolution

struct ProviderContextFillResolutionTests {
    @Test
    func `transcript reported window beats registry`() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let registry = try Self.registry(
            manifest: Self.manifest(
                timestamp: now,
                providers: [Self.providerJSON(id: "openai", timestamp: now)],
                models: [Self.modelJSON(id: "gpt-5.5", provider: "openai", contextWindow: 1_000_000, timestamp: now)]),
            fallback: #"{"codex":{"contextK":400}}"#,
            now: now)
        let sample = ProviderContextFillSample(
            occupiedTokens: 25859,
            model: "gpt-5.5",
            transcriptContextWindow: 258_400,
            timestamp: now,
            sessionID: nil)

        let resolved = UsageStoreLedgerInsightLoader.resolvedContextFill(
            sample: sample,
            provider: .codex,
            registry: registry)

        #expect(resolved?.maxTokens == 258_400)
        #expect(resolved?.occupiedTokens == 25859)
        #expect(resolved?.sampledAt == now)
    }

    @Test
    func `registry model lookup resolves denominator when transcript is silent`() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let registry = try Self.registry(
            manifest: Self.manifest(
                timestamp: now,
                providers: [Self.providerJSON(id: "anthropic", timestamp: now)],
                models: [Self.modelJSON(
                    id: "claude-opus-4-6",
                    provider: "anthropic",
                    contextWindow: 200_000,
                    timestamp: now)]),
            fallback: "{}",
            now: now)
        let sample = ProviderContextFillSample(
            occupiedTokens: 94200,
            model: "claude-opus-4-6",
            transcriptContextWindow: nil,
            timestamp: now,
            sessionID: nil)

        let resolved = UsageStoreLedgerInsightLoader.resolvedContextFill(
            sample: sample,
            provider: .claude,
            registry: registry)

        #expect(resolved?.maxTokens == 200_000)
    }

    @Test
    func `static fallback resolves denominator when model is unknown`() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let registry = try Self.registry(
            manifest: nil,
            fallback: #"{"claude":{"contextK":200}}"#,
            now: now)
        let sample = ProviderContextFillSample(
            occupiedTokens: 94200,
            model: nil,
            transcriptContextWindow: nil,
            timestamp: now,
            sessionID: nil)

        let resolved = UsageStoreLedgerInsightLoader.resolvedContextFill(
            sample: sample,
            provider: .claude,
            registry: registry)

        #expect(resolved?.maxTokens == 200_000)
    }

    @Test
    func `missing sample resolves to nil and unresolvable window keeps occupancy`() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let registry = try Self.registry(manifest: nil, fallback: "{}", now: now)

        let missing = UsageStoreLedgerInsightLoader.resolvedContextFill(
            sample: nil,
            provider: .claude,
            registry: registry)
        #expect(missing == nil)

        let sample = ProviderContextFillSample(
            occupiedTokens: 94200,
            model: "some-unknown-model-name",
            transcriptContextWindow: nil,
            timestamp: now,
            sessionID: nil)
        let unresolved = UsageStoreLedgerInsightLoader.resolvedContextFill(
            sample: sample,
            provider: .claude,
            registry: registry)
        #expect(unresolved?.occupiedTokens == 94200)
    }

    @Test
    func `store roundtrips and clears fills per provider`() {
        let store = ProviderContextFillStore()
        let fill = ResolvedContextFill(
            occupiedTokens: 124_000,
            maxTokens: 200_000,
            model: "claude-opus-4-6",
            sampledAt: Date())

        store.update(fill, for: .claude)
        #expect(store.fill(for: .claude) == fill)
        #expect(store.fill(for: .codex) == nil)

        store.update(nil, for: .claude)
        #expect(store.fill(for: .claude) == nil)
    }

    // MARK: - Registry fixtures

    private static func registry(
        manifest: String?,
        fallback: String,
        now: Date) throws -> ProviderContextWindowRegistry
    {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-context-fill-registry-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let manifestURL = root.appendingPathComponent("registry.json")
        if let manifest {
            try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
        }
        let fallbackURL = root.appendingPathComponent("provider-context-windows.json")
        try fallback.write(to: fallbackURL, atomically: true, encoding: .utf8)

        return ProviderContextWindowRegistry(
            manifestURL: manifestURL,
            fallbackURL: fallbackURL,
            ttl: 24 * 60 * 60,
            reloadInterval: 0,
            nowProvider: { now })
    }

    private static func manifest(timestamp: Date, providers: [String], models: [String]) -> String {
        """
        {
          "schemaVersion": 1,
          "discoveredAt": \(Int(timestamp.timeIntervalSince1970 * 1000)),
          "providers": [\(providers.joined(separator: ","))],
          "models": [\(models.joined(separator: ","))]
        }
        """
    }

    private static func providerJSON(id: String, timestamp: Date) -> String {
        """
        {"providerId":"\(id)","canonicalProviderId":"\(id)","aliases":[],\
        "lastRefreshed":\(Int(timestamp.timeIntervalSince1970 * 1000))}
        """
    }

    private static func modelJSON(id: String, provider: String, contextWindow: Int, timestamp: Date) -> String {
        """
        {"key":"\(provider):\(id)","modelId":"\(id)","name":"\(id)","providerId":"\(provider)",\
        "canonicalProviderId":"\(provider)","mode":"chat","aliases":[],"contextWindow":\(contextWindow),\
        "discoveredAt":\(Int(timestamp.timeIntervalSince1970 * 1000))}
        """
    }
}

// MARK: - Staleness cutoff and formatting

struct ProviderContextFillLineTests {
    @Test
    func `fresh fill renders percent and occupancy over window`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fill = ResolvedContextFill(
            occupiedTokens: 124_000,
            maxTokens: 200_000,
            model: "claude-opus-4-6",
            sampledAt: now.addingTimeInterval(-120))

        let lines = UsageMenuCardView.Model.liveContextFillLines(fill: fill, now: now)

        #expect(lines?.line == "Context: 62% · 124K/200K")
        #expect(lines?.detail.contains("Live session context from local transcript") == true)
        #expect(lines?.detail.contains("Sampled 2m ago") == true)
    }

    @Test
    func `stale fill is suppressed after the idle cutoff`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let atCutoff = ResolvedContextFill(
            occupiedTokens: 124_000,
            maxTokens: 200_000,
            model: nil,
            sampledAt: now.addingTimeInterval(-ProviderContextFillStore.maxSampleAge))
        #expect(UsageMenuCardView.Model.liveContextFillLines(fill: atCutoff, now: now) != nil)

        let pastCutoff = ResolvedContextFill(
            occupiedTokens: 124_000,
            maxTokens: 200_000,
            model: nil,
            sampledAt: now.addingTimeInterval(-(ProviderContextFillStore.maxSampleAge + 60)))
        #expect(UsageMenuCardView.Model.liveContextFillLines(fill: pastCutoff, now: now) == nil)
    }

    @Test
    func `occupancy above the resolved window avoids a bogus percent`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fill = ResolvedContextFill(
            occupiedTokens: 843_000,
            maxTokens: 200_000,
            model: "claude-opus-4-6",
            sampledAt: now.addingTimeInterval(-60))

        let lines = UsageMenuCardView.Model.liveContextFillLines(fill: fill, now: now)

        #expect(lines?.line == "Context: 843K used · above ctx 200K (larger window likely)")
    }

    @Test
    func `missing denominator shows raw occupancy and zero occupancy shows nothing`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let noMax = ResolvedContextFill(
            occupiedTokens: 124_000,
            maxTokens: nil,
            model: nil,
            sampledAt: now.addingTimeInterval(-60))
        #expect(UsageMenuCardView.Model.liveContextFillLines(fill: noMax, now: now)?.line
            == "Context: 124K in window")

        let empty = ResolvedContextFill(
            occupiedTokens: 0,
            maxTokens: 200_000,
            model: nil,
            sampledAt: now.addingTimeInterval(-60))
        #expect(UsageMenuCardView.Model.liveContextFillLines(fill: empty, now: now) == nil)
    }
}

// MARK: - Card surface integration (shared store, serialized)

@Suite(.serialized)
struct ProviderContextFillCardIntegrationTests {
    @Test
    func `fresh live fill replaces the heuristic context line on the card`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.claude])
        ProviderContextFillStore.shared.update(
            ResolvedContextFill(
                occupiedTokens: 124_000,
                maxTokens: 200_000,
                model: "claude-opus-4-6",
                sampledAt: now.addingTimeInterval(-120)),
            for: .claude)
        defer { ProviderContextFillStore.shared.update(nil, for: .claude) }

        let model = UsageMenuCardView.Model.make(.init(
            provider: .claude,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        #expect(model.insights?.contextLine == "Context: 62% · 124K/200K")
        #expect(model.insights?.contextDetail?.contains("Live session context") == true)
    }

    @Test
    func `stale live fill falls back to the heuristic path`() throws {
        let now = Date()
        let metadata = try #require(ProviderDefaults.metadata[.claude])
        ProviderContextFillStore.shared.update(
            ResolvedContextFill(
                occupiedTokens: 124_000,
                maxTokens: 200_000,
                model: "claude-opus-4-6",
                sampledAt: now.addingTimeInterval(-(ProviderContextFillStore.maxSampleAge + 300))),
            for: .claude)
        defer { ProviderContextFillStore.shared.update(nil, for: .claude) }

        let model = UsageMenuCardView.Model.make(.init(
            provider: .claude,
            metadata: metadata,
            snapshot: nil,
            credits: nil,
            creditsError: nil,
            dashboard: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: false,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: true,
            now: now))

        // No ledger data feeds the heuristic here, so an idle session shows
        // no context line at all — never a stale percentage.
        #expect(model.insights?.contextLine == nil)
    }
}
