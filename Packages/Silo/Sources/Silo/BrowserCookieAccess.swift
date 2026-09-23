import Foundation

/// Whether a cookie read may show the macOS Keychain dialog that unlocks a
/// Chromium browser's cookie key ("Chrome Safe Storage").
///
/// Off by default: background refresh loops must never raise a dialog. A
/// user-initiated action (a button or switch the user just pressed) binds it
/// for its own task with `$allowsKeychainPrompt.withValue(true) { ... }`, so
/// the one expected prompt can appear — and, once the user chooses "Always
/// Allow", later silent reads succeed too. Task-local on purpose: it never
/// leaks into concurrent background work.
public enum BrowserCookieAccess {
    @TaskLocal public static var allowsKeychainPrompt = false
}
