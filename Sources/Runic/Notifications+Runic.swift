import Foundation

extension Notification.Name {
    static let runicOpenSettings = Notification.Name("runicOpenSettings")
    static let runicDebugBlinkNow = Notification.Name("runicDebugBlinkNow")
    /// Posted by menu cards that want a provider re-read from its credential
    /// source (one Keychain prompt at most). `userInfo["provider"]` is the
    /// `UsageProvider` raw value.
    static let runicReloadProvider = Notification.Name("runicReloadProvider")
}
