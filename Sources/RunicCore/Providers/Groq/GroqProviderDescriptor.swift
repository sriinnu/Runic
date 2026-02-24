import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum GroqProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .groq,
            metadata: ProviderMetadata(
                id: .groq,
                displayName: "Groq",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Groq usage",
                cliName: "groq",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://console.groq.com/usage",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .groq,
                iconResourceName: "ProviderIcon-groq",
                color: ProviderColor(red: 0 / 255, green: 200 / 255, blue: 150 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Groq cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [GroqAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "groq",
                aliases: [],
                versionDetector: nil))
    }
}

struct GroqAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "groq.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw GroqSettingsError.missingToken
        }
        let usage = try await GroqUsageFetcher.fetchModels(apiKey: apiKey)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.groqToken(environment: environment)
    }
}

enum GroqSettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Groq API key not found. Set it in Preferences → Providers → Groq or export GROQ_API_KEY."
        }
    }
}
