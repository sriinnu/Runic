import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct OllamaCloudProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .ollamacloud

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "ollama-cloud-api-token",
                title: "API key",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.ollamaCloudAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
