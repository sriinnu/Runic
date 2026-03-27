import Foundation
import Testing
@testable import RunicCore

struct OpenAIDashboardFetcherCreditsWaitTests {
    @Test
    func `waits after scroll request`() {
        let now = Date()
        let shouldWait = OpenAIDashboardFetcher.shouldWaitForCreditsHistory(.init(
            now: now,
            anyDashboardSignalAt: now.addingTimeInterval(-10),
            creditsHeaderVisibleAt: nil,
            creditsHeaderPresent: false,
            creditsHeaderInViewport: false,
            didScrollToCredits: true))
        #expect(shouldWait == true)
    }

    @Test
    func `waits briefly when header visible but table empty`() {
        let now = Date()
        let visibleAt = now.addingTimeInterval(-1.0)
        let shouldWait = OpenAIDashboardFetcher.shouldWaitForCreditsHistory(.init(
            now: now,
            anyDashboardSignalAt: now.addingTimeInterval(-10),
            creditsHeaderVisibleAt: visibleAt,
            creditsHeaderPresent: true,
            creditsHeaderInViewport: true,
            didScrollToCredits: false))
        #expect(shouldWait == true)
    }

    @Test
    func `stops waiting after header has been visible long enough`() {
        let now = Date()
        let visibleAt = now.addingTimeInterval(-3.0)
        let shouldWait = OpenAIDashboardFetcher.shouldWaitForCreditsHistory(.init(
            now: now,
            anyDashboardSignalAt: now.addingTimeInterval(-10),
            creditsHeaderVisibleAt: visibleAt,
            creditsHeaderPresent: true,
            creditsHeaderInViewport: true,
            didScrollToCredits: false))
        #expect(shouldWait == false)
    }

    @Test
    func `waits briefly after first dashboard signal even when header not present yet`() {
        let now = Date()
        let startedAt = now.addingTimeInterval(-2.0)
        let shouldWait = OpenAIDashboardFetcher.shouldWaitForCreditsHistory(.init(
            now: now,
            anyDashboardSignalAt: startedAt,
            creditsHeaderVisibleAt: nil,
            creditsHeaderPresent: false,
            creditsHeaderInViewport: false,
            didScrollToCredits: false))
        #expect(shouldWait == true)
    }

    @Test
    func `stops waiting eventually when header never appears`() {
        let now = Date()
        let startedAt = now.addingTimeInterval(-7.0)
        let shouldWait = OpenAIDashboardFetcher.shouldWaitForCreditsHistory(.init(
            now: now,
            anyDashboardSignalAt: startedAt,
            creditsHeaderVisibleAt: nil,
            creditsHeaderPresent: false,
            creditsHeaderInViewport: false,
            didScrollToCredits: false))
        #expect(shouldWait == false)
    }
}
