import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct StepFunCNProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .stepfunCN

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "stepfun-cn-api-token",
                title: "API key",
                subtitle: "China platform (platform.stepfun.com) key. Saved automatically to Keychain (encrypted).",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.stepfunCNAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
