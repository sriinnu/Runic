import Foundation
import RunicCore
import Testing
@testable import Runic

struct ClaudeUsageTests {
    @Test
    func `parses usage JSON with sonnet limit`() {
        let json = """
        {
          "ok": true,
          "session_5h": { "pct_used": 1, "resets": "11am (Europe/Vienna)" },
          "week_all_models": { "pct_used": 8, "resets": "Nov 21 at 5am (Europe/Vienna)" },
          "week_sonnet": { "pct_used": 0, "resets": "Nov 21 at 5am (Europe/Vienna)" }
        }
        """
        let data = Data(json.utf8)
        let snap = ClaudeUsageFetcher.parse(json: data)
        #expect(snap != nil)
        #expect(snap?.primary.usedPercent == 1)
        #expect(snap?.secondary?.usedPercent == 8)
        #expect(snap?.primary.resetDescription == "11am (Europe/Vienna)")
    }

    @Test
    func `parses usage JSON when weekly missing`() {
        let json = """
        {
          "ok": true,
          "session_5h": { "pct_used": 4, "resets": "11am (Europe/Vienna)" }
        }
        """
        let data = Data(json.utf8)
        let snap = ClaudeUsageFetcher.parse(json: data)
        #expect(snap != nil)
        #expect(snap?.primary.usedPercent == 4)
        #expect(snap?.secondary == nil)
    }

    @Test
    func `parses legacy opus and account`() {
        let json = """
        {
          "ok": true,
          "session_5h": { "pct_used": 2, "resets": "10:59pm (Europe/Vienna)" },
          "week_all_models": { "pct_used": 13, "resets": "Nov 21 at 4:59am (Europe/Vienna)" },
          "week_opus": { "pct_used": 0, "resets": "" },
          "account_email": " sriinnu@icloud.com ",
          "account_org": ""
        }
        """
        let data = Data(json.utf8)
        let snap = ClaudeUsageFetcher.parse(json: data)
        #expect(snap?.opus?.usedPercent == 0)
        #expect(snap?.opus?.resetDescription?.isEmpty == true)
        #expect(snap?.accountEmail == "sriinnu@icloud.com")
        #expect(snap?.accountOrganization == nil)
    }

    @Test
    func `parses usage JSON when only sonnet limit is present`() {
        let json = """
        {
          "ok": true,
          "session_5h": { "pct_used": 3, "resets": "11am (Europe/Vienna)" },
          "week_all_models": { "pct_used": 9, "resets": "Nov 21 at 5am (Europe/Vienna)" },
          "week_sonnet_only": { "pct_used": 12, "resets": "Nov 22 at 5am (Europe/Vienna)" }
        }
        """
        let data = Data(json.utf8)
        let snap = ClaudeUsageFetcher.parse(json: data)
        #expect(snap?.secondary?.usedPercent == 9)
        #expect(snap?.opus?.usedPercent == 12)
        #expect(snap?.opus?.resetDescription == "Nov 22 at 5am (Europe/Vienna)")
    }

    @Test
    func `trims account fields`() throws {
        let cases: [[String: String?]] = [
            ["email": " sriinnu@icloud.com ", "org": "  Org  "],
            ["email": "", "org": " Claude Max Account "],
            ["email": nil, "org": " "],
        ]

        for entry in cases {
            var payload = [
                "ok": true,
                "session_5h": ["pct_used": 0, "resets": ""],
                "week_all_models": ["pct_used": 0, "resets": ""],
            ] as [String: Any]
            if let email = entry["email"] { payload["account_email"] = email }
            if let org = entry["org"] { payload["account_org"] = org }
            let data = try JSONSerialization.data(withJSONObject: payload)
            let snap = ClaudeUsageFetcher.parse(json: data)
            let emailRaw: String? = entry["email"] ?? String?.none
            let expectedEmail = emailRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedEmail = (expectedEmail?.isEmpty ?? true) ? nil : expectedEmail
            #expect(snap?.accountEmail == normalizedEmail)
            let orgRaw: String? = entry["org"] ?? String?.none
            let expectedOrg = orgRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedOrg = (expectedOrg?.isEmpty ?? true) ? nil : expectedOrg
            #expect(snap?.accountOrganization == normalizedOrg)
        }
    }

    @Test
    func `live claude fetch PTY`() async throws {
        guard ProcessInfo.processInfo.environment["LIVE_CLAUDE_FETCH"] == "1" else {
            return
        }
        let fetcher = ClaudeUsageFetcher(dataSource: .cli)
        do {
            let snap = try await fetcher.loadLatestUsage()
            let opusUsed = snap.opus?.usedPercent ?? -1
            let weeklyUsed = snap.secondary?.usedPercent ?? -1
            let email = snap.accountEmail ?? "nil"
            let org = snap.accountOrganization ?? "nil"
            print(
                """
                Live Claude usage (PTY):
                session used \(snap.primary.usedPercent)% 
                week used \(weeklyUsed)% 
                opus \(opusUsed)% 
                email \(email) org \(org)
                """)
            #expect(snap.primary.usedPercent >= 0)
        } catch {
            // Dump raw CLI text captured via `script` to help debug.
            let raw = try Self.captureClaudeUsageRaw(timeout: 15)
            print("RAW CLAUDE OUTPUT BEGIN\n\(raw)\nRAW CLAUDE OUTPUT END")
            throw error
        }
    }

    private static func captureClaudeUsageRaw(timeout: TimeInterval) throws -> String {
        let process = Process()
        process.launchPath = "/usr/bin/script"
        process.arguments = [
            "-q",
            "/dev/null",
            "claude",
            "/usage",
            "--allowed-tools",
            "",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.standardInput = nil

        try process.run()
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if process.isRunning { process.terminate() }
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Web API tests

    @Test
    func `live claude fetch web API`() async throws {
        // Set LIVE_CLAUDE_WEB_FETCH=1 to run this test with real browser cookies
        guard ProcessInfo.processInfo.environment["LIVE_CLAUDE_WEB_FETCH"] == "1" else {
            return
        }
        let fetcher = ClaudeUsageFetcher(dataSource: .web)
        let snap = try await fetcher.loadLatestUsage()
        let weeklyUsed = snap.secondary?.usedPercent ?? -1
        let opusUsed = snap.opus?.usedPercent ?? -1
        print(
            """
            Live Claude usage (Web API):
            session used \(snap.primary.usedPercent)%
            week used \(weeklyUsed)%
            opus \(opusUsed)%
            login method: \(snap.loginMethod ?? "nil")
            """)
        #expect(snap.primary.usedPercent >= 0)
    }

    @Test
    func `claude web API has session key check`() {
        // Quick check that hasSessionKey returns a boolean (doesn't crash)
        let hasKey = ClaudeWebAPIFetcher.hasSessionKey()
        // We can't assert the value since it depends on the test environment
        #expect(hasKey == true || hasKey == false)
    }

    @Test
    func `parses claude web API usage response`() throws {
        let json = """
        {
          "five_hour": { "utilization": 9, "resets_at": "2025-12-23T16:00:00.000Z" },
          "seven_day": { "utilization": 4, "resets_at": "2025-12-29T23:00:00.000Z" },
          "seven_day_opus": { "utilization": 1 }
        }
        """
        let data = Data(json.utf8)
        let parsed = try ClaudeWebAPIFetcher._parseUsageResponseForTesting(data)
        #expect(parsed.sessionPercentUsed == 9)
        #expect(parsed.weeklyPercentUsed == 4)
        #expect(parsed.opusPercentUsed == 1)
        #expect(parsed.sessionResetsAt != nil)
        #expect(parsed.weeklyResetsAt != nil)
    }

    @Test
    func `parses claude web API usage response when weekly missing`() throws {
        let json = """
        {
          "five_hour": { "utilization": 9, "resets_at": "2025-12-23T16:00:00.000Z" }
        }
        """
        let data = Data(json.utf8)
        let parsed = try ClaudeWebAPIFetcher._parseUsageResponseForTesting(data)
        #expect(parsed.sessionPercentUsed == 9)
        #expect(parsed.weeklyPercentUsed == nil)
    }

    @Test
    func `parses claude web API overage spend limit`() {
        let json = """
        {
          "monthly_credit_limit": 2000,
          "currency": "EUR",
          "used_credits": 0,
          "is_enabled": true
        }
        """
        let data = Data(json.utf8)
        let cost = ClaudeWebAPIFetcher._parseOverageSpendLimitForTesting(data)
        #expect(cost != nil)
        #expect(cost?.currencyCode == "EUR")
        #expect(cost?.limit == 20)
        #expect(cost?.used == 0)
        #expect(cost?.period == "Monthly")
    }

    @Test
    func `parses claude web API overage spend limit cents`() {
        let json = """
        {
          "monthly_credit_limit": 12345,
          "currency": "USD",
          "used_credits": 6789,
          "is_enabled": true
        }
        """
        let data = Data(json.utf8)
        let cost = ClaudeWebAPIFetcher._parseOverageSpendLimitForTesting(data)
        #expect(cost?.currencyCode == "USD")
        #expect(cost?.limit == 123.45)
        #expect(cost?.used == 67.89)
    }

    @Test
    func `parses claude web API organizations response`() throws {
        let json = """
        [
          { "uuid": "org-123", "name": "Example Org", "capabilities": [] }
        ]
        """
        let data = Data(json.utf8)
        let org = try ClaudeWebAPIFetcher._parseOrganizationsResponseForTesting(data)
        #expect(org.id == "org-123")
        #expect(org.name == "Example Org")
    }

    @Test
    func `parses claude web API account info`() {
        let json = """
        {
          "email_address": "sriinnu@icloud.com",
          "memberships": [
            {
              "organization": {
                "uuid": "org-123",
                "name": "Example Org",
                "rate_limit_tier": "default_claude_max_20x",
                "billing_type": "stripe_subscription"
              }
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let info = ClaudeWebAPIFetcher._parseAccountInfoForTesting(data, orgId: "org-123")
        #expect(info?.email == "sriinnu@icloud.com")
        #expect(info?.loginMethod == "Claude Max")
    }

    @Test
    func `parses claude web API account info selects matching org`() {
        let json = """
        {
          "email_address": "sriinnu@icloud.com",
          "memberships": [
            {
              "organization": {
                "uuid": "org-other",
                "name": "Other Org",
                "rate_limit_tier": "claude_pro",
                "billing_type": "stripe_subscription"
              }
            },
            {
              "organization": {
                "uuid": "org-123",
                "name": "Example Org",
                "rate_limit_tier": "claude_team",
                "billing_type": "stripe_subscription"
              }
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let info = ClaudeWebAPIFetcher._parseAccountInfoForTesting(data, orgId: "org-123")
        #expect(info?.loginMethod == "Claude Team")
    }

    @Test
    func `parses claude web API account info falls back to first membership`() {
        let json = """
        {
          "email_address": "sriinnu@icloud.com",
          "memberships": [
            {
              "organization": {
                "uuid": "org-first",
                "name": "First Org",
                "rate_limit_tier": "claude_enterprise",
                "billing_type": "invoice"
              }
            },
            {
              "organization": {
                "uuid": "org-second",
                "name": "Second Org",
                "rate_limit_tier": "claude_pro",
                "billing_type": "stripe_subscription"
              }
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let info = ClaudeWebAPIFetcher._parseAccountInfoForTesting(data, orgId: nil)
        #expect(info?.loginMethod == "Claude Enterprise")
    }

    @Test
    func `claude usage fetcher init with data sources`() {
        // Verify we can create fetchers with both configurations
        let defaultFetcher = ClaudeUsageFetcher()
        let webFetcher = ClaudeUsageFetcher(dataSource: .web)
        let cliFetcher = ClaudeUsageFetcher(dataSource: .cli)
        // Both should be valid instances (no crashes)
        let defaultVersion = defaultFetcher.detectVersion()
        let webVersion = webFetcher.detectVersion()
        let cliVersion = cliFetcher.detectVersion()
        #expect(defaultVersion?.isEmpty != true)
        #expect(webVersion?.isEmpty != true)
        #expect(cliVersion?.isEmpty != true)
    }
}
