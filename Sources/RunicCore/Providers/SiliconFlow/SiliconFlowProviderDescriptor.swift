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
                sessionLabel: "Balance",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Balance from the cloud.siliconflow.com console (browser sign-in); an API key alone only checks the key.",
                toggleTitle: "Show SiliconFlow usage",
                cliName: "siliconflow",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
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
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [
                    SiliconFlowConsoleFetchStrategy(china: false),
                    SiliconFlowAPIFetchStrategy(),
                ] })),
            cli: ProviderCLIConfig(
                name: "siliconflow",
                aliases: ["sf"],
                versionDetector: nil))
    }
}

/// Balance from the console with the browser's SiliconFlow sign-in (the public
/// balance API is retired). Falls back to the API-key check only when a key
/// exists; otherwise its own error ("not signed in", "needs your user ID") shows.
struct SiliconFlowConsoleFetchStrategy: ProviderFetchStrategy {
    let china: Bool
    let kind: ProviderFetchKind = .web

    var id: String {
        self.china ? "siliconflowcn.web" : "siliconflow.web"
    }

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        #if os(macOS)
        let response = try await SiliconFlowConsoleFetcher.fetchBalance(china: self.china, environment: context.env)
        return self.makeResult(
            usage: response.toUsageSnapshot(currency: self.china ? "CNY" : "USD"),
            credits: response.toCreditsSnapshot(),
            sourceLabel: "web")
        #else
        throw SiliconFlowConsoleError.notSignedIn(china: self.china)
        #endif
    }

    func shouldFallback(on _: Error, context: ProviderFetchContext) -> Bool {
        context.credential(for: self.china ? .siliconflowCN : .siliconflow) != nil
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
            usage: usage.toUsageSnapshot(balanceIssue: SiliconFlowConsoleTrace.lastFailure(china: false)),
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
