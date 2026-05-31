import Foundation
import Testing
@testable import RunicCore

extension LedgerCacheTests {
    @Test
    func `merge dailies can rebuild historical days for full backfill`() async throws {
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
            todayKey: nil)

        let daily = await cache.loadCachedDailies(provider: "codex")?.dailies.first
        #expect(daily?.inputTokens == 180)
        #expect(daily?.requestCount == 3)
    }

    @Test
    func `scan completion records bounded coverage without entries`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = LedgerCache(cacheDir: root)
        await cache.markScanComplete(
            provider: "codex",
            scanDate: Date(timeIntervalSince1970: 1_767_122_400),
            coveredMaxAgeDays: 30)

        let ledger = await cache.loadCachedDailies(provider: "codex")
        #expect(ledger?.dailies.isEmpty == true)
        #expect(ledger?.coveredMaxAgeDays == 30)
        #expect(ledger?.lastFullScanDate != nil)
    }

    @Test
    func `effective coverage infers legacy cached day count`() async throws {
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
                    inputTokens: 1,
                    outputTokens: 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 1,
                    modelsUsed: []),
                CachedDaily(
                    dayKey: "2026-01-02",
                    inputTokens: 2,
                    outputTokens: 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 1,
                    modelsUsed: []),
            ],
            scanDate: Date(timeIntervalSince1970: 1_767_122_400),
            todayKey: nil)

        #expect(await cache.coveredMaxAgeDays(provider: "codex") == nil)
        #expect(await cache.effectiveCoveredMaxAgeDays(provider: "codex") == 2)
    }

    @Test
    func `cached ledger decodes legacy json without coverage`() throws {
        let data = Data("""
        {
          "lastScanDate": 1767122400,
          "lastFullScanDate": null,
          "dailies": []
        }
        """.utf8)

        let ledger = try JSONDecoder().decode(CachedLedger.self, from: data)
        #expect(ledger.coveredMaxAgeDays == nil)
        #expect(ledger.dailies.isEmpty)
    }
}
