import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum AntigravityProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .antigravity,
            metadata: ProviderMetadata(
                id: .antigravity,
                displayName: "Antigravity",
                sessionLabel: "Gemini 5h",
                weeklyLabel: "Gemini Weekly",
                opusLabel: "Claude & GPT",
                supportsOpus: true,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Antigravity usage (experimental)",
                cliName: "antigravity",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: nil,
                statusPageURL: nil,
                statusLinkURL: "https://www.google.com/appsstatus/dashboard/products/npdyhgECDJ6tB66MxXyo/history",
                statusWorkspaceProductID: "npdyhgECDJ6tB66MxXyo",
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .antigravity,
                iconResourceName: "ProviderIcon-antigravity",
                color: ProviderColor(red: 96 / 255, green: 186 / 255, blue: 126 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Antigravity cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { context in
                    switch context.sourceMode {
                    case .cli:
                        [AntigravityCLIFetchStrategy()]
                    default:
                        [AntigravityStatusFetchStrategy(), AntigravityCLIFetchStrategy()]
                    }
                })),
            cli: ProviderCLIConfig(
                name: "antigravity",
                aliases: ["agy"],
                versionDetector: nil))
    }
}

struct AntigravityStatusFetchStrategy: ProviderFetchStrategy {
    let id: String = "antigravity.local"
    let kind: ProviderFetchKind = .localProbe

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        true
    }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        let probe = AntigravityStatusProbe()
        let snap = try await probe.fetch()
        let usage = try snap.toUsageSnapshot()
        return self.makeResult(
            usage: usage,
            sourceLabel: "local")
    }

    func shouldFallback(on error: Error, context _: ProviderFetchContext) -> Bool {
        guard let probeError = error as? AntigravityStatusProbeError else { return false }
        switch probeError {
        case .standaloneTokenUnavailable, .missingCSRFToken, .notRunning, .portDetectionFailed:
            return AntigravityCLIProbe.resolveBinary() != nil
        case .apiError, .parseFailed, .timedOut:
            return false
        }
    }
}

struct AntigravityCLIFetchStrategy: ProviderFetchStrategy {
    let id: String = "antigravity.cli"
    let kind: ProviderFetchKind = .cli

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        AntigravityCLIProbe.resolveBinary() != nil
    }

    func fetch(_: ProviderFetchContext) async throws -> ProviderFetchResult {
        let probe = AntigravityCLIProbe()
        let snap = try await probe.fetch()
        let usage = try snap.toUsageSnapshot()
        return self.makeResult(
            usage: usage,
            sourceLabel: "cli")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }
}
