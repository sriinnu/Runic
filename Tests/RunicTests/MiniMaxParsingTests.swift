import Foundation
import Testing
@testable import RunicCore

struct MiniMaxParsingTests {
    @Test
    func `parse manual input cookie header`() {
        let input = "Cookie: foo=bar; baz=qux"
        let parsed = MiniMaxWebParsing.parseManualInput(input)
        #expect(parsed?.cookieHeader == "foo=bar; baz=qux")
        #expect(parsed?.accessToken == nil)
    }

    @Test
    func `parse manual input curl extracts bearer and group ID`() {
        let curl = """
        curl 'https://platform.minimax.io/v1/api/openplatform/coding_plan/remains?GroupId=group_123' \
          -H 'Cookie: session=abc; foo=bar' \
          -H 'Authorization: Bearer header.token.value'
        """
        let parsed = MiniMaxWebParsing.parseManualInput(curl)
        #expect(parsed?.cookieHeader == "session=abc; foo=bar")
        #expect(parsed?.accessToken == "header.token.value")
        #expect(parsed?.groupID == "group_123")
    }

    @Test
    func `parse HTML usage with percent and reset`() {
        let html = """
        <html>
        <head><title>MiniMax Pro</title></head>
        <body>
        <div>Available usage: 40%</div>
        <div>Resets in 2d 3h</div>
        </body>
        </html>
        """
        let now = Date(timeIntervalSince1970: 0)
        let parsed = MiniMaxWebParsing.parseHTMLUsage(html, now: now)
        #expect(parsed?.usedPercent == 60)
        #expect(parsed?.planName == "MiniMax Pro")
        #expect(parsed?.resetDescription == "Resets in 2d 3h")
        #expect(parsed?.resetsAt == now.addingTimeInterval(TimeInterval((2 * 24 * 60 + 3 * 60) * 60)))
    }

    @Test
    func `parse remains response uses model remains`() throws {
        let json = """
        {
          "base_resp": { "retcode": 0, "msg": "ok", "success": true },
          "data": {
            "model_remains": { "used": 20, "total": 100 },
            "start_time": 1700000000,
            "end_time": 1700003600,
            "remains_time": 600,
            "plan_name": "MiniMax Pro"
          }
        }
        """
        let now = Date(timeIntervalSince1970: 0)
        let parsed = try MiniMaxWebParsing.parseRemainsResponse(Data(json.utf8), now: now)
        #expect(parsed.usedPercent == 20)
        #expect(parsed.windowMinutes == 60)
        #expect(parsed.resetsAt == now.addingTimeInterval(600))
        #expect(parsed.planName == "MiniMax Pro")
    }

    @Test
    func `api remains snapshot treats full remaining allowance as zero used`() {
        let snapshot = MiniMaxUsageSnapshot(
            total: 4500,
            used: 4500,
            modelName: "MiniMax M1",
            updatedAt: Date(timeIntervalSince1970: 0))

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.primary.usedPercent == 0)
        #expect(usage.primary.remainingPercent == 100)
        #expect(usage.primary.resetDescription == "4500 / 4500 remaining")
    }

    @Test
    func `parse remains response with model array surfaces both models`() throws {
        let json = """
        {
          "base_resp": { "retcode": 0, "msg": "ok", "success": true },
          "data": {
            "model_remains": [
              { "used": 20, "total": 100, "model_name": "MiniMax-M2" },
              { "used": 5, "total": 50, "model_name": "MiniMax-M2-Spark" }
            ],
            "plan_name": "MiniMax Pro"
          }
        }
        """
        let parsed = try MiniMaxWebParsing.parseRemainsResponse(Data(json.utf8))
        #expect(parsed.usedPercent == 20)
        #expect(parsed.modelName == "MiniMax-M2")
        #expect(parsed.secondaryModel?.modelName == "MiniMax-M2-Spark")
        #expect(parsed.secondaryModel?.usedPercent == 10)

        let usage = parsed.toUsageSnapshot(updatedAt: Date(timeIntervalSince1970: 0))
        #expect(usage.tertiary?.label == "MiniMax-M2-Spark")
        #expect(usage.tertiary?.usedPercent == 10)
    }

    @Test
    func `parse remains response ignores an unnamed second model instead of mislabeling it`() throws {
        let json = """
        {
          "base_resp": { "retcode": 0, "msg": "ok", "success": true },
          "data": {
            "model_remains": [
              { "used": 20, "total": 100, "model_name": "MiniMax-M2" },
              { "used": 5, "total": 50 }
            ],
            "plan_name": "MiniMax Pro"
          }
        }
        """
        let parsed = try MiniMaxWebParsing.parseRemainsResponse(Data(json.utf8))
        #expect(parsed.secondaryModel == nil)

        let usage = parsed.toUsageSnapshot(updatedAt: Date(timeIntervalSince1970: 0))
        #expect(usage.tertiary == nil)
    }

    @Test
    func `api snapshot surfaces a second model quota as tertiary`() {
        let snapshot = MiniMaxUsageSnapshot(
            total: 100,
            used: 100,
            modelName: "MiniMax-M2",
            additionalModels: [
                MiniMaxModelQuota(total: 50, used: 25, modelName: "MiniMax-M2-Spark"),
            ],
            updatedAt: Date(timeIntervalSince1970: 0))

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.tertiary?.label == "MiniMax-M2-Spark")
        #expect(usage.tertiary?.usedPercent == 50)
    }
}
