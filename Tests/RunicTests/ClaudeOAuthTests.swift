import Foundation
import Testing
@testable import RunicCore

struct ClaudeOAuthTests {
    private final class DummyClaudeFetcher: ClaudeUsageFetching, @unchecked Sendable {
        func loadLatestUsage(model: String) async throws -> ClaudeUsageSnapshot {
            throw URLError(.unsupportedURL)
        }

        func debugRawProbe(model: String) async -> String {
            ""
        }

        func detectVersion() -> String? {
            nil
        }
    }

    @Test
    func `parses O auth credentials`() throws {
        let json = """
        {
          "claudeAiOauth": {
            "accessToken": "test-token",
            "refreshToken": "test-refresh",
            "expiresAt": 4102444800000,
            "scopes": ["usage:read"],
            "rateLimitTier": "default_claude_max_20x"
          }
        }
        """
        let creds = try ClaudeOAuthCredentials.parse(data: Data(json.utf8))
        #expect(creds.accessToken == "test-token")
        #expect(creds.refreshToken == "test-refresh")
        #expect(creds.scopes == ["usage:read"])
        #expect(creds.rateLimitTier == "default_claude_max_20x")
        #expect(creds.isExpired == false)
    }

    @Test
    func `missing access token throws`() {
        let json = """
        {
          "claudeAiOauth": {
            "accessToken": "",
            "refreshToken": "test-refresh",
            "expiresAt": 1735689600000
          }
        }
        """
        #expect(throws: ClaudeOAuthCredentialsError.self) {
            _ = try ClaudeOAuthCredentials.parse(data: Data(json.utf8))
        }
    }

    @Test
    func `missing O auth block throws`() {
        let json = """
        { "other": { "accessToken": "nope" } }
        """
        #expect(throws: ClaudeOAuthCredentialsError.self) {
            _ = try ClaudeOAuthCredentials.parse(data: Data(json.utf8))
        }
    }

    @Test
    func `treats missing expiry as expired`() {
        let creds = ClaudeOAuthCredentials(
            accessToken: "token",
            refreshToken: nil,
            expiresAt: nil,
            scopes: [],
            rateLimitTier: nil)
        #expect(creds.isExpired == true)
    }

    @Test
    func `maps O auth usage to snapshot`() throws {
        let json = """
        {
          "five_hour": { "utilization": 12.5, "resets_at": "2025-12-25T12:00:00.000Z" },
          "seven_day": { "utilization": 30, "resets_at": "2025-12-31T00:00:00.000Z" },
          "seven_day_sonnet": { "utilization": 5 }
        }
        """
        let snap = try ClaudeUsageFetcher._mapOAuthUsageForTesting(
            Data(json.utf8),
            rateLimitTier: "claude_pro")
        #expect(snap.primary.usedPercent == 12.5)
        #expect(snap.primary.windowMinutes == 300)
        #expect(snap.secondary?.usedPercent == 30)
        #expect(snap.opus?.usedPercent == 5)
        #expect(snap.primary.resetsAt != nil)
        #expect(snap.loginMethod == "Claude Pro")
    }

    @Test
    func `reads session and weekly from limits when flat windows are empty`() throws {
        let json = """
        {
          "five_hour": null,
          "seven_day": { "utilization": null, "resets_at": null },
          "limits": [
            { "kind": "session", "group": "session", "percent": 32,
              "resets_at": "2026-11-03T15:00:00.000Z", "scope": null, "is_active": false },
            { "kind": "weekly_all", "group": "weekly", "percent": 24,
              "resets_at": "2026-11-07T02:00:00.000Z", "scope": null, "is_active": false },
            { "kind": "weekly_scoped", "group": "weekly", "percent": 46,
              "resets_at": "2026-11-07T02:00:00.000Z",
              "scope": { "model": { "id": null, "display_name": "Fable" } }, "is_active": true }
          ]
        }
        """
        let snap = try ClaudeUsageFetcher._mapOAuthUsageForTesting(Data(json.utf8))
        #expect(snap.primary.usedPercent == 32)
        #expect(snap.primary.windowMinutes == 300)
        #expect(snap.primary.resetsAt != nil)
        #expect(snap.secondary?.usedPercent == 24)
        #expect(snap.secondary?.windowMinutes == 7 * 24 * 60)
        #expect(snap.opus?.label == "Fable weekly")
    }

    @Test
    func `flat windows win over limits`() throws {
        let json = """
        {
          "five_hour": { "utilization": 12, "resets_at": "2026-11-03T15:00:00.000Z" },
          "limits": [ { "kind": "session", "percent": 99, "scope": null } ]
        }
        """
        let snap = try ClaudeUsageFetcher._mapOAuthUsageForTesting(Data(json.utf8))
        #expect(snap.primary.usedPercent == 12)
    }

    @Test
    func `a weekly only reply leads with weekly instead of failing`() throws {
        let json = """
        {
          "five_hour": null,
          "seven_day": { "utilization": 8, "resets_at": "2026-11-07T02:00:00.000Z" }
        }
        """
        let snap = try ClaudeUsageFetcher._mapOAuthUsageForTesting(Data(json.utf8))
        #expect(snap.primary.usedPercent == 8)
        #expect(snap.primary.windowMinutes == 7 * 24 * 60)
        #expect(snap.secondary == nil)
    }

    @Test
    func `a reply with no windows says so without a gauge`() throws {
        let snap = try ClaudeUsageFetcher._mapOAuthUsageForTesting(Data(#"{"five_hour": null, "limits": []}"#.utf8))
        #expect(snap.primary == .noLimitsReported)
        #expect(snap.primary.gaugePercent(showUsed: true) == nil)
    }

    @Test
    func `maps O auth extra usage`() throws {
        let json = """
        {
          "five_hour": { "utilization": 1, "resets_at": "2025-12-25T12:00:00.000Z" },
          "extra_usage": {
            "is_enabled": true,
            "monthly_limit": 20.5,
            "used_credits": 3.25
          }
        }
        """
        let snap = try ClaudeUsageFetcher._mapOAuthUsageForTesting(Data(json.utf8))
        #expect(snap.providerCost?.currencyCode == "USD")
        #expect(snap.providerCost?.limit == 20.5)
        #expect(snap.providerCost?.used == 3.25)
    }

    @Test
    func `prefers opus when sonnet missing`() throws {
        let json = """
        {
          "five_hour": { "utilization": 10, "resets_at": "2025-12-25T12:00:00.000Z" },
          "seven_day_opus": { "utilization": 42 }
        }
        """
        let snap = try ClaudeUsageFetcher._mapOAuthUsageForTesting(Data(json.utf8))
        #expect(snap.opus?.usedPercent == 42)
    }

    @Test
    func `skips extra usage when disabled`() throws {
        let json = """
        {
          "five_hour": { "utilization": 1, "resets_at": "2025-12-25T12:00:00.000Z" },
          "extra_usage": {
            "is_enabled": false,
            "monthly_limit": 100,
            "used_credits": 10
          }
        }
        """
        let snap = try ClaudeUsageFetcher._mapOAuthUsageForTesting(Data(json.utf8))
        #expect(snap.providerCost == nil)
    }

    // MARK: - Scope-based strategy resolution

    @Test
    func `oauth requires user profile scope`() {
        // With user:profile scope, OAuth should be selected.
        let withProfile = ClaudeProviderDescriptor.resolveUsageStrategy(
            debugMenuEnabled: false,
            selectedDataSource: .oauth,
            webExtrasEnabled: false,
            hasWebSession: true,
            hasOAuthCredentials: true)
        #expect(withProfile.dataSource == .oauth)

        // Without user:profile scope (hasOAuthCredentials=false), should fall back to web.
        let withoutProfile = ClaudeProviderDescriptor.resolveUsageStrategy(
            debugMenuEnabled: false,
            selectedDataSource: .oauth,
            webExtrasEnabled: false,
            hasWebSession: true,
            hasOAuthCredentials: false)
        #expect(withoutProfile.dataSource == .web)
    }

    @Test
    func `falls back to CLI when no web or O auth`() {
        let strategy = ClaudeProviderDescriptor.resolveUsageStrategy(
            debugMenuEnabled: false,
            selectedDataSource: .oauth,
            webExtrasEnabled: false,
            hasWebSession: false,
            hasOAuthCredentials: false)
        #expect(strategy.dataSource == .cli)
    }

    @Test
    func `app auto refresh does not launch Claude CLI unless debug explicitly selects it`() async {
        let strategy = ClaudeCLIFetchStrategy(useWebExtras: false)

        let autoContext = self.makeContext(
            runtime: .app,
            sourceMode: .auto,
            debugMenuEnabled: false,
            selectedDataSource: .oauth)
        #expect(await strategy.isAvailable(autoContext) == false)

        let debugCLIContext = self.makeContext(
            runtime: .app,
            sourceMode: .auto,
            debugMenuEnabled: true,
            selectedDataSource: .cli)
        #expect(await strategy.isAvailable(debugCLIContext) == true)

        let cliContext = self.makeContext(
            runtime: .cli,
            sourceMode: .cli,
            debugMenuEnabled: false,
            selectedDataSource: .oauth)
        #expect(await strategy.isAvailable(cliContext) == true)
    }

    private func makeContext(
        runtime: ProviderRuntime,
        sourceMode: ProviderSourceMode,
        debugMenuEnabled: Bool,
        selectedDataSource: ClaudeUsageDataSource) -> ProviderFetchContext
    {
        ProviderFetchContext(
            runtime: runtime,
            sourceMode: sourceMode,
            includeCredits: false,
            webTimeout: 60,
            webDebugDumpHTML: false,
            verbose: false,
            env: [:],
            settings: ProviderSettingsSnapshot(
                debugMenuEnabled: debugMenuEnabled,
                codex: nil,
                claude: ProviderSettingsSnapshot.ClaudeProviderSettings(
                    usageDataSource: selectedDataSource,
                    webExtrasEnabled: false),
                zai: nil,
                copilot: nil,
                azure: nil,
                bedrock: nil),
            fetcher: UsageFetcher(environment: [:]),
            claudeFetcher: DummyClaudeFetcher())
    }
}
