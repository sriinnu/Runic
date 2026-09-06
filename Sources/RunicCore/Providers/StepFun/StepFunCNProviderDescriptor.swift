import Foundation
import RunicMacroSupport

/// China-platform sibling of `StepFunProviderDescriptor`. StepFun issues
/// separate accounts and API keys for `platform.stepfun.com` (China) vs
/// `platform.stepfun.ai` (global) — a China-issued key only authenticates
/// against the `.com` host, so this is a distinct provider slot.
@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum StepFunCNProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .stepfunCN,
            metadata: ProviderMetadata(
                id: .stepfunCN,
                displayName: "StepFun (China)",
                sessionLabel: "Balance",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows account balance from the StepFun China (platform.stepfun.com) API.",
                toggleTitle: "Show StepFun (China) usage",
                cliName: "stepfun-cn",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://platform.stepfun.com/account-info",
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
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [StepFunCNAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "stepfun-cn",
                aliases: [],
                versionDetector: nil))
    }
}

struct StepFunCNAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "stepfuncn.api"
    let kind: ProviderFetchKind = .apiToken

    private static let baseURL = "https://api.stepfun.com"

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        ProviderTokenResolver.stepfunCNResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = ProviderTokenResolver.stepfunCNResolution(environment: context.env) else {
            throw StepFunSettingsError.missingToken
        }
        let snapshot = try await StepFunUsageFetcher.fetchAccount(apiKey: tokenRes.token, baseURL: Self.baseURL)
        return self.makeResult(
            usage: snapshot.toUsageSnapshot(providerID: .stepfunCN),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
