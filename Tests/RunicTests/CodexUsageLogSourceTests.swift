import Foundation
import Testing
@testable import RunicCore

struct CodexUsageLogSourceTests {
    @Test
    func `codex usage falls back to workspace path from turn context`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_122_400) // 2026-01-01T00:00:00Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let dayDir = root
            .appendingPathComponent(String(format: "%04d", parts.year ?? 1970), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.day ?? 1), isDirectory: true)
        try fm.createDirectory(at: dayDir, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let turnTimestamp = formatter.string(from: now)
        let tokenTimestamp = formatter.string(from: now.addingTimeInterval(1))

        let turnContext = try Self.jsonLine([
            "type": "turn_context",
            "timestamp": turnTimestamp,
            "payload": [
                "model": "openai/gpt-5.2-codex",
                "workspace_path": "/Users/me/work/Runic-App",
            ],
        ])
        let tokenCount = try Self.jsonLine([
            "type": "event_msg",
            "timestamp": tokenTimestamp,
            "payload": [
                "type": "token_count",
                "info": [
                    "model": "openai/gpt-5.2-codex",
                    "total_token_usage": [
                        "input_tokens": 120,
                        "cached_input_tokens": 20,
                        "output_tokens": 10,
                    ],
                ],
            ],
        ])

        let fileURL = dayDir.appendingPathComponent("session.jsonl")
        try "\(turnContext)\n\(tokenCount)\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: nil,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()

        #expect(entries.count == 1)
        #expect(entries.first?.projectID == "/Users/me/work/Runic-App")
        #expect(entries.first?.projectName == nil)

        let summary = UsageLedgerAggregator.projectSummaries(entries: entries).first
        #expect(summary?.displayProjectName == "Runic-App")
    }

    @Test
    func `codex usage counts cumulative token reset as fresh epoch`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_122_400) // 2026-01-01T00:00:00Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let dayDir = root
            .appendingPathComponent(String(format: "%04d", parts.year ?? 1970), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.day ?? 1), isDirectory: true)
        try fm.createDirectory(at: dayDir, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let turnTimestamp = formatter.string(from: now)
        let firstTimestamp = formatter.string(from: now.addingTimeInterval(1))
        let resetTimestamp = formatter.string(from: now.addingTimeInterval(2))

        let turnContext = try Self.jsonLine([
            "type": "turn_context",
            "timestamp": turnTimestamp,
            "payload": [
                "model": "openai/gpt-5.2-codex",
            ],
        ])
        let firstTokenCount = try Self.jsonLine([
            "type": "event_msg",
            "timestamp": firstTimestamp,
            "payload": [
                "type": "token_count",
                "info": [
                    "model": "openai/gpt-5.2-codex",
                    "total_token_usage": [
                        "input_tokens": 300,
                        "cached_input_tokens": 50,
                        "output_tokens": 40,
                    ],
                ],
            ],
        ])
        let resetTokenCount = try Self.jsonLine([
            "type": "event_msg",
            "timestamp": resetTimestamp,
            "payload": [
                "type": "token_count",
                "info": [
                    "model": "openai/gpt-5.2-codex",
                    "total_token_usage": [
                        "input_tokens": 80,
                        "cached_input_tokens": 10,
                        "output_tokens": 12,
                    ],
                ],
            ],
        ])

        let fileURL = dayDir.appendingPathComponent("session.jsonl")
        try "\(turnContext)\n\(firstTokenCount)\n\(resetTokenCount)\n"
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: nil,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()

        #expect(entries.count == 2)
        #expect(entries.reduce(0) { $0 + $1.inputTokens } == 380)
        #expect(entries.reduce(0) { $0 + $1.cacheReadTokens } == 60)
        #expect(entries.reduce(0) { $0 + $1.outputTokens } == 52)

        let cachedAfterFirst = await cache.loadCachedDailies(provider: "codex")?.dailies.first
        #expect(cachedAfterFirst?.inputTokens == 380)
        #expect(cachedAfterFirst?.cacheReadTokens == 60)
        #expect(cachedAfterFirst?.outputTokens == 52)

        _ = try await source.loadEntries()
        let cachedAfterSecond = await cache.loadCachedDailies(provider: "codex")?.dailies.first
        #expect(cachedAfterSecond?.inputTokens == 380)
        #expect(cachedAfterSecond?.cacheReadTokens == 60)
        #expect(cachedAfterSecond?.outputTokens == 52)
    }

    @Test
    func `codex usage handles partial cumulative counter regression per field`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_122_400) // 2026-01-01T00:00:00Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let dayDir = root
            .appendingPathComponent(String(format: "%04d", parts.year ?? 1970), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.day ?? 1), isDirectory: true)
        try fm.createDirectory(at: dayDir, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let turnTimestamp = formatter.string(from: now)
        let firstTimestamp = formatter.string(from: now.addingTimeInterval(1))
        let partialTimestamp = formatter.string(from: now.addingTimeInterval(2))

        let turnContext = try Self.jsonLine([
            "type": "turn_context",
            "timestamp": turnTimestamp,
            "payload": [
                "model": "openai/gpt-5.2-codex",
            ],
        ])
        let firstTokenCount = try Self.jsonLine([
            "type": "event_msg",
            "timestamp": firstTimestamp,
            "payload": [
                "type": "token_count",
                "info": [
                    "model": "openai/gpt-5.2-codex",
                    "total_token_usage": [
                        "input_tokens": 300,
                        "cached_input_tokens": 50,
                        "output_tokens": 40,
                    ],
                ],
            ],
        ])
        let partialRegressionTokenCount = try Self.jsonLine([
            "type": "event_msg",
            "timestamp": partialTimestamp,
            "payload": [
                "type": "token_count",
                "info": [
                    "model": "openai/gpt-5.2-codex",
                    "total_token_usage": [
                        "input_tokens": 330,
                        "cached_input_tokens": 10,
                        "output_tokens": 45,
                    ],
                ],
            ],
        ])

        let fileURL = dayDir.appendingPathComponent("session.jsonl")
        try "\(turnContext)\n\(firstTokenCount)\n\(partialRegressionTokenCount)\n"
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: nil,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()

        #expect(entries.count == 2)
        #expect(entries.reduce(0) { $0 + $1.inputTokens } == 330)
        #expect(entries.reduce(0) { $0 + $1.cacheReadTokens } == 60)
        #expect(entries.reduce(0) { $0 + $1.outputTokens } == 45)
    }

    @Test
    func `codex usage skips unchanged files after cache scan date`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_122_400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let dayDir = root
            .appendingPathComponent(String(format: "%04d", parts.year ?? 1970), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.day ?? 1), isDirectory: true)
        try fm.createDirectory(at: dayDir, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let tokenTimestamp = formatter.string(from: now.addingTimeInterval(-20))
        let tokenCount = try Self.jsonLine([
            "type": "event_msg",
            "timestamp": tokenTimestamp,
            "payload": [
                "type": "token_count",
                "info": [
                    "total_token_usage": [
                        "input_tokens": 120,
                        "cached_input_tokens": 20,
                        "output_tokens": 10,
                    ],
                ],
            ],
        ])

        let fileURL = dayDir.appendingPathComponent("session.jsonl")
        try "\(tokenCount)\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: now.addingTimeInterval(-10)], ofItemAtPath: fileURL.path)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: nil,
            now: now,
            cache: cache)

        let firstEntries = try await source.loadEntries()
        let secondEntries = try await source.loadEntries()
        let cached = await cache.loadCachedDailies(provider: "codex")?.dailies.first

        #expect(firstEntries.count == 1)
        #expect(secondEntries.isEmpty)
        #expect(cached?.inputTokens == 120)
        #expect(cached?.cacheReadTokens == 20)
        #expect(cached?.outputTokens == 10)
    }

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
    func `codex relay backfills when requested history exceeds cache coverage`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        try Self.writeSession(root: root, date: yesterday, input: 900, modifiedAt: now.addingTimeInterval(-7200), fileManager: fm)
        try Self.writeSession(root: root, date: now, input: 40, modifiedAt: now.addingTimeInterval(-7200), fileManager: fm)

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
        #expect(entries.map(\.inputTokens).sorted() == [40, 900])
        #expect(await cache.loadCachedDailies(provider: "codex")?.coveredMaxAgeDays == 30)
    }

    private static func jsonLine(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CodexUsageLogSourceTests", code: 1)
        }
        return text
    }

    private static func writeSession(
        root: URL,
        date: Date,
        input: Int,
        modifiedAt: Date,
        fileManager: FileManager) throws
    {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let dayDir = root
            .appendingPathComponent(String(format: "%04d", parts.year ?? 1970), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.day ?? 1), isDirectory: true)
        try fileManager.createDirectory(at: dayDir, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let tokenCount = try Self.jsonLine([
            "type": "event_msg",
            "timestamp": formatter.string(from: date),
            "payload": [
                "type": "token_count",
                "info": [
                    "model": "openai/gpt-5.2-codex",
                    "total_token_usage": [
                        "input_tokens": input,
                        "cached_input_tokens": 0,
                        "output_tokens": 1,
                    ],
                ],
            ],
        ])
        let fileURL = dayDir.appendingPathComponent(UUID().uuidString + ".jsonl")
        try "\(tokenCount)\n".write(to: fileURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: fileURL.path)
    }
}
