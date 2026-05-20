import Foundation
import Testing
@testable import RunicCore

struct LedgerCacheTests {
    @Test
    func `merge dailies replaces today instead of accumulating repeated full scans`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = LedgerCache(cacheDir: root)
        let today = "2026-01-01"
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: today,
                    inputTokens: 100,
                    outputTokens: 20,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 10,
                    costUSD: 1,
                    requestCount: 1,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: Date(timeIntervalSince1970: 1_767_122_400),
            todayKey: today)

        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: today,
                    inputTokens: 120,
                    outputTokens: 25,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 12,
                    costUSD: 1.2,
                    requestCount: 2,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: Date(timeIntervalSince1970: 1_767_122_460),
            todayKey: today)

        let daily = await cache.loadCachedDailies(provider: "codex")?.dailies.first
        #expect(daily?.inputTokens == 120)
        #expect(daily?.outputTokens == 25)
        #expect(daily?.cacheReadTokens == 12)
        #expect(daily?.requestCount == 2)
    }

    @Test
    func `merge dailies replaces historical days when logs backfill`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = LedgerCache(cacheDir: root)
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: "2026-01-01",
                    inputTokens: 100,
                    outputTokens: 20,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 10,
                    costUSD: 1,
                    requestCount: 1,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: Date(timeIntervalSince1970: 1_767_122_400),
            todayKey: "2026-01-02")

        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: "2026-01-01",
                    inputTokens: 180,
                    outputTokens: 30,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 16,
                    costUSD: 1.8,
                    requestCount: 3,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: Date(timeIntervalSince1970: 1_767_122_460),
            todayKey: "2026-01-02")

        let daily = await cache.loadCachedDailies(provider: "codex")?.dailies.first
        #expect(daily?.inputTokens == 180)
        #expect(daily?.requestCount == 3)
    }
}
