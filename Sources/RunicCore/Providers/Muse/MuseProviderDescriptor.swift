import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum MuseProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .muse,
            metadata: ProviderMetadata(
                id: .muse,
                displayName: "Muse (Meta)",
                sessionLabel: "Requests",
                weeklyLabel: "Tokens",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Muse usage",
                cliName: "muse",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                // Meta's Model API has no usage/billing endpoint: only
                // GET /v1/models (and the unauthenticated /v1/status). Spend
                // lives in the developer console.
                dashboardURL: "https://dev.meta.ai",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .muse,
                iconResourceName: "ProviderIcon-muse",
                color: ProviderColor(red: 8 / 255, green: 102 / 255, blue: 255 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Muse cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [MuseAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "muse",
                aliases: ["meta"],
                versionDetector: nil))
    }
}

struct MuseAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "muse.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw MuseSettingsError.missingToken
        }
        let result = try await MuseUsageFetcher.fetchModels(apiKey: apiKey)
        return self.makeResult(
            usage: result.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.museToken(environment: environment)
    }
}

enum MuseSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Muse API key not found. Set it in Preferences → Providers → Muse (Meta) or export MODEL_API_KEY."
        }
    }
}
