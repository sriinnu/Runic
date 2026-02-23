import AppKit
import RunicCore
import RunicMacroSupport
import Foundation

@ProviderImplementationRegistration
struct AzureProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .azure
    private static let defaultAPIVersion = "2024-10-21"

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "azure-openai-endpoint",
                title: "Endpoint",
                subtitle: "Azure OpenAI resource endpoint (for example, https://my-resource.openai.azure.com).",
                kind: .plain,
                placeholder: "https://<resource>.openai.azure.com",
                binding: context.stringBinding(\.azureOpenAIEndpoint),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "azure-openai-api-token",
                title: "API key",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.azureOpenAIAPIToken),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "azure-openai-deployment",
                title: "Deployment (optional)",
                subtitle: "Optional deployment name to highlight in summaries.",
                kind: .plain,
                placeholder: "gpt-4o-prod",
                binding: context.stringBinding(\.azureOpenAIDeployment),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "azure-openai-api-version",
                title: "API version",
                subtitle: "Defaults to \(Self.defaultAPIVersion).",
                kind: .plain,
                placeholder: Self.defaultAPIVersion,
                binding: context.stringBinding(\.azureOpenAIAPIVersion),
                actions: [],
                isVisible: nil),
        ]
    }
}
