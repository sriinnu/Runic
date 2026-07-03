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
        await cache.markCatchUpHealed(provider: "codex") // already-healed install

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
        await cache.markCatchUpHealed(provider: "codex") // already-healed install

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

        await cache.markCatchUpHealed(provider: "codex") // already-healed install

        _ = try await source.loadEntries()
        let repaired = await cache.loadCachedDailies(provider: "codex")?.dailies.first
        #expect(repaired?.inputTokens == 10)
        #expect(await cache.loadCachedDailies(provider: "codex")?.coveredMaxAgeDays == 1)
    }

    @Test
    func `codex backfill is one-shot then stays today-only`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
        try Self.writeSession(root: root, date: yesterday, input: 900, modifiedAt: now, fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))

        // First scan, empty cache → one-time backfill rebuild picks up yesterday.
        let first = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let firstEntries = try await first.loadEntries()
        #expect(firstEntries.map(\.inputTokens) == [900])

        // A NEW historical day appears. A second scan must NOT rebuild again — it
        // stays today-only, so this older day is ignored (the relay contract), and
        // there's no rebuild loop.
        try Self.writeSession(root: root, date: twoDaysAgo, input: 500, modifiedAt: now, fileManager: fm)
        let second = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let secondEntries = try await second.loadEntries()

        #expect(!secondEntries.map(\.inputTokens).contains(500))
        let dailies = await cache.loadCachedDailies(provider: "codex")?.dailies ?? []
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: yesterday) })
        #expect(!dailies.contains { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) })
    }

    @Test
    func `codex catches up missed days after a gap, not just today`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000) // 2026-01-02T12:00:00Z
        let cal = Calendar.current
        let fourDaysAgo = cal.date(byAdding: .day, value: -4, to: now) ?? now
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now
        // The user ran Codex on days the app was closed. Nothing today.
        try Self.writeSession(root: root, date: fourDaysAgo, input: 111, modifiedAt: now, fileManager: fm)
        try Self.writeSession(root: root, date: twoDaysAgo, input: 222, modifiedAt: now, fileManager: fm)

        // History is already covered, but the last scan was 4 days ago — the app
        // was closed. A today-only refresh would silently lose both gap days.
        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.markScanComplete(provider: "codex", scanDate: fourDaysAgo, coveredMaxAgeDays: 30)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()

        // Both missed days must be backfilled, not just today.
        #expect(entries.map(\.inputTokens).sorted() == [111, 222])
        let dailies = await cache.loadCachedDailies(provider: "codex")?.dailies ?? []
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: fourDaysAgo) })
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) })
        // Coverage must not shrink to the small catch-up window.
        #expect(await cache.loadCachedDailies(provider: "codex")?.coveredMaxAgeDays == 30)
    }

    @Test
    func `codex self-heals the legacy gap once even when lastScanDate is today`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let cal = Calendar.current
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: now) ?? now

        // Reproduce the stuck legacy state: an old today-only build already advanced
        // lastScanDate to TODAY (so normal gap detection sees gap=1), but a usage day
        // two days back was never backfilled. No heal stamp on the cache yet.
        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.markScanComplete(provider: "codex", scanDate: now, coveredMaxAgeDays: 30)
        #expect(await cache.needsCatchUpHeal(provider: "codex") == true)
        try Self.writeSession(root: root, date: twoDaysAgo, input: 333, modifiedAt: now, fileManager: fm)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        // First refresh: the one-time heal backfills the skipped day despite gap==1.
        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens) == [333])
        let dailies = await cache.loadCachedDailies(provider: "codex")?.dailies ?? []
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) })
        #expect(await cache.needsCatchUpHeal(provider: "codex") == false)

        // A NEW older day appears. The heal already ran, so a second refresh stays
        // today-only (gap==1) and must NOT re-backfill — no permanent heal loop.
        try Self.writeSession(root: root, date: threeDaysAgo, input: 999, modifiedAt: now, fileManager: fm)
        let second = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let secondEntries = try await second.loadEntries()
        #expect(!secondEntries.map(\.inputTokens).contains(999))
    }

    @Test
    func `codex catch-up clears a today that dropped to zero while a gap day has usage`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let cal = Calendar.current
        let todayKey = LedgerCache.dayKey(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now

        // Today already has an aggregate, last scan was 2 days ago (so a multi-day
        // catch-up fires), and today's raw session is gone (usage dropped to zero).
        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: todayKey,
                    inputTokens: 4321,
                    outputTokens: 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 9,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: twoDaysAgo,
            todayKey: nil,
            coveredMaxAgeDays: 30)
        await cache.markCatchUpHealed(provider: "codex") // isolate catch-up from the one-time heal
        try Self.writeSession(root: root, date: yesterday, input: 222, modifiedAt: now, fileManager: fm)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        _ = try await source.loadEntries()
        let dailies = await cache.loadCachedDailies(provider: "codex")?.dailies ?? []
        // Yesterday backfilled; today's stale aggregate cleared (not left behind).
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: yesterday) })
        #expect(!dailies.contains { $0.dayKey == todayKey })
    }

    @Test
    func `codex catch-up preserves a gap day whose raw logs rotated away`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let cal = Calendar.current
        let fourDaysAgo = cal.date(byAdding: .day, value: -4, to: now) ?? now
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now
        let fourDaysAgoKey = LedgerCache.dayKey(for: fourDaysAgo)

        // A real usage day exists in the gap with NO raw session file left — only
        // its relay aggregate survives (raw logs rotated away while app was shut).
        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: fourDaysAgoKey,
                    inputTokens: 7777,
                    outputTokens: 3,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 5,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: fourDaysAgo, // last scan 4 days ago → catch-up will fire
            todayKey: nil,
            coveredMaxAgeDays: 30)
        // Already-healed install: this exercises the NORMAL additive catch-up
        // (which preserves rotated-away days), not the one-time heal (a rebuild
        // that deliberately re-derives the window from raw logs).
        await cache.markCatchUpHealed(provider: "codex")
        // A more recent gap day DOES still have its raw session.
        try Self.writeSession(root: root, date: twoDaysAgo, input: 222, modifiedAt: now, fileManager: fm)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()

        // The recent gap day is backfilled from its raw logs...
        #expect(entries.map(\.inputTokens) == [222])
        let dailies = await cache.loadCachedDailies(provider: "codex")?.dailies ?? []
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) })
        // ...and the rotated-away day's relay aggregate must NOT be erased.
        let preserved = dailies.first { $0.dayKey == fourDaysAgoKey }
        #expect(preserved?.inputTokens == 7777)
    }

    @Test
    func `codex steady-state stays today-only when already scanned today`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now
        // An older day exists, plus a session today.
        try Self.writeSession(root: root, date: twoDaysAgo, input: 500, modifiedAt: now, fileManager: fm)
        try Self.writeSession(root: root, date: now, input: 40, modifiedAt: now, fileManager: fm)

        // Already scanned earlier today → gap is one day → no catch-up rebuild.
        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.markScanComplete(
            provider: "codex",
            scanDate: todayStart.addingTimeInterval(60 * 60),
            coveredMaxAgeDays: 30)
        // An already-healed install (the one-time legacy repair has run).
        await cache.markCatchUpHealed(provider: "codex")

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()
        // Only today; the older day is not re-scanned (relay contract holds).
        #expect(entries.map(\.inputTokens) == [40])
    }

    @Test
    func `codex rebuild with an unreadable file keeps that day's cached history`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let busyDay = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        // A readable session today so the scan isn't a total failure.
        try Self.writeSession(root: root, date: now, input: 700, modifiedAt: now, fileManager: fm)
        // The busy day's session, then make it unreadable to stand in for a file
        // a live session is rewriting mid-scan (the parser throws either way).
        try Self.writeSession(root: root, date: busyDay, input: 999, modifiedAt: now, fileManager: fm)
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: busyDay)
        let busyDir = root
            .appendingPathComponent(String(format: "%04d", parts.year ?? 1970), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.day ?? 1), isDirectory: true)
        let busyFile = try #require(
            try fm.contentsOfDirectory(at: busyDir, includingPropertiesForKeys: nil)
                .first { $0.pathExtension == "jsonl" })
        try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: busyFile.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: busyFile.path) }

        // The busy day already holds real cached history that must survive the scan.
        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.mergeDailies(
            provider: "codex",
            newDailies: [
                CachedDaily(
                    dayKey: LedgerCache.dayKey(for: busyDay),
                    inputTokens: 5000,
                    outputTokens: 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 1,
                    modelsUsed: ["gpt-5"]),
            ],
            scanDate: now,
            todayKey: nil,
            coveredMaxAgeDays: 3)

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache,
            scanMode: .rebuildHistory(maxAgeDays: 3))

        _ = try await source.loadEntries()

        // The busy day's file failed to read — its cached 5000 must NOT be erased
        // by a spurious empty snapshot.
        let busyDaily = await cache.loadCachedDailies(provider: "codex")?.dailies
            .first { $0.dayKey == LedgerCache.dayKey(for: busyDay) }
        #expect(busyDaily?.inputTokens == 5000)
    }

    @Test
    func `codex busy file during gap catch-up seals no gap day and retries next refresh`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000) // 2026-01-02T12:00:00Z
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now

        // Readable files: PARTIAL data for the gap day (a second file also
        // covering that day is busy) plus today's live usage.
        try Self.writeSession(root: root, date: yesterday, input: 111, modifiedAt: now, fileManager: fm)
        try Self.writeSession(root: root, date: now, input: 40, modifiedAt: now, fileManager: fm)
        // The busy file: unreadable mid-catch-up; we cannot know which gap days
        // it covers, so no gap day may be sealed from this partial scan.
        try Self.writeSession(root: root, date: twoDaysAgo, input: 999, modifiedAt: now, fileManager: fm)
        let parts = cal.dateComponents([.year, .month, .day], from: twoDaysAgo)
        let busyDir = root
            .appendingPathComponent(String(format: "%04d", parts.year ?? 1970), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.day ?? 1), isDirectory: true)
        let busyFile = try #require(
            try fm.contentsOfDirectory(at: busyDir, includingPropertiesForKeys: nil)
                .first { $0.pathExtension == "jsonl" })
        try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: busyFile.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: busyFile.path) }

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.markScanComplete(provider: "codex", scanDate: twoDaysAgo, coveredMaxAgeDays: 30)
        await cache.markCatchUpHealed(provider: "codex")

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()

        // Today (the mutable day) still lands; NO gap day is sealed with the
        // partial recount.
        #expect(entries.map(\.inputTokens) == [40])
        var dailies = await cache.loadCachedDailies(provider: "codex")?.dailies ?? []
        #expect(dailies.first { $0.dayKey == LedgerCache.dayKey(for: now) }?.inputTokens == 40)
        #expect(!dailies.contains { $0.dayKey == LedgerCache.dayKey(for: yesterday) })
        #expect(!dailies.contains { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) })
        // The anchor must NOT advance: the catch-up window stays open.
        #expect(await cache.scanGapDays(provider: "codex", now: now) == 3)

        // Once the busy file is readable again, the retried catch-up completes
        // every gap day in full.
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: busyFile.path)
        let retry = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let retried = try await retry.loadEntries()
        #expect(retried.map(\.inputTokens).sorted() == [40, 111, 999])
        dailies = await cache.loadCachedDailies(provider: "codex")?.dailies ?? []
        #expect(dailies.first { $0.dayKey == LedgerCache.dayKey(for: yesterday) }?.inputTokens == 111)
        #expect(dailies.first { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) }?.inputTokens == 999)
        #expect(await cache.scanGapDays(provider: "codex", now: now) == 1)
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
