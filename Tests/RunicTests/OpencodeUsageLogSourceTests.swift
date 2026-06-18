import Foundation
import Testing
@testable import RunicCore

struct OpencodeUsageLogSourceTests {
    /// Write one opencode message JSON at `<root>/<session>/<id>.json` using the
    /// real on-disk shape (assistant message with a tokens block + cost).
    @discardableResult
    // swiftlint:disable:next function_parameter_count
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

    private static func ms(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1000)
    }

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
        try Self.writeMessage(
            root: root,
            session: "ses1",
            id: "m1",
            created: Self.ms(now),
            cost: 0.012,
            input: 100,
            output: 10,
            reasoning: 5,
            cacheRead: 200,
            cacheWrite: 1,
            modifiedAt: now,
            fileManager: fm)
        try Self.writeMessage(
            root: root,
            session: "ses1",
            id: "m2",
            created: Self.ms(now.addingTimeInterval(60)),
            cost: 0.003,
            input: 50,
            output: 4,
            modifiedAt: now,
            fileManager: fm)
        try Self.writeMessage(
            root: root,
            session: "ses1",
            id: "u1",
            created: Self.ms(now),
            role: "user",
            modifiedAt: now,
            fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        let source = OpencodeUsageLogSource(
            environment: [:],
            fileManager: fm,
            storageRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()
        #expect(entries.count == 2) // user message skipped
        let totalInput = entries.reduce(0) { $0 + $1.inputTokens }
        let totalOutput = entries.reduce(0) { $0 + $1.outputTokens } // includes reasoning
        let totalCost = entries.compactMap(\.costUSD).reduce(0, +)
        #expect(totalInput == 150)
        #expect(totalOutput == 19) // (10+5) + 4
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
        try Self.writeMessage(
            root: root,
            session: "ses1",
            id: "y1",
            created: Self.ms(yesterday),
            input: 900,
            output: 1,
            modifiedAt: now,
            fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        let source = OpencodeUsageLogSource(
            environment: [:],
            fileManager: fm,
            storageRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        // Empty cache + default scan mode → one-time history rebuild surfaces yesterday.
        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens) == [900])
        #expect(await cache.loadCachedDailies(provider: "opencode")?.coveredMaxAgeDays == 30)
    }

    @Test
    func `opencode folds reasoning into output and skips user and zero-token messages`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-opencode-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        // Reasoning-only output; a user message WITH a tokens block (must skip via
        // role guard); a zero-token assistant (aborted turn, must skip via > 0 guard).
        try Self.writeMessage(
            root: root,
            session: "s",
            id: "r",
            created: Self.ms(now),
            output: 0,
            reasoning: 7,
            modifiedAt: now,
            fileManager: fm)
        try Self.writeMessage(
            root: root,
            session: "s",
            id: "u",
            created: Self.ms(now),
            role: "user",
            input: 999,
            output: 999,
            modifiedAt: now,
            fileManager: fm)
        try Self.writeMessage(
            root: root,
            session: "s",
            id: "z",
            created: Self.ms(now),
            input: 0,
            output: 0,
            reasoning: 0,
            cacheRead: 0,
            cacheWrite: 0,
            modifiedAt: now,
            fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        let source = OpencodeUsageLogSource(
            environment: [:],
            fileManager: fm,
            storageRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()
        #expect(entries.count == 1) // user + zero-token skipped
        #expect(entries.first?.outputTokens == 7) // reasoning folded into output
    }

    @Test
    func `opencode busy file is skipped, not fatal`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-opencode-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        try Self.writeMessage(
            root: root,
            session: "s",
            id: "ok",
            created: Self.ms(now),
            input: 700,
            modifiedAt: now,
            fileManager: fm)
        let busy = try Self.writeMessage(
            root: root,
            session: "s",
            id: "busy",
            created: Self.ms(now),
            input: 999,
            modifiedAt: now,
            fileManager: fm)
        try fm.setAttributes([.posixPermissions: 0], ofItemAtPath: busy.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: busy.path) }

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        await cache.markScanComplete(provider: "opencode", scanDate: now, coveredMaxAgeDays: 30)
        await cache.markCatchUpHealed(provider: "opencode")

        let source = OpencodeUsageLogSource(
            environment: [:],
            fileManager: fm,
            storageRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens) == [700]) // readable lands, busy skipped, no throw
    }

    @Test
    func `opencode catch-up clears a today that dropped to zero while a gap day has usage`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-opencode-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(
            at: root.appendingPathComponent("placeholder", isDirectory: true),
            withIntermediateDirectories: true)

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let cal = Calendar.current
        let todayKey = LedgerCache.dayKey(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now) ?? now

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        await cache.mergeDailies(
            provider: "opencode",
            newDailies: [CachedDaily(
                dayKey: todayKey,
                inputTokens: 4321,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: nil,
                requestCount: 9,
                modelsUsed: ["glm-4.7"])],
            scanDate: twoDaysAgo,
            todayKey: nil,
            coveredMaxAgeDays: 30)
        await cache.markCatchUpHealed(provider: "opencode")
        try Self.writeMessage(
            root: root,
            session: "s",
            id: "y",
            created: Self.ms(yesterday),
            input: 222,
            modifiedAt: now,
            fileManager: fm)

        let source = OpencodeUsageLogSource(
            environment: [:],
            fileManager: fm,
            storageRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        _ = try await source.loadEntries()
        let dailies = await cache.loadCachedDailies(provider: "opencode")?.dailies ?? []
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: yesterday) })
        #expect(!dailies.contains { $0.dayKey == todayKey }) // stale today cleared
    }

    @Test
    func `opencode self-heals the legacy gap once even when lastScanDate is today`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-opencode-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
        try Self.writeMessage(
            root: root,
            session: "s",
            id: "g",
            created: Self.ms(twoDaysAgo),
            input: 333,
            modifiedAt: now,
            fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        // Established install scanned today already (gap=1) but never healed.
        await cache.markScanComplete(provider: "opencode", scanDate: now, coveredMaxAgeDays: 30)
        #expect(await cache.needsCatchUpHeal(provider: "opencode") == true)

        let source = OpencodeUsageLogSource(
            environment: [:],
            fileManager: fm,
            storageRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens) == [333]) // one-time heal backfills despite gap==1
        #expect(await cache.needsCatchUpHeal(provider: "opencode") == false)
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
        try Self.writeMessage(
            root: root,
            session: "ses1",
            id: "g1",
            created: Self.ms(twoDaysAgo),
            input: 222,
            output: 1,
            modifiedAt: now,
            fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("cache", isDirectory: true))
        // Established + already-healed install whose last scan was 2 days ago.
        await cache.markScanComplete(provider: "opencode", scanDate: twoDaysAgo, coveredMaxAgeDays: 30)
        await cache.markCatchUpHealed(provider: "opencode")

        let source = OpencodeUsageLogSource(
            environment: [:],
            fileManager: fm,
            storageRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        let entries = try await source.loadEntries()
        #expect(entries.map(\.inputTokens) == [222]) // missed gap day backfilled
        let dailies = await cache.loadCachedDailies(provider: "opencode")?.dailies ?? []
        #expect(dailies.contains { $0.dayKey == LedgerCache.dayKey(for: twoDaysAgo) })
    }
}
