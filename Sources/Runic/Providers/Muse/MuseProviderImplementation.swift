import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct MuseProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .muse

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "muse-api-token",
                title: "API key",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.museAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
