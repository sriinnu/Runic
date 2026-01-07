import AppKit
import RunicCore
import RunicMacroSupport
import Foundation

@ProviderImplementationRegistration
struct OpenRouterProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .openrouter

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "openrouter-api-token",
                title: "API key",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.openRouterAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
