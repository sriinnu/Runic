import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum OllamaCloudProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .ollamacloud,
            metadata: ProviderMetadata(
                id: .ollamacloud,
                displayName: "Ollama Cloud",
                sessionLabel: "Session",
                weeklyLabel: "Weekly",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Ollama Cloud usage",
                cliName: "ollama-cloud",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                // GET https://ollama.com/api/usage is undocumented; the
                // settings page is the authoritative view.
                dashboardURL: "https://ollama.com/settings/usage",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .ollamacloud,
                iconResourceName: "ProviderIcon-ollamacloud",
                color: ProviderColor(red: 58 / 255, green: 58 / 255, blue: 64 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Ollama Cloud cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [OllamaCloudAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "ollama-cloud",
                // Not "ollama": that alias belongs to the Local LLM provider.
                aliases: ["ollamacloud"],
                versionDetector: nil))
    }
}

struct OllamaCloudAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "ollamacloud.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw OllamaCloudSettingsError.missingToken
        }
        let usage = try await OllamaCloudUsageFetcher.fetchUsage(apiKey: apiKey)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.ollamaCloudToken(environment: environment)
    }
}

enum OllamaCloudSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Ollama Cloud API key not found. Set it in Preferences → Providers → Ollama Cloud or export OLLAMA_API_KEY."
        }
    }
}
