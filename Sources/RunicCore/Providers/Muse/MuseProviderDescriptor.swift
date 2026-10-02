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
                displayName: "Muse Code (Meta)",
                sessionLabel: "Current",
                weeklyLabel: "Weekly",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Muse Code usage",
                cliName: "muse",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://dev.meta.ai/products/muse-code",
                subscriptionDashboardURL: "https://dev.meta.ai/docs/muse-code/subscriptions",
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
                noDataMessage: { "Muse Code subscription spend is not reported as token cost." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { context in
                    switch context.sourceMode {
                    case .cli: [MuseCodeCLIFetchStrategy()]
                    case .api: [MuseAPIFetchStrategy()]
                    case .auto: [MuseCodeCLIFetchStrategy(), MuseAPIFetchStrategy()]
                    case .web, .oauth: []
                    }
                })),
            cli: ProviderCLIConfig(
                name: "muse",
                aliases: ["meta"],
                versionDetector: nil))
    }
}

struct MuseCodeCLIFetchStrategy: ProviderFetchStrategy {
    let id: String = "muse.code-cli"
    let kind: ProviderFetchKind = .cli

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        TTYCommandRunner.which("muse") != nil
    }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        let usage = try await MuseCodeCLIUsageFetcher.load()
        return self.makeResult(usage: usage, sourceLabel: "muse-code-cli")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
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
            "Muse Model API key not found. Set it in Preferences → Providers → " +
                "Muse Code (Meta) or export MODEL_API_KEY."
        }
    }
}
