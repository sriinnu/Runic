import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum FireworksProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .fireworks,
            metadata: ProviderMetadata(
                id: .fireworks,
                displayName: "Fireworks",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows model availability from Fireworks API.",
                toggleTitle: "Show Fireworks usage",
                cliName: "fireworks",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://fireworks.ai",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .fireworks,
                iconResourceName: "ProviderIcon-fireworks",
                color: ProviderColor(red: 255 / 255, green: 115 / 255, blue: 0 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Fireworks cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [FireworksAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "fireworks",
                aliases: ["fw"],
                versionDetector: nil))
    }
}

struct FireworksAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "fireworks.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        context.credential(for: .fireworks) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = context.credential(for: .fireworks) else {
            throw FireworksSettingsError.missingToken
        }
        let usage = try await FireworksUsageFetcher.fetchModels(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}

enum FireworksSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Fireworks API key not found. Set it in Preferences → Providers → Fireworks or " +
                "export FIREWORKS_API_KEY."
        }
    }
}
