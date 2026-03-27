import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum AuggieProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .auggie,
            metadata: ProviderMetadata(
                id: .auggie,
                displayName: "Auggie",
                sessionLabel: "Daily usage",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows analytics usage from Auggie API.",
                toggleTitle: "Show Auggie usage",
                cliName: "auggie",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://dashboard.augmentcode.com",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: true,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .auggie,
                iconResourceName: "ProviderIcon-auggie",
                color: ProviderColor(red: 255 / 255, green: 180 / 255, blue: 0 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Auggie cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [AuggieAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "auggie",
                aliases: ["augment"],
                versionDetector: nil))
    }
}

struct AuggieAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "auggie.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw AuggieSettingsError.missingToken
        }
        let usage = try await AuggieUsageFetcher.fetchDailyUsage(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.auggieResolution(environment: environment)
    }
}

enum AuggieSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Auggie API token not found. Set it in Preferences → Providers → Auggie or export AUGMENT_API_TOKEN."
        }
    }
}
