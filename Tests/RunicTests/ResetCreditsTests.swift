import Foundation
import Testing
@testable import Runic
@testable import RunicCore

struct ResetCreditsTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func `codex usage payload decodes banked reset summary and extra limits`() throws {
        let json = """
        {
          "plan_type": "pro",
          "rate_limit": {
            "allowed": false,
            "limit_reached": true,
            "primary_window": { "used_percent": 100, "limit_window_seconds": 604800, "reset_at": 1789436007 },
            "secondary_window": null
          },
          "additional_rate_limits": [
            {
              "limit_name": "GPT-5.3-Codex-Spark",
              "metered_feature": "codex_bengalfox",
              "rate_limit": {
                "allowed": true,
                "primary_window": { "used_percent": 46, "limit_window_seconds": 18000, "reset_at": 1788963630 },
                "secondary_window": { "used_percent": 20, "limit_window_seconds": 604800, "reset_at": 1789550430 }
              },
              "normal_model_slug": null
            }
          ],
          "credits": { "has_credits": false, "unlimited": false, "balance": "0" },
          "rate_limit_reset_credits": { "available_count": 2, "applicable_available_count": 2 }
        }
        """
        let usage = try JSONDecoder().decode(CodexUsageResponse.self, from: Data(json.utf8))
        #expect(usage.rateLimitResetCredits?.availableCount == 2)
        #expect(usage.additionalRateLimits?.first?.limitName == "GPT-5.3-Codex-Spark")
        #expect(usage.additionalRateLimits?.first?.rateLimit?.primaryWindow?.usedPercent == 46)

        let creds = CodexOAuthCredentials(
            accessToken: "t",
            refreshToken: "",
            idToken: nil,
            accountId: "acct",
            lastRefresh: nil)
        let snapshot = CodexOAuthFetchStrategy.mapUsage(
            usage,
            credentials: creds,
            resetCredits: UsageResetCredits(availableCount: 2))
        #expect(snapshot.primary.usedPercent == 100)
        #expect(snapshot.tertiary?.label == "GPT-5.3-Codex-Spark 5h")
        #expect(snapshot.tertiary?.usedPercent == 46)
        #expect(snapshot.tertiary?.windowMinutes == 300)
        #expect(snapshot.resetCredits?.availableCount == 2)
    }

    @Test
    func `codex reset credit inventory maps expiries and availability`() throws {
        let json = """
        {
          "credits": [
            { "id": "a", "reset_type": "codex_rate_limits", "status": "available",
              "granted_at": "2026-09-04T02:28:45.347345Z", "expires_at": "2026-10-04T02:28:45.347345Z",
              "title": "Full reset", "description": "x" },
            { "id": "b", "reset_type": "codex_rate_limits", "status": "available",
              "granted_at": "2026-09-05T04:20:26.764651Z", "expires_at": "2026-10-05T04:20:26.764651Z",
              "title": "Full reset", "description": "x" },
            { "id": "c", "reset_type": "codex_rate_limits", "status": "redeemed",
              "granted_at": "2026-08-01T00:00:00Z", "expires_at": "2026-08-31T00:00:00Z",
              "title": "Full reset", "description": "x" }
          ],
          "available_count": 2,
          "total_earned_count": 0
        }
        """
        let response = try JSONDecoder().decode(CodexResetCreditsResponse.self, from: Data(json.utf8))
        let credits = response.toUsageResetCredits(summaryCount: 2)
        let reference = Date(timeIntervalSince1970: 1_788_998_400) // 2026-09-09
        #expect(credits.availableCount == 2)
        #expect(credits.credits.count == 3)
        #expect(credits.available(now: reference).map(\.id) == ["a", "b"])
        let nearest = try #require(credits.nearestExpiry(now: reference))
        let latest = try #require(credits.latestExpiry(now: reference))
        #expect(nearest < latest)
        #expect(Calendar(identifier: .gregorian).component(.day, from: latest) == 5)
        #expect(credits.credits[2].isAvailable(now: reference) == false)
    }

    @Test
    func `reset credit inventory falls back to summary count when list is empty`() throws {
        let response = try JSONDecoder().decode(
            CodexResetCreditsResponse.self,
            from: Data(#"{"credits": []}"#.utf8))
        #expect(response.toUsageResetCredits(summaryCount: 1).availableCount == 1)
        #expect(response.toUsageResetCredits(summaryCount: nil).availableCount == 0)
    }

    @Test
    func `usage snapshot round trips reset credits`() throws {
        let credits = UsageResetCredits(
            availableCount: 1,
            credits: [UsageResetCredit(id: "x", title: "Full reset", status: "available", expiresAt: self.now)])
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: self.now, resetDescription: nil),
            secondary: nil,
            resetCredits: credits,
            updatedAt: self.now)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(UsageSnapshot.self, from: data)
        #expect(decoded.resetCredits == credits)
        #expect(decoded.scoped(to: .codex).resetCredits == credits)
    }

    @Test
    func `claude oauth payload decodes scoped limits into a labelled window`() throws {
        let json = """
        {
          "five_hour": { "utilization": 32, "resets_at": "2026-09-08T15:59:59.848981+00:00" },
          "seven_day": { "utilization": 24, "resets_at": "2026-09-12T01:59:59.849007+00:00" },
          "seven_day_opus": null,
          "seven_day_sonnet": null,
          "limits": [
            { "kind": "session", "group": "session", "percent": 32, "resets_at": "2026-09-08T15:59:59.848981+00:00",
              "scope": null, "is_active": false },
            { "kind": "weekly_all", "group": "weekly", "percent": 24, "resets_at": "2026-09-12T01:59:59.849007+00:00",
              "scope": null, "is_active": false },
            { "kind": "weekly_scoped", "group": "weekly", "percent": 46,
              "resets_at": "2026-09-12T01:59:59.849259+00:00",
              "scope": { "model": { "id": null, "display_name": "Fable" }, "surface": null }, "is_active": true }
          ]
        }
        """
        let usage = try ClaudeOAuthUsageFetcher._decodeUsageResponseForTesting(Data(json.utf8))
        #expect(usage.limits?.count == 3)
        let window = try #require(ClaudeUsageFetcher.scopedLimitWindow(usage.limits))
        #expect(window.label == "Fable weekly")
        #expect(window.usedPercent == 46)
        #expect(window.windowMinutes == 7 * 24 * 60)
        #expect(window.resetsAt != nil)
        #expect(ClaudeUsageFetcher.scopedLimitWindow(nil) == nil)
    }

    @MainActor
    @Test
    func `schedule builder lists banked resets with expiry`() {
        let codexMeta = ProviderDescriptorRegistry.descriptor(for: .codex).metadata
        let claudeMeta = ProviderDescriptorRegistry.descriptor(for: .claude).metadata
        let credits = UsageResetCredits(
            availableCount: 2,
            credits: [
                UsageResetCredit(
                    id: "a",
                    title: "Full reset",
                    status: "available",
                    expiresAt: self.now.addingTimeInterval(25 * 86400)),
                UsageResetCredit(
                    id: "b",
                    title: "Full reset",
                    status: "available",
                    expiresAt: self.now.addingTimeInterval(26 * 86400)),
            ])
        let codex = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 100,
                windowMinutes: 10080,
                resetsAt: self.now.addingTimeInterval(3600),
                resetDescription: nil),
            secondary: nil,
            resetCredits: credits,
            updatedAt: self.now)
        let claude = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 10,
                windowMinutes: 300,
                resetsAt: self.now.addingTimeInterval(7200),
                resetDescription: nil),
            secondary: nil,
            updatedAt: self.now)
        let entries = ResetScheduleBuilder.credits([
            .init(provider: .claude, metadata: claudeMeta, snapshot: claude),
            .init(provider: .codex, metadata: codexMeta, snapshot: codex),
        ], now: self.now)
        #expect(entries.count == 1)
        #expect(entries.first?.provider == .codex)
        #expect(entries.first?.availableCount == 2)
        #expect(entries.first?.summaryText == "2 resets available")
        #expect(entries.first?.expiries.count == 2)
        #expect(entries.first?.latestExpiry == self.now.addingTimeInterval(26 * 86400))

        let line = ResetCreditEntry.summaryLine(for: credits, now: self.now)
        #expect(line?.hasPrefix("2 banked resets · usable until ") == true)
        #expect(ResetCreditEntry.summaryLine(for: UsageResetCredits(availableCount: 0), now: self.now) == nil)
        #expect(OverviewMenuView.bankedResetsPill(for: credits) == "2 resets")
        #expect(OverviewMenuView.bankedResetsPill(for: UsageResetCredits(availableCount: 1)) == "1 reset")
    }
}
