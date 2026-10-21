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
                subtitle: "Optional — Pro accounts just stay signed in to ollama.com in a browser.",
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
                    + "Turning this on reads your ollama.com sign-in from your browser once (macOS may ask "
                    + "for your password) and keeps a copy in Runic's own Keychain item.",
                hooks: BrowserSignInToggle.Hooks(
                    site: "ollama.com",
                    isConnected: { OllamaCloudWebUsageFetcher.isConnected },
                    connect: { try await OllamaCloudWebUsageFetcher.connect() },
                    disconnect: { OllamaCloudWebUsageFetcher.disconnect() }),
                context: context),
        ]
    }
}
