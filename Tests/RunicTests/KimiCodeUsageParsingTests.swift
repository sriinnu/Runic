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

    @Test
    func `a Kimi Code base URL routes usages to that host, ahead of the env override`() {
        #expect(KimiCodeUsageFetcher.isKimiCodeHost("https://api.kimi.ai/coding/"))
        #expect(KimiCodeUsageFetcher.isKimiCodeHost("api.kimi.com/coding/v1"))
        #expect(KimiCodeUsageFetcher.isKimiCodeHost("HTTPS://API.KIMI.AI/Coding/"))
        #expect(!KimiCodeUsageFetcher.isKimiCodeHost("https://api.moonshot.ai"))
        #expect(!KimiCodeUsageFetcher.isKimiCodeHost("https://api.moonshot.cn/v1"))
        #expect(!KimiCodeUsageFetcher.isKimiCodeHost("https://www.kimi.com/code/console"))
        #expect(!KimiCodeUsageFetcher.isKimiCodeHost("https://api.kimi.ai.evil.com"))
        #expect(!KimiCodeUsageFetcher.isKimiCodeHost("https://notkimi.ai"))
        #expect(!KimiCodeUsageFetcher.isKimiCodeHost(nil))
        #expect(!KimiCodeUsageFetcher.isKimiCodeHost("  "))

        #expect(KimiCodeUsageFetcher.usagesURL(baseURL: "https://api.kimi.ai/coding/", environment: [:])?
            .absoluteString == "https://api.kimi.ai/coding/v1/usages")
        #expect(KimiCodeUsageFetcher.usagesURL(
            baseURL: "api.kimi.com/coding/v1",
            environment: ["KIMI_CODE_BASE_URL": "https://proxy.local/v1"])?
            .absoluteString == "https://api.kimi.com/coding/v1/usages")
        // A Moonshot host is not a plan host: fall through to the env/default resolution.
        #expect(KimiCodeUsageFetcher.usagesURL(baseURL: "https://api.moonshot.ai", environment: [:])?
            .absoluteString == "https://api.kimi.com/coding/v1/usages")
    }

    @Test
    func `a pasted endpoint, odd path, query, fragment or port never doubles the usages path`() {
        let cases: [(String, String)] = [
            ("https://api.kimi.ai/coding/v1/usages", "https://api.kimi.ai/coding/v1/usages"),
            ("https://api.kimi.ai/v1/coding", "https://api.kimi.ai/coding/v1/usages"),
            ("https://api.kimi.ai/coding?x=1", "https://api.kimi.ai/coding/v1/usages"),
            ("api.kimi.ai/coding/v1/#frag", "https://api.kimi.ai/coding/v1/usages"),
            ("https://api.kimi.com:8443/coding/", "https://api.kimi.com:8443/coding/v1/usages"),
            ("HTTPS://API.KIMI.AI/Coding/", "HTTPS://API.KIMI.AI/coding/v1/usages"),
        ]
        for (input, expected) in cases {
            #expect(
                KimiCodeUsageFetcher.usagesURL(baseURL: input, environment: [:])?.absoluteString == expected,
                "input \(input)")
        }
    }

    @Test
    func `a 404 retries the key on the plan platform only after a Kimi-operated host`() {
        #expect(KimiCodeUsageFetcher.isKimiOperatedHost("https://api.moonshot.ai"))
        #expect(KimiCodeUsageFetcher.isKimiOperatedHost("api.moonshot.cn/v1"))
        #expect(KimiCodeUsageFetcher.isKimiOperatedHost("https://www.kimi.com/code/console"))
        #expect(KimiCodeUsageFetcher.isKimiOperatedHost("https://api.kimi.ai"))
        #expect(!KimiCodeUsageFetcher.isKimiOperatedHost("https://gw.example.com"))
        #expect(!KimiCodeUsageFetcher.isKimiOperatedHost("https://moonshot.cn.evil.com"))
        #expect(!KimiCodeUsageFetcher.isKimiOperatedHost(nil))
    }

    @Test
    func `live 2026-10 shape: 5h count window, monthly pool, no weekly`() throws {
        let snapshot = try self.parse("""
        {"limits": [{"window": {"duration": 300, "timeUnit": "TIME_UNIT_MINUTE"},
                     "detail": {"limit": "100", "used": "15", "remaining": "85",
                                "resetTime": "2026-10-15T14:18:14.197162Z"}}],
         "usages": {"limit_5h": {"used_ratio": 0.1539, "reset_time": "2026-10-15T14:18:13Z"},
                    "limit_month_total": {"used_ratio": 0.0042, "reset_time": "2026-11-15T09:19:24Z"},
                    "limit_month_code": {"used_ratio": 0.0042, "reset_time": "2026-11-15T09:19:24Z"}}}
        """)
        #expect(snapshot.primary.label == "5h")
        #expect(snapshot.primary.usedPercent == 15)
        let monthly = try #require(snapshot.secondary)
        #expect(monthly.label == "Monthly")
        #expect(abs(monthly.usedPercent - 0.42) < 0.001)
        #expect(snapshot.tertiary == nil)
    }

    @Test
    func `monthly pool falls back to limit_month_code`() throws {
        let snapshot = try self.parse("""
        {"usages": {"limit_5h": {"used_ratio": 0.2},
                    "limit_month_code": {"used_ratio": 0.0042, "reset_time": "2026-11-15T09:19:24Z"}}}
        """)
        let monthly = try #require(snapshot.secondary)
        #expect(monthly.label == "Monthly")
        #expect(abs(monthly.usedPercent - 0.42) < 0.001)
        #expect(monthly.resetsAt != nil)
    }

    @Test
    func `a null or empty limit_month_total still falls back to limit_month_code`() throws {
        let nulled = try self.parse("""
        {"usages": {"limit_5h": {"used_ratio": 0.2}, "limit_month_total": null,
                    "limit_month_code": {"used_ratio": 0.0042}}}
        """)
        #expect(abs((nulled.secondary?.usedPercent ?? -1) - 0.42) < 0.001)
        let empty = try self.parse("""
        {"usages": {"limit_5h": {"used_ratio": 0.2}, "limit_month_total": {},
                    "limit_month_code": {"used_ratio": 0.0042}}}
        """)
        #expect(abs((empty.secondary?.usedPercent ?? -1) - 0.42) < 0.001)
    }
}
