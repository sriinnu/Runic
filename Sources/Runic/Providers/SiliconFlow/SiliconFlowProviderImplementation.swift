import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct SiliconFlowProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .siliconflow

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "siliconflow-api-token",
                title: "API key",
                subtitle: "Saved automatically to Keychain (encrypted).",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.siliconFlowAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
