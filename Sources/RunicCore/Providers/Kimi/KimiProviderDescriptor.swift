import RunicMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum KimiProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .kimi,
            metadata: ProviderMetadata(
                id: .kimi,
                displayName: "Kimi",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows model availability from Kimi API.",
                toggleTitle: "Show Kimi usage",
                cliName: "kimi",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://platform.moonshot.ai/console",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .kimi,
                iconResourceName: "ProviderIcon-kimi",
                color: ProviderColor(red: 0 / 255, green: 129 / 255, blue: 255 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Kimi cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [KimiAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "kimi",
                aliases: ["moonshot"],
                versionDetector: nil))
    }
}

struct KimiAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "kimi.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveTokenResolution(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let tokenRes = Self.resolveTokenResolution(environment: context.env) else {
            throw KimiSettingsError.missingToken
        }
        let usage = try await KimiUsageFetcher.fetchModels(apiKey: tokenRes.token)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: tokenRes.source.rawValue)
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveTokenResolution(environment: [String: String]) -> ProviderTokenResolution? {
        ProviderTokenResolver.kimiResolution(environment: environment)
    }
}

enum KimiSettingsError: LocalizedError, Sendable {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Kimi API key not found. Set it in Preferences → Providers → Kimi or export KIMI_API_KEY."
        }
    }
}
