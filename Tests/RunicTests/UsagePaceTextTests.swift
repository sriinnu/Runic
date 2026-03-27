import Foundation
import RunicCore
import Testing
@testable import Runic

struct UsagePaceTextTests {
    @Test
    func `weekly pace text includes eta when running out before reset`() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 50,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(4 * 24 * 3600),
            resetDescription: nil)

        let text = UsagePaceText.weekly(provider: .codex, window: window, now: now)

        #expect(text == "Pace: Ahead (+7%) · Runs out in 3d")
    }

    @Test
    func `weekly pace text shows reset safe when pace is slow`() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(4 * 24 * 3600),
            resetDescription: nil)

        let text = UsagePaceText.weekly(provider: .codex, window: window, now: now)

        #expect(text == "Pace: Behind (-33%) · Lasts to reset")
    }

    @Test
    func `weekly pace text hides when reset is missing`() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: nil,
            resetDescription: nil)

        let text = UsagePaceText.weekly(provider: .codex, window: window, now: now)

        #expect(text == nil)
    }

    @Test
    func `weekly pace text hides when reset is in past or too far`() {
        let now = Date(timeIntervalSince1970: 0)
        let pastWindow = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(-60),
            resetDescription: nil)
        let farFutureWindow = RateWindow(
            usedPercent: 10,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(9 * 24 * 3600),
            resetDescription: nil)

        #expect(UsagePaceText.weekly(provider: .codex, window: pastWindow, now: now) == nil)
        #expect(UsagePaceText.weekly(provider: .codex, window: farFutureWindow, now: now) == nil)
    }

    @Test
    func `weekly pace text hides when no elapsed but usage exists`() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 5,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(7 * 24 * 3600),
            resetDescription: nil)

        let text = UsagePaceText.weekly(provider: .codex, window: window, now: now)

        #expect(text == nil)
    }

    @Test
    func `weekly pace text hides when too early in window`() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 40,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval((7 * 24 * 3600) - (60 * 60)),
            resetDescription: nil)

        let text = UsagePaceText.weekly(provider: .codex, window: window, now: now)

        #expect(text == nil)
    }

    @Test
    func `weekly pace text hides when usage is depleted`() {
        let now = Date(timeIntervalSince1970: 0)
        let window = RateWindow(
            usedPercent: 100,
            windowMinutes: 10080,
            resetsAt: now.addingTimeInterval(2 * 24 * 3600),
            resetDescription: nil)

        let text = UsagePaceText.weekly(provider: .codex, window: window, now: now)

        #expect(text == nil)
    }
}
