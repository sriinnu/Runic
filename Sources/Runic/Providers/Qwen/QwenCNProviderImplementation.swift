import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct QwenCNProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .qwenCN

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "qwen-cn-api-token",
                title: "DashScope API key (China)",
                subtitle: "China platform (dashscope.aliyuncs.com) key. Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.qwenCNAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
