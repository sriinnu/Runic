import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum DeepSeekProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .deepseek,
            metadata: ProviderMetadata(
                id: .deepseek,
                displayName: "DeepSeek",
                sessionLabel: "Balance",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Shows remaining balance from DeepSeek API",
                toggleTitle: "Show DeepSeek usage",
                cliName: "deepseek",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://platform.deepseek.com/usage",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .deepseek,
                iconResourceName: "ProviderIcon-deepseek",
                color: ProviderColor(red: 76 / 255, green: 110 / 255, blue: 245 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "DeepSeek cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [DeepSeekAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "deepseek",
                aliases: ["ds"],
                versionDetector: nil))
    }
}

struct DeepSeekAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "deepseek.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw DeepSeekSettingsError.missingToken
        }
        let usage = try await DeepSeekUsageFetcher.fetchBalance(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            credits: usage.toCreditsSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.deepSeekResolution(environment: environment)
    }
}

enum DeepSeekSettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "DeepSeek API key not found. Set it in Preferences → Providers → DeepSeek or " +
                "export DEEPSEEK_API_KEY."
        }
    }
}
