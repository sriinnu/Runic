import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum PerplexityProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .perplexity,
            metadata: ProviderMetadata(
                id: .perplexity,
                displayName: "Perplexity",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows model availability from Perplexity API.",
                toggleTitle: "Show Perplexity usage",
                cliName: "perplexity",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://www.perplexity.ai/settings/api",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .perplexity,
                iconResourceName: "ProviderIcon-perplexity",
                color: ProviderColor(red: 35 / 255, green: 180 / 255, blue: 146 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Perplexity cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [PerplexityAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "perplexity",
                aliases: ["pplx"],
                versionDetector: nil))
    }
}

struct PerplexityAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "perplexity.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw PerplexitySettingsError.missingToken
        }
        let usage = try await PerplexityUsageFetcher.fetchModels(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.perplexityResolution(environment: environment)
    }
}

enum PerplexitySettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Perplexity API key not found. Set it in Preferences → Providers → Perplexity or " +
                "export PPLX_API_KEY."
        }
    }
}
