import XCTest
@testable import RunicCore

final class AntigravityCLIProbeTests: XCTestCase {
    func test_parsesAgyUsageOutputWithGroupsResetsAccountAndPlan() throws {
        let now = Date(timeIntervalSince1970: 1_795_266_000)
        let raw = """
        \u{001B}]0;agy\u{0007}
        \u{001B}[32mWelcome\u{001B}[0m to the Antigravity CLI. You are currently not signed in.
        \u{001B}[1mAntigravity CLI\u{001B}[0m 1.5.14
        pendela@gmail.com (Google AI Ultra)
        Gemini 4 Neon (High)
        └ Models & Quota
        Account: pendela@gmail.com
        GEMINI MODELS
        Models within this group: Gemini 4 Neon, Gemini 4 Carbon
        Weekly Limit Remaining
        [ █████████████████████████████████████████ ░░░░░░░░░ ] 82.30%
        Refreshes in 165h 24m
        Five Hour Limit Remaining
        [ ███████████████ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ] 30.61%
        Refreshes in 2h 24m
        CLAUDE AND GPT MODELS
        Models within this group: Claude Opus 5.5, Claude Sonnet 5.5, GPT-OSS 120B
        Weekly Limit Remaining
        [ ██████████████████████████████████████████████████ ] 100.00%
        Quota available
        Five Hour Limit Remaining
        [ ██████████████████████████████████████████████████ ] 100.00%
        Quota available
        (1–27 of 30 lines)
        ↑/↓ Scroll · pgup/pgdown Page · ctrl+end Bottom · ctrl+home Top · esc Close
        """

        let snapshot = try AntigravityCLIProbe.parse(rawText: raw, now: now)
        XCTAssertEqual(snapshot.accountEmail, "pendela@gmail.com")
        XCTAssertEqual(snapshot.accountPlan, "Google AI Ultra")
        XCTAssertEqual(snapshot.modelQuotas.count, 4)

        let usage = try snapshot.toUsageSnapshot()
        // Native Gemini group first, shortest window (5h) ahead of Weekly.
        XCTAssertEqual(usage.primary.label, "Gemini 5h")
        XCTAssertEqual(usage.primary.remainingPercent, 30.61, accuracy: 0.01)
        XCTAssertEqual(usage.primary.windowMinutes, 300)
        XCTAssertEqual(usage.primary.resetDescription, "Resets in 2h 24m")
        XCTAssertEqual(usage.primary.resetsAt?.timeIntervalSince(now) ?? 0, 2 * 3600 + 24 * 60, accuracy: 0.5)

        // Second: Gemini Weekly (82.30% left)
        XCTAssertEqual(usage.secondary?.label, "Gemini Weekly")
        XCTAssertEqual(usage.secondary?.remainingPercent ?? 0, 82.30, accuracy: 0.01)
        XCTAssertEqual(usage.secondary?.windowMinutes, 10080)
        XCTAssertEqual(usage.secondary?.resetsAt?.timeIntervalSince(now) ?? 0, 165 * 3600 + 24 * 60, accuracy: 0.5)

        // Third: Claude & GPT 5h, with Claude & GPT Weekly preserved in additionalWindows.
        XCTAssertEqual(usage.tertiary?.label, "Claude & GPT 5h")
        XCTAssertEqual(usage.tertiary?.remainingPercent ?? 0, 100.0, accuracy: 0.01)
        XCTAssertEqual(usage.tertiary?.windowMinutes, 300)
        XCTAssertEqual(usage.tertiary?.resetDescription, "Quota available")
        XCTAssertEqual(usage.additionalWindows?.count, 1)
        XCTAssertEqual(usage.additionalWindows?.first?.label, "Claude & GPT Weekly")
        XCTAssertEqual(usage.additionalWindows?.first?.remainingPercent ?? 0, 100.0, accuracy: 0.01)
        XCTAssertEqual(usage.additionalWindows?.first?.windowMinutes, 10080)
    }

    func test_gemini5hLeadsEvenWhenClaudeWeeklyHasLowerRemainingPercent() throws {
        let now = Date(timeIntervalSince1970: 1_795_590_000)
        let raw = """
        user@example.com (Google AI Ultra)
        GEMINI MODELS
        Weekly Limit Remaining
        [████████████████████████████████████████████████░░] 96.22%
        Refreshes in 140h 10m
        Five Hour Limit Remaining
        [█████████████████████████████████████████████████░] 97.76%
        Refreshes in 4h 30m
        CLAUDE AND GPT MODELS
        Weekly Limit Remaining
        [███████████████████████████░░░░░░░░░░░░░░░░░░░░░░░] 54.59%
        Refreshes in 90h 00m
        Five Hour Limit Remaining
        [██████████████████████████████████████████████████] 100.00%
        Quota available
        """

        let snapshot = try AntigravityCLIProbe.parse(rawText: raw, now: now)
        XCTAssertEqual(snapshot.modelQuotas.count, 4)

        let usage = try snapshot.toUsageSnapshot()
        XCTAssertEqual(usage.primary.label, "Gemini 5h")
        XCTAssertEqual(usage.primary.remainingPercent, 97.76, accuracy: 0.01)
        XCTAssertEqual(usage.secondary?.label, "Gemini Weekly")
        XCTAssertEqual(usage.secondary?.remainingPercent ?? 0, 96.22, accuracy: 0.01)
        XCTAssertEqual(usage.tertiary?.label, "Claude & GPT 5h")
        XCTAssertEqual(usage.tertiary?.remainingPercent ?? 0, 100.0, accuracy: 0.01)
        XCTAssertEqual(usage.additionalWindows?.count, 1)
        XCTAssertEqual(usage.additionalWindows?.first?.label, "Claude & GPT Weekly")
        XCTAssertEqual(usage.additionalWindows?.first?.remainingPercent ?? 0, 54.59, accuracy: 0.01)

        // Ensure menu bar primary prefers Gemini 5h over Claude & GPT Weekly
        let preferred = usage.preferredQuotaWindow(for: .antigravity)
        XCTAssertEqual(preferred?.label, "Gemini 5h")
        XCTAssertEqual(preferred?.remainingPercent ?? 0, 97.76, accuracy: 0.01)
    }

    func test_parsesNotSignedInErrorWhenNoQuotaRendered() {
        let raw = """
        Welcome to the Antigravity CLI . You are currently not signed in.
        Run /login to authenticate.
        """
        XCTAssertThrowsError(try AntigravityCLIProbe.parse(rawText: raw)) { error in
            guard case let AntigravityStatusProbeError.apiError(message) = error else {
                return XCTFail("Expected apiError, got \(error)")
            }
            XCTAssertTrue(message.contains("isn't signed in"))
        }
    }

    func test_desktopStrategyFallbacksOnlyWhenBinaryExistsAndErrorIsRecoverable() {
        let strategy = AntigravityStatusFetchStrategy()
        let context = ProviderFetchContext(
            runtime: .app,
            sourceMode: .auto,
            includeCredits: false,
            webTimeout: 10,
            webDebugDumpHTML: false,
            verbose: false,
            env: [:],
            settings: nil,
            fetcher: UsageFetcher(environment: [:]),
            claudeFetcher: ClaudeUsageFetcher())

        let expectedCLIAvailable = AntigravityCLIProbe.resolveBinary() != nil
        XCTAssertEqual(
            strategy.shouldFallback(
                on: AntigravityStatusProbeError.standaloneTokenUnavailable(version: "2.34.0"),
                context: context),
            expectedCLIAvailable)
        XCTAssertEqual(
            strategy.shouldFallback(on: AntigravityStatusProbeError.missingCSRFToken, context: context),
            expectedCLIAvailable)
        XCTAssertEqual(
            strategy.shouldFallback(on: AntigravityStatusProbeError.notRunning, context: context),
            expectedCLIAvailable)
        XCTAssertFalse(
            strategy.shouldFallback(on: AntigravityStatusProbeError.parseFailed("bad json"), context: context))
    }

    func test_extractPlanHandlesUnparenthesizedAndExplicitLabels() {
        XCTAssertEqual(
            AntigravityCLIProbe.extractPlan(from: ["Plan: Google AI Ultra", "Account: user@example.com"]),
            "Google AI Ultra")
        XCTAssertEqual(
            AntigravityCLIProbe.extractPlan(from: ["Subscription active - Google AI Pro"]),
            "Google AI Pro")
    }

    func test_parsesLiveAgyANSIStreamWithDelayedPlanPatch() throws {
        let now = Date(timeIntervalSince1970: 1_795_266_000)
        let raw = """
        \u{001B}[94;1mesc\u{001B}[90;22m Close
        └ Models & Quota
        Account: user@example.com
        GEMINI MODELS
        Models within this group: Gemini 4 Neon, Gemini 4 Carbon
        Weekly Limit Remaining
        [█████████████████████████████████████████████████░] 97.55%
        Refreshes in 166h 31m
        Five Hour Limit Remaining
        [██████████████████████████████████████████████░░░░] 92.94%
        Refreshes in 3h 31m
        CLAUDE AND GPT MODELS
        Within each group, models share a weekly limit and a 5-hour limit.
        \u{001B}[2m31%\u{001B}[m\u{001B}[32A\u{001B}[28D\u{001B}[90m (Google AI Ultra)\u{001B}[m
        """

        let snapshot = try AntigravityCLIProbe.parse(rawText: raw, now: now)
        XCTAssertEqual(snapshot.accountEmail, "user@example.com")
        XCTAssertEqual(snapshot.accountPlan, "Google AI Ultra")
        XCTAssertEqual(snapshot.modelQuotas.count, 2)
        XCTAssertEqual(snapshot.modelQuotas.first?.label, "Gemini Weekly")
    }

    func test_liveAgyCLIProbeWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["LIVE_ANTIGRAVITY_CLI_TEST"] == "1" else {
            throw XCTSkip("Set LIVE_ANTIGRAVITY_CLI_TEST=1 to exercise live agy /usage capture.")
        }
        let snapshot = try await AntigravityCLIProbe().fetch()
        XCTAssertFalse(snapshot.modelQuotas.isEmpty)
        let usage = try snapshot.toUsageSnapshot()
        XCTAssertNotNil(usage.primary.label)
    }
}
