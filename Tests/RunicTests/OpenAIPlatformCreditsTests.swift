import Foundation
import Testing
@testable import Runic
@testable import RunicCore

/// The fixture keeps the real reply's shape and worst rows, captured on
/// 2026-11-04: a used-up grant, and grants with fractions of a cent used.
struct OpenAIPlatformCreditsTests {
    private static let reply = Data("""
    {
      "object": "credit_summary",
      "total_granted": 243.0, "total_used": 23.00316382,
      "total_available": 219.99683618, "total_paid_available": 0.0,
      "grants": {"object": "list", "data": [
        {"object": "credit_grant", "id": "a", "grant_amount": 200.0, "used_amount": 0.0,
         "effective_at": 1790000000, "expires_at": 1796083200,
         "is_scheduled": false, "is_held_for_prepaid_transition": false},
        {"object": "credit_grant", "id": "b", "grant_amount": 20.0, "used_amount": 0.00316382,
         "effective_at": 1790000000, "expires_at": 1801440000,
         "is_scheduled": false, "is_held_for_prepaid_transition": false},
        {"object": "credit_grant", "id": "c", "grant_amount": 23.0, "used_amount": 23.0,
         "effective_at": 1700000000, "expires_at": null,
         "is_scheduled": false, "is_held_for_prepaid_transition": false},
        {"object": "credit_grant", "id": "d", "grant_amount": 50.0, "used_amount": 0.0,
         "effective_at": 1799000000, "expires_at": 1810000000,
         "is_scheduled": true, "is_held_for_prepaid_transition": false}
      ]}
    }
    """.utf8)

    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    @Test
    func `reads what's left and skips spent and scheduled grants`() throws {
        let credits = try OpenAIPlatformCredits.parse(Self.reply, fetchedAt: self.now)
        #expect(credits.available == 219.99683618)
        #expect(credits.currencyCode == "USD")
        #expect(credits.grants.map(\.granted) == [200, 20])
        #expect(credits.nextExpiring(after: self.now)?.remaining == 200)
    }

    @Test
    func `the codex card says what's left and what expires next`() throws {
        let credits = try OpenAIPlatformCredits.parse(Self.reply, fetchedAt: self.now)
        var cost = ProviderCostSnapshot(used: 0, limit: 0, currencyCode: "USD", updatedAt: self.now)
        cost.apiCredits = credits
        let section = try #require(UsageMenuCardView.Model.providerCostSection(provider: .codex, cost: cost))
        #expect(section.title == "OpenAI API")
        #expect(section.spendLine.hasPrefix("API credits $220.00 left"))
        #expect(section.spendLine.contains("$200"))
    }

    @Test
    func `a rejected token asks for a new sign-in`() {
        #expect(OpenAIPlatformCredits.failure(forStatus: 200) == nil)
        for status in [401, 403] {
            guard case .signInExpired = OpenAIPlatformCredits.failure(forStatus: status) else {
                Issue.record("status \(status) should read as an expired sign-in")
                continue
            }
        }
        guard case .unexpectedReply = OpenAIPlatformCredits.failure(forStatus: 500) else {
            Issue.record("a server error isn't an expired sign-in")
            return
        }
    }

    @Test
    func `a reply in another shape fails instead of showing zero`() {
        #expect(throws: OpenAIPlatformCredits.Failure.self) {
            try OpenAIPlatformCredits.parse(Data(#"{"balance": 0}"#.utf8), fetchedAt: self.now)
        }
    }

    @Test
    func `attaching keeps everything else on the snapshot`() throws {
        let snapshot = UsageSnapshot(
            primary: .noLimitsReported,
            secondary: nil,
            tertiary: nil,
            resetCredits: UsageResetCredits(availableCount: 2),
            balance: ProviderBalance(available: 5, currency: "USD"),
            updatedAt: self.now)
        let credits = try OpenAIPlatformCredits.parse(Self.reply, fetchedAt: self.now)
        let updated = snapshot.with(apiCredits: credits)
        #expect(updated.providerCost?.apiCredits == credits)
        #expect(updated.resetCredits?.availableCount == 2)
        #expect(updated.balance?.available == 5)
    }
}
