import Foundation
import Testing
@testable import RunicCore

struct ClineUsageFetcherTests {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 2026-09-23 12:00 UTC.
    private static let now = Date(timeIntervalSince1970: 1_790_164_800)

    private static let usagesJSON = """
    {
      "success": true,
      "error": null,
      "data": {
        "items": [
          {"aiInferenceProviderName": "anthropic", "aiModelName": "claude-sonnet",
           "promptTokens": 1000, "completionTokens": 200, "totalTokens": 1200,
           "costUsd": 0.25, "creditsUsed": 250000,
           "createdAt": "2026-09-23T09:15:00.123Z", "generationId": "g1"},
          {"aiModelName": "gpt", "costUsd": "0.50",
           "createdAt": "2026-09-23T01:00:00Z"},
          {"costUsd": 1.0, "createdAt": "2026-09-02T10:00:00Z"},
          {"costUsd": 9.0, "createdAt": "2026-08-31T23:59:59Z"},
          {"costUsd": 3.0},
          {"createdAt": "2026-09-23T03:00:00Z"}
        ]
      }
    }
    """

    @Test
    func `wrapped usages decode leniently including string costUsd`() throws {
        let list = try ClineUsageFetcher.decodeEnvelope(ClineUsageList.self, from: Data(Self.usagesJSON.utf8))
        let items = try #require(list.items)

        #expect(items.count == 6)
        #expect(items[0].costUsd?.value == 0.25)
        #expect(items[0].totalTokens?.value == 1200)
        #expect(items[1].costUsd?.value == 0.5)
        #expect(items[0].createdDate != nil)
        #expect(items[1].createdDate != nil)
        #expect(items[4].createdDate == nil)
        #expect(items[5].costUsd == nil)
    }

    @Test
    func `spend sums today and calendar month by createdAt`() throws {
        let list = try ClineUsageFetcher.decodeEnvelope(ClineUsageList.self, from: Data(Self.usagesJSON.utf8))
        let spend = ClineUsageFetcher.spend(items: list.items ?? [], now: Self.now, calendar: Self.utcCalendar)

        #expect(abs(spend.today - 0.75) < 1e-9)
        #expect(abs(spend.thisMonth - 1.75) < 1e-9)
    }

    @Test
    func `unsuccessful envelope surfaces cline error message`() {
        let json = #"{"success": false, "error": "Unauthorized", "data": null}"#
        #expect(throws: ClineAPIError.self) {
            _ = try ClineUsageFetcher.decodeEnvelope(ClineUser.self, from: Data(json.utf8))
        }
        do {
            _ = try ClineUsageFetcher.decodeEnvelope(ClineUser.self, from: Data(json.utf8))
        } catch {
            #expect(error.localizedDescription.contains("Unauthorized"))
        }
    }

    @Test
    func `snapshot maps micro-usd balance, spend, and email`() throws {
        let user = try ClineUsageFetcher.decodeEnvelope(
            ClineUser.self,
            from: Data(
                #"{"success":true,"data":{"id":"u1","email":"dev@example.com","displayName":"Dev","organizations":[]}}"#
                    .utf8))
        let balance = try ClineUsageFetcher.decodeEnvelope(
            ClineBalance.self,
            from: Data(#"{"success":true,"data":{"balance":12500000,"userId":"u1"}}"#.utf8))
        let usages = try ClineUsageFetcher.decodeEnvelope(ClineUsageList.self, from: Data(Self.usagesJSON.utf8))

        let account = ClineAccountUsage(user: user, balance: balance, usages: usages.items)
        let snapshot = account.toUsageSnapshot(now: Self.now, calendar: Self.utcCalendar)
        let providerBalance = try #require(snapshot.balance)

        #expect(providerBalance.available == 12.5)
        #expect(providerBalance.currency == "USD")
        #expect(abs((providerBalance.reportedSpend?.today ?? 0) - 0.75) < 1e-9)
        #expect(abs((providerBalance.reportedSpend?.thisMonth ?? 0) - 1.75) < 1e-9)
        #expect(providerBalance.reportedSpend?.thisWeek == nil)
        #expect(snapshot.primary.hasKnownLimit == false)
        #expect(snapshot.primary.resetDescription?.contains("12.50") == true)
        #expect(snapshot.identity?.accountEmail == "dev@example.com")
    }

    @Test
    func `snapshot keeps balance when usages are unavailable`() {
        let account = ClineAccountUsage(
            user: ClineUser(id: "u1", email: nil, displayName: nil),
            balance: ClineBalance(balance: ClineLenientDouble(2_000_000), userId: "u1"),
            usages: nil)
        let snapshot = account.toUsageSnapshot(now: Self.now, calendar: Self.utcCalendar)

        #expect(snapshot.balance?.available == 2)
        #expect(snapshot.balance?.reportedSpend == nil)
        #expect(snapshot.identity?.accountEmail == nil)
    }
}
