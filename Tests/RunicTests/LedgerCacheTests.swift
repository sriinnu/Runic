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
    func `merge dailies keeps existing historical days frozen on menu refresh`() async throws {
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
        #expect(daily?.inputTokens == 100)
        #expect(daily?.requestCount == 1)
    }

    @Test
    func `relay archives historical days and restores without mutable cache`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cacheDir = root.appendingPathComponent("ledger-cache", isDirectory: true)
        let relayDir = root.appendingPathComponent("relay", isDirectory: true)
        let cache = LedgerCache(cacheDir: cacheDir, relayDir: relayDir)
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
                CachedDaily(
                    dayKey: "2026-01-02",
                    inputTokens: 200,
                    outputTokens: 40,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 20,
                    costUSD: 2,
                    requestCount: 2,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: Date(timeIntervalSince1970: 1_767_252_000),
            todayKey: "2026-01-02")

        let relayFile = await cache.relayHistoryFileURL(provider: "codex")
        #expect(fm.fileExists(atPath: relayFile.path))
        #expect(relayFile.lastPathComponent == "codex-events.jsonl")
        let relayText = try String(contentsOf: relayFile, encoding: .utf8)
        #expect(relayText.contains(#""recordType":"event""#))
        #expect(relayText.contains(#""recordType":"watermark""#))

        try fm.removeItem(at: cacheDir.appendingPathComponent("codex-daily.json"))

        let restored = await cache.loadCachedDailies(provider: "codex")
        #expect(restored?.dailies.count == 1)
        #expect(restored?.dailies.first?.dayKey == "2026-01-01")
        #expect(restored?.dailies.first?.inputTokens == 100)
    }

    @Test
    func `relay materializes latest event snapshot for a day`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cacheDir = root.appendingPathComponent("ledger-cache", isDirectory: true)
        let relayDir = root.appendingPathComponent("relay", isDirectory: true)
        let cache = LedgerCache(cacheDir: cacheDir, relayDir: relayDir)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let timestamp = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 1,
            hour: 12)))
        let dayKey = LedgerCache.dayKey(for: timestamp)

        await cache.mergeEntries(
            provider: "codex",
            entries: [
                self.entry(
                    timestamp: timestamp,
                    inputTokens: 10,
                    requestID: "request-1",
                    sourceFingerprint: "file-v1"),
            ],
            scanDate: timestamp.addingTimeInterval(10),
            sourceWatermarks: [
                UsageRelaySourceWatermark(
                    dayKey: dayKey,
                    sourceKind: "codex-jsonl",
                    sourceID: "session.jsonl",
                    sourceFingerprint: "file-v1"),
            ])

        await cache.mergeEntries(
            provider: "codex",
            entries: [
                self.entry(
                    timestamp: timestamp,
                    inputTokens: 20,
                    requestID: "request-2",
                    sourceFingerprint: "file-v2"),
            ],
            scanDate: timestamp.addingTimeInterval(20),
            sourceWatermarks: [
                UsageRelaySourceWatermark(
                    dayKey: dayKey,
                    sourceKind: "codex-jsonl",
                    sourceID: "session.jsonl",
                    sourceFingerprint: "file-v2"),
            ])

        try fm.removeItem(at: cacheDir.appendingPathComponent("codex-daily.json"))

        let restored = await cache.loadCachedDailies(provider: "codex")
        #expect(restored?.dailies.count == 1)
        #expect(restored?.dailies.first?.inputTokens == 20)
        #expect(restored?.dailies.first?.requestCount == 1)
    }

    @Test
    func `relay latest empty snapshot clears stale materialized day`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = LedgerCache(cacheDir: root)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let timestamp = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 1,
            hour: 12)))
        let dayKey = LedgerCache.dayKey(for: timestamp)

        await cache.mergeEntries(
            provider: "codex",
            entries: [
                self.entry(
                    timestamp: timestamp,
                    inputTokens: 10,
                    requestID: "request-1",
                    sourceFingerprint: "file-v1"),
            ],
            scanDate: timestamp.addingTimeInterval(10),
            todayKey: dayKey,
            sourceWatermarks: [
                UsageRelaySourceWatermark(
                    dayKey: dayKey,
                    sourceKind: "codex-jsonl",
                    sourceID: "session.jsonl",
                    sourceFingerprint: "file-v1"),
            ])

        await cache.mergeEntries(
            provider: "codex",
            entries: [],
            scanDate: timestamp.addingTimeInterval(20),
            todayKey: dayKey,
            sourceWatermarks: [
                UsageRelaySourceWatermark(
                    dayKey: dayKey,
                    sourceKind: "codex-jsonl",
                    sourceID: "session.jsonl",
                    sourceFingerprint: "file-v2"),
            ])

        let restored = await cache.loadCachedDailies(provider: "codex")
        #expect(restored?.dailies.isEmpty == true)
    }

    @Test
    func `relay migrates legacy cost usage cache by day`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let legacyCacheRoot = root.appendingPathComponent("legacy-cache", isDirectory: true)
        var legacy = CostUsageCache()
        legacy.days = [
            "2025-12-31": [
                "gpt-5": [340_001_678_885, 323_225_538_944, 943_215_430],
            ],
            "2026-01-01": [
                "gpt-5": [100, 10, 20],
            ],
        ]
        CostUsageCacheIO.save(provider: .codex, cache: legacy, cacheRoot: legacyCacheRoot)

        let cache = LedgerCache(
            cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true),
            relayDir: root.appendingPathComponent("relay", isDirectory: true),
            legacyCostCacheRoot: legacyCacheRoot)
        await cache.migrateLegacyRelaySeedsIfNeeded(
            provider: "codex",
            scanDate: Date(timeIntervalSince1970: 1_767_252_000),
            todayKey: "2026-01-02")

        let restored = await cache.loadCachedDailies(provider: "codex")
        #expect(restored?.dailies.map(\.dayKey) == ["2026-01-01"])
        #expect(restored?.dailies.first?.inputTokens == 100)
        #expect(restored?.dailies.first?.cacheReadTokens == 10)
        #expect(restored?.dailies.first?.outputTokens == 20)
    }

    @Test
    func `legacy implausible codex dailies are quarantined`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = LedgerCache(cacheDir: root)
        let legacy = """
        {
          "lastScanDate": 1767254400,
          "lastFullScanDate": 1767254400,
          "coveredMaxAgeDays": 365,
          "dailies": [
            {
              "dayKey": "2026-01-01",
              "inputTokens": 340001678885,
              "outputTokens": 943215430,
              "cacheCreationTokens": 0,
              "cacheReadTokens": 323225538944,
              "costUSD": 1000,
              "requestCount": 1872308,
              "modelsUsed": ["gpt-5"]
            },
            {
              "dayKey": "2026-01-02",
              "inputTokens": 100,
              "outputTokens": 20,
              "cacheCreationTokens": 0,
              "cacheReadTokens": 10,
              "costUSD": 1,
              "requestCount": 1,
              "modelsUsed": ["gpt-5"]
            }
          ]
        }
        """
        try legacy.write(to: root.appendingPathComponent("codex-daily.json"), atomically: true, encoding: .utf8)

        let loaded = await cache.loadCachedDailies(provider: "codex")
        #expect(loaded?.dailies.map(\.dayKey) == ["2026-01-02"])
    }

    private func entry(
        timestamp: Date,
        inputTokens: Int,
        requestID: String,
        sourceFingerprint: String)
        -> UsageLedgerEntry
    {
        UsageLedgerEntry(
            provider: .codex,
            timestamp: timestamp,
            sessionID: "session",
            projectID: nil,
            model: "gpt-5",
            inputTokens: inputTokens,
            outputTokens: 1,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            costUSD: nil,
            requestID: requestID,
            messageID: nil,
            version: nil,
            source: .codexLog,
            sourceFingerprint: sourceFingerprint)
    }
}
