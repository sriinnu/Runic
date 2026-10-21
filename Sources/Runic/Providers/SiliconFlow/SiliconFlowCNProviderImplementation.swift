import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct SiliconFlowCNProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .siliconflowCN

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "siliconflow-cn-api-token",
                title: "API key",
                subtitle: "Saved automatically to Keychain (encrypted).",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.siliconFlowCNAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
