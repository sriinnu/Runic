import Foundation
import Testing
@testable import RunicCore

struct UsageLedgerPeakBurnTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    /// Fri 30 Oct 2026, 20:00 Berlin.
    private var now: Date {
        self.calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 20))!
    }

    private func hour(dayOffset: Int, hour: Int, tokens: Int, provider: UsageProvider = .claude)
        -> UsageLedgerHourlySummary
    {
        let day = self.calendar.date(byAdding: .day, value: dayOffset, to: self.calendar.startOfDay(for: self.now))!
        let start = self.calendar.date(byAdding: .hour, value: hour, to: day)!
        return UsageLedgerHourlySummary(
            provider: provider,
            projectID: nil,
            hourStart: start,
            hourKey: "",
            totals: UsageLedgerTotals(
                inputTokens: tokens,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: nil),
            requestCount: 1)
    }

    @Test
    func `finds the afternoon slot that dominates the week`() throws {
        var hourly: [UsageLedgerHourlySummary] = []
        for day in -4...0 {
            hourly.append(self.hour(dayOffset: day, hour: 9, tokens: 100))
            hourly.append(self.hour(dayOffset: day, hour: 15, tokens: 300))
            hourly.append(self.hour(dayOffset: day, hour: 17, tokens: 200))
        }

        let peak = try #require(UsageLedgerAggregator.peakBurn(hourly: hourly, now: self.now, calendar: self.calendar))

        #expect(peak.startHour == 15)
        #expect(peak.endHour == 18)
        #expect(peak.tokens == 2500)
        #expect(abs(peak.share - 2500.0 / 3000.0) < 0.0001)
        #expect(peak.activeDays == 5)
    }

    @Test
    func `the last slot ends at midnight`() throws {
        let hourly = (-2...0).map { self.hour(dayOffset: $0, hour: 22, tokens: 500) }
            + [self.hour(dayOffset: 0, hour: 10, tokens: 10)]

        let peak = try #require(UsageLedgerAggregator.peakBurn(hourly: hourly, now: self.now, calendar: self.calendar))

        #expect(peak.startHour == 21)
        #expect(peak.endHour == 0)
    }

    @Test
    func `too few active days show no peak`() {
        let hourly = [
            self.hour(dayOffset: -1, hour: 15, tokens: 900),
            self.hour(dayOffset: 0, hour: 15, tokens: 900),
        ]

        #expect(UsageLedgerAggregator.peakBurn(hourly: hourly, now: self.now, calendar: self.calendar) == nil)
    }

    @Test
    func `an even spread shows no peak`() {
        var hourly: [UsageLedgerHourlySummary] = []
        for day in -4...0 {
            for hour in [9, 12, 15] {
                hourly.append(self.hour(dayOffset: day, hour: hour, tokens: 100))
            }
        }

        #expect(UsageLedgerAggregator.peakBurn(hourly: hourly, now: self.now, calendar: self.calendar) == nil)
    }

    @Test
    func `usage older than the lookback is ignored`() throws {
        var hourly = (-20 ... -8).map { self.hour(dayOffset: $0, hour: 3, tokens: 10000) }
        hourly += (-3...0).map { self.hour(dayOffset: $0, hour: 7, tokens: 100) }

        let peak = try #require(UsageLedgerAggregator.peakBurn(hourly: hourly, now: self.now, calendar: self.calendar))

        #expect(peak.startHour == 6)
        #expect(peak.activeDays == 4)
        #expect(peak.share == 1)
    }

    @Test
    func `hourly counts survive the relay round trip`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-peak-burn-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cacheDir = root.appendingPathComponent("ledger-cache", isDirectory: true)
        let cache = LedgerCache(cacheDir: cacheDir, relayDir: root.appendingPathComponent("relay", isDirectory: true))
        var hours = [Int](repeating: 0, count: 24)
        hours[15] = 300
        hours[9] = 100
        await cache.mergeDailies(
            provider: "claude",
            newDailies: [
                CachedDaily(
                    dayKey: "2026-01-01",
                    inputTokens: 400,
                    outputTokens: 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 2,
                    modelsUsed: [],
                    hourlyTokens: hours),
                CachedDaily(
                    dayKey: "2026-01-02",
                    inputTokens: 50,
                    outputTokens: 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 1,
                    modelsUsed: []),
            ],
            scanDate: Date(timeIntervalSince1970: 1_767_252_000),
            todayKey: "2026-01-02")

        // Only the relay is left: the hours must come back from it.
        try fm.removeItem(at: cacheDir.appendingPathComponent("claude-daily.json"))
        let restored = await cache.loadCachedDailies(provider: "claude")

        #expect(restored?.dailies.first?.dayKey == "2026-01-01")
        #expect(restored?.dailies.first?.hourlyTokens == hours)
    }

    @Test
    func `a day aggregate keeps tokens per local hour`() {
        let entries = [(9, 100), (15, 200), (15, 50)].map { hour, tokens in
            UsageLedgerEntry(
                provider: .claude,
                timestamp: self.calendar.date(bySettingHour: hour, minute: 10, second: 0, of: self.now)!,
                sessionID: nil,
                projectID: nil,
                projectName: nil,
                model: nil,
                inputTokens: tokens,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: nil,
                requestID: nil,
                messageID: nil,
                version: nil,
                source: .claudeLog)
        }

        let hours = UsageLedgerAggregator.hourlyTokens(entries, calendar: self.calendar)

        #expect(hours.count == 24)
        #expect(hours[9] == 100)
        #expect(hours[15] == 250)
        #expect(hours.reduce(0, +) == 350)
    }
}
