import Foundation
#if os(macOS)
import Security
#endif

/// Banked "reset your limits" grants from claude.ai.
///
/// Claude's OAuth usage endpoint (Claude Code's login) returns the resets
/// block with an empty grant list for launch grants that claude.ai lists
/// (observed 2026-09-23: claude.ai showed `opus55-launch-promax-20260921`,
/// OAuth showed none). claude.ai is reached with the browser's `sessionKey`.
/// Reading it from the browser can raise a Keychain dialog, so that happens
/// only when the user turns the option on; Runic keeps its own copy after.
public enum ClaudeWebResets {
    public enum Failure: LocalizedError, Sendable {
        case noBrowserSession
        case sessionExpired

        public var errorDescription: String? {
            switch self {
            case .noBrowserSession:
                "No claude.ai login found in your browsers. Sign in at claude.ai, then turn this on again."
            case .sessionExpired:
                "The saved claude.ai login expired. Turn this off and on again to reconnect."
            }
        }
    }

    /// User action: find the claude.ai login in the browser (may prompt once)
    /// and save a Runic-owned copy. Returns where it was found ("Chrome").
    public static func connect() throws -> String {
        let info: ClaudeWebAPIFetcher.SessionKeyInfo
        do {
            info = try ClaudeWebAPIFetcher.sessionKeyInfo()
        } catch {
            throw Failure.noBrowserSession
        }
        SessionStore.store(info.key)
        return info.sourceLabel
    }

    public static func disconnect() {
        SessionStore.clear()
    }

    public static var isConnected: Bool {
        SessionStore.load() != nil
    }

    /// Resets for the chat org, using the saved session only (never the
    /// browser, never a prompt). Nil when not connected or nothing is banked.
    public static func fetchResetCredits() async throws -> UsageResetCredits? {
        guard let sessionKey = SessionStore.load() else { return nil }
        do {
            let organization = try await ClaudeWebAPIFetcher.fetchOrganizationInfo(sessionKey: sessionKey)
            let usage = try await ClaudeWebAPIFetcher.fetchUsageData(
                orgId: organization.id,
                sessionKey: sessionKey)
            return usage.resetCredits
        } catch ClaudeWebAPIFetcher.FetchError.unauthorized {
            throw Failure.sessionExpired
        }
    }

    /// Runic-owned Keychain copy of the claude.ai session.
    enum SessionStore {
        private static let service = RunicKeychainService.providerCredentials
        private static let account = "claude-web-session"

        static func load() -> String? {
            #if os(macOS)
            var query = self.baseQuery()
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            query[kSecReturnData as String] = true
            RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
            var result: AnyObject?
            guard RunicKeychainGate.copyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data,
                  let key = String(data: data, encoding: .utf8), !key.isEmpty
            else { return nil }
            return key
            #else
            return nil
            #endif
        }

        static func store(_ key: String) {
            #if os(macOS)
            self.clear()
            var query = self.baseQuery()
            query[kSecValueData as String] = Data(key.utf8)
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            _ = RunicKeychainGate.add(query as CFDictionary)
            #endif
        }

        static func clear() {
            #if os(macOS)
            var query = self.baseQuery()
            RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)
            _ = RunicKeychainGate.delete(query as CFDictionary)
            #endif
        }

        #if os(macOS)
        private static func baseQuery() -> [String: Any] {
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: self.account,
            ]
        }
        #endif
    }
}
