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
                subtitle: "China platform (open.bigmodel.cn) key. Saved automatically to Keychain (encrypted).",
                kind: .secure,
                placeholder: "Paste token…",
                binding: context.stringBinding(\.zaiCNAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
