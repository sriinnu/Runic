import AppKit
import RunicCore
import RunicMacroSupport
import Foundation

@ProviderImplementationRegistration
struct GroqProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .groq

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "groq-api-token",
                title: "API key",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.groqAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
