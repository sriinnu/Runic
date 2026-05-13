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

    private static func jsonLine(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CodexUsageLogSourceTests", code: 1)
        }
        return text
    }
}
