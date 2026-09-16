import Foundation
import Testing
@testable import RunicCore

/// Kimi Code subscription usage (`GET api.kimi.com/coding/v1/usages`). A
/// subscription key is rejected by the Open Platform balance endpoint, so these
/// windows are the only data a subscriber gets.
struct KimiCodeUsageParsingTests {
    private func parse(_ json: String) throws -> UsageSnapshot {
        try KimiCodeUsageFetcher.parse(Data(json.utf8), now: Date(timeIntervalSince1970: 0))
    }

    @Test
    func `weekly summary and 5h window parse from string counts`() throws {
        let snapshot = try self.parse("""
        {"usage": {"limit": "2048", "used": "214", "remaining": "1834",
                   "resetTime": "2026-01-09T15:23:13.716839300Z"},
         "limits": [{"window": {"duration": 300, "timeUnit": "TIME_UNIT_MINUTE"},
                     "detail": {"limit": "200", "used": "139", "remaining": "61",
                                "resetTime": "2026-01-06T13:33:02.717479433Z"}}]}
        """)

        #expect(snapshot.primary.label == "5h")
        #expect(snapshot.primary.windowMinutes == 300)
        #expect(abs(snapshot.primary.usedPercent - 69.5) < 0.001)
        #expect(snapshot.primary.hasKnownLimit == true)
        let reset = try #require(snapshot.primary.resetsAt)
        #expect(abs(reset.timeIntervalSince1970 - 1_767_706_382.717) < 0.01)

        let weekly = try #require(snapshot.secondary)
        #expect(weekly.label == "Weekly")
        #expect(abs(weekly.usedPercent - 214.0 / 2048.0 * 100) < 0.001)
        #expect(weekly.resetsAt != nil)
        #expect(snapshot.tertiary == nil)
    }

    @Test
    func `used derives from remaining when absent`() throws {
        let snapshot = try self.parse("""
        {"limits": [{"window": {"duration": 5, "timeUnit": "TIME_UNIT_HOUR"},
                     "detail": {"limit": 100, "remaining": 25}}]}
        """)
        #expect(snapshot.primary.label == "5h")
        #expect(snapshot.primary.windowMinutes == 300)
        #expect(snapshot.primary.usedPercent == 75)
    }

    @Test
    func `ratio pools fill 5h and monthly`() throws {
        let snapshot = try self.parse("""
        {"usages": {"limit_5h": {"used_ratio": 0.25},
                    "limit_month_total": {"used_ratio": 0.0338, "reset_time": "2026-10-15T07:49:10Z"}}}
        """)
        #expect(snapshot.primary.label == "5h")
        #expect(snapshot.primary.usedPercent == 25)
        let monthly = try #require(snapshot.secondary)
        #expect(monthly.label == "Monthly")
        #expect(abs(monthly.usedPercent - 3.38) < 0.001)
        #expect(monthly.resetsAt != nil)
    }

    @Test
    func `count window wins over a duplicate 5h ratio pool`() throws {
        let snapshot = try self.parse("""
        {"limits": [{"window": {"duration": 300, "timeUnit": "TIME_UNIT_MINUTE"},
                     "detail": {"limit": "200", "used": "50"}}],
         "usage": {"limit": "1000", "used": "100"},
         "usages": {"limit_5h": {"used_ratio": 0.9}, "limit_month_total": {"used_ratio": 0.5}}}
        """)
        #expect(snapshot.primary.usedPercent == 25)
        #expect(snapshot.secondary?.label == "Weekly")
        #expect(snapshot.tertiary?.label == "Monthly")
    }

    @Test
    func `empty payload is an error, not a blank card`() {
        #expect(throws: KimiCodeUsageError.self) { try self.parse("{}") }
    }

    @Test
    func `usages URL honors KIMI_CODE_BASE_URL like kimi-cli`() {
        #expect(KimiCodeUsageFetcher.usagesURL(environment: [:])?.absoluteString
            == "https://api.kimi.com/coding/v1/usages")
        #expect(KimiCodeUsageFetcher.usagesURL(environment: ["KIMI_CODE_BASE_URL": "https://proxy.local/v1/"])?
            .absoluteString == "https://proxy.local/v1/usages")
    }
}
