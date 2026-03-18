import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum QwenProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .qwen,
            metadata: ProviderMetadata(
                id: .qwen,
                displayName: "Qwen",
                sessionLabel: "Tokens",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Qwen usage",
                cliName: "qwen",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://dashscope.console.aliyun.com",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: true,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .qwen,
                iconResourceName: "ProviderIcon-qwen",
                color: ProviderColor(red: 1.0, green: 0.416, blue: 0.0)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Qwen cost estimates are shown per-model in the details submenu (based on public DashScope pricing)." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [QwenAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "qwen",
                aliases: ["dashscope", "alibaba"],
                versionDetector: nil))
    }
}

struct QwenAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "qwen.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw QwenSettingsError.missingToken
        }
        let usage = try await QwenUsageFetcher.fetchUsage(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.qwenResolution(environment: environment)
    }
}

enum QwenSettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Qwen DashScope API key not found. Set it in Preferences \u{2192} Providers \u{2192} Qwen or " +
                "export DASHSCOPE_API_KEY."
        }
    }
}
