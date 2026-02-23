import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum XAIProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .xai,
            metadata: ProviderMetadata(
                id: .xai,
                displayName: "xAI",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows model availability from xAI API.",
                toggleTitle: "Show xAI usage",
                cliName: "xai",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://console.x.ai",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .xai,
                iconResourceName: "ProviderIcon-xai",
                color: ProviderColor(red: 20 / 255, green: 20 / 255, blue: 20 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "xAI cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [XAIApiFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "xai",
                aliases: ["grok"],
                versionDetector: nil))
    }
}

struct XAIApiFetchStrategy: ProviderFetchStrategy {
    let id: String = "xai.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw XAISettingsError.missingToken
        }
        let usage = try await XAIUsageFetcher.fetchModels(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.xaiResolution(environment: environment)
    }
}

enum XAISettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "xAI API key not found. Set it in Preferences → Providers → xAI or export XAI_API_KEY."
        }
    }
}
