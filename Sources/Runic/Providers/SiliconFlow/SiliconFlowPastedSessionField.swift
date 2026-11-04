import Foundation
import RunicCore
import SwiftUI

/// The way in when the sign-in window can't finish, such as Google refusing to
/// sign in inside it. Connects as soon as something login-shaped is pasted, and
/// reports through the sign-in switch's status line.
@MainActor
enum SiliconFlowPastedSessionField {
    /// Descriptors are rebuilt on every render, so what's in the field lives here.
    private static var drafts: [Bool: String] = [:]

    static func descriptor(
        id: String,
        host: String,
        china: Bool,
        statusToggleID: String,
        context: ProviderSettingsContext) -> ProviderSettingsFieldDescriptor
    {
        ProviderSettingsFieldDescriptor(
            id: id,
            title: "Session cookie (if sign-in doesn't work)",
            subtitle: "If the sign-in window doesn't work, open \(host) in your browser, then copy the "
                + "__SF_auth.session-token cookie from its developer tools and paste it here. It works "
                + "like your login, so don't share it. Runic checks it and keeps it in its own Keychain item.",
            kind: .secure,
            placeholder: "Paste cookie…",
            binding: Binding(
                get: { self.drafts[china] ?? "" },
                set: { text in
                    self.drafts[china] = text
                    self.connectIfComplete(
                        text,
                        china: china,
                        statusToggleID: statusToggleID,
                        context: context)
                }),
            actions: [],
            isVisible: nil)
    }

    private static func connectIfComplete(
        _ text: String,
        china: Bool,
        statusToggleID: String,
        context: ProviderSettingsContext)
    {
        guard SiliconFlowConsoleFetcher.looksLikePastedSession(text) else { return }
        context.setStatusText(statusToggleID, "Checking the pasted session…")
        Task { @MainActor in
            do {
                try await SiliconFlowConsoleFetcher.connect(
                    pastedCookie: text,
                    china: china,
                    environment: ProcessInfo.processInfo.environment)
                guard self.drafts[china] == text else { return }
                self.drafts[china] = nil
                context.setStatusText(statusToggleID, "Connected with the pasted session.")
                await context.store.reloadAfterSignInChange(context.provider)
            } catch {
                guard self.drafts[china] == text else { return }
                context.setStatusText(statusToggleID, "That session didn't work: \(error.localizedDescription)")
            }
        }
    }
}
