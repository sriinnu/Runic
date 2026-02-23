import AppKit
import RunicCore
import RunicMacroSupport
import Foundation

@ProviderImplementationRegistration
struct KimiProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .kimi

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "kimi-api-token",
                title: "API key",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.kimiAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
