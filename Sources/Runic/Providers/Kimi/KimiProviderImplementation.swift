import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct KimiProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .kimi

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "kimi-base-url",
                title: "API base URL (optional)",
                subtitle: "Defaults to https://api.moonshot.ai. Use https://api.moonshot.cn for the China platform.",
                kind: .plain,
                placeholder: "https://api.moonshot.ai",
                binding: context.stringBinding(\.kimiBaseURL),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "kimi-api-token",
                title: "API key",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.kimiAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
