import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct ClineProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .cline

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "cline-api-token",
                title: "API key",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.clineAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
