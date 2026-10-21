import Foundation
#if os(macOS)
import Security
#endif

/// Runic's own copy of a website login (a `Cookie:` header) taken from the
/// browser once, when the user connects it in Settings. Reading the browser can
/// raise the "Chrome Safe Storage" Keychain dialog, which background refreshes
/// are never allowed to show, so refreshes use this copy instead. The item is
/// Runic-owned (no prompt to read it back) — same scheme as Claude's
/// `claude-web-session`.
public struct SavedBrowserSession: Sendable {
    public let account: String

    public init(account: String) {
        self.account = account
    }

    public static let siliconFlow = SavedBrowserSession(account: "siliconflow-web-session")
    public static let siliconFlowCN = SavedBrowserSession(account: "siliconflow-cn-web-session")
    public static let ollamaCloud = SavedBrowserSession(account: "ollama-cloud-web-session")

    public func load() -> String? {
        #if os(macOS)
        var query = self.baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
        var result: AnyObject?
        guard RunicKeychainGate.copyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8), !value.isEmpty
        else { return nil }
        return value
        #else
        return nil
        #endif
    }

    public func store(_ value: String) {
        #if os(macOS)
        self.clear()
        var query = self.baseQuery()
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        _ = RunicKeychainGate.add(query as CFDictionary)
        #endif
    }

    public func clear() {
        #if os(macOS)
        var query = self.baseQuery()
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
        _ = RunicKeychainGate.delete(query as CFDictionary)
        #endif
    }

    public var isConnected: Bool {
        self.load() != nil
    }

    #if os(macOS)
    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: RunicKeychainService.providerCredentials,
            kSecAttrAccount as String: self.account,
        ]
    }
    #endif
}
