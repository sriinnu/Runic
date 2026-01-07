import AppKit
import RunicCore
import RunicMacroSupport
import Foundation

@ProviderImplementationRegistration
struct MiniMaxProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .minimax

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "minimax-api-token",
                title: "API token",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste token…",
                binding: context.stringBinding(\.minimaxAPIToken),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "minimax-group-id",
                title: "Group ID",
                subtitle: "Stored in Keychain (encrypted). Press Return to save.",
                kind: .secure,
                placeholder: "Paste Group ID…",
                binding: context.stringBinding(\.minimaxGroupID),
                actions: [],
                isVisible: nil),
        ]
    }
}
