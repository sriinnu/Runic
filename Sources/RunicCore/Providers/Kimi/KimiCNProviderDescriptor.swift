import Foundation
import RunicMacroSupport

/// China-platform sibling of `KimiProviderDescriptor`. Moonshot issues separate
/// accounts and API keys for `api.moonshot.cn` vs `api.moonshot.ai` — this is a
/// distinct provider slot so both subscriptions can be tracked at once.
@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum KimiCNProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .kimiCN,
            metadata: ProviderMetadata(
                id: .kimiCN,
                displayName: "Kimi (China)",
                sessionLabel: "Balance",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows account balance from the Moonshot China (api.moonshot.cn) API.",
                toggleTitle: "Show Kimi (China) usage",
                cliName: "kimi-cn",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://platform.moonshot.cn/console",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .kimi,
                iconResourceName: "ProviderIcon-kimi",
                color: ProviderColor(red: 0 / 255, green: 129 / 255, blue: 255 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Kimi cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [KimiCNAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "kimi-cn",
                aliases: ["moonshot-cn"],
                versionDetector: nil))
    }
}

struct KimiCNAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "kimicn.api"
    let kind: ProviderFetchKind = .apiToken

    private static let baseURL = "https://api.moonshot.cn"

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        ProviderTokenResolver.kimiCNResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = ProviderTokenResolver.kimiCNResolution(environment: context.env) else {
            throw KimiSettingsError.missingToken
        }
        let usage = try await KimiUsageFetcher.fetchBalance(apiKey: tokenRes.token, baseURL: Self.baseURL)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
