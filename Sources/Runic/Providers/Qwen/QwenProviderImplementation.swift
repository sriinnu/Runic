import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct QwenProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .qwen

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "qwen-api-token",
                title: "DashScope API key",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.qwenAPIToken),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "qwen-base-url",
                title: "API base URL (optional)",
                subtitle: "Defaults to https://dashscope.aliyuncs.com. Set a regional or custom gateway host.",
                kind: .plain,
                placeholder: "https://dashscope.aliyuncs.com",
                binding: context.stringBinding(\.qwenBaseURL),
                actions: [],
                isVisible: nil),
        ]
    }
}
