import Foundation
import RunicCore
import Testing

struct CLICostTests {
    @Test
    func `cost snapshot stores session and month fields`() {
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: 1200,
            sessionCostUSD: 1.25,
            last30DaysTokens: 9000,
            last30DaysCostUSD: 9.99,
            daily: [],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000))

        #expect(snapshot.sessionTokens == 1200)
        #expect(snapshot.sessionCostUSD == 1.25)
        #expect(snapshot.last30DaysTokens == 9000)
        #expect(snapshot.last30DaysCostUSD == 9.99)
    }

    @Test
    func `daily report decodes legacy cache token keys`() throws {
        let json = """
        {
          "daily": [
            {
              "date": "2025-12-20",
              "inputTokens": 10,
              "outputTokens": 5,
              "cacheReadInputTokens": 2,
              "cacheCreationInputTokens": 3,
              "totalTokens": 20,
              "totalCost": 0.01,
              "models": {
                "claude-sonnet-4-20250514": 20
              }
            }
          ],
          "totals": {
            "totalInputTokens": 10,
            "totalOutputTokens": 5,
            "totalCacheReadTokens": 2,
            "totalCacheCreationTokens": 3,
            "totalTokens": 20,
            "totalCost": 0.01
          }
        }
        """

        let data = try #require(json.data(using: .utf8))
        let report = try JSONDecoder().decode(CostUsageDailyReport.self, from: data)
        let entry = try #require(report.data.first)
        let summary = try #require(report.summary)

        #expect(entry.cacheReadTokens == 2)
        #expect(entry.cacheCreationTokens == 3)
        #expect(entry.costUSD == 0.01)
        #expect(entry.modelsUsed == ["claude-sonnet-4-20250514"])
        #expect(summary.cacheReadTokens == 2)
        #expect(summary.cacheCreationTokens == 3)
        #expect(summary.totalCostUSD == 0.01)
    }
}
