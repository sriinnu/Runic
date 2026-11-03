import Foundation
import Testing
@testable import Runic
@testable import RunicCore

/// The Console's credit balance. The fixture keeps the real reply's shape,
/// captured from the billing page on 2026-11-03: `money` null, the balance under
/// `credits`, and grants in `promo_tranches` with their amounts in minor units.
struct ClaudeConsoleCreditsTests {
    private static let reply = Data("""
    {
      "amount": 39014, "currency": "USD",
      "balance": {"money": null, "credits": {"amount_minor": 39014, "exponent": 2}},
      "balance_credits": 390, "amount_without_scoped_credits": 0,
      "auto_reload_settings": null, "tranches": [],
      "promo_tranches": [
        {"remaining_amount_minor_units": 19013, "currency": "USD", "expires_at": "2026-11-04T00:00:00Z",
         "granted_amount_minor_units": 20000, "granted_at": "2026-10-11T14:05:53.045000Z",
         "remaining": {"money": null, "credits": {"amount_minor": 19013, "exponent": 2}},
         "granted": {"money": null, "credits": {"amount_minor": 20000, "exponent": 2}},
         "program_id": "p", "name": "API credit (Ultra)", "id": "a",
         "scope": {"kind": "products", "applies_to": ["api"]}},
        {"remaining_amount_minor_units": 20000, "currency": "USD", "expires_at": "2026-12-04T00:00:00Z",
         "granted_amount_minor_units": 20000, "granted_at": "2026-11-01T10:00:00Z",
         "name": "API credit (Ultra)", "id": "b", "scope": null}
      ],
      "next_expires_at": "2026-11-04T00:00:00Z"
    }
    """.utf8)

    private static func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text) ?? .distantPast
    }

    @Test
    func `parses the balance and grants from the real reply shape`() throws {
        let credits = try #require(ClaudeConsoleCredits.parseCredits(Self.reply))
        #expect(credits.available == 390.14)
        #expect(credits.currencyCode == "USD")
        #expect(credits.grants.count == 2)
        #expect(credits.grants[0].remaining == 190.13)
        #expect(credits.grants[0].granted == 200)
        #expect(credits.grants[0].expiresAt == Self.date("2026-11-04T00:00:00Z"))
    }

    @Test
    func `a reply without a balance is not a zero balance`() {
        #expect(ClaudeConsoleCredits.parseCredits(Data(#"{"amount": 5}"#.utf8)) == nil)
        #expect(ClaudeConsoleCredits.parseCredits(Data("not json".utf8)) == nil)
    }

    @Test
    func `picks the console org and not the chat org`() {
        let orgs = """
        [{"uuid": "chat", "capabilities": ["claude_max", "chat"]},
         {"uuid": "console", "capabilities": ["api", "api_individual"]}]
        """
        #expect(ClaudeConsoleCredits.consoleOrganizationID(Data(orgs.utf8)) == "console")
        let chatOnly = Data(#"[{"uuid": "c", "capabilities": ["chat"]}]"#.utf8)
        #expect(ClaudeConsoleCredits.consoleOrganizationID(chatOnly) == nil)
    }

    @Test
    func `the card names the balance and the next expiry`() throws {
        var cost = ProviderCostSnapshot(used: 0, limit: 0, currencyCode: "USD", updatedAt: .init())
        cost.includedMonthlyCreditUSD = 200
        cost.apiCredits = try #require(ClaudeConsoleCredits.parseCredits(Self.reply))
        let line = UsageMenuCardView.Model.apiCreditGrantLine(cost, now: Self.date("2026-11-03T11:00:00Z"))
        #expect(line == "API credits $390.14 left · $190.13 expires in 13h")
    }

    @Test
    func `an expired grant stops counting on a card left unrefreshed`() throws {
        var cost = ProviderCostSnapshot(used: 0, limit: 0, currencyCode: "USD", updatedAt: .init())
        cost.apiCredits = try #require(ClaudeConsoleCredits.parseCredits(Self.reply))
        let afterExpiry = Self.date("2026-11-04T00:30:00Z")
        let line = try #require(UsageMenuCardView.Model.apiCreditGrantLine(cost, now: afterExpiry))
        #expect(line.hasPrefix("API credits $200.01 left · $200.00 expires "))
    }

    @Test
    func `without the console the plan amount still shows`() {
        var cost = ProviderCostSnapshot(used: 0, limit: 0, currencyCode: "USD", updatedAt: .init())
        cost.includedMonthlyCreditUSD = 200
        #expect(UsageMenuCardView.Model.apiCreditGrantLine(cost) == "API credits $200.00 a month")
    }

    @Test
    func `credits ride on a snapshot with no spend block`() throws {
        let base = ClaudeUsageSnapshot(
            primary: RateWindow(usedPercent: 10, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            opus: nil,
            updatedAt: .init(),
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: nil,
            rawText: nil)
        let credits = try #require(ClaudeConsoleCredits.parseCredits(Self.reply))
        #expect(base.with(apiCredits: credits).providerCost?.apiCredits == credits)
    }
}
