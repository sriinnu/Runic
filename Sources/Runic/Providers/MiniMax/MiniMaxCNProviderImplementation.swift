import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct MiniMaxCNProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .minimaxCN

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "minimax-cn-api-token",
                title: "API Token",
                subtitle: "China platform (minimaxi.com) key.",
                kind: .secure,
                placeholder: "ey...",
                binding: context.stringBinding(\.minimaxCNAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }
}
