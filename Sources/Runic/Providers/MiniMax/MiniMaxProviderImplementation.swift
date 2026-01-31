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
                title: "API Token",
                subtitle: "Enter your MiniMax API Key.",
                kind: .secure,
                placeholder: "ey...",
                binding: context.stringBinding(\.minimaxAPIToken),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "minimax-cookie-header",
                title: "Cookie header (manual)",
                subtitle: "Paste a Cookie: header or Copy as cURL. Stored in Keychain. Press Return to save.",
                kind: .secure,
                placeholder: "Paste Cookie header or cURL…",
                binding: context.stringBinding(\.minimaxCookieHeader),
                actions: [],
                isVisible: nil),
        ]
    }
}
