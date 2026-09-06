import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum StepFunProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .stepfun,
            metadata: ProviderMetadata(
                id: .stepfun,
                displayName: "StepFun",
                sessionLabel: "Balance",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows account balance from the StepFun (platform.stepfun.ai) API.",
                toggleTitle: "Show StepFun usage",
                cliName: "stepfun",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://platform.stepfun.ai/account-info",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .stepfun,
                iconResourceName: "ProviderIcon-stepfun",
                color: ProviderColor(red: 74 / 255, green: 111 / 255, blue: 255 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "StepFun cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [StepFunAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "stepfun",
                aliases: [],
                versionDetector: nil))
    }
}

struct StepFunAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "stepfun.api"
    let kind: ProviderFetchKind = .apiToken

    private static let baseURL = "https://api.stepfun.ai"

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        ProviderTokenResolver.stepfunResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = ProviderTokenResolver.stepfunResolution(environment: context.env) else {
            throw StepFunSettingsError.missingToken
        }
        let snapshot = try await StepFunUsageFetcher.fetchAccount(apiKey: tokenRes.token, baseURL: Self.baseURL)
        return self.makeResult(
            usage: snapshot.toUsageSnapshot(providerID: .stepfun),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}

enum StepFunSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "StepFun API key not found. Set it in Preferences → Providers → StepFun or export STEPFUN_API_KEY."
        }
    }
}
