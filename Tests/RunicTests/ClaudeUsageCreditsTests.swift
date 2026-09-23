import Foundation
import Testing
@testable import Runic
@testable import RunicCore

/// Claude usage credits (the `spend` block and the claude.ai prepaid balance).
struct ClaudeUsageCreditsTests {
    private func spend(_ json: String) throws -> OAuthSpend {
        try JSONDecoder().decode(OAuthSpend.self, from: Data(json.utf8))
    }

    @Test
    func `spend block money is read from minor units`() throws {
        let spend = try self.spend("""
        {"used": {"amount_minor": 450, "currency": "EUR", "exponent": 2},
         "limit": {"amount_minor": 1000, "currency": "EUR", "exponent": 2},
         "balance": {"amount_minor": 1250, "currency": "EUR", "exponent": 2},
         "enabled": true, "percent": 45, "can_purchase_credits": true}
        """)
        let cost = try #require(spend.costSnapshot)
        #expect(cost.used == 4.5)
        #expect(cost.limit == 10)
        #expect(cost.balance == 12.5)
        #expect(cost.currencyCode == "EUR")
        #expect(cost.isEnabled == true)
    }

    @Test
    func `credits switched off still say so`() throws {
        let spend = try self.spend("""
        {"used": {"amount_minor": 0, "currency": "USD", "exponent": 2}, "limit": null,
         "balance": null, "enabled": false}
        """)
        let cost = try #require(spend.costSnapshot)
        let section = try #require(UsageMenuCardView.Model.claudeUsageCreditsSection(cost))
        #expect(section.title == "Usage credits")
        #expect(section.spendLine == "Off")
        #expect(section.percentUsed == nil)
    }

    @Test
    func `an odd field does not drop the rest of the block`() throws {
        let spend = try self.spend(#"{"used": "weird", "enabled": true, "balance": 3.5}"#)
        #expect(spend.used == nil)
        #expect(spend.enabled == true)
        #expect(spend.balance?.value == 3.5)
    }

    @Test
    func `claude ai balance takes its own currency when there is no spend`() throws {
        let off = try #require(try self.spend(
            #"{"used": {"amount_minor": 0, "currency": "USD", "exponent": 2}, "enabled": false}"#).costSnapshot)
        let snapshot = ClaudeUsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            opus: nil,
            providerCost: off,
            updatedAt: Date(timeIntervalSince1970: 0),
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: nil,
            rawText: nil)
        let prepaid = try #require(ClaudeWebResets.parseCreditBalance(Data("""
        {"amount": 0, "currency": "EUR", "balance": {"money": {"amount_minor": 0, "currency": "EUR", "exponent": 2}}}
        """.utf8)))
        let merged = try #require(snapshot.with(creditBalance: prepaid).providerCost)
        #expect(merged.currencyCode == "EUR")
        #expect(merged.balance == 0)
        #expect(merged.isEnabled == false)
        let section = try #require(UsageMenuCardView.Model.claudeUsageCreditsSection(merged))
        #expect(section.spendLine == "Off · Balance €0.00")
    }

    @Test
    func `spend in one currency never shows another currency's balance`() throws {
        let spending = try #require(try self.spend("""
        {"used": {"amount_minor": 300, "currency": "USD", "exponent": 2}, "enabled": true}
        """).costSnapshot)
        let snapshot = ClaudeUsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            opus: nil,
            providerCost: spending,
            updatedAt: Date(timeIntervalSince1970: 0),
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: nil,
            rawText: nil)
        let merged = snapshot.with(creditBalance: ClaudeMoney(value: 5, currency: "EUR"))
        #expect(merged.providerCost?.balance == nil)
        #expect(merged.providerCost?.currencyCode == "USD")
    }
}
