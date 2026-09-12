import Foundation
import Testing
@testable import Runic
@testable import RunicCore

struct QuotaBurnTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func window(used: Double, resetsIn: TimeInterval, minutes: Int?) -> RateWindow {
        RateWindow(
            usedPercent: used,
            windowMinutes: minutes,
            resetsAt: self.now.addingTimeInterval(resetsIn),
            resetDescription: nil)
    }

    @Test
    func `budget line runs from window start to reset`() throws {
        let window = self.window(used: 50, resetsIn: 2 * 3600, minutes: 300)
        let samples = [
            QuotaSample(
                at: self.now.addingTimeInterval(-2 * 3600),
                usedPercent: 10,
                resetsAt: window.resetsAt,
                windowMinutes: 300),
            QuotaSample(
                at: self.now.addingTimeInterval(-3600),
                usedPercent: 30,
                resetsAt: window.resetsAt,
                windowMinutes: 300),
        ]
        let series = try #require(QuotaBurnSeries.make(samples: samples, window: window, now: self.now))
        #expect(series.windowStart == self.now.addingTimeInterval(-3 * 3600))
        #expect(series.windowDuration == 5 * 3600)
        #expect(series.budgetPercent(at: series.windowStart) == 0)
        #expect(series.budgetPercent(at: series.resetsAt) == 100)
        // 3h into a 5h window the even burn sits at 60%; we're at 50 → under by 10.
        #expect(abs(series.budgetPercent(at: self.now) - 60) < 0.001)
        #expect(abs(series.paceDeltaPercent + 10) < 0.001)
        // The live reading is appended as the final point.
        #expect(series.points.count == 3)
        #expect(series.points.last?.usedPercent == 50)
    }

    @Test
    func `projections use the rate over each horizon and stop at the reset`() throws {
        let window = self.window(used: 60, resetsIn: 4 * 3600, minutes: 300)
        // 20%/h over the last hour, 10%/h averaged over the last 6h (only 1h of the cycle exists).
        let samples = [
            QuotaSample(
                at: self.now.addingTimeInterval(-3600),
                usedPercent: 40,
                resetsAt: window.resetsAt,
                windowMinutes: 300),
            QuotaSample(
                at: self.now.addingTimeInterval(-1800),
                usedPercent: 50,
                resetsAt: window.resetsAt,
                windowMinutes: 300),
        ]
        let series = try #require(QuotaBurnSeries.make(samples: samples, window: window, now: self.now))
        let oneHour = series.projections[0]
        #expect(abs(oneHour.ratePercentPerHour - 20) < 0.01)
        // 40% left at 20%/h → runs out in 2h, before the 4h reset.
        let runsOut = try #require(oneHour.runsOutAt)
        #expect(abs(runsOut.timeIntervalSince(self.now) - 2 * 3600) < 1)
        #expect(series.earliestRunOut?.horizon == 3600)

        // A slow rate lasts to the reset: runsOutAt nil.
        let slow = self.window(used: 20, resetsIn: 4 * 3600, minutes: 300)
        let slowSamples = [
            QuotaSample(
                at: self.now.addingTimeInterval(-3600),
                usedPercent: 19,
                resetsAt: slow.resetsAt,
                windowMinutes: 300),
        ]
        let slowSeries = try #require(QuotaBurnSeries.make(samples: slowSamples, window: slow, now: self.now))
        #expect(slowSeries.projections[0].lastsToReset)
    }

    @Test
    func `readings from a previous cycle and after a reset drop are excluded`() throws {
        let window = self.window(used: 12, resetsIn: 4 * 3600, minutes: 300)
        let oldReset = window.resetsAt?.addingTimeInterval(-5 * 3600)
        let samples = [
            // Previous cycle, tagged with the old reset.
            QuotaSample(
                at: self.now.addingTimeInterval(-50 * 60),
                usedPercent: 90,
                resetsAt: oldReset,
                windowMinutes: 300),
            // This cycle: a high reading then a cliff (reset happened), then the climb.
            QuotaSample(
                at: self.now.addingTimeInterval(-45 * 60),
                usedPercent: 95,
                resetsAt: window.resetsAt,
                windowMinutes: 300),
            QuotaSample(
                at: self.now.addingTimeInterval(-40 * 60),
                usedPercent: 2,
                resetsAt: window.resetsAt,
                windowMinutes: 300),
            QuotaSample(
                at: self.now.addingTimeInterval(-20 * 60),
                usedPercent: 8,
                resetsAt: window.resetsAt,
                windowMinutes: 300),
        ]
        let series = try #require(QuotaBurnSeries.make(samples: samples, window: window, now: self.now))
        #expect(series.points.map(\.usedPercent) == [2, 8, 12])
    }

    @Test
    func `series needs a reset moment and two points`() {
        let noReset = RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        #expect(QuotaBurnSeries.make(samples: [], window: noReset, now: self.now) == nil)
        let window = self.window(used: 10, resetsIn: 3600, minutes: 300)
        #expect(QuotaBurnSeries.make(samples: [], window: window, now: self.now) == nil)
    }

    @Test
    func `sample store drops exact repeats inside two minutes and keeps slots apart`() {
        let store = QuotaSampleStore(directory: nil, memoryOnly: true)
        let reset = self.now.addingTimeInterval(3600)
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 40, windowMinutes: 300, resetsAt: reset, resetDescription: nil),
            secondary: RateWindow(usedPercent: 10, windowMinutes: 10080, resetsAt: reset, resetDescription: nil),
            tertiary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance",
                hasKnownLimit: false),
            updatedAt: self.now)
        store.record(provider: .codex, snapshot: snapshot, at: self.now)
        store.record(provider: .codex, snapshot: snapshot, at: self.now.addingTimeInterval(30))
        store.record(provider: .codex, snapshot: snapshot, at: self.now.addingTimeInterval(200))
        #expect(store.samples(provider: .codex, slot: .primary).count == 2)
        #expect(store.samples(provider: .codex, slot: .secondary).count == 2)
        // A window without a real limit is never recorded.
        #expect(store.samples(provider: .codex, slot: .tertiary).isEmpty)
        #expect(store.hasHistory(provider: .codex))
        #expect(!store.hasHistory(provider: .claude))
        #expect(store.samples(provider: .codex, slot: .primary, since: self.now.addingTimeInterval(100)).count == 1)
    }

    @Test
    func `burn copy names the run out and the reset`() throws {
        let window = self.window(used: 60, resetsIn: 4 * 3600, minutes: 300)
        let samples = [
            QuotaSample(
                at: self.now.addingTimeInterval(-3600),
                usedPercent: 40,
                resetsAt: window.resetsAt,
                windowMinutes: 300),
        ]
        let series = try #require(QuotaBurnSeries.make(samples: samples, window: window, now: self.now))
        let text = QuotaBurnChartMenuView.runOutText(series)
        #expect(text.hasPrefix("Runs out "))
        #expect(text.contains("at the 1h rate") || text.contains("at the 6h rate"))
        #expect(text.contains("resets "))
        #expect(QuotaBurnChartMenuView.sampleSummary(series).hasPrefix("2 samples"))
    }
}
