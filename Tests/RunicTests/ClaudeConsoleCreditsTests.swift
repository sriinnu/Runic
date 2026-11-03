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

    private static func cookie(name: String = "n", value: String = "v", domain: String) throws -> HTTPCookie {
        try #require(HTTPCookie(properties: [.name: name, .value: value, .domain: domain, .path: "/"]))
    }

    @Test
    func `only console cookies are sent to the console`() throws {
        #expect(try ClaudeConsoleCredits.isConsoleCookie(Self.cookie(domain: "platform.claude.com")))
        #expect(try ClaudeConsoleCredits.isConsoleCookie(Self.cookie(domain: ".claude.com")))
        #expect(try !ClaudeConsoleCredits.isConsoleCookie(Self.cookie(domain: "docs.claude.com")))
        #expect(try !ClaudeConsoleCredits.isConsoleCookie(Self.cookie(domain: "evilclaude.com")))
        #expect(try !ClaudeConsoleCredits.isConsoleCookie(Self.cookie(domain: "claude.ai")))
    }

    @Test
    func `a page with no console cookies never counts as signed in`() async throws {
        let cookies = try [Self.cookie(domain: "docs.claude.com")]
        #expect(try await ClaudeConsoleCredits.validate(cookies: cookies) == nil)
    }

    @Test
    func `only a real session key from claude's own sites is tried`() throws {
        let good = try Self.cookie(name: "sessionKey", value: "sk-ant-a", domain: ".claude.ai")
        let console = try Self.cookie(name: "sessionKey", value: "sk-ant-b", domain: "platform.claude.com")
        let foreign = try Self.cookie(name: "sessionKey", value: "sk-ant-c", domain: "evilclaude.ai")
        let notAKey = try Self.cookie(name: "sessionKey", value: "nope", domain: "claude.ai")
        let otherName = try Self.cookie(name: "other", value: "sk-ant-d", domain: "claude.ai")
        let keys = ClaudeWebResets.sessionKeys(in: [good, console, foreign, notAKey, otherName])
        #expect(keys == ["sk-ant-a", "sk-ant-b"])
    }

    @Test
    func `the diagnostics file keeps only claude's own hosts`() {
        #expect(ClaudeConsoleCredits.isClaudeHost("platform.claude.com"))
        #expect(ClaudeConsoleCredits.isClaudeHost(".claude.ai"))
        #expect(!ClaudeConsoleCredits.isClaudeHost("claudemonet.com"))
        #expect(!ClaudeConsoleCredits.isClaudeHost("evilclaude.ai"))
    }

    @Test
    func `grant amounts honour their own exponent`() throws {
        let reply = Data("""
        {"balance": {"credits": {"amount_minor": 1500, "exponent": 3}},
         "promo_tranches": [{"remaining_amount_minor_units": 1500,
                             "remaining": {"money": null, "credits": {"amount_minor": 1500, "exponent": 3}},
                             "expires_at": "2026-12-04T00:00:00Z"}]}
        """.utf8)
        let credits = try #require(ClaudeConsoleCredits.parseCredits(reply))
        #expect(credits.available == 1.5)
        #expect(credits.grants.first?.remaining == 1.5)
    }

    @Test
    func `a grant already expired when fetched is not taken off twice`() {
        let credits = ProviderAPICredits(
            available: 200,
            currencyCode: "USD",
            grants: [ProviderAPICredits.Grant(
                name: nil,
                remaining: 190,
                granted: 200,
                expiresAt: Self.date("2026-11-04T00:00:00Z"))],
            fetchedAt: Self.date("2026-11-04T01:00:00Z"))
        #expect(credits.available(at: Self.date("2026-11-04T02:00:00Z")) == 200)
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
        let parsed = try #require(ClaudeConsoleCredits.parseCredits(Self.reply))
        cost.apiCredits = ProviderAPICredits(
            available: parsed.available,
            currencyCode: parsed.currencyCode,
            grants: parsed.grants,
            fetchedAt: Self.date("2026-11-03T11:00:00Z"))
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
