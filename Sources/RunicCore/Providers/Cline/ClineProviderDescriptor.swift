import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum ClineProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .cline,
            metadata: ProviderMetadata(
                id: .cline,
                displayName: "Cline",
                sessionLabel: "Credits",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Cline usage",
                cliName: "cline",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://app.cline.bot/dashboard",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .cline,
                iconResourceName: "ProviderIcon-cline",
                color: ProviderColor(red: 94 / 255, green: 106 / 255, blue: 210 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Cline cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [ClineAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "cline",
                aliases: [],
                versionDetector: nil))
    }
}

struct ClineAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "cline.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw ClineSettingsError.missingToken
        }
        let account = try await ClineUsageFetcher.fetchAll(apiKey: apiKey)
        return self.makeResult(
            usage: account.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.clineToken(environment: environment)
    }
}

enum ClineSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Cline API key not found. Set it in Preferences → Providers → Cline or export CLINE_API_KEY."
        }
    }
}
