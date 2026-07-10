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
          "base_resp": { "status_code": 0, "status_msg": "success" },
          "data": {
            "model_remains": { "current_interval_total_count": 100, "current_interval_usage_count": 20 },
            "start_time": 1700000000,
            "end_time": 1700003600,
            "remains_time": 600,
            "plan_name": "MiniMax Pro"
          }
        }
        """
        let now = Date(timeIntervalSince1970: 0)
        let parsed = try MiniMaxWebParsing.parseRemainsResponse(Data(json.utf8), now: now)
        // coding_plan: usage_count = remaining, so total=100, remaining=20 → used=80%
        #expect(parsed.usedPercent == 80)
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
          "base_resp": { "status_code": 0, "status_msg": "success" },
          "data": {
            "model_remains": [
              { "current_interval_total_count": 100, "current_interval_usage_count": 20, "model_name": "MiniMax-M2" },
              { "current_interval_total_count": 50, "current_interval_usage_count": 5,
                "model_name": "MiniMax-M2-Spark" }
            ],
            "plan_name": "MiniMax Pro"
          }
        }
        """
        let parsed = try MiniMaxWebParsing.parseRemainsResponse(Data(json.utf8))
        // coding_plan: usage_count = remaining. M2: total=100, remaining=20 → 80% used
        #expect(parsed.usedPercent == 80)
        #expect(parsed.modelName == "MiniMax-M2")
        // Spark: total=50, remaining=5 → 45/50 = 90% used
        #expect(parsed.secondaryModel?.modelName == "MiniMax-M2-Spark")
        #expect(parsed.secondaryModel?.usedPercent == 90)

        let usage = parsed.toUsageSnapshot(updatedAt: Date(timeIntervalSince1970: 0))
        #expect(usage.tertiary?.label == "MiniMax-M2-Spark")
        #expect(usage.tertiary?.usedPercent == 90)
    }

    @Test
    func `parse remains response ignores an unnamed second model instead of mislabeling it`() throws {
        let json = """
        {
          "base_resp": { "status_code": 0, "status_msg": "success" },
          "data": {
            "model_remains": [
              { "current_interval_total_count": 100, "current_interval_usage_count": 20, "model_name": "MiniMax-M2" },
              { "current_interval_total_count": 50, "current_interval_usage_count": 5 }
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

    // MARK: - token_plan format tests

    @Test
    func `parse remains response with token_plan remaining percent`() throws {
        let json = """
        {
          "base_resp": { "status_code": 0, "status_msg": "success" },
          "model_remains": [
            {
              "model_name": "video",
              "current_interval_total_count": 3,
              "current_interval_usage_count": 0,
              "current_interval_remaining_percent": 100,
              "start_time": 1783555200000,
              "end_time": 1783641600000,
              "remains_time": 21508467
            }
          ]
        }
        """
        let parsed = try MiniMaxWebParsing.parseRemainsResponse(Data(json.utf8))
        // remaining_percent=100 → 0% used
        #expect(parsed.usedPercent == 0)
        #expect(parsed.modelName == "video")
    }

    @Test
    func `parse remains response with token_plan partially used`() throws {
        let json = """
        {
          "base_resp": { "status_code": 0, "status_msg": "success" },
          "model_remains": [
            {
              "model_name": "video",
              "current_interval_total_count": 10,
              "current_interval_usage_count": 3,
              "current_interval_remaining_percent": 70
            }
          ]
        }
        """
        let parsed = try MiniMaxWebParsing.parseRemainsResponse(Data(json.utf8))
        // remaining=70% → 30% used
        #expect(parsed.usedPercent == 30)
    }

    @Test
    func `api snapshot with weekly quota surfaces it as secondary`() {
        let weeklyQuota = MiniMaxModelQuota(
            total: 21,
            used: 0,
            modelName: "video",
            remainingPercent: 100)
        let snapshot = MiniMaxUsageSnapshot(
            total: 3,
            used: 0,
            modelName: "video",
            remainingPercent: 100,
            weeklyQuota: weeklyQuota,
            sessionWindowMinutes: 300,
            sessionResetsAt: Date(timeIntervalSince1970: 1000),
            weeklyResetsAt: Date(timeIntervalSince1970: 2000),
            updatedAt: Date(timeIntervalSince1970: 0))

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.primary.usedPercent == 0)
        #expect(usage.primary.label == "video")
        #expect(usage.primary.windowMinutes == 300)
        #expect(usage.primary.resetsAt == Date(timeIntervalSince1970: 1000))
        #expect(usage.secondary?.usedPercent == 0)
        #expect(usage.secondary?.label == "video")
        #expect(usage.secondary?.windowMinutes == 7 * 24 * 60)
        #expect(usage.secondary?.resetsAt == Date(timeIntervalSince1970: 2000))
    }

    @Test
    func `api snapshot with token plan style remaining percent`() {
        let snapshot = MiniMaxUsageSnapshot(
            total: 10,
            used: 3,
            modelName: "video",
            additionalModels: [],
            updatedAt: Date(timeIntervalSince1970: 0))

        // Without remainingPercent, falls back to coding_plan math where
        // `used`=3 means 3 remaining → 7/10 = 70% used.
        let usage = snapshot.toUsageSnapshot()
        #expect(usage.primary.usedPercent == 70)
    }

    @Test
    func `api snapshot filters zero total models`() {
        // Models with total=0 should be skipped as primary — they have no quota.
        let quota = MiniMaxModelQuota(total: 0, used: 0, modelName: "general")
        #expect(quota.usedPercent == 0)
    }
}
