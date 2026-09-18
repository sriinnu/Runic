import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum TypeSafeProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .typesafe,
            metadata: ProviderMetadata(
                id: .typesafe,
                displayName: "TypeSafe",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show TypeSafe usage",
                cliName: "typesafe",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                // TypeSafe reports spend only in the console; the API exposes no
                // usage/billing endpoint (probed 2026-09-18: /v1/models is the
                // only GET that answers, everything else 404s).
                dashboardURL: "https://console.typesafe.ai/usage",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .typesafe,
                iconResourceName: "ProviderIcon-typesafe",
                color: ProviderColor(red: 229 / 255, green: 81 / 255, blue: 186 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "TypeSafe cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [TypeSafeAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "typesafe",
                aliases: ["jev"],
                versionDetector: nil))
    }
}

struct TypeSafeAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "typesafe.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw TypeSafeSettingsError.missingToken
        }
        let usage = try await TypeSafeUsageFetcher.fetchModels(apiKey: apiKey)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.typeSafeToken(environment: environment)
    }
}

enum TypeSafeSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "TypeSafe API key not found. Set it in Preferences → Providers → TypeSafe or export TYPESAFE_API_KEY."
        }
    }
}
