import Foundation
import Testing
@testable import RunicCore

struct ClaudeUsageLogSourceCacheTests {
    /// Write one minimal Claude JSONL session under `<base>/projects/<project>/<session>.jsonl`.
    static func writeSession( // swiftlint:disable:this function_parameter_count
        base: URL,
        project: String,
        session: String,
        date: Date,
        input: Int,
        modifiedAt: Date,
        fileManager fm: FileManager) throws -> URL
    {
        let dir = base
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(project, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(session).jsonl")
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let line = "{\"timestamp\":\"\(iso.string(from: date))\"," +
            "\"requestId\":\"\(session)-req\"," +
            "\"message\":{\"id\":\"\(session)-msg\",\"model\":\"claude-sonnet-4\"," +
            "\"usage\":{\"input_tokens\":\(input),\"output_tokens\":1}}}\n"
        try line.write(to: file, atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: file.path)
        return file
    }

    @Test
    func `claude busy file is skipped, not fatal, and keeps the rest of the scan`() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory
            .appendingPathComponent("runic-claude-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        // Two sessions today: one readable, one unreadable (a live session rewriting it).
        _ = try Self.writeSession(
            base: base,
            project: "proj",
            session: "ok",
            date: now,
            input: 700,
            modifiedAt: now,
            fileManager: fm)
        let busy = try Self.writeSession(
            base: base,
            project: "proj",
            session: "busy",
            date: now,
            input: 999,
            modifiedAt: now,
            fileManager: fm)
        try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: busy.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: busy.path) }

        let cache = LedgerCache(cacheDir: base.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.markScanComplete(provider: "claude", scanDate: now, coveredMaxAgeDays: 30)
        await cache.markCatchUpHealed(provider: "claude") // already-healed install

        let source = ClaudeUsageLogSource(
            environment: [:],
            fileManager: fm,
            basePaths: [base],
            maxAgeDays: 30,
            now: now,
            cache: cache)

        // The busy file must NOT abort the scan — the readable one still lands.
        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens) == [700])
    }

    // L9: a retried request reuses its requestId across DISTINCT usage-bearing
    // messages — dedupe must key on messageId+requestId, not requestId alone,
    // or the retry's second message is silently dropped.
    @Test
    func `claude retried request with distinct messages keeps both`() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory
            .appendingPathComponent("runic-claude-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let dir = base
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent("proj", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        func line(messageID: String, input: Int, at date: Date) -> String {
            "{\"timestamp\":\"\(iso.string(from: date))\"," +
                "\"requestId\":\"req-retry\"," +
                "\"message\":{\"id\":\"\(messageID)\",\"model\":\"claude-sonnet-4\"," +
                "\"usage\":{\"input_tokens\":\(input),\"output_tokens\":1}}}"
        }
        let retryFile = dir.appendingPathComponent("retry.jsonl")
        let body = line(messageID: "msg-a", input: 100, at: now) + "\n"
            + line(messageID: "msg-b", input: 50, at: now.addingTimeInterval(1)) + "\n"
        try body.write(to: retryFile, atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: now], ofItemAtPath: retryFile.path)
        // The SAME message duplicated into a second file (e.g. a resumed session
        // copy) must still dedupe across files.
        let dupFile = dir.appendingPathComponent("dup.jsonl")
        try (line(messageID: "msg-a", input: 100, at: now) + "\n")
            .write(to: dupFile, atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: now], ofItemAtPath: dupFile.path)

        let cache = LedgerCache(cacheDir: base.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = ClaudeUsageLogSource(
            environment: [:],
            fileManager: fm,
            basePaths: [base],
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()
        // Both retry messages land; the cross-file duplicate of msg-a does not.
        #expect(entries.count == 2)
        #expect(entries.map(\.inputTokens).sorted() == [50, 100])
    }

    @Test
    func `claude busy file during gap catch-up seals no gap day and retries next refresh`() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory
            .appendingPathComponent("runic-claude-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now

        // Readable: PARTIAL gap-day data plus today's live usage. Busy: another
        // long-lived project JSONL spanning the gap that cannot be read.
        _ = try Self.writeSession(
            base: base,
            project: "proj",
            session: "gap-partial",
            date: yesterday,
            input: 111,
            modifiedAt: now,
            fileManager: fm)
        _ = try Self.writeSession(
            base: base,
            project: "proj",
            session: "today",
            date: now,
            input: 40,
            modifiedAt: now,
            fileManager: fm)
        let busy = try Self.writeSession(
            base: base,
            project: "proj",
            session: "busy",
            date: twoDaysAgo,
            input: 999,
            modifiedAt: now,
            fileManager: fm)
        try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: busy.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: busy.path) }

        let cache = LedgerCache(cacheDir: base.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.markScanComplete(provider: "claude", scanDate: twoDaysAgo, coveredMaxAgeDays: 30)
        await cache.markCatchUpHealed(provider: "claude")

        let source = ClaudeUsageLogSource(
            environment: [:],
            fileManager: fm,
            basePaths: [base],
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()

        // Today (the mutable day) still lands; NO gap day is sealed with the
        // partial recount, and the anchor keeps the catch-up window open.
        #expect(entries.map(\.inputTokens) == [40])
        var dailies = await cache.loadCachedDailies(provider: "claude")?.dailies ?? []
        #expect(dailies.first { $0.dayKey == LedgerCache.dayKey(for: now) }?.inputTokens == 40)
        #expect(!dailies.contains { $0.dayKey == LedgerCache.dayKey(for: yesterday) })
        #expect(!dailies.contains { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) })
        #expect(await cache.scanGapDays(provider: "claude", now: now) == 3)

        // Busy file readable again -> the retried catch-up completes the gap.
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: busy.path)
        let retry = ClaudeUsageLogSource(
            environment: [:],
            fileManager: fm,
            basePaths: [base],
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let retried = try await retry.loadEntries()
        #expect(retried.map(\.inputTokens).sorted() == [40, 111, 999])
        dailies = await cache.loadCachedDailies(provider: "claude")?.dailies ?? []
        #expect(dailies.first { $0.dayKey == LedgerCache.dayKey(for: yesterday) }?.inputTokens == 111)
        #expect(dailies.first { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) }?.inputTokens == 999)
        #expect(await cache.scanGapDays(provider: "claude", now: now) == 1)
    }

    @Test
    func `claude catch-up clears a today that dropped to zero while a gap day has usage`() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory
            .appendingPathComponent("runic-claude-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        // The projects dir must exist for the source to resolve it.
        try fm.createDirectory(
            at: base.appendingPathComponent("projects", isDirectory: true),
            withIntermediateDirectories: true)

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let cal = Calendar.current
        let todayKey = LedgerCache.dayKey(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now

        // Today already has an aggregate; last scan was 2 days ago (multi-day
        // catch-up fires); today's raw session is gone (usage dropped to zero).
        let cache = LedgerCache(cacheDir: base.appendingPathComponent("ledger-cache", isDirectory: true))
        await cache.mergeDailies(
            provider: "claude",
            newDailies: [
                CachedDaily(
                    dayKey: todayKey,
                    inputTokens: 5555,
                    outputTokens: 0,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 0,
                    costUSD: nil,
                    requestCount: 3,
                    modelsUsed: ["claude-sonnet-4"]),
            ],
            scanDate: twoDaysAgo,
            todayKey: nil,
            coveredMaxAgeDays: 30)
        await cache.markCatchUpHealed(provider: "claude") // isolate catch-up from the heal
        _ = try Self.writeSession(
            base: base,
            project: "proj",
            session: "y",
            date: yesterday,
            input: 321,
            modifiedAt: now,
            fileManager: fm)

        let source = ClaudeUsageLogSource(
            environment: [:],
            fileManager: fm,
            basePaths: [base],
            maxAgeDays: 30,
            now: now,
            cache: cache)

        _ = try await source.loadEntries()
        let dailies = await cache.loadCachedDailies(provider: "claude")?.dailies ?? []
        // Yesterday backfilled; today's stale aggregate cleared (not left behind).
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: yesterday) })
        #expect(!dailies.contains { $0.dayKey == todayKey })
    }
}
