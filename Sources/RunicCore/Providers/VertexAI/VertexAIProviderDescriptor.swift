import Foundation
import RunicMacroSupport

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum VertexAIProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .vertexai,
            metadata: ProviderMetadata(
                id: .vertexai,
                displayName: "Vertex AI",
                sessionLabel: "Requests",
                weeklyLabel: "",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "Shows model inventory via gcloud CLI.",
                toggleTitle: "Show Vertex AI usage",
                cliName: "vertexai",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://console.cloud.google.com/vertex-ai",
                statusPageURL: nil,
                statusLinkURL: "https://status.cloud.google.com/",
                usageCoverage: ProviderUsageCoverage(
                    supportsModelBreakdown: true,
                    supportsTokenMetrics: false,
                    supportsProjectAttribution: false)),
            branding: ProviderBranding(
                iconStyle: .vertexai,
                iconResourceName: "ProviderIcon-vertexai",
                color: ProviderColor(red: 66 / 255, green: 133 / 255, blue: 244 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Vertex AI cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .cli],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [VertexAICLIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "vertexai",
                aliases: ["vertex-ai", "google-vertex"],
                versionDetector: nil))
    }
}

struct VertexAICLIFetchStrategy: ProviderFetchStrategy {
    let id: String = "vertexai.cli"
    let kind: ProviderFetchKind = .cli

    func isAvailable(_: ProviderFetchContext) async -> Bool {
        true
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        let project = Self.resolveProject(context: context)
        let location = Self.resolveLocation(context: context)

        guard let project else {
            throw VertexAISettingsError.missingProject
        }

        let usage = try await VertexAIUsageFetcher.fetchModels(
            project: project,
            location: location ?? "us-central1")

        return self.makeResult(
            usage: usage.toUsageSnapshot(project: project, location: location ?? "us-central1"),
            sourceLabel: "gcloud")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveProject(context: ProviderFetchContext) -> String? {
        if let project = cleaned(context.settings?.vertexai?.project) {
            return project
        }
        if let project = Self.cleaned(context.env["VERTEX_AI_PROJECT"]) {
            return project
        }
        if let project = Self.cleaned(context.env["GOOGLE_CLOUD_PROJECT"]) {
            return project
        }
        if let project = Self.cleaned(context.env["GCLOUD_PROJECT"]) {
            return project
        }
        return nil
    }

    private static func resolveLocation(context: ProviderFetchContext) -> String? {
        if let location = cleaned(context.settings?.vertexai?.location) {
            return location
        }
        if let location = Self.cleaned(context.env["VERTEX_AI_LOCATION"]) {
            return location
        }
        if let location = Self.cleaned(context.env["GOOGLE_CLOUD_REGION"]) {
            return location
        }
        return nil
    }

    private static func cleaned(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

enum VertexAISettingsError: LocalizedError {
    case missingProject

    var errorDescription: String? {
        switch self {
        case .missingProject:
            "Google Cloud project not found. Set it in Preferences \u{2192} Providers \u{2192} Vertex AI or " +
                "export VERTEX_AI_PROJECT."
        }
    }
}
