import Foundation
#if os(macOS)
import Security
#endif

/// Runic-owned copy of the Claude access token.
///
/// `Claude Code-credentials` is written by the Claude CLI, so its Keychain ACL
/// trusts that binary and not Runic — every read from the app can raise the
/// "Runic wants to use your confidential information" dialog, and the grant is
/// lost again as soon as the CLI rewrites the item on a token refresh. Copying
/// the token into an item Runic itself created removes the prompt from the
/// refresh path entirely: the app owns that item, so it is never asked.
///
/// Only what the usage fetch needs is copied. The refresh token stays in the
/// CLI's item — Runic never refreshes, so it has no reason to hold one.
public enum ClaudeOAuthCredentialCache {
    private static let log = RunicLog.logger("claude-oauth-cache")
    private static let service = RunicKeychainService.providerCredentials
    private static let account = "claude-oauth-cache"

    private struct Payload: Codable {
        let accessToken: String
        let expiresAt: Date?
        let scopes: [String]
        let rateLimitTier: String?
        /// When Runic copied the token. Absent on caches written before 2.8.1.
        let cachedAt: Date?
    }

    /// Cached credentials, or nil when absent, unreadable, or past expiry.
    public static func load() -> ClaudeOAuthCredentials? {
        #if os(macOS)
        guard let data = self.read() else { return nil }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        let credentials = ClaudeOAuthCredentials(
            accessToken: payload.accessToken,
            refreshToken: nil,
            expiresAt: payload.expiresAt,
            scopes: payload.scopes,
            rateLimitTier: payload.rateLimitTier)
        return credentials.isExpired ? nil : credentials
        #else
        return nil
        #endif
    }

    /// When the current cache entry was written, or nil when there is none or
    /// it predates the timestamp. Read even past expiry — the reload button
    /// compares it against the CLI item's modification date.
    public static func cachedAt() -> Date? {
        #if os(macOS)
        guard let data = self.read(),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }
        return payload.cachedAt
        #else
        return nil
        #endif
    }

    public static func store(_ credentials: ClaudeOAuthCredentials) {
        #if os(macOS)
        let payload = Payload(
            accessToken: credentials.accessToken,
            expiresAt: credentials.expiresAt,
            scopes: credentials.scopes,
            rateLimitTier: credentials.rateLimitTier,
            cachedAt: Date())
        guard let data = try? JSONEncoder().encode(payload) else { return }

        // Delete-then-add: SecItemUpdate leaves a stale ACL behind.
        var deleteQuery = self.baseQuery()
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &deleteQuery)
        _ = RunicKeychainGate.delete(deleteQuery as CFDictionary)

        var addQuery = self.baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = RunicKeychainGate.add(addQuery as CFDictionary)
        if status != errSecSuccess {
            Self.log.error("Keychain add failed: \(status)")
        }
        #endif
    }

    public static func clear() {
        #if os(macOS)
        var query = self.baseQuery()
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
        _ = RunicKeychainGate.delete(query as CFDictionary)
        #endif
    }

    #if os(macOS)
    private static func read() -> Data? {
        var query = self.baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)

        var result: AnyObject?
        let status = RunicKeychainGate.copyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, !data.isEmpty else {
            return nil
        }
        return data
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: self.account,
        ]
    }
    #endif
}

/// Suppresses the legacy Keychain ACL dialog for the duration of `body`.
///
/// `kSecUseAuthenticationUI: fail` covers items guarded by biometry or a
/// passcode, but the file-based login keychain's "app wants to access" prompt
/// is driven by the item's ACL and only `SecKeychainSetUserInteractionAllowed`
/// turns it off. The previous value is restored afterwards so an explicitly
/// user-initiated read can still prompt.
public enum ClaudeKeychainInteraction {
    public static func withoutUserInteraction<T>(_ body: () throws -> T) rethrows -> T {
        #if os(macOS)
        var previous: DarwinBoolean = true
        let read = SecKeychainGetUserInteractionAllowed(&previous)
        if SecKeychainSetUserInteractionAllowed(false) != errSecSuccess {
            return try body()
        }
        defer {
            if read == errSecSuccess {
                _ = SecKeychainSetUserInteractionAllowed(previous.boolValue)
            } else {
                _ = SecKeychainSetUserInteractionAllowed(true)
            }
        }
        return try body()
        #else
        return try body()
        #endif
    }
}
