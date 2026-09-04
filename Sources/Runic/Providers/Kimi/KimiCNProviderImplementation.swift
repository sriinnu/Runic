import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct KimiCNProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .kimiCN

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "kimi-cn-api-token",
                title: "API key",
                subtitle: "China platform (api.moonshot.cn) key. Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.kimiCNAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
