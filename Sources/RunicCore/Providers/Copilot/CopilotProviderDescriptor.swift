import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum CopilotProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .copilot,
            metadata: ProviderMetadata(
                id: .copilot,
                displayName: "Copilot",
                sessionLabel: "Premium",
                weeklyLabel: "Chat",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Copilot usage",
                cliName: "copilot",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://github.com/settings/copilot",
                statusPageURL: "https://www.githubstatus.com/",
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .copilot,
                iconResourceName: "ProviderIcon-copilot",
                color: ProviderColor(red: 168 / 255, green: 85 / 255, blue: 247 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Copilot cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [CopilotAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "copilot",
                versionDetector: nil))
    }
}

struct CopilotAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "copilot.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        true
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let selection = Self.resolveToken(context: context), !selection.token.isEmpty else {
            throw CopilotUsageFetchError.missingCredentials(details: Self.missingTokenGuidance())
        }
        let fetcher = CopilotUsageFetcher(token: selection.token, tokenSourceLabel: selection.sourceLabel)
        let snap = try await fetcher.fetch()
        return self.makeResult(
            usage: snap,
            sourceLabel: "api(\(selection.sourceLabel))")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private struct CopilotTokenSelection {
        let token: String
        let sourceLabel: String
    }

    private static func resolveToken(context: ProviderFetchContext) -> CopilotTokenSelection? {
        if let token = context.settings?.copilot?.apiToken?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty
        {
            return CopilotTokenSelection(token: token, sourceLabel: "settings")
        }
        guard let resolution = ProviderTokenResolver.copilotResolution(environment: context.env) else { return nil }
        let sourceLabel = self.sourceLabel(from: resolution.source, sourceKey: resolution.sourceKey)
        return CopilotTokenSelection(token: resolution.token, sourceLabel: sourceLabel)
    }

    private static func sourceLabel(from source: ProviderTokenSource, sourceKey: String?) -> String {
        switch source {
        case .keychain:
            sourceKey ?? "keychain"
        case .environment:
            sourceKey ?? "env"
        case .vscode:
            sourceKey ?? "vscode"
        }
    }

    private static func missingTokenGuidance() -> String {
        "Add one of COPILOT_API_TOKEN/GITHUB_TOKEN/GH_TOKEN, configure GitHub CLI token storage (`~/.config/gh/hosts.yml`), " +
            "or sign in / re-import from VS Code in Runic settings."
    }
}
