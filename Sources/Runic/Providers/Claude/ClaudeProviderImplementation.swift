import RunicCore
import RunicMacroSupport
import SwiftUI

@ProviderImplementationRegistration
struct ClaudeProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .claude
    let supportsLoginFlow: Bool = true

    @MainActor
    func runLoginFlow(context: ProviderLoginContext) async -> Bool {
        await context.controller.runClaudeLoginFlow()
        return true
    }

    static let webResetsToggleID = "claude-web-resets"

    /// Banked resets from claude.ai. The connect/disconnect work runs from the
    /// binding itself so it behaves the same in the list and sidebar layouts.
    @MainActor
    func settingsToggles(context: ProviderSettingsContext) -> [ProviderSettingsToggleDescriptor] {
        let id = Self.webResetsToggleID
        let binding = Binding<Bool>(
            get: { context.settings.claudeWebResetsEnabled },
            set: { enabled in
                guard enabled != context.settings.claudeWebResetsEnabled else { return }
                context.settings.claudeWebResetsEnabled = enabled
                Task { @MainActor in
                    await Self.applyWebResets(enabled: enabled, context: context)
                }
            })
        return [
            ProviderSettingsToggleDescriptor(
                id: id,
                title: "Banked resets from claude.ai",
                subtitle: "Claude only lists launch and promo resets to claude.ai and to Claude Code itself, "
                    + "not to other apps. Turning this on reads your claude.ai login from your browser once "
                    + "(macOS may ask for your password) and keeps a copy in Runic's own Keychain item.",
                binding: binding,
                statusText: { ClaudeWebResets.lastFailure ?? context.statusText(id) },
                actions: [],
                isVisible: nil,
                onChange: nil,
                onAppDidBecomeActive: nil,
                onAppearWhenEnabled: nil),
        ]
    }

    @MainActor
    private static func applyWebResets(enabled: Bool, context: ProviderSettingsContext) async {
        let id = Self.webResetsToggleID
        guard enabled else {
            ClaudeWebResets.disconnect()
            context.setStatusText(id, nil)
            await context.store.reloadProvider(.claude)
            return
        }
        context.setStatusText(id, "Looking for your claude.ai login…")
        let result = await Task.detached(priority: .userInitiated) {
            Result { try ClaudeWebResets.connect() }
        }.value
        switch result {
        case let .success(source):
            context.setStatusText(id, "Connected via \(source). Resets refresh with Claude.")
            await context.store.reloadProvider(.claude)
        case let .failure(error):
            context.settings.claudeWebResetsEnabled = false
            context.setStatusText(id, nil)
            context.requestConfirmation(ProviderSettingsConfirmation(
                title: "Couldn't connect claude.ai",
                message: error.localizedDescription,
                confirmTitle: "OK",
                onConfirm: {}))
        }
    }

    /// A `/login` in the terminal rewrites the CLI's Keychain item behind
    /// Runic's back; re-read it here, off the main actor since it may prompt.
    func prepareManualReload() async {
        await Task.detached(priority: .userInitiated) {
            ClaudeOAuthCredentialsStore.reloadIfSourceChanged()
        }.value
    }
}
