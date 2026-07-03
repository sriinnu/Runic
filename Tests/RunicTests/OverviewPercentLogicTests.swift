import Foundation
import RunicCore
import SwiftUI
import Testing
@testable import Runic

/// Overview consistency: percents honor the used/left toggle the cards and
/// menubar honor, and providers without a real quota window are excluded from
/// the cross-provider average instead of dragging it down with permanent 0s.
@MainActor
struct OverviewPercentLogicTests {
    @Test
    func `display percent honors used and left modes`() {
        let window = RateWindow(usedPercent: 30, windowMinutes: 300, resetsAt: nil, resetDescription: nil)

        #expect(OverviewMenuView.displayPercent(for: window, showsUsed: true) == 30)
        #expect(OverviewMenuView.displayPercent(for: window, showsUsed: false) == 70)
        #expect(OverviewMenuView.displayPercent(for: nil, showsUsed: true) == 0)
    }

    @Test
    func `display percent is zero for limitless windows`() {
        let balance = RateWindow(
            usedPercent: 0,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: "Balance: 12.34",
            hasKnownLimit: false)

        #expect(OverviewMenuView.displayPercent(for: balance, showsUsed: false) == 0)
        #expect(OverviewMenuView.windowHasQuota(balance) == false)
    }

    @Test
    func `window quota detection reuses session quota logic`() {
        let real = RateWindow(usedPercent: 30, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        let stub = RateWindow(usedPercent: 0, windowMinutes: nil, resetsAt: nil, resetDescription: nil)

        #expect(OverviewMenuView.windowHasQuota(real))
        #expect(OverviewMenuView.windowHasQuota(stub) == false)
        #expect(OverviewMenuView.windowHasQuota(nil) == false)
    }

    @Test
    func `average excludes providers without a real quota`() {
        let summaries = [
            self.summary(id: "a", percent: 40, hasQuota: true),
            self.summary(id: "b", percent: 60, hasQuota: true),
            self.summary(id: "c", percent: 0, hasQuota: false),
        ]

        #expect(OverviewMenuView.averagePercent(summaries) == 50)
    }

    @Test
    func `average includes real zero percent providers`() {
        let summaries = [
            self.summary(id: "a", percent: 40, hasQuota: true),
            self.summary(id: "b", percent: 0, hasQuota: true),
        ]

        #expect(OverviewMenuView.averagePercent(summaries) == 20)
    }

    @Test
    func `average is nil when no provider has a quota`() {
        let summaries = [
            self.summary(id: "a", percent: 0, hasQuota: false),
        ]

        // No measurable quota anywhere: there is no average (rendered "—"),
        // not a fake "0% left avg" that reads as everything-depleted.
        #expect(OverviewMenuView.averagePercent(summaries) == nil)
        #expect(OverviewMenuView.averagePercent([]) == nil)
    }

    @Test
    func `gauge percent hides windows without a known limit`() {
        let balance = RateWindow(
            usedPercent: 0,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: "Balance: 12.34",
            hasKnownLimit: false)
        let real = RateWindow(usedPercent: 30, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        let overflow = RateWindow(usedPercent: 130, windowMinutes: 300, resetsAt: nil, resetDescription: nil)

        #expect(balance.gaugePercent(showUsed: true) == nil)
        #expect(balance.gaugePercent(showUsed: false) == nil)
        #expect(real.gaugePercent(showUsed: true) == 30)
        #expect(real.gaugePercent(showUsed: false) == 70)
        #expect(overflow.gaugePercent(showUsed: true) == 100)
        #expect(overflow.gaugePercent(showUsed: false) == 0)
    }

    private func summary(id: String, percent: Double, hasQuota: Bool) -> OverviewMenuView.ProviderSummary {
        OverviewMenuView.ProviderSummary(
            id: id,
            provider: .codex,
            name: id,
            icon: nil,
            usedPercent: percent,
            todayTokens: 0,
            brandColor: .blue,
            resetDescription: nil,
            windowLabel: nil,
            topModelContext: nil,
            hasQuota: hasQuota)
    }
}
