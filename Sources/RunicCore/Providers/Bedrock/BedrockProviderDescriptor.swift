import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum BedrockProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .bedrock,
            metadata: ProviderMetadata(
                id: .bedrock,
                displayName: "Amazon Bedrock",
                sessionLabel: "Models",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows foundation model inventory via AWS CLI.",
                toggleTitle: "Show Amazon Bedrock usage",
                cliName: "bedrock",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://console.aws.amazon.com/bedrock/",
                statusPageURL: nil,
                statusLinkURL: "https://health.aws.amazon.com/health/status",
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .bedrock,
                iconResourceName: "ProviderIcon-bedrock",
                color: ProviderColor(red: 255 / 255, green: 153 / 255, blue: 0 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Amazon Bedrock cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [BedrockCLIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "bedrock",
                aliases: ["aws-bedrock", "amazon-bedrock"],
                versionDetector: nil))
    }
}

struct BedrockCLIFetchStrategy: ProviderFetchStrategy {
    let id: String = "bedrock.cli"
    let kind: ProviderFetchKind = .cli

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        true
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let region = Self.resolveRegion(context: context) else {
            throw BedrockSettingsError.missingRegion
        }
        let profile = Self.resolveProfile(context: context)
        let modelFilter = Self.resolveModelFilter(context: context)
        let usage = try await BedrockUsageFetcher.fetchModels(
            region: region,
            profile: profile,
            modelFilter: modelFilter)

        return self.makeResult(
            usage: usage.toUsageSnapshot(region: region, profile: profile, modelFilter: modelFilter),
            sourceLabel: profile.map { "aws-cli:\($0)" } ?? "aws-cli")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveRegion(context: ProviderFetchContext) -> String? {
        if let region = cleaned(context.settings?.bedrock?.region) {
            return region
        }
        if let region = Self.cleaned(context.env["AWS_REGION"]) {
            return region
        }
        if let region = Self.cleaned(context.env["AWS_DEFAULT_REGION"]) {
            return region
        }
        return nil
    }

    private static func resolveProfile(context: ProviderFetchContext) -> String? {
        if let profile = cleaned(context.settings?.bedrock?.profile) {
            return profile
        }
        if let profile = Self.cleaned(context.env["AWS_PROFILE"]) {
            return profile
        }
        return nil
    }

    private static func resolveModelFilter(context: ProviderFetchContext) -> String? {
        if let model = cleaned(context.settings?.bedrock?.modelID) {
            return model
        }
        if let model = Self.cleaned(context.env["BEDROCK_MODEL_ID"]) {
            return model
        }
        return nil
    }

    private static func cleaned(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

enum BedrockSettingsError: LocalizedError {
    case missingRegion

    var errorDescription: String? {
        switch self {
        case .missingRegion:
            "AWS region not found. Set it in Preferences → Providers → Amazon Bedrock or " +
                "export AWS_REGION."
        }
    }
}
