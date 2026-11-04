import Foundation
import RunicCore
import SwiftUI

/// "Use my browser sign-in" switch for providers whose numbers only exist
/// behind a website login (SiliconFlow's console balance, Ollama Cloud's plan
/// usage). Background refreshes may never show the "Chrome Safe Storage"
/// Keychain dialog, so reading the browser happens here, once, when the user
/// turns it on; the provider then refreshes from Runic's saved copy
/// (`SavedBrowserSession`). Same flow as Claude's banked-resets toggle.
@MainActor
enum BrowserSignInToggle {
    struct Hooks {
        /// What the user signs in to, for status text ("ollama.com").
        let site: String
        let isConnected: @Sendable () -> Bool
        let connect: @Sendable () async throws -> String
        let disconnect: @Sendable () -> Void
        /// Why the last refresh failed, when the provider keeps it.
        var lastFailure: (@Sendable () -> String?)?
        /// Sign in inside Runic when the browser can't give a working login,
        /// such as macOS refusing Runic the browser's folder.
        var signIn: WebSignInWindow.Step?
    }

    static func descriptor(
        id: String,
        title: String,
        subtitle: String,
        hooks: Hooks,
        context: ProviderSettingsContext) -> ProviderSettingsToggleDescriptor
    {
        let binding = Binding<Bool>(
            get: { hooks.isConnected() },
            set: { enabled in
                guard enabled != hooks.isConnected() else { return }
                Task { @MainActor in
                    await Self.apply(enabled: enabled, id: id, hooks: hooks, context: context)
                }
            })
        return ProviderSettingsToggleDescriptor(
            id: id,
            title: title,
            subtitle: subtitle,
            binding: binding,
            statusText: { hooks.lastFailure?() ?? context.statusText(id) },
            actions: [],
            isVisible: nil,
            onChange: nil,
            onAppDidBecomeActive: nil,
            onAppearWhenEnabled: nil)
    }

    private static func apply(
        enabled: Bool,
        id: String,
        hooks: Hooks,
        context: ProviderSettingsContext) async
    {
        guard enabled else {
            hooks.disconnect()
            context.setStatusText(id, nil)
            await context.store.reloadAfterSignInChange(context.provider)
            return
        }
        context.setStatusText(id, "Looking for your \(hooks.site) sign-in…")
        do {
            let source = try await Self.connect(id: id, hooks: hooks, context: context)
            context.setStatusText(id, "Connected via \(source).")
            await context.store.reloadAfterSignInChange(context.provider)
        } catch {
            context.setStatusText(id, nil)
            context.requestConfirmation(ProviderSettingsConfirmation(
                title: "Couldn't connect \(hooks.site)",
                message: error.localizedDescription,
                confirmTitle: "OK",
                onConfirm: {}))
        }
    }

    /// The browser's login when it works, otherwise a sign-in window, which also
    /// covers a browser profile that holds cookies but isn't signed in.
    private static func connect(
        id: String,
        hooks: Hooks,
        context: ProviderSettingsContext) async throws -> String
    {
        do {
            return try await hooks.connect()
        } catch {
            guard let signIn = hooks.signIn else { throw error }
            context.setStatusText(id, "Waiting for you to sign in…")
            try await WebSignInWindow.run(steps: [signIn])
            guard hooks.isConnected() else { throw SaveFailure(site: hooks.site) }
            return "the Runic sign-in window"
        }
    }

    private struct SaveFailure: LocalizedError {
        let site: String
        var errorDescription: String? {
            "Runic couldn't save the \(self.site) login to the Keychain."
        }
    }
}
