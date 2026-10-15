import CryptoKit
import Foundation
import RunicCore
import Testing

struct AccountRegistryTests {
    private static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    @Test
    func `registry stores added accounts only and lists the default first`() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-accounts-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(AccountRegistry.load(url: url).isEmpty)
        #expect(AccountRegistry.accounts(for: .claude, added: []).map(\.id) == [UsageProvider.claude.defaultAccount])

        let work = ProviderAccount(
            id: AccountID(kind: .claude, slug: "a1b2"),
            displayName: "work",
            credential: .oauthDir("/Users/me/Library/Application Support/Runic/accounts/a1b2"))
        let off = ProviderAccount(id: AccountID(kind: .claude, slug: "c3d4"), displayName: "old", isEnabled: false)
        let cn = ProviderAccount(id: AccountID(kind: .kimi, slug: "cn"), displayName: "cn", region: .china)
        try AccountRegistry.save([.default(for: .claude), work, off, cn], url: url)

        let onDisk = try String(bytes: Data(contentsOf: url), encoding: .utf8) ?? ""
        #expect(onDisk.contains(#""type" : "oauthDir""#))
        #expect(onDisk.contains(#""id" : "claude~a1b2""#))
        let loaded = AccountRegistry.load(url: url)
        #expect(loaded.map(\.id.rawValue) == ["claude~a1b2", "claude~c3d4", "kimi~cn"])
        #expect(loaded.first?.credential == .oauthDir("/Users/me/Library/Application Support/Runic/accounts/a1b2"))
        #expect(loaded.last?.region == .china)

        let claude = AccountRegistry.accounts(for: .claude, added: loaded)
        #expect(claude.map(\.id.rawValue) == ["claude", "claude~a1b2"])
        #expect(AccountRegistry.accounts(for: .codex, added: loaded).map(\.id.rawValue) == ["codex"])
    }

    @Test
    func `an oauth dir credential overrides the vendor's location variable for its kind only`() {
        let dir = CredentialRef.oauthDir("/tmp/acct")
        #expect(dir.environmentOverrides(for: .claude) == ["CLAUDE_CONFIG_DIR": "/tmp/acct"])
        #expect(dir.environmentOverrides(for: .codex) == ["CODEX_HOME": "/tmp/acct"])
        #expect(dir.environmentOverrides(for: .kimi) == ["KIMI_CODE_HOME": "/tmp/acct"])
        #expect(dir.environmentOverrides(for: .deepseek).isEmpty)
        #expect(CredentialRef.keychainItem("x").environmentOverrides(for: .claude).isEmpty)
    }

    @Test
    func `claude credential location follows CLAUDE_CONFIG_DIR with a hashed keychain service`() {
        let base = ClaudeCredentialLocation.default
        #expect(base.keychainService == "Claude Code-credentials")
        #expect(base.cacheAccount == "claude-oauth-cache")
        #expect(base.credentialsFileURL.path.hasSuffix("/.claude/.credentials.json"))
        #expect(ClaudeCredentialLocation(environment: [:]) == base)
        #expect(ClaudeCredentialLocation(environment: ["CLAUDE_CONFIG_DIR": "  "]) == base)

        let custom = ClaudeCredentialLocation(environment: ["CLAUDE_CONFIG_DIR": "/tmp/claude-work"])
        #expect(custom.configDir == "/tmp/claude-work")
        let suffix = custom.directorySuffix
        // sha256("/tmp/claude-work") = 6e2f9c…; the CLI hashes the raw string.
        #expect(suffix == String(Self.sha256Hex("/tmp/claude-work").prefix(8)))
        #expect(suffix?.count == 8)
        #expect(suffix?.allSatisfy(\.isHexDigit) == true)
        // Secure-storage override replaces the hash source; empty means no suffix.
        #expect(ClaudeCredentialLocation(
            environment: ["CLAUDE_CONFIG_DIR": "/tmp/claude-work", "CLAUDE_SECURESTORAGE_CONFIG_DIR": "/elsewhere"])
            .directorySuffix == String(Self.sha256Hex("/elsewhere").prefix(8)))
        #expect(ClaudeCredentialLocation(
            environment: ["CLAUDE_CONFIG_DIR": "/tmp/claude-work", "CLAUDE_SECURESTORAGE_CONFIG_DIR": ""])
            .directorySuffix == nil)
        #expect(custom.keychainService == "Claude Code-credentials-\(suffix ?? "")")
        #expect(custom.cacheAccount == "claude-oauth-cache.\(suffix ?? "")")
        #expect(custom.credentialsFileURL.path == "/tmp/claude-work/.credentials.json")
        // Same directory, same item; a different directory, a different item.
        #expect(ClaudeCredentialLocation(configDir: "/tmp/claude-work").keychainService == custom.keychainService)
        #expect(ClaudeCredentialLocation(configDir: "/tmp/claude-home").keychainService != custom.keychainService)
    }

    @Test
    func `codex auth file follows CODEX_HOME`() {
        #expect(CodexOAuthCredentialsStore.authFilePath(environment: [:]).path.hasSuffix("/.codex/auth.json"))
        #expect(CodexOAuthCredentialsStore.authFilePath(environment: ["CODEX_HOME": "/tmp/codex-org"]).path
            == "/tmp/codex-org/auth.json")
        #expect(CodexOAuthCredentialsStore.authFilePath(environment: ["CODEX_HOME": " "]).path
            .hasSuffix("/.codex/auth.json"))
    }
}
