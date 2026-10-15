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
                subtitle: "Defaults to https://api.moonshot.ai (pay-as-you-go balance). " +
                    "For a Kimi Code plan key use https://api.kimi.ai/coding (or api.kimi.com); " +
                    "for a China-platform key use the Kimi (China) account instead.",
                kind: .plain,
                placeholder: "https://api.moonshot.ai",
                binding: context.stringBinding(\.kimiBaseURL),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "kimi-api-token",
                title: "API key",
                subtitle: "Saved automatically to Keychain (encrypted).",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.kimiAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
