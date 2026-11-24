import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum OllamaCloudProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .ollamacloud,
            metadata: ProviderMetadata(
                id: .ollamacloud,
                displayName: "Ollama Cloud",
                sessionLabel: "Session",
                weeklyLabel: "Weekly",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Ollama Cloud usage",
                cliName: "ollama-cloud",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                // GET https://ollama.com/api/usage is undocumented; the
                // settings page is the authoritative view.
                dashboardURL: "https://ollama.com/settings/usage",
                statusPageURL: nil,
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: false,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .ollamacloud,
                iconResourceName: "ProviderIcon-ollamacloud",
                color: ProviderColor(red: 58 / 255, green: 58 / 255, blue: 64 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Ollama Cloud cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [
                    OllamaCloudAPIFetchStrategy(),
                    OllamaCloudWebFetchStrategy(),
                ] })),
            cli: ProviderCLIConfig(
                name: "ollama-cloud",
                // Not "ollama": that alias belongs to the Local LLM provider.
                aliases: ["ollamacloud"],
                versionDetector: nil))
    }
}

/// Pro/Max accounts sign in on the website and have no API key: read the
/// usage off `ollama.com/settings` with the browser's session cookies.
struct OllamaCloudWebFetchStrategy: ProviderFetchStrategy {
    let id: String = "ollamacloud.web"
    let kind: ProviderFetchKind = .web

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        #if os(macOS)
        context.account?.isDefault != false
        #else
        false
        #endif
    }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        #if os(macOS)
        let usage = try await OllamaCloudWebUsageFetcher.fetchUsage()
        return self.makeResult(usage: usage.toUsageSnapshot(), sourceLabel: "web")
        #else
        throw OllamaCloudAPIError.notSignedIn
        #endif
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}

struct OllamaCloudAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "ollamacloud.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        context.credential(for: .ollamacloud) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = context.credential(for: .ollamacloud)?.token else {
            throw OllamaCloudSettingsError.missingToken
        }
        var usage = try await OllamaCloudUsageFetcher.fetchUsage(apiKey: apiKey)
        var sourceLabel = "api"
        #if os(macOS)
        if Self.shouldEnrichFromWeb(context: context, usage: usage),
           let webUsage = try? await OllamaCloudWebUsageFetcher.fetchUsage(),
           webUsage.monthlyUsage != nil || webUsage.sessionUsage != nil || webUsage.weeklyUsage != nil
        {
            usage = OllamaCloudUsage(
                monthlyUsage: webUsage.monthlyUsage,
                sessionUsage: webUsage.sessionUsage,
                weeklyUsage: webUsage.weeklyUsage,
                models: usage.models,
                cost: usage.cost ?? webUsage.cost,
                totalRequests: usage.totalRequests,
                rangeLabel: usage.rangeLabel,
                sessionResetsAt: webUsage.sessionResetsAt,
                weeklyResetsAt: webUsage.weeklyResetsAt)
            sourceLabel = "api + web"
        }
        #endif
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: sourceLabel)
    }

    static func shouldEnrichFromWeb(context: ProviderFetchContext, usage: OllamaCloudUsage) -> Bool {
        context.runtime == .app
            && context.account?.isDefault != false
            && context.sourceMode == .auto
            && usage.monthlyUsage == nil
            && usage.sessionUsage == nil
            && usage.weeklyUsage == nil
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}

enum OllamaCloudSettingsError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Ollama Cloud API key not found. Set it in Preferences → Providers → Ollama Cloud or export OLLAMA_API_KEY."
        }
    }
}
