import Foundation
import RunicMacroSupport

/// China-platform sibling of `QwenProviderDescriptor`. Alibaba Cloud DashScope
/// issues separate accounts and API keys for the China platform
/// (`dashscope.aliyuncs.com`) vs the international platform — this is a
/// distinct provider slot so both subscriptions can be tracked at once.
@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum QwenCNProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .qwenCN,
            metadata: ProviderMetadata(
                id: .qwenCN,
                displayName: "Qwen (China)",
                sessionLabel: "Tokens",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows token usage from the DashScope China (dashscope.aliyuncs.com) API.",
                toggleTitle: "Show Qwen (China) usage",
                cliName: "qwen-cn",
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
                noDataMessage: {
                    "Qwen cost estimates are shown per-model in the details submenu " +
                        "(based on public DashScope pricing)."
                }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [QwenCNAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "qwen-cn",
                aliases: ["dashscope-cn"],
                versionDetector: nil))
    }
}

struct QwenCNAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "qwencn.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw QwenCNSettingsError.missingToken
        }
        let baseURL = Self.resolveBaseURL(context: context)
        let usage = try await QwenUsageFetcher.fetchUsageOrEmpty(apiKey: tokenRes.token, baseURL: baseURL)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.qwenCNResolution(environment: environment)
    }

    /// Resolve the API base URL: explicit setting first, then environment override,
    /// else the fetcher default.
    private static func resolveBaseURL(context: ProviderFetchContext) -> String? {
        func cleaned(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else { return nil }
            return trimmed
        }
        return cleaned(context.settings?.qwenCN?.baseURL)
            ?? cleaned(context.env["DASHSCOPE_CN_BASE_URL"])
    }
}

enum QwenCNSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Qwen DashScope (China) API key not found. " +
                "Set it in Preferences \u{2192} Providers \u{2192} Qwen (China) or export DASHSCOPE_CN_API_KEY."
        }
    }
}
