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
            // One sign-in can connect this while the Console switch is the one
            // being turned on, so a saved session counts as on.
            get: { context.settings.claudeWebResetsEnabled || ClaudeWebResets.isConnected },
            set: { enabled in
                guard enabled != (context.settings.claudeWebResetsEnabled || ClaudeWebResets.isConnected)
                else { return }
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
                    + "not to other apps. Turning this on uses your claude.ai login from your browser, or a Runic "
                    + "sign-in window if macOS blocks that. That window also connects the Console balance below, "
                    + "so both take one sign-in. Runic keeps copies in its own Keychain item.",
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
                    + "you to sign in once in a Runic window if macOS blocks that. That window also connects "
                    + "the claude.ai resets above. Runic keeps copies in its own Keychain item.",
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
        if case .failure = result {
            context.setStatusText(id, "Waiting for you to sign in…")
            do {
                try await WebSignInWindow.run(steps: Self.signInSteps(startingWithConsole: false))
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
            try await WebSignInWindow.run(steps: self.signInSteps(startingWithConsole: true))
            return "the Runic sign-in window"
        }
    }

    /// One window signs in to everything not connected yet, starting with the
    /// switch the user just turned on, so both switches take one sign-in.
    @MainActor
    private static func signInSteps(startingWithConsole: Bool) -> [WebSignInWindow.Step] {
        let console = URL(string: "https://platform.claude.com/settings/billing").map { url in
            WebSignInWindow.Step(site: "platform.claude.com", url: url) { cookies in
                await ClaudeConsoleCredits.connect(cookies: cookies)
            }
        }
        let chat = URL(string: "https://claude.ai/login").map { url in
            WebSignInWindow.Step(site: "claude.ai", url: url) { cookies in
                await ClaudeWebResets.connect(cookies: cookies)
            }
        }
        let wanted = startingWithConsole
            ? [console, ClaudeWebResets.isConnected ? nil : chat]
            : [chat, ClaudeConsoleCredits.isConnected ? nil : console]
        return wanted.compactMap(\.self)
    }

    /// A `/login` in the terminal rewrites the CLI's Keychain item behind
    /// Runic's back; re-read it here, off the main actor since it may prompt.
    func prepareManualReload() async {
        await Task.detached(priority: .userInitiated) {
            ClaudeOAuthCredentialsStore.reloadIfSourceChanged()
        }.value
    }
}
