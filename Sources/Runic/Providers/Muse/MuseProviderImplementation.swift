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
                title: "Model API key (optional)",
                subtitle: "Muse Code subscription usage comes from your signed-in muse CLI. " +
                    "This separate key is pay-as-you-go and is saved to Keychain.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.museAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
