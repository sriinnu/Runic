import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct ZaiCNProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .zaiCN

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "zai-cn-api-token",
                title: "API token",
                subtitle: "China platform (open.bigmodel.cn) key. Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste token…",
                binding: context.stringBinding(\.zaiCNAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
