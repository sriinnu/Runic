import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum TogetherProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .together,
            metadata: ProviderMetadata(
                id: .together,
                displayName: "Together",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows model availability from Together API.",
                toggleTitle: "Show Together usage",
                cliName: "together",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://api.together.xyz/settings/api-keys",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .together,
                iconResourceName: "ProviderIcon-together",
                color: ProviderColor(red: 98 / 255, green: 76 / 255, blue: 245 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Together cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [TogetherAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "together",
                aliases: [],
                versionDetector: nil))
    }
}

struct TogetherAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "together.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw TogetherSettingsError.missingToken
        }
        let usage = try await TogetherUsageFetcher.fetchModels(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.togetherResolution(environment: environment)
    }
}

enum TogetherSettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Together API key not found. Set it in Preferences → Providers → Together or export TOGETHER_API_KEY."
        }
    }
}
