import Foundation
import Testing
@testable import RunicCore

struct SiliconFlowUsageFetcherTests {
    private static func decode(_ json: String) throws -> SiliconFlowBalanceResponse {
        try JSONDecoder().decode(SiliconFlowBalanceResponse.self, from: Data(json.utf8))
    }

    @Test
    func `decodes string money fields`() throws {
        let response = try Self.decode(#"""
        {"code":20000,"data":{"balance":"1.50","chargeBalance":"10.25","totalBalance":"11.75","status":"normal"}}
        """#)
        let info = try #require(response.data)
        #expect(info.balance == 1.50)
        #expect(info.chargeBalance == 10.25)
        #expect(info.totalBalance == 11.75)
        #expect(info.status == "normal")
    }

    @Test
    func `decodes numeric money fields`() throws {
        let response = try Self.decode(#"""
        {"data":{"balance":2,"chargeBalance":3.5,"totalBalance":5.5,"status":"normal"}}
        """#)
        let info = try #require(response.data)
        #expect(info.balance == 2)
        #expect(info.chargeBalance == 3.5)
        #expect(info.totalBalance == 5.5)
    }

    @Test
    func `total balance falls back to parts`() throws {
        let response = try Self.decode(#"""
        {"data":{"balance":"1.00","chargeBalance":"4.00","status":"normal"}}
        """#)
        let snapshot = response.toUsageSnapshot()
        #expect(snapshot.balance?.available == 5.0)
        #expect(snapshot.balance?.currency == "USD")
        #expect(response.toCreditsSnapshot().remaining == 5.0)
    }

    @Test
    func `cny snapshot carries currency and description`() throws {
        let response = try Self.decode(#"""
        {"data":{"balance":"0","chargeBalance":"88.88","totalBalance":"88.88","status":"normal"}}
        """#)
        let snapshot = response.toUsageSnapshot(currency: "CNY")
        #expect(snapshot.balance?.currency == "CNY")
        #expect(snapshot.balance?.available == 88.88)
        #expect(snapshot.primary.resetDescription == "Balance: 88.88 CNY")
    }

    @Test
    func `api calls allowed reflects status`() throws {
        let normal = try Self.decode(#"{"data":{"totalBalance":"1","status":"normal"}}"#)
        #expect(normal.toUsageSnapshot().balance?.apiCallsAllowed == true)
        let upper = try Self.decode(#"{"data":{"totalBalance":"1","status":"NORMAL"}}"#)
        #expect(upper.toUsageSnapshot().balance?.apiCallsAllowed == true)
        let frozen = try Self.decode(#"{"data":{"totalBalance":"1","status":"frozen"}}"#)
        #expect(frozen.toUsageSnapshot().balance?.apiCallsAllowed == false)
        let missing = try Self.decode(#"{"data":{"totalBalance":"1"}}"#)
        #expect(missing.toUsageSnapshot().balance?.apiCallsAllowed == nil)
    }
}
