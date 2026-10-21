import Foundation
import RunicMacroSupport

/// China-platform sibling of `SiliconFlowProviderDescriptor`: `siliconflow.cn` issues separate
/// accounts and keys (CNY), so it is a distinct provider slot.
@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum SiliconFlowCNProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .siliconflowCN,
            metadata: ProviderMetadata(
                id: .siliconflowCN,
                displayName: "SiliconFlow (China)",
                sessionLabel: "Balance",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Shows remaining balance from the SiliconFlow China (siliconflow.cn) account",
                toggleTitle: "Show SiliconFlow (China) usage",
                cliName: "siliconflow-cn",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://cloud.siliconflow.cn/me/expensebill",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .siliconflow,
                iconResourceName: "ProviderIcon-siliconflow",
                color: ProviderColor(red: 139 / 255, green: 92 / 255, blue: 246 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "SiliconFlow China cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [SiliconFlowCNAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "siliconflow-cn",
                aliases: ["sfcn"],
                versionDetector: nil))
    }
}

struct SiliconFlowCNAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "siliconflowcn.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        context.credential(for: .siliconflowCN) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = context.credential(for: .siliconflowCN) else {
            throw SiliconFlowCNSettingsError.missingToken
        }
        let usage = try await SiliconFlowUsageFetcher.fetchBalance(apiKey: tokenRes.token, china: true)
        return self.makeResult(
            usage: usage.toUsageSnapshot(currency: "CNY"),
            credits: usage.toCreditsSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}

enum SiliconFlowCNSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "SiliconFlow China API key not found. Set it in Preferences → Providers → SiliconFlow (China) or " +
                "export SILICONFLOW_CN_API_KEY."
        }
    }
}
