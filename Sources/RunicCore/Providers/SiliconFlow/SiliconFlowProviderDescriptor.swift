import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum SiliconFlowProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .siliconflow,
            metadata: ProviderMetadata(
                id: .siliconflow,
                displayName: "SiliconFlow",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show SiliconFlow usage",
                cliName: "siliconflow",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://cloud.siliconflow.com/me/expensebill",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .siliconflow,
                iconResourceName: "ProviderIcon-siliconflow",
                color: ProviderColor(red: 139 / 255, green: 92 / 255, blue: 246 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "SiliconFlow cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [SiliconFlowAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "siliconflow",
                aliases: ["sf"],
                versionDetector: nil))
    }
}

struct SiliconFlowAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "siliconflow.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        context.credential(for: .siliconflow) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = context.credential(for: .siliconflow) else {
            throw SiliconFlowSettingsError.missingToken
        }
        let usage = try await SiliconFlowUsageFetcher.fetchModels(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}

enum SiliconFlowSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "SiliconFlow API key not found. Set it in Preferences → Providers → SiliconFlow or " +
                "export SILICONFLOW_API_KEY."
        }
    }
}
