import Foundation
import Testing
@testable import RunicCore

struct VercelAIUsageFetcherTests {
    @Test
    func `credits response decodes string amounts`() throws {
        let data = #"{"balance":"95.50","total_used":"4.50"}"#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(VercelAICreditsResponse.self, from: data)

        #expect(decoded.balance == 95.50)
        #expect(decoded.totalUsed == 4.50)
        #expect(abs(decoded.usedPercent - 4.5) < 0.0001)

        let snapshot = decoded.toUsageSnapshot(tokenSource: "environment")
        #expect(snapshot.primary.resetDescription?.contains("Balance: 95.50 credits") == true)
        #expect(snapshot.identity?.providerID == .vercelai)
    }

    @Test
    func `models response decodes gateway model format`() throws {
        let data = """
        {
          "object": "list",
          "data": [
            {
              "id": "openai/gpt-5",
              "object": "model",
              "name": "GPT-5",
              "type": "language",
              "context_window": 400000,
              "max_tokens": 128000
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(VercelAIModelsResponse.self, from: data)

        #expect(decoded.data?.count == 1)
        #expect(decoded.data?.first?.id == "openai/gpt-5")
        #expect(decoded.data?.first?.contextWindow == 400000)
    }
}
