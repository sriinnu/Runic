import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct SiliconFlowCNProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .siliconflowCN

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "siliconflow-cn-api-token",
                title: "API key",
                subtitle: "Saved automatically to Keychain (encrypted).",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.siliconFlowCNAPIToken),
                actions: [],
                isVisible: nil),
        ]
    }

    /// The balance only exists behind the console login (the public balance
    /// API is retired), so it needs the browser sign-in, read once from here.
    @MainActor
    func settingsToggles(context: ProviderSettingsContext) -> [ProviderSettingsToggleDescriptor] {
        [
            BrowserSignInToggle.descriptor(
                id: "siliconflow-cn-browser-sign-in",
                title: "Balance from browser sign-in",
                subtitle: "SiliconFlow retired its balance API; the balance now comes from the cloud.siliconflow.cn "
                    + "console. Turning this on reads your sign-in from your browser once (macOS may ask "
                    + "for your password) and keeps a copy in Runic's own Keychain item.",
                hooks: BrowserSignInToggle.Hooks(
                    site: "cloud.siliconflow.cn",
                    isConnected: { SiliconFlowConsoleFetcher.isConnected(china: true) },
                    connect: {
                        try await SiliconFlowConsoleFetcher.connect(
                            china: true,
                            environment: ProcessInfo.processInfo.environment)
                    },
                    disconnect: { SiliconFlowConsoleFetcher.disconnect(china: true) }),
                context: context),
        ]
    }
}
