import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct SiliconFlowProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .siliconflow

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "siliconflow-api-token",
                title: "API key",
                subtitle: "Saved automatically to Keychain (encrypted).",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.siliconFlowAPIToken),
                actions: [],
                isVisible: nil),
            SiliconFlowPastedSessionField.descriptor(
                id: "siliconflow-pasted-session",
                host: "cloud.siliconflow.com",
                china: false,
                statusToggleID: "siliconflow-browser-sign-in",
                context: context),
        ]
    }

    /// The balance only exists behind the console login (the public balance
    /// API is retired), so it needs the browser sign-in, read once from here.
    @MainActor
    func settingsToggles(context: ProviderSettingsContext) -> [ProviderSettingsToggleDescriptor] {
        [
            BrowserSignInToggle.descriptor(
                id: "siliconflow-browser-sign-in",
                title: "Balance from browser sign-in",
                subtitle: "SiliconFlow retired its balance API; the balance now comes from the cloud.siliconflow.com "
                    + "console. Turning this on uses your sign-in from your browser, or asks you to sign in once in a "
                    + "Runic window if macOS blocks that. Runic keeps a copy in its own Keychain item.",
                hooks: BrowserSignInToggle.Hooks(
                    site: "cloud.siliconflow.com",
                    isConnected: { SiliconFlowConsoleFetcher.isConnected(china: false) },
                    connect: {
                        try await SiliconFlowConsoleFetcher.connect(
                            china: false,
                            environment: ProcessInfo.processInfo.environment)
                    },
                    disconnect: { SiliconFlowConsoleFetcher.disconnect(china: false) },
                    signIn: WebSignInWindow.Step(
                        site: "cloud.siliconflow.com",
                        url: SiliconFlowConsoleFetcher.signInURL(china: false))
                    { cookies in
                        await SiliconFlowConsoleFetcher.validate(
                            cookies: cookies,
                            china: false,
                            environment: ProcessInfo.processInfo.environment)
                    }),
                context: context),
        ]
    }
}
