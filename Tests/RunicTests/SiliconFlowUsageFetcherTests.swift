import Foundation
import Testing
@testable import RunicCore

struct SiliconFlowUsageFetcherTests {
    @Test
    func `models reply becomes a key health tile`() throws {
        let json = #"{"object":"list","data":[{"id":"Qwen/Qwen3-8B"},{"id":"deepseek-ai/DeepSeek-V3"}]}"#
        let response = try JSONDecoder().decode(SiliconFlowModelsResponse.self, from: Data(json.utf8))
        let snapshot = response.toUsageSnapshot()
        #expect(snapshot.primary.hasKnownLimit == false)
        #expect(snapshot.primary.resetDescription?.hasPrefix("Key active · 2 models") == true)
        #expect(snapshot.balance == nil)
    }

    @Test
    func `an empty model list still reports an active key`() throws {
        let response = try JSONDecoder().decode(SiliconFlowModelsResponse.self, from: Data(#"{"data":[]}"#.utf8))
        #expect(response.toUsageSnapshot().primary.resetDescription == "Key active · 0 models")
    }

    @Test
    func `the two regions use separate hosts`() {
        #expect(SiliconFlowUsageFetcher.apiURL.host == "api.siliconflow.com")
        #expect(SiliconFlowUsageFetcher.apiURLChina.host == "api.siliconflow.cn")
    }

    private static func console(_ json: String) throws -> SiliconFlowBalanceResponse {
        try JSONDecoder().decode(SiliconFlowBalanceResponse.self, from: Data(json.utf8))
    }

    @Test
    func `console reply with string money becomes a balance tile`() throws {
        let response = try Self.console(#"""
        {"code":20000,"status":true,
         "data":{"balance":"1.50","chargeBalance":"10.25","totalBalance":"11.75","status":"normal"}}
        """#)
        #expect(response.hasBalance)
        let snapshot = response.toUsageSnapshot(currency: "CNY")
        #expect(snapshot.balance?.available == 11.75)
        #expect(snapshot.balance?.currency == "CNY")
        #expect(snapshot.balance?.apiCallsAllowed == true)
        #expect(snapshot.primary.resetDescription == "Balance: 11.75 CNY")
        #expect(response.toCreditsSnapshot().remaining == 11.75)
    }

    @Test
    func `console total falls back to the parts`() throws {
        let response = try Self.console(#"{"code":20000,"data":{"balance":1,"chargeBalance":4}}"#)
        #expect(response.remainingBalance == 5)
    }

    @Test
    func `a console error envelope is not a balance`() throws {
        // Wrong subject / expired session: 200 with a non-success code.
        #expect(try !Self.console(#"{"code":30001,"status":false,"message":"no auth","data":null}"#).hasBalance)
        #expect(try !Self.console(#"{"code":20000,"status":true,"data":{"status":"normal"}}"#).hasBalance)
    }

    @Test
    func `subject candidates try env then cookie then none without duplicates`() {
        #expect(SiliconFlowConsole.subjectCandidates(environment: " 42 ", cookie: "42") == ["42", nil])
        #expect(SiliconFlowConsole.subjectCandidates(environment: nil, cookie: "7") == ["7", nil])
        #expect(SiliconFlowConsole.subjectCandidates(environment: "", cookie: nil) == [nil])
    }
}
