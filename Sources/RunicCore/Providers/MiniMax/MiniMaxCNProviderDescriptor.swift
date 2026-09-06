import Foundation
import RunicMacroSupport

/// China-platform sibling of `MiniMaxProviderDescriptor`. MiniMax issues
/// separate accounts and API keys for `minimaxi.com` vs the international
/// `minimax.io` platform — this is a distinct provider slot so both
/// subscriptions can be tracked at once.
///
/// API-key mode only (no web/cookie fallback) — kept lean since this is a
/// second account slot, not a full re-implementation of MiniMax's web scraping.
@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum MiniMaxCNProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .minimaxCN,
            metadata: ProviderMetadata(
                id: .minimaxCN,
                displayName: "MiniMax (China)",
                sessionLabel: "Plan",
                weeklyLabel: "Cycle",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show MiniMax (China) usage",
                cliName: "minimax-cn",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://platform.minimaxi.com/user-center/payment/coding-plan",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: true,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .minimax,
                iconResourceName: "ProviderIcon-minimax",
                color: ProviderColor(red: 50 / 255, green: 50 / 255, blue: 70 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "MiniMax cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [MiniMaxCNAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "minimax-cn",
                aliases: ["minimaxi"],
                versionDetector: nil))
    }
}

struct MiniMaxCNAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "minimaxcn.api"
    let kind: ProviderFetchKind = .api

    private static let quotaAPIURL = "https://www.minimaxi.com/v1/token_plan/remains"

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        ProviderTokenResolver.minimaxCNResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = ProviderTokenResolver.minimaxCNResolution(environment: context.env) else {
            throw ProviderFetchError.missingCredentials
        }
        let snapshot = try await MiniMaxUsageFetcher.fetchUsage(
            apiKey: tokenRes.token,
            quotaAPIURL: Self.quotaAPIURL)
        return self.makeResult(
            usage: snapshot.toUsageSnapshot(providerID: .minimaxCN),
            sourceLabel: "API")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
