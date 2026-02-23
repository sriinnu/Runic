import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum AzureProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .azure,
            metadata: ProviderMetadata(
                id: .azure,
                displayName: "Azure OpenAI",
                sessionLabel: "Deployments",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows deployment inventory from Azure OpenAI.",
                toggleTitle: "Show Azure OpenAI usage",
                cliName: "azure",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://oai.azure.com/",
                statusPageURL: nil,
                statusLinkURL: "https://status.azure.com/",
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .azure,
                iconResourceName: "ProviderIcon-azure",
                color: ProviderColor(red: 0 / 255, green: 120 / 255, blue: 212 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Azure OpenAI cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [AzureOpenAIAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "azure",
                aliases: ["azure-openai", "aoai"],
                versionDetector: nil))
    }
}

struct AzureOpenAIAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "azure.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        true
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenResolution = Self.resolveToken(context: context) else {
            throw AzureSettingsError.missingToken
        }
        guard let endpoint = Self.resolveEndpoint(context: context) else {
            throw AzureSettingsError.missingEndpoint
        }

        let apiVersion = Self.resolveAPIVersion(context: context)
        let deployment = Self.resolveDeployment(context: context)
        let usage = try await AzureUsageFetcher.fetchDeployments(
            endpoint: endpoint,
            apiKey: tokenResolution.token,
            apiVersion: apiVersion)

        return self.makeResult(
            usage: usage.toUsageSnapshot(highlightedDeployment: deployment),
            sourceLabel: tokenResolution.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(context: ProviderFetchContext) -> ProviderTokenResolution? {
        if let token = Self.cleaned(context.settings?.azure?.apiToken) {
            return ProviderTokenResolution(token: token, source: .keychain)
        }
        return ProviderTokenResolver.azureOpenAIResolution(environment: context.env)
    }

    private static func resolveEndpoint(context: ProviderFetchContext) -> String? {
        if let endpoint = Self.cleaned(context.settings?.azure?.endpoint) {
            return endpoint
        }
        if let endpoint = Self.cleaned(context.env["AZURE_OPENAI_ENDPOINT"]) {
            return endpoint
        }
        if let endpoint = Self.cleaned(context.env["AZURE_OPENAI_BASE_URL"]) {
            return endpoint
        }
        return nil
    }

    private static func resolveAPIVersion(context: ProviderFetchContext) -> String {
        if let version = Self.cleaned(context.settings?.azure?.apiVersion) {
            return version
        }
        if let version = Self.cleaned(context.env["AZURE_OPENAI_API_VERSION"]) {
            return version
        }
        return AzureUsageFetcher.defaultAPIVersion
    }

    private static func resolveDeployment(context: ProviderFetchContext) -> String? {
        if let deployment = Self.cleaned(context.settings?.azure?.deployment) {
            return deployment
        }
        if let deployment = Self.cleaned(context.env["AZURE_OPENAI_DEPLOYMENT"]) {
            return deployment
        }
        return nil
    }

    private static func cleaned(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

enum AzureSettingsError: LocalizedError, Sendable {
    case missingEndpoint
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingEndpoint:
            return "Azure OpenAI endpoint not found. Set it in Preferences → Providers → Azure OpenAI or " +
                "export AZURE_OPENAI_ENDPOINT."
        case .missingToken:
            return "Azure OpenAI API key not found. Set it in Preferences → Providers → Azure OpenAI or " +
                "export AZURE_OPENAI_API_KEY."
        }
    }
}
