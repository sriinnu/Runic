import Foundation
import Testing
@testable import RunicCore

@Suite
struct MiniMaxParsingTests {
    @Test
    func parseManualInputCookieHeader() {
        let input = "Cookie: foo=bar; baz=qux"
        let parsed = MiniMaxWebParsing.parseManualInput(input)
        #expect(parsed?.cookieHeader == "foo=bar; baz=qux")
        #expect(parsed?.accessToken == nil)
    }

    @Test
    func parseManualInputCurlExtractsBearerAndGroupID() {
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
    func parseHTMLUsageWithPercentAndReset() {
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
    func parseRemainsResponseUsesModelRemains() throws {
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
}
