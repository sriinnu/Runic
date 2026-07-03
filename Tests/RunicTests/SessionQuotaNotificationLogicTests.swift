import Foundation
import RunicCore
import Testing
@testable import Runic

struct SessionQuotaNotificationLogicTests {
    @Test
    func `does nothing without previous value`() {
        let transition = SessionQuotaNotificationLogic.transition(previousRemaining: nil, currentRemaining: 0)
        #expect(transition == .none)
    }

    @Test
    func `detects depleted transition`() {
        let transition = SessionQuotaNotificationLogic.transition(previousRemaining: 12, currentRemaining: 0)
        #expect(transition == .depleted)
    }

    @Test
    func `detects restored transition`() {
        let transition = SessionQuotaNotificationLogic.transition(previousRemaining: 0, currentRemaining: 5)
        #expect(transition == .restored)
    }

    @Test
    func `ignores non transitions`() {
        #expect(SessionQuotaNotificationLogic.transition(previousRemaining: 0, currentRemaining: 0) == .none)
        #expect(SessionQuotaNotificationLogic.transition(previousRemaining: 10, currentRemaining: 10) == .none)
        #expect(SessionQuotaNotificationLogic.transition(previousRemaining: 10, currentRemaining: 9) == .none)
    }

    @Test
    func `treats tiny positive remaining as depleted`() {
        let transition = SessionQuotaNotificationLogic.transition(previousRemaining: 0, currentRemaining: 0.00001)
        #expect(transition == .none)
    }

    @Test
    func `hardcoded zero stub window is not a real quota`() {
        let stub = RateWindow(
            usedPercent: 100,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: nil,
            label: "Some Model")
        #expect(!SessionQuotaNotificationLogic.hasRealQuota(stub))

        let blankDescription = RateWindow(
            usedPercent: 100,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: "   ")
        #expect(!SessionQuotaNotificationLogic.hasRealQuota(blankDescription))
    }

    @Test
    func `windows with quota evidence are real`() {
        let session = RateWindow(usedPercent: 100, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        #expect(SessionQuotaNotificationLogic.hasRealQuota(session))

        let resetting = RateWindow(usedPercent: 100, windowMinutes: nil, resetsAt: Date(), resetDescription: nil)
        #expect(SessionQuotaNotificationLogic.hasRealQuota(resetting))

        let credits = RateWindow(
            usedPercent: 100,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: "Balance: $0.00")
        #expect(SessionQuotaNotificationLogic.hasRealQuota(credits))
    }

    @Test
    func `explicit hasKnownLimit overrides the metadata heuristic`() {
        // Zai-shaped window: a real quota that carries no reset metadata at
        // all. The explicit flag must keep it a real quota so a 0%-remaining
        // reading still fires the depletion notification.
        let zaiShaped = RateWindow(
            usedPercent: 100,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: nil,
            hasKnownLimit: true)
        #expect(SessionQuotaNotificationLogic.hasRealQuota(zaiShaped))
        #expect(SessionQuotaNotificationLogic.transition(
            previousRemaining: 12,
            currentRemaining: zaiShaped.remainingPercent) == .depleted)

        // Conversely, an informational window stays fake even when it carries
        // reset-ish metadata that the heuristic would accept.
        let balance = RateWindow(
            usedPercent: 0,
            windowMinutes: 60,
            resetsAt: Date(),
            resetDescription: "Models available: 42",
            hasKnownLimit: false)
        #expect(!SessionQuotaNotificationLogic.hasRealQuota(balance))
    }

    @Test
    func `classifies lifetime credit balances as credits`() {
        // OpenRouter / Vercel AI: credits provider, no rolling window, no reset.
        let credits = SessionQuotaNotificationLogic.quotaKind(
            windowMinutes: nil,
            resetsAt: nil,
            supportsCredits: true)
        #expect(credits == .credits)

        // Codex: credits-capable, but the primary window is a rolling session.
        let codex = SessionQuotaNotificationLogic.quotaKind(
            windowMinutes: 300,
            resetsAt: nil,
            supportsCredits: true)
        #expect(codex == .session)

        // Claude: no credits support, reset-driven session window.
        let claude = SessionQuotaNotificationLogic.quotaKind(
            windowMinutes: nil,
            resetsAt: nil,
            supportsCredits: false)
        #expect(claude == .session)

        let resetting = SessionQuotaNotificationLogic.quotaKind(
            windowMinutes: nil,
            resetsAt: Date(),
            supportsCredits: true)
        #expect(resetting == .session)
    }

    @Test
    func `depletion wording says credits exhausted for credit quotas`() {
        let session = SessionQuotaNotificationLogic.notificationContent(
            transition: .depleted,
            providerName: "Claude",
            quotaKind: .session)
        #expect(session?.title == "Claude session depleted")

        let credits = SessionQuotaNotificationLogic.notificationContent(
            transition: .depleted,
            providerName: "OpenRouter",
            quotaKind: .credits)
        #expect(credits?.title == "OpenRouter credits exhausted")

        let restored = SessionQuotaNotificationLogic.notificationContent(
            transition: .restored,
            providerName: "OpenRouter",
            quotaKind: .credits)
        #expect(restored?.title == "OpenRouter credits restored")

        let none = SessionQuotaNotificationLogic.notificationContent(
            transition: .none,
            providerName: "Claude",
            quotaKind: .session)
        #expect(none == nil)
    }
}
