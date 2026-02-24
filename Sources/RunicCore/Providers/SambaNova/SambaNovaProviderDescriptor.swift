import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum SambaNovaProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .sambanova,
            metadata: ProviderMetadata(
                id: .sambanova,
                displayName: "SambaNova",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows model availability from SambaNova API.",
                toggleTitle: "Show SambaNova usage",
                cliName: "sambanova",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://cloud.sambanova.ai",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .sambanova,
                iconResourceName: "ProviderIcon-sambanova",
                color: ProviderColor(red: 236 / 255, green: 84 / 255, blue: 74 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "SambaNova cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [SambaNovaAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "sambanova",
                aliases: ["samba"],
                versionDetector: nil))
    }
}

struct SambaNovaAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "sambanova.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw SambaNovaSettingsError.missingToken
        }
        let usage = try await SambaNovaUsageFetcher.fetchModels(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.sambaNovaResolution(environment: environment)
    }
}

enum SambaNovaSettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "SambaNova API key not found. Set it in Preferences → Providers → SambaNova or " +
                "export SAMBANOVA_API_KEY."
        }
    }
}
