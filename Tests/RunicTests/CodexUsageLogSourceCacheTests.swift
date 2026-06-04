import Foundation
import Testing
@testable import RunicCore

extension CodexUsageLogSourceTests {
    @Test
    func `codex relay scans only today after bounded history is cached`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000) // 2026-01-02T12:00:00Z
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        try Self.writeSession(root: root, date: yesterday, input: 900, modifiedAt: now, fileManager: fm)
        try Self.writeSession(root: root, date: now, input: 40, modifiedAt: now, fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.markScanComplete(
            provider: "codex",
            scanDate: now.addingTimeInterval(-3600),
            coveredMaxAgeDays: 30)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()
        #expect(entries.count == 1)
        #expect(entries.first?.inputTokens == 40)
        #expect(await cache.loadCachedDailies(provider: "codex")?.coveredMaxAgeDays == 30)
    }

    @Test
    func `codex relay recomputes the whole mutable day after history coverage`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let todayStart = Calendar.current.startOfDay(for: now)
        let earlyToday = todayStart.addingTimeInterval(60 * 60)
        let laterToday = todayStart.addingTimeInterval(3 * 60 * 60)
        try Self.writeSession(root: root, date: earlyToday, input: 40, modifiedAt: earlyToday, fileManager: fm)
        try Self.writeSession(root: root, date: laterToday, input: 70, modifiedAt: now, fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.markScanComplete(
            provider: "codex",
            scanDate: todayStart.addingTimeInterval(2 * 60 * 60),
            coveredMaxAgeDays: 30)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens).sorted() == [40, 70])
    }

    @Test
    func `codex relay hot scan does not advance requested history coverage`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        try Self.writeSession(
            root: root,
            date: yesterday,
            input: 900,
            modifiedAt: now.addingTimeInterval(-7200),
            fileManager: fm)
        try Self.writeSession(
            root: root,
            date: now,
            input: 40,
            modifiedAt: now.addingTimeInterval(-7200),
            fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.markScanComplete(provider: "codex", scanDate: now, coveredMaxAgeDays: 1)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens).sorted() == [40])
        #expect(await cache.loadCachedDailies(provider: "codex")?.coveredMaxAgeDays == 1)
    }

    @Test
    func `codex relay preserves cached history instead of repairing from yesterday jsonl`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        try Self.writeSession(
            root: root,
            date: yesterday,
            input: 900,
            modifiedAt: now.addingTimeInterval(-7200),
            fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: LedgerCache.dayKey(for: yesterday),
                    inputTokens: 10,
                    outputTokens: 1,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 1,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: now,
            todayKey: nil,
            coveredMaxAgeDays: 1)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        _ = try await source.loadEntries()
        let repaired = await cache.loadCachedDailies(provider: "codex")?.dailies.first
        #expect(repaired?.inputTokens == 10)
        #expect(await cache.loadCachedDailies(provider: "codex")?.coveredMaxAgeDays == 1)
    }

    @Test
    func `codex backfills history once when cache is empty`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        try Self.writeSession(root: root, date: yesterday, input: 900, modifiedAt: now, fileManager: fm)

        // Empty cache, DEFAULT (today-only) scan mode. With nothing cached yet it
        // must do a one-time history rebuild and surface yesterday's usage, then
        // record coverage so subsequent refreshes return to today-only.
        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens) == [900])
        #expect(await cache.loadCachedDailies(provider: "codex")?.coveredMaxAgeDays == 30)
    }

    @Test
    func `codex rebuild repairs cached history from historical jsonl`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        try Self.writeSession(root: root, date: yesterday, input: 900, modifiedAt: now, fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: LedgerCache.dayKey(for: yesterday),
                    inputTokens: 10,
                    outputTokens: 1,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 1,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: now,
            todayKey: nil,
            coveredMaxAgeDays: 1)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache,
            scanMode: .rebuildHistory(maxAgeDays: 2))

        let entries = try await source.loadEntries()
        let repaired = await cache.loadCachedDailies(provider: "codex")?.dailies
            .first { $0.dayKey == LedgerCache.dayKey(for: yesterday) }
        #expect(entries.map(\.inputTokens) == [900])
        #expect(repaired?.inputTokens == 900)
        #expect(await cache.loadCachedDailies(provider: "codex")?.coveredMaxAgeDays == 2)
    }

    @Test
    func `codex rebuild clears stale cached days missing from raw window`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayKey = LedgerCache.dayKey(for: yesterday)
        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: yesterdayKey,
                    inputTokens: 10,
                    outputTokens: 1,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 1,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: now,
            todayKey: nil,
            coveredMaxAgeDays: 1)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache,
            scanMode: .rebuildHistory(maxAgeDays: 2))

        let entries = try await source.loadEntries()
        let dailies = await cache.loadCachedDailies(provider: "codex")?.dailies ?? []
        #expect(entries.isEmpty)
        #expect(!dailies.contains { $0.dayKey == yesterdayKey })
        #expect(await cache.loadCachedDailies(provider: "codex")?.coveredMaxAgeDays == 2)
    }
}
