import Foundation
import Testing
@testable import RunicCore

struct ClaudeLimitResetsTests {
    /// Shape observed on claude.ai `/usage?cedar_ember=1`, 2026-09-22.
    private static func payload(grants: String) -> Data {
        Data("""
        {
          "five_hour": {"utilization": 10, "resets_at": "2026-09-22T21:40:00.947455+00:00"},
          "seven_day": {"utilization": 40, "resets_at": "2026-09-26T02:00:00.947475+00:00"},
          "cedar_ember": {
            "eligible": true, "ineligible_reason": null, "at_limit": false, "exhausted": [],
            "grants": [\(grants)],
            "next_grant_id": "opus55-launch-promax-20260921",
            "weekly_resets_at": "2026-09-26T02:00:00+00:00", "cooldown_until": null
          }
        }
        """.utf8)
    }

    private static let launchGrant = """
    {"id": "opus55-launch-promax-20260921",
     "label": "Claude Opus 5.5 launch: one usage-limit reset for Pro and Max",
     "resets_total": 1, "resets_left": 1,
     "starts_at": "2026-09-22T16:00:00+00:00", "ends_at": "2026-10-22T16:00:00+00:00",
     "clears": ["five_hour", "seven_day"], "paused": false, "usable_now": true,
     "use_requires_limit": false, "blocking": []}
    """

    private static let now = ISO8601DateFormatter().date(from: "2026-09-23T00:00:00Z")!

    @Test
    func `oauth payload yields one banked reset with its expiry`() throws {
        let usage = try ClaudeOAuthUsageFetcher._decodeUsageResponseForTesting(
            Self.payload(grants: Self.launchGrant))
        let credits = try #require(usage.cedarEmber?.resetCredits(now: Self.now))
        #expect(credits.availableCount == 1)
        let credit = try #require(credits.credits.first)
        #expect(credit.id == "opus55-launch-promax-20260921")
        #expect(credit.title?.hasPrefix("Claude Opus 5.5 launch") == true)
        #expect(credit.expiresAt == ISO8601DateFormatter().date(from: "2026-10-22T16:00:00Z"))
        #expect(credit.isAvailable(now: Self.now))
    }

    @Test
    func `web payload carries the same resets`() throws {
        let parsed = try ClaudeWebAPIFetcher._parseUsageResponseForTesting(Self.payload(grants: Self.launchGrant))
        #expect(parsed.resetCredits?.availableCount == 1)
    }

    @Test
    func `spent, paused and expired grants bank nothing`() throws {
        let spent = Self.launchGrant.replacingOccurrences(of: "\"resets_left\": 1", with: "\"resets_left\": 0")
        let paused = Self.launchGrant.replacingOccurrences(of: "\"paused\": false", with: "\"paused\": true")
        let expired = Self.launchGrant.replacingOccurrences(
            of: "2026-10-22T16:00:00+00:00",
            with: "2026-09-22T20:00:00+00:00")
        for grant in [spent, paused, expired] {
            let usage = try ClaudeOAuthUsageFetcher._decodeUsageResponseForTesting(Self.payload(grants: grant))
            #expect(usage.cedarEmber?.resetCredits(now: Self.now) == nil)
        }
    }

    @Test
    func `multiple resets in one grant list separately`() throws {
        let two = Self.launchGrant.replacingOccurrences(of: "\"resets_left\": 1", with: "\"resets_left\": 2")
        let usage = try ClaudeOAuthUsageFetcher._decodeUsageResponseForTesting(Self.payload(grants: two))
        let credits = try #require(usage.cedarEmber?.resetCredits(now: Self.now))
        #expect(credits.availableCount == 2)
        #expect(Set(credits.credits.map(\.id)).count == 2)
    }

    @Test
    func `payload without the flag decodes with no resets`() throws {
        let data = Data(#"{"five_hour": {"utilization": 5}, "cedar_ember": null}"#.utf8)
        let usage = try ClaudeOAuthUsageFetcher._decodeUsageResponseForTesting(data)
        #expect(usage.cedarEmber == nil)
        #expect(try ClaudeWebAPIFetcher._parseUsageResponseForTesting(data).resetCredits == nil)
    }
}
