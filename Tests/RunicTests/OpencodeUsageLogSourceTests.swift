import Foundation
import Testing
@testable import RunicCore

struct OpencodeUsageLogSourceTests {
    /// Write one opencode message JSON at `<root>/<session>/<id>.json` using the
    /// real on-disk shape (assistant message with a tokens block + cost).
    @discardableResult
    static func writeMessage(
        root: URL,
        session: String,
        id: String,
        created: Int64,
        role: String = "assistant",
        model: String = "glm-4.7",
        cwd: String = "/Users/me/proj",
        cost: Double = 0,
        input: Int = 100,
        output: Int = 10,
        reasoning: Int = 0,
        cacheRead: Int = 0,
        cacheWrite: Int = 0,
        modifiedAt: Date,
        fileManager fm: FileManager) throws -> URL
    {
        let dir = root.appendingPathComponent(session, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(id).json")
        let tokens = role == "assistant"
            ? ",\"tokens\":{\"input\":\(input),\"output\":\(output),\"reasoning\":\(reasoning)," +
            "\"cache\":{\"read\":\(cacheRead),\"write\":\(cacheWrite)}}"
            : ""
        let json = "{\"id\":\"\(id)\",\"sessionID\":\"\(session)\",\"role\":\"\(role)\"," +
            "\"time\":{\"created\":\(created)},\"modelID\":\"\(model)\",\"providerID\":\"zai-coding-plan\"," +
            "\"path\":{\"cwd\":\"\(cwd)\"},\"cost\":\(cost)\(tokens)}"
        try json.write(to: file, atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: file.path)
        return file
    }

    private static func ms(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

    @Test
    func `opencode parses assistant messages, sums tokens, keeps cost and model`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-opencode-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        // Two assistant messages today + one user message (must be ignored).
        try Self.writeMessage(root: root, session: "ses1", id: "m1", created: Self.ms(now),
                              cost: 0.012, input: 100, output: 10, reasoning: 5, cacheRead: 200, cacheWrite: 1,
                              modifiedAt: now, fileManager: fm)
        try Self.writeMessage(root: root, session: "ses1", id: "m2", created: Self.ms(now.addingTimeInterval(60)),
                              cost: 0.003, input: 50, output: 4, modifiedAt: now, fileManager: fm)
        try Self.writeMessage(root: root, session: "ses1", id: "u1", created: Self.ms(now), role: "user",
                              modifiedAt: now, fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        let source = OpencodeUsageLogSource(
            environment: [:], fileManager: fm, storageRoot: root,
            maxAgeDays: 30, now: now, cache: cache)

        let entries = try await source.loadEntries()
        #expect(entries.count == 2) // user message skipped
        let totalInput = entries.reduce(0) { $0 + $1.inputTokens }
        let totalOutput = entries.reduce(0) { $0 + $1.outputTokens } // includes reasoning
        let totalCost = entries.compactMap(\.costUSD).reduce(0, +)
        #expect(totalInput == 150)
        #expect(totalOutput == 19)       // (10+5) + 4
        #expect(entries.contains { $0.cacheReadTokens == 200 && $0.cacheCreationTokens == 1 })
        #expect(abs(totalCost - 0.015) < 1e-9)
        #expect(entries.allSatisfy { $0.model == "glm-4.7" })
        #expect(entries.allSatisfy { $0.projectName == "proj" })
        #expect(entries.allSatisfy { $0.source == .opencodeLog })
    }

    @Test
    func `opencode backfills history once when cache is empty`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-opencode-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        try Self.writeMessage(root: root, session: "ses1", id: "y1", created: Self.ms(yesterday),
                              input: 900, output: 1, modifiedAt: now, fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        let source = OpencodeUsageLogSource(
            environment: [:], fileManager: fm, storageRoot: root,
            maxAgeDays: 30, now: now, cache: cache)

        // Empty cache + default scan mode → one-time history rebuild surfaces yesterday.
        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens) == [900])
        #expect(await cache.loadCachedDailies(provider: "opencode")?.coveredMaxAgeDays == 30)
    }

    @Test
    func `opencode catches up missed days after a gap`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-opencode-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let cal = Calendar.current
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now
        try Self.writeMessage(root: root, session: "ses1", id: "g1", created: Self.ms(twoDaysAgo),
                              input: 222, output: 1, modifiedAt: now, fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        // Established + already-healed install whose last scan was 2 days ago.
        await cache.markScanComplete(provider: "opencode", scanDate: twoDaysAgo, coveredMaxAgeDays: 30)
        await cache.markCatchUpHealed(provider: "opencode")

        let source = OpencodeUsageLogSource(
            environment: [:], fileManager: fm, storageRoot: root,
            maxAgeDays: 30, now: now, cache: cache)

        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens) == [222]) // missed gap day backfilled
        let dailies = await cache.loadCachedDailies(provider: "opencode")?.dailies ?? []
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) })
    }
}
