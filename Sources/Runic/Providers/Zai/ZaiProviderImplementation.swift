import AppKit
import RunicCore
import RunicMacroSupport
import Foundation

@ProviderImplementationRegistration
struct ZaiProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .zai

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "zai-api-token",
                title: "API token",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste token…",
                binding: context.stringBinding(\.zaiAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
