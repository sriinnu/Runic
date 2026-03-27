import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct AuggieProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .auggie

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "auggie-api-token",
                title: "API token",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste token…",
                binding: context.stringBinding(\.auggieAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
