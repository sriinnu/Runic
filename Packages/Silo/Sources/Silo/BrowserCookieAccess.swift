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

    /// Receives one report per Chromium database read in this task. Off by
    /// default. The report's host table is browsing data, so a receiver must
    /// keep only the hosts it is asking about.
    @TaskLocal public static var readReporter: (@Sendable (BrowserCookieReadReport) -> Void)?
}

/// What a Chromium cookie read found. Counts and hosts, never cookie values.
public struct BrowserCookieReadReport: Sendable {
    public struct HostCount: Sendable {
        public var rows = 0
        public var failed = 0
    }

    public let store: String
    public var rows = 0
    public var encrypted = 0
    public var failed = 0
    /// How many values carry each format prefix ("v10", "v11", or "other").
    public var prefixes: [String: Int] = [:]
    public var failedPrefixes: [String: Int] = [:]
    public var hosts: [String: HostCount] = [:]

    public init(store: String) {
        self.store = store
    }

    static func prefix(of data: Data) -> String {
        let head = data.prefix(3)
        guard head.count == 3, let text = String(data: head, encoding: .ascii),
              text.first == "v", text.dropFirst().allSatisfy(\.isNumber)
        else { return "other" }
        return text
    }
}
