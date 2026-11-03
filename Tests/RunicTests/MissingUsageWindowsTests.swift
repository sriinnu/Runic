import Foundation
import Testing
@testable import RunicCore

/// Providers add and drop limit windows without notice. A reply missing one is
/// a normal state: show what came back, and never invent a number.
struct MissingUsageWindowsTests {
    @Test
    func `claude CLI panel without a session row leads with weekly`() throws {
        let sample = """
        Current week (all models)
        92% used  (Resets Dec 2 at 12am (Europe/Vienna))
        Current week (Sonnet only)
        94% used (Resets Dec 2 at 12am (Europe/Vienna))
        Account: user@example.com
        """
        let snap = try ClaudeStatusProbe.parse(text: sample)
        #expect(snap.sessionPercentLeft == nil)
        #expect(snap.weeklyPercentLeft == 8)
        #expect(snap.opusPercentLeft == 6)
    }

    @Test
    func `claude CLI order fallback does not call the weekly row a session`() throws {
        let sample = """
        Current week (all models)
        Current week (Sonnet only)
        92% used
        94% used
        """
        let snap = try ClaudeStatusProbe.parse(text: sample)
        #expect(snap.sessionPercentLeft == nil)
        #expect(snap.weeklyPercentLeft == 8)
    }

    @Test
    func `claude CLI output with no usage rows is still an error`() {
        #expect(throws: ClaudeStatusProbeError.self) {
            try ClaudeStatusProbe.parse(text: "Welcome to Claude Code")
        }
    }

    @Test
    func `claude web reply without a session window keeps the rest`() throws {
        let json = """
        {"five_hour": null, "seven_day": {"utilization": 9, "resets_at": "2026-11-07T02:00:00.000Z"}}
        """
        let parsed = try ClaudeWebAPIFetcher._parseUsageResponseForTesting(Data(json.utf8))
        #expect(parsed.sessionPercentUsed == nil)
        #expect(parsed.weeklyPercentUsed == 9)
    }

    @Test
    func `gemini reply with no buckets says no limits`() throws {
        let snap = try GeminiStatusProbe.parseAPIResponse(Data(#"{"buckets": []}"#.utf8), email: nil)
        #expect(snap.toUsageSnapshot().primary == .noLimitsReported)
    }

    @Test
    func `minimax with no session quota leads with weekly`() {
        let snap = MiniMaxUsageSnapshot(
            total: 0,
            used: 0,
            weeklyQuota: MiniMaxModelQuota(total: 100, used: 25, modelName: "M", remainingPercent: nil),
            updatedAt: Date()).toUsageSnapshot()
        #expect(snap.primary.windowMinutes == 7 * 24 * 60)
        // On this path MiniMax's `used` field holds the remaining count.
        #expect(snap.primary.usedPercent == 75)
        #expect(snap.secondary == nil)
    }

    @Test
    func `minimax with nothing says no limits`() {
        let snap = MiniMaxUsageSnapshot(total: 0, used: 0, updatedAt: Date()).toUsageSnapshot()
        #expect(snap.primary == .noLimitsReported)
    }

    @Test
    func `codex with only a weekly window leads with it`() throws {
        let json = """
        {"rate_limit": {"secondary_window":
            {"used_percent": 43, "reset_at": 1766948068, "limit_window_seconds": 604800}}}
        """
        let snap = try CodexOAuthFetchStrategy._mapUsageForTesting(Data(json.utf8), credentials: Self.codexCredentials)
        #expect(snap.primary.usedPercent == 43)
        #expect(snap.primary.windowMinutes == 10080)
        #expect(snap.secondary == nil)
    }

    @Test
    func `codex with no windows draws no gauge`() throws {
        let snap = try CodexOAuthFetchStrategy._mapUsageForTesting(Data("{}".utf8), credentials: Self.codexCredentials)
        #expect(snap.primary == .noLimitsReported)
    }

    private static let codexCredentials = CodexOAuthCredentials(
        accessToken: "access",
        refreshToken: "refresh",
        idToken: nil,
        accountId: nil,
        lastRefresh: Date())

    @Test
    func `no limits window never reads as a measured percent`() {
        #expect(RateWindow.noLimitsReported.gaugePercent(showUsed: false) == nil)
        #expect(RateWindow.noLimitsReported.hasKnownLimit == false)
    }
}
