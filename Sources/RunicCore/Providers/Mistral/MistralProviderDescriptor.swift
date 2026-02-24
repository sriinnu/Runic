import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum MistralProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .mistral,
            metadata: ProviderMetadata(
                id: .mistral,
                displayName: "Mistral",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows model availability from Mistral API.",
                toggleTitle: "Show Mistral usage",
                cliName: "mistral",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://console.mistral.ai",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .mistral,
                iconResourceName: "ProviderIcon-mistral",
                color: ProviderColor(red: 255 / 255, green: 90 / 255, blue: 52 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Mistral cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [MistralAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "mistral",
                aliases: [],
                versionDetector: nil))
    }
}

struct MistralAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "mistral.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw MistralSettingsError.missingToken
        }
        let usage = try await MistralUsageFetcher.fetchModels(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.mistralResolution(environment: environment)
    }
}

enum MistralSettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Mistral API key not found. Set it in Preferences → Providers → Mistral or " +
                "export MISTRAL_API_KEY."
        }
    }
}
