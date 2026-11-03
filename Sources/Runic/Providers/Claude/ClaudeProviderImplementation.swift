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
            BrowserSignInToggle.descriptor(
                id: "claude-console-credits",
                title: "API credit balance from the Console",
                subtitle: "Shows what's left of your API credits and when the next grant expires. API keys can't "
                    + "read this, so turning it on uses your platform.claude.com login from your browser, or asks "
                    + "you to sign in once in a Runic window if macOS blocks that. Runic keeps a copy in its own "
                    + "Keychain item.",
                hooks: BrowserSignInToggle.Hooks(
                    site: "platform.claude.com",
                    isConnected: { ClaudeConsoleCredits.isConnected },
                    connect: { try await Self.connectConsole() },
                    disconnect: { ClaudeConsoleCredits.disconnect() },
                    lastFailure: { ClaudeConsoleCredits.lastFailure }),
                context: context),
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
        var result = await Task.detached(priority: .userInitiated) {
            Result { try ClaudeWebResets.connect() }
        }.value
        // macOS can refuse Runic the browser's folder: sign in here instead.
        if case .failure = result, let url = URL(string: "https://claude.ai/login") {
            context.setStatusText(id, "Waiting for you to sign in to claude.ai…")
            do {
                try await WebSignInWindow.run(site: "claude.ai", url: url) { cookies in
                    ClaudeWebResets.connect(cookies: cookies)
                }
                result = .success("the Runic sign-in window")
            } catch {
                result = .failure(error)
            }
        }
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

    /// The browser's login when macOS allows reading it, otherwise a sign-in
    /// window. A failure with a login present (an unexpected reply) is reported.
    private static func connectConsole() async throws -> String {
        do {
            return try await ClaudeConsoleCredits.connect()
        } catch ClaudeConsoleCredits.Failure.notSignedIn {
            guard let url = URL(string: "https://platform.claude.com/settings/billing") else { throw URLError(.badURL) }
            try await WebSignInWindow.run(site: "platform.claude.com", url: url) { cookies in
                await ClaudeConsoleCredits.connect(cookies: cookies)
            }
            return "the Runic sign-in window"
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
