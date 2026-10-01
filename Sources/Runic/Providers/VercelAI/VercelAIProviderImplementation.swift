import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct VercelAIProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .vercelai

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "vercelai-api-token",
                title: "AI Gateway API key",
                subtitle: "Saved automatically to Keychain (encrypted).",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.vercelAIAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
