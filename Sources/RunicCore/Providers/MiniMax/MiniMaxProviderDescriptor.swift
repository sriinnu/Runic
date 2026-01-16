import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum MiniMaxProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .minimax,
            metadata: ProviderMetadata(
                id: .minimax,
                displayName: "MiniMax",
                sessionLabel: "Plan",
                weeklyLabel: "Cycle",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show MiniMax usage",
                cliName: "minimax",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://platform.minimax.io/user-center/payment/coding-plan",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .minimax,
                iconResourceName: "ProviderIcon-minimax",
                color: ProviderColor(red: 50 / 255, green: 50 / 255, blue: 70 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "MiniMax cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .web],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [MiniMaxWebFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "minimax",
                aliases: ["minimax-api"],
                versionDetector: nil))
    }
}

struct MiniMaxWebFetchStrategy: ProviderFetchStrategy {
    let id: String = "minimax.web"
    let kind: ProviderFetchKind = .web

    func isAvailable(_: ProviderFetchContext) async -> Bool { true }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        let fetcher = MiniMaxWebUsageFetcher()
        let result = try await fetcher.fetchUsage(
            timeout: context.webTimeout,
            logger: context.verbose ? { RunicLog.logger("minimax-web").debug("\($0)") } : nil)
        return self.makeResult(
            usage: result.usage,
            sourceLabel: result.sourceLabel)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
