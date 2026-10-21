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
            statusText: { context.statusText(id) },
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
            await context.store.reloadProvider(context.provider)
            return
        }
        context.setStatusText(id, "Looking for your \(hooks.site) sign-in…")
        do {
            let source = try await hooks.connect()
            context.setStatusText(id, "Connected via \(source).")
            await context.store.reloadProvider(context.provider)
        } catch {
            context.setStatusText(id, nil)
            context.requestConfirmation(ProviderSettingsConfirmation(
                title: "Couldn't connect \(hooks.site)",
                message: error.localizedDescription,
                confirmTitle: "OK",
                onConfirm: {}))
        }
    }
}
