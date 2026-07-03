import Foundation
import Testing
@testable import RunicCore

/// Perf-fix behavior coverage: changed-days-only relay archiving, relay memo
/// invalidation, the one-time legacy-seed stamp, and live-timezone day keys.
struct LedgerCachePerfTests {
    private static func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-ledger-perf-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func daily(_ dayKey: String, input: Int, output: Int = 10, requests: Int = 1) -> CachedDaily {
        CachedDaily(
            dayKey: dayKey,
            inputTokens: input,
            outputTokens: output,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            costUSD: nil,
            requestCount: requests,
            modelsUsed: ["gpt-5"])
    }

    private static func relayLineCount(_ url: URL) -> Int {
        guard let data = try? Data(contentsOf: url) else { return 0 }
        return data.split(separator: 0x0A, omittingEmptySubsequences: true).count
    }

    // MARK: - Item 5: changed-days-only archiving

    @Test
    func `merge dailies archives nothing when no aggregate changed`() async throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = LedgerCache(cacheDir: root)
        let scan1 = Date(timeIntervalSince1970: 1_767_122_400)

        await cache.mergeDailies(
            provider: "codex",
            newDailies: [Self.daily("2025-12-30", input: 100), Self.daily("2025-12-31", input: 200)],
            scanDate: scan1)
        let relayURL = await cache.relayHistoryFileURL(provider: "codex")
        let afterFirst = Self.relayLineCount(relayURL)
        #expect(afterFirst == 4) // 2 days × (event + watermark)

        // Identical content again: an unchanged day must add NO relay records.
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [Self.daily("2025-12-30", input: 100), Self.daily("2025-12-31", input: 200)],
            scanDate: scan1.addingTimeInterval(90))
        #expect(Self.relayLineCount(relayURL) == afterFirst)

        let dailies = await cache.loadCachedDailies(provider: "codex")?.dailies
        #expect(dailies?.count == 2)
    }

    @Test
    func `merge dailies archives exactly one event and watermark for a changed day`() async throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = LedgerCache(cacheDir: root)
        let scan1 = Date(timeIntervalSince1970: 1_767_122_400)

        await cache.mergeDailies(
            provider: "codex",
            newDailies: [Self.daily("2025-12-30", input: 100), Self.daily("2025-12-31", input: 200)],
            scanDate: scan1)
        let relayURL = await cache.relayHistoryFileURL(provider: "codex")
        let afterFirst = Self.relayLineCount(relayURL)

        // One day changes → exactly one new event + one new watermark; the
        // unchanged day contributes nothing.
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [Self.daily("2025-12-30", input: 100), Self.daily("2025-12-31", input: 250)],
            scanDate: scan1.addingTimeInterval(90))
        #expect(Self.relayLineCount(relayURL) == afterFirst + 2)

        // Replace semantics hold: the changed day's aggregate is the new value.
        let dailies = await cache.loadCachedDailies(provider: "codex")?.dailies
        #expect(dailies?.first { $0.dayKey == "2025-12-31" }?.inputTokens == 250)
        #expect(dailies?.first { $0.dayKey == "2025-12-30" }?.inputTokens == 100)
    }

    @Test
    func `merge dailies with today key never archives today and keeps frozen days silent`() async throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = LedgerCache(cacheDir: root)
        let scan1 = Date(timeIntervalSince1970: 1_767_122_400)
        let today = "2026-01-01"

        await cache.mergeDailies(
            provider: "codex",
            newDailies: [Self.daily("2025-12-31", input: 200), Self.daily(today, input: 50)],
            scanDate: scan1,
            todayKey: today)
        let relayURL = await cache.relayHistoryFileURL(provider: "codex")
        let afterFirst = Self.relayLineCount(relayURL)
        #expect(afterFirst == 2) // only the historical day; today is live-only

        // Steady state refresh: only today's number moves. Historical day is
        // frozen (skipped), today is < todayKey ? no — today is excluded from
        // relay archiving. Net: zero new relay records.
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [Self.daily("2025-12-31", input: 999), Self.daily(today, input: 75)],
            scanDate: scan1.addingTimeInterval(90),
            todayKey: today)
        #expect(Self.relayLineCount(relayURL) == afterFirst)

        let dailies = await cache.loadCachedDailies(provider: "codex")?.dailies
        #expect(dailies?.first { $0.dayKey == "2025-12-31" }?.inputTokens == 200) // frozen
        #expect(dailies?.first { $0.dayKey == today }?.inputTokens == 75) // replaced
    }

    // MARK: - Item 4: relay memo invalidation

    @Test
    func `relay memo observes appends from another cache instance`() async throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let cacheA = LedgerCache(cacheDir: root)
        let cacheB = LedgerCache(cacheDir: root)
        let scanDate = Date(timeIntervalSince1970: 1_767_122_400)

        await cacheA.mergeDailies(
            provider: "codex",
            newDailies: [Self.daily("2025-12-30", input: 100)],
            scanDate: scanDate)
        // Prime A's memo.
        let first = await cacheA.loadCachedDailies(provider: "codex")
        #expect(first?.dailies.count == 1)

        // B appends relay-only records (no daily cache file write), the exact
        // change a stale memo would hide.
        _ = await cacheB.archiveDailySummariesAsRelayEvents(
            provider: "codex",
            dailies: [Self.daily("2025-12-29", input: 70)],
            writtenAt: scanDate.addingTimeInterval(10))

        let second = await cacheA.loadCachedDailies(provider: "codex")
        #expect(second?.dailies.contains { $0.dayKey == "2025-12-29" && $0.inputTokens == 70 } == true)
    }

    // MARK: - Item 4: legacy cost-cache seed stamp

    @Test
    func `legacy cost cache seeds once and is stamped complete`() async throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let legacyRoot = root.appendingPathComponent("legacy", isDirectory: true)
        let cache = LedgerCache(cacheDir: root, legacyCostCacheRoot: legacyRoot)
        let scanDate = Date(timeIntervalSince1970: 1_767_122_400)
        let today = "2026-01-01"

        var legacy = CostUsageCache()
        legacy.days = ["2025-12-30": ["gpt-5": [100, 0, 10]]]
        CostUsageCacheIO.save(provider: .codex, cache: legacy, cacheRoot: legacyRoot)

        await cache.mergeEntries(provider: "codex", entries: [], scanDate: scanDate, todayKey: today)
        let seeded = await cache.loadCachedDailies(provider: "codex")?.dailies
        #expect(seeded?.contains { $0.dayKey == "2025-12-30" } == true)

        // The stamp is persisted next to the relay.
        let stampURL = await cache.relayHistoryFileURL(provider: "codex")
            .deletingLastPathComponent()
            .appendingPathComponent("codex.legacy-seeded")
        #expect(FileManager.default.fileExists(atPath: stampURL.path))

        // A day added to the legacy cache AFTER seeding must never be read
        // again — the stamp short-circuits the disk load.
        legacy.days["2025-12-28"] = ["gpt-5": [40, 0, 4]]
        CostUsageCacheIO.save(provider: .codex, cache: legacy, cacheRoot: legacyRoot)
        await cache.mergeEntries(
            provider: "codex",
            entries: [],
            scanDate: scanDate.addingTimeInterval(90),
            todayKey: today)
        let after = await cache.loadCachedDailies(provider: "codex")?.dailies
        #expect(after?.contains { $0.dayKey == "2025-12-28" } == false)

        // The persisted stamp survives a new instance (fresh in-memory state).
        let cache2 = LedgerCache(cacheDir: root, legacyCostCacheRoot: legacyRoot)
        await cache2.mergeEntries(
            provider: "codex",
            entries: [],
            scanDate: scanDate.addingTimeInterval(180),
            todayKey: today)
        let afterRestart = await cache2.loadCachedDailies(provider: "codex")?.dailies
        #expect(afterRestart?.contains { $0.dayKey == "2025-12-28" } == false)
    }

    // MARK: - Item 6: live-timezone day keys

    @Test
    func `day key derivation follows the requested timezone per call`() throws {
        let box = LedgerDayKeyFormatterBox()
        // 2026-01-01T00:30:00Z straddles midnight UTC.
        let instant = Date(timeIntervalSince1970: 1_767_227_400)
        let utc = try #require(TimeZone(identifier: "UTC"))
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))

        #expect(box.string(from: instant, timeZone: utc) == "2026-01-01")
        // A timezone change mid-run must be reflected immediately (no frozen
        // launch-time zone).
        #expect(box.string(from: instant, timeZone: losAngeles) == "2025-12-31")
        #expect(box.string(from: instant, timeZone: utc) == "2026-01-01")

        // Round-trip: parsing a key yields that day's local midnight.
        let parsed = box.date(from: "2026-01-01", timeZone: utc)
        #expect(parsed == Date(timeIntervalSince1970: 1_767_225_600))
    }
}
