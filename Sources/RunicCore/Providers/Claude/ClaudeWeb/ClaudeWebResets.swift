import Foundation
#if os(macOS)
import Security
import Silo
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
                "No claude.ai login found. Runic reads Chrome, Edge, Brave and Arc (allow the Keychain "
                    + "prompt when it appears); Safari's cookies also need Full Disk Access for Runic in "
                    + "System Settings → Privacy & Security. Sign in at claude.ai in one of them, then turn this on again."
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
            // The user just flipped the switch: this is the one read allowed
            // to show the browser's Keychain dialog ("Chrome Safe Storage").
            info = try BrowserCookieAccess.$allowsKeychainPrompt.withValue(true) {
                try ClaudeWebAPIFetcher.sessionKeyInfo()
            }
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

    private static let failureLock = NSLock()
    private nonisolated(unsafe) static var failure: String?

    /// Why the last claude.ai resets fetch failed, for the settings status line.
    public static var lastFailure: String? {
        self.failureLock.withLock { self.failure }
    }

    static func setLastFailure(_ message: String?) {
        self.failureLock.withLock { self.failure = message }
    }

    /// Adds claude.ai resets to a snapshot that has none. Best effort: a
    /// failure is remembered for the settings line and the usage still shows.
    static func attach(to snapshot: ClaudeUsageSnapshot) async -> ClaudeUsageSnapshot {
        guard self.isConnected else { return snapshot }
        do {
            guard let extras = try await self.fetchExtras() else { return snapshot }
            self.setLastFailure(nil)
            var updated = snapshot
            if updated.resetCredits == nil { updated = updated.with(resetCredits: extras.resetCredits) }
            if let balance = extras.creditBalance { updated = updated.with(creditBalance: balance) }
            return updated
        } catch {
            self.setLastFailure(error.localizedDescription)
            return snapshot
        }
    }

    struct Extras {
        let resetCredits: UsageResetCredits?
        /// Prepaid usage-credit balance (`prepaid/credits`), with its currency.
        let creditBalance: ClaudeMoney?
    }

    /// Resets and the usage-credit balance for the chat org, using the saved
    /// session only (never the browser, never a prompt). Nil when not connected.
    static func fetchExtras() async throws -> Extras? {
        guard let sessionKey = SessionStore.load() else { return nil }
        do {
            let organization = try await ClaudeWebAPIFetcher.fetchOrganizationInfo(sessionKey: sessionKey)
            let usage = try await ClaudeWebAPIFetcher.fetchUsageData(
                orgId: organization.id,
                sessionKey: sessionKey)
            let balance = await Self.fetchCreditBalance(orgId: organization.id, sessionKey: sessionKey)
            return Extras(resetCredits: usage.resetCredits, creditBalance: balance)
        } catch ClaudeWebAPIFetcher.FetchError.unauthorized {
            throw Failure.sessionExpired
        }
    }

    /// Best effort: `GET /api/organizations/{org}/prepaid/credits` →
    /// `balance.money {amount_minor, currency, exponent}`.
    static func fetchCreditBalance(orgId: String, sessionKey: String) async -> ClaudeMoney? {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/prepaid/credits") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return Self.parseCreditBalance(data)
    }

    static func parseCreditBalance(_ data: Data) -> ClaudeMoney? {
        struct Envelope: Decodable {
            struct Balance: Decodable { let money: ClaudeMoney? }
            let balance: Balance?
        }
        return (try? JSONDecoder().decode(Envelope.self, from: data))?.balance?.money
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
