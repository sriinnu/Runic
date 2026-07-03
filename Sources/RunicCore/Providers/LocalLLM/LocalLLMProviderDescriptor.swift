import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum LocalLLMProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .localLLM,
            metadata: ProviderMetadata(
                id: .localLLM,
                displayName: "Local LLM",
                sessionLabel: "Local",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Local LLM usage",
                cliName: "local-llm",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: nil,
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: true,
                    supportsProjectAttribution: true)),
            branding: ProviderBranding(
                iconStyle: .localLLM,
                iconResourceName: "ProviderIcon-local-llm",
                color: ProviderColor(red: 46 / 255, green: 204 / 255, blue: 113 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: {
                    "Local LLM API cost is not applicable; " +
                        "Runic tracks local token usage when logs or telemetry expose it."
                }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [LocalLLMStatusFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "local-llm",
                aliases: ["ollama", "lmstudio", "vllm", "llama.cpp", "openwebui"],
                versionDetector: nil))
    }
}

struct LocalLLMStatusFetchStrategy: ProviderFetchStrategy {
    let id: String = "local-llm.local"
    let kind: ProviderFetchKind = .localProbe

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        true
    }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        let status = try await LocalLLMUsageFetcher.fetchFirstAvailable()
        return self.makeResult(
            usage: status.toUsageSnapshot(),
            sourceLabel: "local")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}

public struct LocalLLMStatusSnapshot: Sendable, Codable, Hashable {
    public let runtimeName: String
    public let baseURL: String
    public let models: [String]
    public let updatedAt: Date

    public init(runtimeName: String, baseURL: String, models: [String], updatedAt: Date = Date()) {
        self.runtimeName = runtimeName
        self.baseURL = baseURL
        self.models = models
        self.updatedAt = updatedAt
    }

    public func toUsageSnapshot() -> UsageSnapshot {
        let modelCount = self.models.count
        let modelLabel = if let first = self.models.first, modelCount == 1 {
            first
        } else if let first = self.models.first, modelCount > 1 {
            "\(first) +\(modelCount - 1)"
        } else {
            "No models reported"
        }

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "\(self.runtimeName) online · \(modelCount) model\(modelCount == 1 ? "" : "s")",
                label: modelLabel,
                hasKnownLimit: false),
            secondary: nil,
            providerCost: nil,
            updatedAt: self.updatedAt,
            identity: ProviderIdentitySnapshot(
                providerID: .localLLM,
                accountEmail: nil,
                accountOrganization: self.baseURL,
                loginMethod: self.runtimeName))
    }
}

public enum LocalLLMUsageError: LocalizedError, Sendable, Equatable {
    case noLocalRuntimeFound
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .noLocalRuntimeFound:
            "No local LLM runtime found. Runic checked Ollama, LM Studio, vLLM, " +
                "llama.cpp, and Open WebUI localhost endpoints."
        case let .invalidResponse(runtime):
            "Local LLM runtime \(runtime) returned an unsupported models response."
        }
    }
}

public enum LocalLLMUsageFetcher {
    private struct Endpoint {
        let runtimeName: String
        let url: URL
        let responseKind: ResponseKind
    }

    private enum ResponseKind {
        case ollamaTags
        case openAIModels
    }

    private struct OllamaTagsResponse: Decodable {
        let models: [Model]?

        struct Model: Decodable {
            let name: String?
            let model: String?
        }
    }

    private struct OpenAIModelsResponse: Decodable {
        let data: [Model]?

        struct Model: Decodable {
            let id: String?
            let name: String?
        }
    }

    private static let endpoints: [Endpoint] = [
        Endpoint(
            runtimeName: "Ollama",
            url: URL(string: "http://127.0.0.1:11434/api/tags")!,
            responseKind: .ollamaTags),
        Endpoint(
            runtimeName: "LM Studio",
            url: URL(string: "http://127.0.0.1:1234/v1/models")!,
            responseKind: .openAIModels),
        Endpoint(
            runtimeName: "vLLM",
            url: URL(string: "http://127.0.0.1:8000/v1/models")!,
            responseKind: .openAIModels),
        Endpoint(
            runtimeName: "llama.cpp",
            url: URL(string: "http://127.0.0.1:8080/v1/models")!,
            responseKind: .openAIModels),
        Endpoint(
            runtimeName: "Open WebUI",
            url: URL(string: "http://127.0.0.1:3000/api/models")!,
            responseKind: .openAIModels),
    ]

    public static func fetchFirstAvailable() async throws -> LocalLLMStatusSnapshot {
        for endpoint in self.endpoints {
            if let snapshot = try? await fetch(endpoint) {
                return snapshot
            }
        }
        throw LocalLLMUsageError.noLocalRuntimeFound
    }

    static func parseOllamaModels(_ data: Data) throws -> [String] {
        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return Self.uniqueModels(decoded.models?.compactMap { $0.name ?? $0.model } ?? [])
    }

    static func parseOpenAIModels(_ data: Data) throws -> [String] {
        let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return Self.uniqueModels(decoded.data?.compactMap { $0.id ?? $0.name } ?? [])
    }

    private static func fetch(_ endpoint: Endpoint) async throws -> LocalLLMStatusSnapshot {
        var request = URLRequest(url: endpoint.url)
        request.timeoutInterval = 1.5
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LocalLLMUsageError.invalidResponse(endpoint.runtimeName)
        }

        let models = switch endpoint.responseKind {
        case .ollamaTags:
            try Self.parseOllamaModels(data)
        case .openAIModels:
            try Self.parseOpenAIModels(data)
        }

        return LocalLLMStatusSnapshot(
            runtimeName: endpoint.runtimeName,
            baseURL: endpoint.url.deletingLastPathComponent().absoluteString,
            models: models)
    }

    private static func uniqueModels(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
