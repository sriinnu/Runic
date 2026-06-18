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
    func `compaction keeps the latest event snapshot and drops superseded ones`() async throws {
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
        let timestamp = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12)))
        let dayKey = LedgerCache.dayKey(for: timestamp)

        // Two scans of the same day → two snapshots; the newer one wins.
        for (index, tokens) in [10, 50].enumerated() {
            await cache.mergeEntries(
                provider: "codex",
                entries: [self.entry(
                    timestamp: timestamp,
                    inputTokens: tokens,
                    requestID: "request-\(index)",
                    sourceFingerprint: "file-v\(index)")],
                scanDate: timestamp.addingTimeInterval(TimeInterval(10 * (index + 1))),
                sourceWatermarks: [
                    UsageRelaySourceWatermark(
                        dayKey: dayKey,
                        sourceKind: "codex-jsonl",
                        sourceID: "session.jsonl",
                        sourceFingerprint: "file-v\(index)"),
                ])
        }

        await cache.compactRelay(provider: "codex")

        // After compaction the latest snapshot's data must still materialize — the
        // superseded snapshot is dropped, but the day is NOT lost.
        try fm.removeItem(at: cacheDir.appendingPathComponent("codex-daily.json"))
        let restored = await cache.loadCachedDailies(provider: "codex")
        #expect(restored?.dailies.count == 1)
        #expect(restored?.dailies.first?.inputTokens == 50)
    }

    @Test
    func `relay writes one watermark per day regardless of source file count`() async throws {
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
        let timestamp = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12)))

        // Simulate a scan that touched 50 distinct source files — each used to
        // produce its own per-day watermark, exploding the relay to O(files × days).
        let fileWatermarks = (0..<50).map { index in
            UsageRelaySourceWatermark(
                dayKey: nil,
                sourceKind: "claude-jsonl",
                sourceID: "session-\(index).jsonl",
                sourceFingerprint: "fingerprint-\(index)")
        }
        await cache.mergeEntries(
            provider: "claude",
            entries: [self.entry(timestamp: timestamp, inputTokens: 10, requestID: "r1", sourceFingerprint: "f1")],
            scanDate: timestamp.addingTimeInterval(5),
            sourceWatermarks: fileWatermarks)

        let relayURL = await cache.relayHistoryFileURL(provider: "claude")
        let relayText = try String(contentsOf: relayURL, encoding: .utf8)
        let watermarkLines = relayText
            .split(separator: "\n")
            .filter { $0.contains(#""recordType":"watermark""#) }
        #expect(watermarkLines.count == 1)
    }

    @Test
    func `relay keeps heavy days above the legacy plausibility cap`() async throws {
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
        let timestamp = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12)))
        let dayKey = LedgerCache.dayKey(for: timestamp)

        // A real heavy day: well over the 100M-token legacy cap (cache reads alone
        // run into the hundreds of millions for power users).
        await cache.mergeEntries(
            provider: "claude",
            entries: [
                self.entry(timestamp: timestamp, inputTokens: 600_000_000, requestID: "r1", sourceFingerprint: "f1"),
            ],
            scanDate: timestamp.addingTimeInterval(10),
            sourceWatermarks: [
                UsageRelaySourceWatermark(
                    dayKey: dayKey,
                    sourceKind: "claude-jsonl",
                    sourceID: "session.jsonl",
                    sourceFingerprint: "f1"),
            ])

        try fm.removeItem(at: cacheDir.appendingPathComponent("claude-daily.json"))
        let restored = await cache.loadCachedDailies(provider: "claude")
        // Must NOT be quarantined: relay data is trusted, not legacy-suspect.
        #expect(restored?.dailies.count == 1)
        #expect(restored?.dailies.first?.inputTokens == 600_000_000)
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

    @Test
    func `relay collapses a busy day into one aggregate record`() async throws {
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

        let entryCount = 5000
        let entries = (0..<entryCount).map { index in
            self.entry(
                timestamp: timestamp.addingTimeInterval(Double(index)),
                inputTokens: 10,
                requestID: "request-\(index)",
                sourceFingerprint: "file-v1")
        }

        await cache.mergeEntries(
            provider: "codex",
            entries: entries,
            scanDate: timestamp.addingTimeInterval(Double(entryCount)),
            sourceWatermarks: [
                UsageRelaySourceWatermark(
                    dayKey: dayKey,
                    sourceKind: "codex-jsonl",
                    sourceID: "session.jsonl",
                    sourceFingerprint: "file-v1"),
            ])

        // The relay must remember the day as a single aggregate row, not 5000
        // verbatim event records — the regression that once drove the file past
        // 500MB. A busy day stays a handful of lines (one event + watermark).
        let relayFile = await cache.relayHistoryFileURL(provider: "codex")
        let relayText = try String(contentsOf: relayFile, encoding: .utf8)
        let recordCount = relayText.split(separator: "\n").count
        #expect(recordCount <= 8)

        // The aggregate still materializes the correct daily totals.
        try fm.removeItem(at: cacheDir.appendingPathComponent("codex-daily.json"))
        let restored = await cache.loadCachedDailies(provider: "codex")
        #expect(restored?.dailies.count == 1)
        #expect(restored?.dailies.first?.inputTokens == entryCount * 10)
        #expect(restored?.dailies.first?.requestCount == entryCount)
    }

    @Test
    func `relay materializes records written by an older schema version`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = LedgerCache(
            cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true),
            relayDir: root.appendingPathComponent("relay", isDirectory: true))
        let writtenAt = Date(timeIntervalSince1970: 1_767_252_000)

        func records(dayKey: String, tokens: Int, schemaVersion: Int) -> [UsageRelayRecord] {
            let snapshotID = "snapshot:codex:\(dayKey):\(schemaVersion)"
            let event = UsageRelayEvent(
                eventID: "daily-aggregate:codex:\(dayKey)",
                snapshotID: snapshotID,
                provider: "codex",
                timestamp: writtenAt,
                dayKey: dayKey,
                sessionID: nil,
                projectID: nil,
                projectName: nil,
                model: "gpt-5",
                modelsUsed: ["gpt-5"],
                inputTokens: tokens,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: nil,
                requestCount: 1,
                requestID: nil,
                messageID: nil,
                version: nil,
                source: "test",
                operationKind: nil,
                tokenProvenance: nil,
                costProvenance: nil,
                sourceFingerprint: nil)
            let watermark = UsageRelayWatermark(
                snapshotID: snapshotID,
                dayKey: dayKey,
                sourceKind: "test",
                sourceID: "test",
                sourceFingerprint: "test",
                path: nil,
                modifiedAt: nil,
                sizeBytes: nil,
                scannedAt: writtenAt)
            return [
                UsageRelayRecord(
                    schemaVersion: schemaVersion,
                    recordType: "event",
                    provider: "codex",
                    writtenAt: writtenAt,
                    event: event,
                    watermark: nil),
                UsageRelayRecord(
                    schemaVersion: schemaVersion,
                    recordType: "watermark",
                    provider: "codex",
                    writtenAt: writtenAt,
                    event: nil,
                    watermark: watermark),
            ]
        }

        // A day written by an OLDER schema must still materialize (the bug: `>=`
        // dropped it, blanking all history on a future schema bump). A FUTURE
        // schema we can't interpret is ignored.
        try await cache.appendRelayRecords(records(
            dayKey: "2026-01-01",
            tokens: 4242,
            schemaVersion: LedgerCache.relaySchemaVersion - 1))
        try await cache.appendRelayRecords(records(
            dayKey: "2026-01-02",
            tokens: 9999,
            schemaVersion: LedgerCache.relaySchemaVersion + 1))

        let restored = await cache.loadCachedDailies(provider: "codex")
        let byDay = Dictionary(uniqueKeysWithValues: (restored?.dailies ?? []).map { ($0.dayKey, $0) })
        #expect(byDay["2026-01-01"]?.inputTokens == 4242) // older schema survives
        #expect(byDay["2026-01-02"] == nil) // future schema ignored
    }

    @Test
    func `concurrent appends from two cache instances do not tear relay lines`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let relayDir = root.appendingPathComponent("relay", isDirectory: true)
        // Two instances over the SAME relay dir stand in for two processes; the
        // advisory flock must serialize their appends so no line is torn.
        let a = LedgerCache(cacheDir: root.appendingPathComponent("a", isDirectory: true), relayDir: relayDir)
        let b = LedgerCache(cacheDir: root.appendingPathComponent("b", isDirectory: true), relayDir: relayDir)
        let writtenAt = Date(timeIntervalSince1970: 1_767_252_000)

        func record(_ i: Int) -> [UsageRelayRecord] {
            let watermark = UsageRelayWatermark(
                snapshotID: "snap-\(i)",
                dayKey: "2026-01-01",
                sourceKind: "test",
                sourceID: "test",
                sourceFingerprint: "f-\(i)",
                path: nil,
                modifiedAt: nil,
                sizeBytes: nil,
                scannedAt: writtenAt)
            return [UsageRelayRecord(
                schemaVersion: LedgerCache.relaySchemaVersion,
                recordType: "watermark",
                provider: "codex",
                writtenAt: writtenAt,
                event: nil,
                watermark: watermark)]
        }

        let count = 40
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                let cache = (i % 2 == 0) ? a : b
                group.addTask { try? await cache.appendRelayRecords(record(i)) }
            }
        }

        let url = await a.relayHistoryFileURL(provider: "codex")
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n")
        #expect(lines.count == count) // no records lost
        for line in lines {
            // Every line is a complete, decodable record — none interleaved/torn.
            #expect((try? JSONDecoder().decode(UsageRelayRecord.self, from: Data(line.utf8))) != nil)
        }
        #expect(fm.fileExists(atPath: relayDir.appendingPathComponent("codex.lock").path))
    }

    @Test
    func `relay picks the last-appended snapshot even when its clock time is earlier`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cache = LedgerCache(
            cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true),
            relayDir: root.appendingPathComponent("relay", isDirectory: true))
        let dayKey = "2026-01-01"

        func records(tokens: Int, writtenAt: Date, tag: String) -> [UsageRelayRecord] {
            let snapshotID = "snapshot:codex:\(dayKey):\(tag)"
            let event = UsageRelayEvent(
                eventID: "daily-aggregate:codex:\(dayKey)",
                snapshotID: snapshotID,
                provider: "codex",
                timestamp: writtenAt,
                dayKey: dayKey,
                sessionID: nil,
                projectID: nil,
                projectName: nil,
                model: "gpt-5",
                modelsUsed: ["gpt-5"],
                inputTokens: tokens,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: nil,
                requestCount: 1,
                requestID: nil,
                messageID: nil,
                version: nil,
                source: "test",
                operationKind: nil,
                tokenProvenance: nil,
                costProvenance: nil,
                sourceFingerprint: nil)
            let watermark = UsageRelayWatermark(
                snapshotID: snapshotID,
                dayKey: dayKey,
                sourceKind: "test",
                sourceID: "test",
                sourceFingerprint: "test",
                path: nil,
                modifiedAt: nil,
                sizeBytes: nil,
                scannedAt: writtenAt)
            return [
                UsageRelayRecord(
                    schemaVersion: LedgerCache.relaySchemaVersion,
                    recordType: "event",
                    provider: "codex",
                    writtenAt: writtenAt,
                    event: event,
                    watermark: nil),
                UsageRelayRecord(
                    schemaVersion: LedgerCache.relaySchemaVersion,
                    recordType: "watermark",
                    provider: "codex",
                    writtenAt: writtenAt,
                    event: nil,
                    watermark: watermark),
            ]
        }

        let base = Date(timeIntervalSince1970: 1_767_252_000)
        // First append has a FUTURE clock time; the second (newer) scan's clock has
        // jumped backward. Append order, not wall-clock, must decide the winner.
        try await cache.appendRelayRecords(records(tokens: 100, writtenAt: base.addingTimeInterval(3600), tag: "a"))
        try await cache.appendRelayRecords(records(tokens: 200, writtenAt: base, tag: "b"))

        let restored = await cache.loadCachedDailies(provider: "codex")
        #expect(restored?.dailies.first?.inputTokens == 200) // last appended wins
    }

    @Test
    func `catch-up heal still triggers after the cache file is deleted but relay survives`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-ledger-cache-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let cacheDir = root.appendingPathComponent("ledger-cache", isDirectory: true)
        let cache = LedgerCache(cacheDir: cacheDir, relayDir: root.appendingPathComponent("relay", isDirectory: true))
        let timestamp = Date(timeIntervalSince1970: 1_767_252_000)

        await cache.mergeEntries(
            provider: "codex",
            entries: [self.entry(timestamp: timestamp, inputTokens: 10, requestID: "r1", sourceFingerprint: "f1")],
            scanDate: timestamp)
        #expect(await cache.needsCatchUpHeal(provider: "codex") == true) // unstamped install
        await cache.markCatchUpHealed(provider: "codex")
        #expect(await cache.needsCatchUpHeal(provider: "codex") == false) // stamped

        // Cache file deleted, relay survives — must still heal (and re-stamp).
        try fm.removeItem(at: cacheDir.appendingPathComponent("codex-daily.json"))
        #expect(await cache.needsCatchUpHeal(provider: "codex") == true)
        await cache.markCatchUpHealed(provider: "codex")
        #expect(await cache.needsCatchUpHeal(provider: "codex") == false) // file recreated + stamped
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
