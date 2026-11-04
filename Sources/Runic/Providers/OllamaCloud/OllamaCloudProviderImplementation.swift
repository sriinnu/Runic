import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct OllamaCloudProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .ollamacloud

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "ollama-cloud-api-token",
                title: "API key",
                subtitle: "Optional — Pro and Max accounts can use the sign-in switch below instead.",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.ollamaCloudAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }

    /// Pro/Max accounts have no API key: usage comes from the ollama.com
    /// settings page with the browser sign-in, read once from here.
    @MainActor
    func settingsToggles(context: ProviderSettingsContext) -> [ProviderSettingsToggleDescriptor] {
        [
            BrowserSignInToggle.descriptor(
                id: "ollama-cloud-browser-sign-in",
                title: "Usage from browser sign-in",
                subtitle: "For Pro and Max plans, which sign in on ollama.com instead of using an API key. "
                    + "Turning this on uses your ollama.com sign-in from your browser, or asks you to sign in once "
                    + "in a Runic window if macOS blocks that. Runic keeps a copy in its own Keychain item.",
                hooks: BrowserSignInToggle.Hooks(
                    site: "ollama.com",
                    isConnected: { OllamaCloudWebUsageFetcher.isConnected },
                    connect: { try await OllamaCloudWebUsageFetcher.connect() },
                    disconnect: { OllamaCloudWebUsageFetcher.disconnect() },
                    signIn: WebSignInWindow
                        .Step(site: "ollama.com", url: OllamaCloudWebUsageFetcher.settingsURL) { cookies in
                            await OllamaCloudWebUsageFetcher.validate(cookies: cookies)
                        }),
                context: context),
        ]
    }
}
