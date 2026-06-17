import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum OpencodeProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .opencode,
            metadata: ProviderMetadata(
                id: .opencode,
                displayName: "opencode",
                sessionLabel: "Session",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show opencode usage",
                cliName: "opencode",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: nil,
                statusPageURL: nil,
                // opencode is BYOK and routes to many underlying providers, so it has
                // no subscription/usage window of its own — it gets a historical
                // timeline plus model/cost breakdowns from its local message log.
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: true,
                    supportsProjectAttribution: true),
                providesLiveSnapshot: false),
            branding: ProviderBranding(
                iconStyle: .opencode,
                iconResourceName: "ProviderIcon-opencode",
                color: ProviderColor(red: 217 / 255, green: 119 / 255, blue: 87 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: true,
                noDataMessage: self.noDataMessage),
            // History-only: usage comes from the local message ledger, not a live
            // API, so there are no fetch strategies (no live gauge to fetch).
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [] })),
            cli: ProviderCLIConfig(
                name: "opencode",
                versionDetector: nil))
    }

    private static func noDataMessage() -> String {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let root = ProcessInfo.processInfo.environment["OPENCODE_DATA"].flatMap { raw -> String? in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return "\(trimmed)/storage/message"
        } ?? "\(home)/.local/share/opencode/storage/message"
        return "No opencode messages found in \(root)."
    }
}
