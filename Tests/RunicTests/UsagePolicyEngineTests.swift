import Testing
@testable import RunicCore

struct UsagePolicyEngineTests {
    @Test
    func `returns none when no rules match`() {
        let context = UsagePolicyContext(
            provider: .codex,
            observedSpendUSD: 45,
            projectedSpendUSD: 70,
            budgetLimitUSD: 100,
            anomalySeverity: .elevated)
        let rules = [
            UsagePolicyRule(
                id: "hard-stop-over-budget",
                name: "Hard stop after budget breach",
                condition: .actualBudgetOverrun,
                action: .hardStop),
            UsagePolicyRule(
                id: "critical-anomaly-soft-limit",
                name: "Soft limit only on critical anomaly",
                condition: .anomalySeverityAtLeast(.critical),
                action: .softLimit),
        ]

        let decision = UsagePolicyEngine.evaluate(context: context, rules: rules)
        #expect(decision.action == .none)
        #expect(decision.matches.isEmpty)
        #expect(decision.shouldThrottle == false)
        #expect(decision.shouldBlock == false)
    }

    @Test
    func `selects strongest action across matched rules`() {
        let context = UsagePolicyContext(
            provider: .codex,
            observedSpendUSD: 120,
            projectedSpendUSD: 170,
            budgetLimitUSD: 100,
            anomalySeverity: .critical)
        let rules = [
            UsagePolicyRule(
                id: "warn-projected-20",
                name: "Warn at projected +20%",
                condition: .projectedBudgetOverrun(minimumPercent: 0.20),
                action: .warn),
            UsagePolicyRule(
                id: "soft-anomaly-high",
                name: "Soft limit on high anomaly",
                condition: .anomalySeverityAtLeast(.high),
                action: .softLimit),
            UsagePolicyRule(
                id: "stop-actual-overrun",
                name: "Hard stop once actually over budget",
                condition: .actualBudgetOverrun,
                action: .hardStop),
        ]

        let decision = UsagePolicyEngine.evaluate(context: context, rules: rules)
        #expect(decision.action == .hardStop)
        #expect(decision.shouldThrottle == true)
        #expect(decision.shouldBlock == true)
        #expect(decision.matches.count == 3)
        #expect(decision.matches.contains { $0.ruleID == "warn-projected-20" })
        #expect(decision.matches.contains { $0.ruleID == "soft-anomaly-high" })
        #expect(decision.matches.contains { $0.ruleID == "stop-actual-overrun" })
    }

    @Test
    func `projected overrun condition respects threshold`() {
        let context = UsagePolicyContext(
            provider: .codex,
            observedSpendUSD: 80,
            projectedSpendUSD: 112,
            budgetLimitUSD: 100,
            anomalySeverity: nil)
        let rules = [
            UsagePolicyRule(
                id: "warn-projected-20",
                name: "Warn at projected +20%",
                condition: .projectedBudgetOverrun(minimumPercent: 0.20),
                action: .warn),
        ]

        let decision = UsagePolicyEngine.evaluate(context: context, rules: rules)
        #expect(decision.action == .none)
        #expect(decision.matches.isEmpty)
    }
}
