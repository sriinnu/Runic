import Foundation
import RunicCore

struct ProviderContextWindowLabel: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case kosha
        case modelHeuristic
        case staticFallback
    }

    let text: String
    let maxTokens: Int?
    let source: Source
    let isStale: Bool
}

final class ProviderContextWindowRegistry: @unchecked Sendable {
    static let shared = ProviderContextWindowRegistry()

    private static let koshaSchemaVersion = 1
    private static let defaultKoshaTTL: TimeInterval = 24 * 60 * 60

    private let manifestURLProvider: @Sendable () -> URL?
    private let fallbackURLProvider: @Sendable () -> URL?
    private let ttl: TimeInterval
    private let reloadInterval: TimeInterval
    private let nowProvider: @Sendable () -> Date
    private let lock = NSLock()

    private var cachedManifest: ProviderContextSnapshot?
    private var lastManifestCheck: Date?
    private var cachedFallbackLabels: [String: String]?

    init(
        manifestURL: URL? = ProviderContextWindowRegistry.defaultKoshaManifestURL(),
        fallbackURL: URL? = ProviderContextWindowRegistry.bundledFallbackURL(),
        ttl: TimeInterval = ProviderContextWindowRegistry.defaultKoshaTTL,
        reloadInterval: TimeInterval = 60,
        nowProvider: @escaping @Sendable () -> Date = { Date() })
    {
        self.manifestURLProvider = { manifestURL }
        self.fallbackURLProvider = { fallbackURL }
        self.ttl = ttl
        self.reloadInterval = reloadInterval
        self.nowProvider = nowProvider
    }

    func contextLabel(for provider: UsageProvider, model: String? = nil) -> ProviderContextWindowLabel? {
        let snapshot = self.koshaSnapshot()
        if let snapshot,
           let model,
           let label = self.koshaModelLabel(for: provider, model: model, snapshot: snapshot)
        {
            return label
        }

        if let model,
           let contextWindow = UsageFormatter.modelContextWindow(for: model)
        {
            return ProviderContextWindowLabel(
                text: "ctx \(UsageFormatter.tokenCountString(contextWindow))",
                maxTokens: contextWindow,
                source: .modelHeuristic,
                isStale: false)
        }

        if let snapshot,
           Self.allowsProviderWideKoshaContext(provider),
           let label = self.koshaProviderLabel(for: provider, snapshot: snapshot)
        {
            return label
        }

        return self.staticFallbackLabel(for: provider)
    }

    private func koshaModelLabel(
        for provider: UsageProvider,
        model: String,
        snapshot: ProviderContextSnapshot) -> ProviderContextWindowLabel?
    {
        let models = Self.models(
            for: provider,
            snapshot: snapshot,
            includingModelBridges: true)
        guard let match = models.first(where: { Self.model($0, matches: model) }) else {
            return nil
        }

        let providerRecord = Self.providerRecord(
            for: provider,
            snapshot: snapshot,
            includingModelBridges: true)
        return ProviderContextWindowLabel(
            text: Self.contextText(
                tokens: match.contextWindow,
                exactModel: true,
                stale: self.isStale(model: match, provider: providerRecord)),
            maxTokens: match.contextWindow,
            source: .kosha,
            isStale: self.isStale(model: match, provider: providerRecord))
    }

    private func koshaProviderLabel(
        for provider: UsageProvider,
        snapshot: ProviderContextSnapshot) -> ProviderContextWindowLabel?
    {
        let models = Self.models(
            for: provider,
            snapshot: snapshot,
            includingModelBridges: false)
        guard !models.isEmpty else { return nil }

        let chatModels = models.filter { $0.mode == nil || $0.mode == "chat" }
        let candidates = chatModels.isEmpty ? models : chatModels
        guard let selected = candidates.max(by: { lhs, rhs in
            if lhs.contextWindow != rhs.contextWindow {
                return lhs.contextWindow < rhs.contextWindow
            }
            return (lhs.discoveredAt ?? .distantPast) < (rhs.discoveredAt ?? .distantPast)
        }) else {
            return nil
        }

        let distinctContexts = Set(candidates.map(\.contextWindow))
        let providerRecord = Self.providerRecord(for: provider, snapshot: snapshot, includingModelBridges: false)
        let stale = self.isStale(model: selected, provider: providerRecord)
        return ProviderContextWindowLabel(
            text: Self.contextText(
                tokens: selected.contextWindow,
                exactModel: distinctContexts.count == 1,
                stale: stale),
            maxTokens: selected.contextWindow,
            source: .kosha,
            isStale: stale)
    }

    private func staticFallbackLabel(for provider: UsageProvider) -> ProviderContextWindowLabel? {
        guard let text = self.fallbackLabels()[provider.rawValue] else { return nil }
        let maxTokens = self.fallbackContextWindows()[provider.rawValue]
        return ProviderContextWindowLabel(text: text, maxTokens: maxTokens, source: .staticFallback, isStale: false)
    }

    private func isStale(model: ContextModel, provider: ContextProvider?) -> Bool {
        let now = self.nowProvider()
        if let discoveredAt = model.discoveredAt, now.timeIntervalSince(discoveredAt) > self.ttl {
            return true
        }
        if let lastRefreshed = provider?.lastRefreshed, now.timeIntervalSince(lastRefreshed) > self.ttl {
            return true
        }
        return model.discoveredAt == nil && provider?.lastRefreshed == nil
    }

    private static func contextText(tokens: Int, exactModel: Bool, stale: Bool) -> String {
        var text = exactModel
            ? "ctx \(UsageFormatter.tokenCountString(tokens))"
            : "ctx <=\(UsageFormatter.tokenCountString(tokens))"
        if stale {
            text += " (stale)"
        }
        return text
    }

    private func koshaSnapshot() -> ProviderContextSnapshot? {
        let now = self.nowProvider()
        self.lock.lock()
        if let lastManifestCheck,
           now.timeIntervalSince(lastManifestCheck) < self.reloadInterval
        {
            let snapshot = self.cachedManifest
            self.lock.unlock()
            return snapshot
        }
        self.lock.unlock()

        let snapshot = self.manifestURLProvider().flatMap(Self.loadKoshaSnapshot(from:))

        self.lock.lock()
        self.cachedManifest = snapshot
        self.lastManifestCheck = now
        self.lock.unlock()
        return snapshot
    }

    private func fallbackLabels() -> [String: String] {
        self.lock.lock()
        if let cachedFallbackLabels {
            self.lock.unlock()
            return cachedFallbackLabels
        }
        self.lock.unlock()

        let labels = self.fallbackURLProvider()
            .flatMap(Self.loadStaticFallbackLabels(from:)) ?? [:]

        self.lock.lock()
        self.cachedFallbackLabels = labels
        self.lock.unlock()
        return labels
    }

    private func fallbackContextWindows() -> [String: Int] {
        self.fallbackURLProvider()
            .flatMap(Self.loadStaticFallbackContextWindows(from:)) ?? [:]
    }

    private static func loadKoshaSnapshot(from url: URL) -> ProviderContextSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(KoshaSnapshotRaw.self, from: data),
              raw.schemaVersion == Self.koshaSchemaVersion
        else {
            return nil
        }

        let providers = raw.providers.reduce(into: [String: ContextProvider]()) { result, rawProvider in
            guard let providerID = Self.normalizedProviderID(rawProvider.providerId) else { return }
            let provider = ContextProvider(
                providerID: providerID,
                canonicalProviderID: Self.normalizedProviderID(rawProvider.canonicalProviderId),
                aliases: Set((rawProvider.aliases ?? []).compactMap(Self.normalizedProviderID)),
                lastRefreshed: Self.date(fromKoshaTimestamp: rawProvider.lastRefreshed))

            for id in provider.lookupIDs {
                result[id] = provider
            }
        }

        var modelsByProviderID: [String: [ContextModel]] = [:]
        for rawModel in raw.models {
            guard let modelID = Self.normalizedModelID(rawModel.modelId),
                  let providerID = Self.normalizedProviderID(rawModel.providerId),
                  let contextWindow = rawModel.contextWindow,
                  contextWindow > 0
            else {
                continue
            }

            let model = ContextModel(
                key: Self.normalizedModelID(rawModel.key) ?? "\(providerID):\(modelID)",
                modelID: modelID,
                name: Self.normalizedModelID(rawModel.name),
                aliases: (rawModel.aliases ?? []).compactMap(Self.normalizedModelID),
                providerID: providerID,
                canonicalProviderID: Self.normalizedProviderID(rawModel.canonicalProviderId),
                mode: rawModel.mode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                contextWindow: contextWindow,
                discoveredAt: Self.date(fromKoshaTimestamp: rawModel.discoveredAt))

            for id in model.lookupProviderIDs {
                modelsByProviderID[id, default: []].append(model)
            }
        }

        return ProviderContextSnapshot(
            discoveredAt: Self.date(fromKoshaTimestamp: raw.discoveredAt),
            providersByID: providers,
            modelsByProviderID: modelsByProviderID)
    }

    private static func loadStaticFallbackLabels(from url: URL) -> [String: String]? {
        struct Entry: Decodable {
            let contextK: Int?
            let label: String?
        }

        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Entry].self, from: data)
        else {
            return nil
        }

        return dict.reduce(into: [:]) { labels, pair in
            if let label = pair.value.label?.trimmingCharacters(in: .whitespacesAndNewlines),
               !label.isEmpty
            {
                labels[pair.key] = label
            } else if let k = pair.value.contextK {
                labels[pair.key] = "ctx ~\(UsageFormatter.tokenCountString(k * 1000))"
            }
        }
    }

    private static func loadStaticFallbackContextWindows(from url: URL) -> [String: Int]? {
        struct Entry: Decodable {
            let contextK: Int?
        }

        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Entry].self, from: data)
        else {
            return nil
        }

        return dict.reduce(into: [:]) { values, pair in
            if let k = pair.value.contextK, k > 0 {
                values[pair.key] = k * 1000
            }
        }
    }

    private static func models(
        for provider: UsageProvider,
        snapshot: ProviderContextSnapshot,
        includingModelBridges: Bool) -> [ContextModel]
    {
        var seen = Set<String>()
        var result: [ContextModel] = []
        for providerID in Self.koshaProviderIDs(for: provider, includingModelBridges: includingModelBridges) {
            for model in snapshot.modelsByProviderID[providerID] ?? [] where seen.insert(model.key).inserted {
                result.append(model)
            }
        }
        return result
    }

    private static func providerRecord(
        for provider: UsageProvider,
        snapshot: ProviderContextSnapshot,
        includingModelBridges: Bool) -> ContextProvider?
    {
        for providerID in Self.koshaProviderIDs(for: provider, includingModelBridges: includingModelBridges) {
            if let record = snapshot.providersByID[providerID] {
                return record
            }
        }
        return nil
    }

    private static func model(_ candidate: ContextModel, matches rawModel: String) -> Bool {
        guard let target = Self.normalizedModelID(rawModel) else { return false }
        return candidate.lookupModelIDs.contains { id in
            target == id
                || target.hasSuffix("/\(id)")
                || target.hasSuffix(":\(id)")
                || id.hasSuffix("/\(target)")
                || id.hasSuffix(":\(target)")
        }
    }

    private static func allowsProviderWideKoshaContext(_ provider: UsageProvider) -> Bool {
        switch provider {
        case .codex, .cursor, .factory, .antigravity, .copilot, .auggie, .azure:
            return false
        default:
            return true
        }
    }

    private static func koshaProviderIDs(for provider: UsageProvider, includingModelBridges: Bool) -> [String] {
        let ids: [String]
        switch provider {
        case .codex:
            ids = ["openai", "codex"]
        case .claude:
            ids = ["anthropic", "claude"]
        case .gemini:
            ids = ["google", "gemini"]
        case .zai:
            ids = ["zai", "glm"]
        case .vercelai:
            ids = ["vercel", "vercelai", "vercel-ai-gateway", "ai-gateway"]
        case .kimi:
            ids = ["moonshot", "kimi"]
        case .vertexai:
            ids = ["vertex", "vertexai", "vertex-ai"]
        case .azure:
            ids = includingModelBridges
                ? ["azure", "azure-openai", "aoai", "openai"]
                : ["azure", "azure-openai", "aoai"]
        case .xai:
            ids = ["xai", "x-ai", "grok"]
        case .qwen:
            ids = ["qwen", "dashscope", "alibaba"]
        case .localLLM:
            ids = [
                "local-llm", "local", "ollama", "lmstudio", "lm-studio",
                "llamacpp", "llama-cpp", "vllm", "openwebui",
            ]
        case .sambanova:
            ids = ["sambanova", "samba"]
        case .bedrock:
            ids = ["bedrock", "aws-bedrock"]
        default:
            ids = [provider.rawValue]
        }

        var seen = Set<String>()
        return ids.compactMap(Self.normalizedProviderID).filter { seen.insert($0).inserted }
    }

    private static func normalizedProviderID(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedModelID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: "_", with: "-")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return normalized.isEmpty ? nil : normalized
    }

    private static func date(fromKoshaTimestamp value: Int?) -> Date? {
        guard let value else { return nil }
        let timestamp = Double(value)
        let seconds = timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp
        return Date(timeIntervalSince1970: seconds)
    }

    private static func defaultKoshaManifestURL() -> URL? {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kosha", isDirectory: true)
            .appendingPathComponent("registry.json", isDirectory: false)
    }

    private static func bundledFallbackURL() -> URL? {
        RunicResourceLocator.url(forResource: "provider-context-windows", withExtension: "json")
    }
}
