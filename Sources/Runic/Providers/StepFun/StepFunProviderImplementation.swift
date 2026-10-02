import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct StepFunProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .stepfun

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "stepfun-api-token",
                title: "API key",
                subtitle: "Global platform (platform.stepfun.ai) key. Saved automatically to Keychain (encrypted).",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.stepfunAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
