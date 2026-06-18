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
