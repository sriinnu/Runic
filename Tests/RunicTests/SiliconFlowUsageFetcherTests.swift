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
}
