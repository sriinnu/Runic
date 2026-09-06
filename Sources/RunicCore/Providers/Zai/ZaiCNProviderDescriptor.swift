import Foundation
import RunicMacroSupport

/// China-platform sibling of `ZaiProviderDescriptor`. Zhipu AI issues separate
/// accounts and API keys for `open.bigmodel.cn` vs the international `z.ai`
/// brand — this is a distinct provider slot so both subscriptions can be
/// tracked at once.
///
/// The usage endpoint path is mirrored from z.ai's `/api/monitor/usage/*`
/// shape onto the bigmodel.cn host; this has not been verified against a real
/// bigmodel.cn account. If it doesn't resolve, the fetch will surface an
/// error rather than silently show wrong numbers.
@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum ZaiCNProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .zaiCN,
            metadata: ProviderMetadata(
                id: .zaiCN,
                displayName: "z.ai (China)",
                sessionLabel: "Tokens",
                weeklyLabel: "MCP",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show z.ai (China) usage",
                cliName: "glm-cn",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://open.bigmodel.cn/usercenter/apikeys",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: true,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .zai,
                iconResourceName: "ProviderIcon-zai",
                color: ProviderColor(red: 232 / 255, green: 90 / 255, blue: 106 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: {
                    "GLM cost estimates are shown per-model in the details submenu (based on public API pricing)."
                }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [ZaiCNAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "glm-cn",
                aliases: ["bigmodel", "zai-cn"],
                versionDetector: nil))
    }
}

struct ZaiCNAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "zaicn.api"
    let kind: ProviderFetchKind = .apiToken

    private static let baseURL = "https://open.bigmodel.cn/api/monitor/usage"

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        ProviderTokenResolver.zaiCNResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = ProviderTokenResolver.zaiCNResolution(environment: context.env) else {
            throw ZaiSettingsError.missingToken
        }
        let usage = try await ZaiUsageFetcher.fetchUsage(apiKey: tokenRes.token, baseURL: Self.baseURL)
        return self.makeResult(
            usage: usage.toUsageSnapshot(providerID: .zaiCN),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
