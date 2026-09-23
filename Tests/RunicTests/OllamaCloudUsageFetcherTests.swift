import Foundation
import Testing
@testable import RunicCore

struct OllamaCloudUsageFetcherTests {
    private static let monthlyJSON = #"""
    {
      "limits": {
        "monthly": {
          "usage": 0.42,
          "models": [
            {"name": "qwen3-coder", "request_count": 40},
            {"name": "glm-5", "request_count": 120},
            {"name": "gpt-oss", "request_count": "7"},
            {"name": "kimi-k2", "request_count": 3}
          ]
        }
      },
      "activity": {
        "cost": "12.34",
        "period": {"type": "last_4_weeks", "starting_at": "2026-08-26", "ending_at": "2026-09-23"}
      }
    }
    """#

    private static let legacyJSON = #"""
    {
      "limits": {
        "session": {"usage": "0.25"},
        "weekly": {"usage": 0.6}
      },
      "models": {
        "deepseek-v3.1": {"request_count": 9},
        "glm-5": {"request_count": "31"}
      }
    }
    """#

    private static func usage(_ json: String) throws -> OllamaCloudUsage {
        try OllamaCloudUsage.parse(Data(json.utf8))
    }

    @Test
    func `monthly plan maps to a monthly credits window with top models`() throws {
        let snapshot = try Self.usage(Self.monthlyJSON).toUsageSnapshot()

        #expect(abs(snapshot.primary.usedPercent - 42) < 1e-9)
        #expect(snapshot.primary.windowMinutes == 43200)
        #expect(snapshot.primary.resetsAt == nil)
        #expect(snapshot.primary.label == "Monthly credits")
        #expect(snapshot.primary.hasKnownLimit == true)
        #expect(snapshot.primary.resetDescription == "Top: glm-5 (120), qwen3-coder (40), gpt-oss (7)")
        #expect(snapshot.secondary == nil)
    }

    @Test
    func `legacy plan maps session primary and weekly secondary`() throws {
        let snapshot = try Self.usage(Self.legacyJSON).toUsageSnapshot()

        #expect(abs(snapshot.primary.usedPercent - 25) < 1e-9)
        #expect(snapshot.primary.windowMinutes == 300)
        #expect(snapshot.primary.label == "Session")
        #expect(snapshot.primary.resetDescription == "Top: glm-5 (31), deepseek-v3.1 (9)")
        let weekly = try #require(snapshot.secondary)
        #expect(abs(weekly.usedPercent - 60) < 1e-9)
        #expect(weekly.windowMinutes == 10080)
        #expect(weekly.label == "Weekly")
        #expect(snapshot.providerCost == nil)
    }

    @Test
    func `models map inside limits is accepted too`() throws {
        let json = #"{"limits":{"weekly":{"usage":0.1},"models":{"glm-5":{"request_count":2}}}}"#
        let snapshot = try Self.usage(json).toUsageSnapshot()

        #expect(snapshot.primary.label == "Weekly")
        #expect(snapshot.secondary == nil)
        #expect(snapshot.primary.resetDescription == "Top: glm-5 (2)")
    }

    @Test
    func `numbers are read from numbers and strings but not booleans`() throws {
        #expect(OllamaCloudUsage.number(NSNumber(value: 0.5)) == 0.5)
        #expect(OllamaCloudUsage.number(" 0.75 ") == 0.75)
        #expect(OllamaCloudUsage.number("$1,234.50") == 1234.5)
        #expect(OllamaCloudUsage.number("n/a") == nil)
        #expect(OllamaCloudUsage.number(nil) == nil)
        let root = try #require(
            JSONSerialization.jsonObject(with: Data(#"{"flag":true}"#.utf8)) as? [String: Any])
        #expect(OllamaCloudUsage.number(root["flag"]) == nil)
    }

    @Test
    func `activity cost becomes a limitless provider cost`() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cost = try #require(Self.usage(Self.monthlyJSON).toUsageSnapshot(now: now).providerCost)

        #expect(abs(cost.used - 12.34) < 1e-9)
        #expect(cost.limit == 0)
        #expect(cost.currencyCode == "USD")
        #expect(cost.period == "Last 4 weeks")
        #expect(cost.resetsAt == nil)
        #expect(cost.updatedAt == now)
    }

    @Test
    func `no limits reported gives an informational window`() throws {
        let snapshot = try Self.usage(#"{"activity":{"cost":"0"}}"#).toUsageSnapshot()

        #expect(snapshot.primary.hasKnownLimit == false)
        #expect(snapshot.primary.gaugePercent(showUsed: true) == nil)
        #expect(snapshot.primary.resetDescription == "Signed in · no usage limits reported")
        #expect(snapshot.providerCost?.used == 0)
    }

    @Test
    func `top models text is nil without models`() throws {
        #expect(try Self.usage("{}").topModelsText == nil)
    }

    @Test
    func `non object replies fail to decode`() {
        #expect(throws: OllamaCloudAPIError.decodingError) {
            try OllamaCloudUsage.parse(Data("[1,2]".utf8))
        }
    }

    @Test
    func `status codes map to errors`() {
        #expect(OllamaCloudAPIError.from(statusCode: 200) == nil)
        #expect(OllamaCloudAPIError.from(statusCode: 401) == .invalidKey(statusCode: 401))
        #expect(OllamaCloudAPIError.from(statusCode: 403) == .invalidKey(statusCode: 403))
        #expect(OllamaCloudAPIError.from(statusCode: 401)?.errorDescription?
            .contains("Ollama rejected the API key") == true)
        #expect(OllamaCloudAPIError.from(statusCode: 402) == .limitReached)
        #expect(OllamaCloudAPIError.from(statusCode: 402)?.errorDescription ==
            "Ollama Cloud usage limit reached — upgrade or wait for the reset.")
        #expect(OllamaCloudAPIError.from(statusCode: 429) == .rateLimited)
        #expect(OllamaCloudAPIError.from(statusCode: 500) == .httpError(statusCode: 500))
    }

    @Test
    func `shape key paths carry no values or model names`() throws {
        let root = try JSONSerialization.jsonObject(with: Data(Self.monthlyJSON.utf8))
        let legacy = try JSONSerialization.jsonObject(with: Data(Self.legacyJSON.utf8))
        let paths = OllamaCloudUsageFetcher.shapeKeyPaths(of: root)
        let legacyPaths = OllamaCloudUsageFetcher.shapeKeyPaths(of: legacy)

        #expect(paths == paths.sorted())
        #expect(paths.contains("limits.monthly.usage"))
        #expect(paths.contains("limits.monthly.models[]"))
        #expect(paths.contains("limits.monthly.models[].request_count"))
        #expect(paths.contains("activity.period.type"))
        #expect(legacyPaths.contains("models.*.request_count"))

        let joined = (paths + legacyPaths).joined(separator: "\n")
        for value in ["0.42", "12.34", "glm-5", "qwen3-coder", "last_4_weeks", "2026", "deepseek", "120"] {
            #expect(!joined.contains(value))
        }
    }
}
