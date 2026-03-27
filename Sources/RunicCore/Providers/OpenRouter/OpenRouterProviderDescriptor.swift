import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum OpenRouterProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .openrouter,
            metadata: ProviderMetadata(
                id: .openrouter,
                displayName: "OpenRouter",
                sessionLabel: "Credits",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Shows credits from OpenRouter API",
                toggleTitle: "Show OpenRouter usage",
                cliName: "openrouter",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://openrouter.ai/account",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .openrouter,
                iconResourceName: "ProviderIcon-openrouter",
                color: ProviderColor(red: 255 / 255, green: 90 / 255, blue: 0 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "OpenRouter cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [OpenRouterAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "openrouter",
                aliases: ["or"],
                versionDetector: nil))
    }
}

struct OpenRouterAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "openrouter.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw OpenRouterSettingsError.missingToken
        }
        let (credits, keyInfo) = try await OpenRouterUsageFetcher.fetchAll(apiKey: apiKey)
        return self.makeResult(
            usage: credits.toUsageSnapshot(keyInfo: keyInfo),
            credits: credits.toCreditsSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.openRouterToken(environment: environment)
    }
}

// MARK: - Settings Errors

enum OpenRouterSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "OpenRouter API key not found. Set it in Preferences → Providers → OpenRouter or " +
                "export OPENROUTER_API_KEY."
        }
    }
}
