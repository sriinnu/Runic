import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum CerebrasProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .cerebras,
            metadata: ProviderMetadata(
                id: .cerebras,
                displayName: "Cerebras",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows model availability from Cerebras API.",
                toggleTitle: "Show Cerebras usage",
                cliName: "cerebras",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://cloud.cerebras.ai",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .cerebras,
                iconResourceName: "ProviderIcon-cerebras",
                color: ProviderColor(red: 14 / 255, green: 122 / 255, blue: 161 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Cerebras cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [CerebrasAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "cerebras",
                aliases: [],
                versionDetector: nil))
    }
}

struct CerebrasAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "cerebras.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw CerebrasSettingsError.missingToken
        }
        let usage = try await CerebrasUsageFetcher.fetchModels(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.cerebrasResolution(environment: environment)
    }
}

enum CerebrasSettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Cerebras API key not found. Set it in Preferences → Providers → Cerebras or " +
                "export CEREBRAS_API_KEY."
        }
    }
}
