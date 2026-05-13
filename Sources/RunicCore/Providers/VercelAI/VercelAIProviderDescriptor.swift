import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum VercelAIProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .vercelai,
            metadata: ProviderMetadata(
                id: .vercelai,
                displayName: "Vercel AI",
                sessionLabel: "Credits",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Shows AI Gateway credits from the Vercel AI Gateway API.",
                toggleTitle: "Show Vercel AI usage",
                cliName: "vercelai",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://vercel.com/ai-gateway",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .vercelai,
                iconResourceName: "ProviderIcon-vercelai",
                color: ProviderColor(red: 0 / 255, green: 0 / 255, blue: 0 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Vercel AI Gateway cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [VercelAIAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "vercelai",
                aliases: ["vercel-ai", "vercel", "ai-gateway"],
                versionDetector: nil))
    }
}

struct VercelAIAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "vercelai.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw VercelAISettingsError.missingToken
        }
        let (credits, models) = try await VercelAIUsageFetcher.fetchAll(apiKey: tokenRes.token)
        return self.makeResult(
            usage: credits.toUsageSnapshot(
                models: models,
                tokenSource: tokenRes.source.rawValue),
            credits: credits.toCreditsSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.vercelAIResolution(environment: environment)
    }
}

enum VercelAISettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Vercel AI Gateway API key not found. Set it in Preferences → Providers → Vercel AI or " +
                "export AI_GATEWAY_API_KEY."
        }
    }
}
