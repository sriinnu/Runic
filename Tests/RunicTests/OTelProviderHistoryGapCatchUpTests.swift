import Foundation
import RunicCore
import Testing
@testable import Runic

/// Regression tests for the OTel provider-history gap catch-up: a covered
/// refresh used to read only entries `>= todayStart` while `lastScanDate`
/// still advanced, so days the app was closed during were permanently lost
/// for every OTel-backed provider (Copilot, Gemini, ...).
struct OTelProviderHistoryGapCatchUpTests {
    // MARK: - Scan window

    @Test
    func `covered steady state scans today only`() {
        let calendar = Calendar.current
        let now = Date()
        let start = CachedOTelProviderHistorySource.gapScanStart(
            gapDays: 1,
            requestedCoverageDays: 30,
            now: now,
            calendar: calendar)
        #expect(start == calendar.startOfDay(for: now))

        let neverScanned = CachedOTelProviderHistorySource.gapScanStart(
            gapDays: nil,
            requestedCoverageDays: 30,
            now: now,
            calendar: calendar)
        #expect(neverScanned == calendar.startOfDay(for: now))
    }

    @Test
    func `covered refresh widens back over a three day gap`() {
        let calendar = Calendar.current
        let now = Date()
        let start = CachedOTelProviderHistorySource.gapScanStart(
            gapDays: 4,
            requestedCoverageDays: 30,
            now: now,
            calendar: calendar)
        let expected = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: now))
        #expect(start == expected)
    }

    @Test
    func `gap catch up is bounded by the retention window`() {
        let calendar = Calendar.current
        let now = Date()
        let start = CachedOTelProviderHistorySource.gapScanStart(
            gapDays: 400,
            requestedCoverageDays: 30,
            now: now,
            calendar: calendar)
        let expected = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
        #expect(start == expected)
    }

    // MARK: - End-to-end catch-up

    @Test
    func `three day gap is additively backfilled from OTel files`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-otel-gap-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: todayStart)!
        }
        func key(_ offset: Int) -> String {
            LedgerCache.dayKey(for: day(offset))
        }

        // Established install: coverage exists, last scan was 3 days ago.
        // Day -3 was partially counted before the app closed; day -2 has an
        // aggregate whose raw entries have since rotated away.
        await cache.mergeDailies(
            provider: UsageProvider.copilot.rawValue,
            newDailies: [
                self.daily(dayKey: key(-3), inputTokens: 5, requestCount: 1),
                self.daily(dayKey: key(-2), inputTokens: 999, requestCount: 9),
            ],
            scanDate: day(-3),
            coveredMaxAgeDays: 60)
        #expect(await cache.scanGapDays(provider: UsageProvider.copilot.rawValue, now: now) == 4)

        // OTel file: full data for day -3, missed day -1, today, and an old
        // day -5 outside the catch-up window.
        let isoFormatter = ISO8601DateFormatter()
        func line(dayOffset: Int, inputTokens: Int) -> String {
            let timestamp = isoFormatter.string(
                from: day(dayOffset).addingTimeInterval(12 * 3600))
            return """
            {"timestamp":"\(timestamp)","attributes":{"gen_ai.system":"copilot",\
            "gen_ai.request.model":"gpt-5","gen_ai.usage.input_tokens":\(inputTokens),\
            "gen_ai.usage.output_tokens":0}}
            """
        }
        let otelFile = root.appendingPathComponent("copilot.jsonl")
        let lines = [
            line(dayOffset: -5, inputTokens: 7777),
            line(dayOffset: -3, inputTokens: 100),
            line(dayOffset: -3, inputTokens: 200),
            line(dayOffset: -1, inputTokens: 400),
            line(dayOffset: 0, inputTokens: 50),
        ]
        try lines.joined(separator: "\n").write(to: otelFile, atomically: true, encoding: .utf8)

        let source = CachedOTelProviderHistorySource(
            commonFiles: [],
            providerSpecificFiles: [otelFile],
            options: OTelGenAIIngestionOptions(
                enabled: true,
                allowExperimentalSemanticConventions: true,
                defaultProvider: .copilot,
                source: .openTelemetry),
            provider: .copilot,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()

        // Only the gap window [-3, today] is scanned; day -5 stays outside.
        #expect(entries.count == 4)
        #expect(entries.allSatisfy { $0.timestamp >= day(-3) })

        let dailies = await cache.loadCachedDailies(provider: UsageProvider.copilot.rawValue)?.dailies ?? []
        let byKey = Dictionary(uniqueKeysWithValues: dailies.map { ($0.dayKey, $0) })
        // Partially-counted day is REPLACED by the full recount, not doubled.
        #expect(byKey[key(-3)]?.inputTokens == 300)
        #expect(byKey[key(-3)]?.requestCount == 2)
        // Rotated-away day keeps its existing aggregate (additive, never a rebuild).
        #expect(byKey[key(-2)]?.inputTokens == 999)
        // Missed day and today are backfilled.
        #expect(byKey[key(-1)]?.inputTokens == 400)
        #expect(byKey[key(0)]?.inputTokens == 50)
        // Day outside the catch-up window is not materialized.
        #expect(byKey[key(-5)] == nil)
        // The scan anchor advanced, so the next refresh is today-only again.
        #expect(await cache.scanGapDays(provider: UsageProvider.copilot.rawValue, now: now) == 1)
    }

    @Test
    func `gap catch-up never seals today's partial aggregate into the relay`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-otel-gap-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        let calendar = Calendar.current
        // Mid-day, so the catch-up runs while today is still partial.
        let now = try #require(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()))
        let todayStart = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: todayStart)!
        }
        func key(_ offset: Int) -> String {
            LedgerCache.dayKey(for: day(offset))
        }
        let provider = UsageProvider.copilot.rawValue

        // Established install, last scanned YESTERDAY: the everyday morning
        // rollover (scanGapDays == 2), so the catch-up path fires daily.
        await cache.mergeDailies(
            provider: provider,
            newDailies: [self.daily(dayKey: key(-1), inputTokens: 5, requestCount: 1)],
            scanDate: day(-1),
            coveredMaxAgeDays: 60)
        #expect(await cache.scanGapDays(provider: provider, now: now) == 2)

        let isoFormatter = ISO8601DateFormatter()
        func line(dayOffset: Int, hour: Int, inputTokens: Int, model: String = "gpt-5") -> String {
            let timestamp = isoFormatter.string(
                from: day(dayOffset).addingTimeInterval(TimeInterval(hour) * 3600))
            return """
            {"timestamp":"\(timestamp)","attributes":{"gen_ai.system":"copilot",\
            "gen_ai.request.model":"\(model)","gen_ai.usage.input_tokens":\(inputTokens),\
            "gen_ai.usage.output_tokens":0}}
            """
        }
        func makeSource(now: Date) -> CachedOTelProviderHistorySource {
            CachedOTelProviderHistorySource(
                commonFiles: [],
                providerSpecificFiles: [root.appendingPathComponent("copilot.jsonl")],
                options: OTelGenAIIngestionOptions(
                    enabled: true,
                    allowExperimentalSemanticConventions: true,
                    defaultProvider: .copilot,
                    source: .openTelemetry),
                provider: .copilot,
                maxAgeDays: 30,
                now: now,
                cache: cache)
        }
        let otelFile = root.appendingPathComponent("copilot.jsonl")
        var lines = [
            line(dayOffset: -1, hour: 12, inputTokens: 100),
            // Two models: modelsUsed must come out deterministically sorted or
            // every later merge sees a "changed" day and re-archives it.
            line(dayOffset: 0, hour: 9, inputTokens: 50, model: "zeta-model"),
        ]
        try lines.joined(separator: "\n").write(to: otelFile, atomically: true, encoding: .utf8)

        // Morning-rollover catch-up at a mid-day timestamp.
        _ = try await makeSource(now: now).loadEntries()

        // (c) The relay must contain NO daily-summary row for the catch-up
        // day itself — today is still partial and would be pinned.
        let relayURL = await cache.relayHistoryFileURL(provider: provider)
        let relayText = (try? String(contentsOf: relayURL, encoding: .utf8)) ?? ""
        #expect(!relayText.contains("\"dayKey\":\"\(key(0))\""))
        #expect(relayText.contains("\"dayKey\":\"\(key(-1))\""))

        // (a) A follow-up SAME-DAY refresh with more entries must surface the
        // larger today total (a relay-pinned today would stay at 50).
        lines.append(line(dayOffset: 0, hour: 10, inputTokens: 30, model: "alpha-model"))
        try lines.joined(separator: "\n").write(to: otelFile, atomically: true, encoding: .utf8)
        _ = try await makeSource(now: now).loadEntries()
        var dailies = await cache.loadCachedDailies(provider: provider)?.dailies ?? []
        var byKey = Dictionary(uniqueKeysWithValues: dailies.map { ($0.dayKey, $0) })
        #expect(byKey[key(0)]?.inputTokens == 80)
        #expect(byKey[key(-1)]?.inputTokens == 100)
        #expect(byKey[key(0)]?.modelsUsed == ["alpha-model", "zeta-model"])

        // (b) Next day, the rollover catch-up seals yesterday at its FULL
        // value — including entries that arrived after the mid-day catch-up.
        lines.append(line(dayOffset: 0, hour: 20, inputTokens: 20, model: "alpha-model"))
        try lines.joined(separator: "\n").write(to: otelFile, atomically: true, encoding: .utf8)
        let nextDay = day(1).addingTimeInterval(12 * 3600)
        _ = try await makeSource(now: nextDay).loadEntries()
        dailies = await cache.loadCachedDailies(provider: provider)?.dailies ?? []
        byKey = Dictionary(uniqueKeysWithValues: dailies.map { ($0.dayKey, $0) })
        #expect(byKey[key(0)]?.inputTokens == 100)
        // The new "today" (day +1) is in turn not sealed into the relay.
        let rolledText = (try? String(contentsOf: relayURL, encoding: .utf8)) ?? ""
        #expect(rolledText.contains("\"dayKey\":\"\(key(0))\""))
        #expect(!rolledText.contains("\"dayKey\":\"\(key(1))\""))
    }

    private func daily(dayKey: String, inputTokens: Int, requestCount: Int) -> CachedDaily {
        CachedDaily(
            dayKey: dayKey,
            inputTokens: inputTokens,
            outputTokens: 0,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            costUSD: nil,
            requestCount: requestCount,
            modelsUsed: ["gpt-5"])
    }
}
