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

        // Cached tokens are a subset of input; entries store the disjoint
        // remainder: (300-50) + (80-10) = 320 input alongside 60 cache reads.
        #expect(entries.count == 2)
        #expect(entries.reduce(0) { $0 + $1.inputTokens } == 320)
        #expect(entries.reduce(0) { $0 + $1.cacheReadTokens } == 60)
        #expect(entries.reduce(0) { $0 + $1.outputTokens } == 52)

        let cachedAfterFirst = await cache.loadCachedDailies(provider: "codex")?.dailies.first
        #expect(cachedAfterFirst?.inputTokens == 320)
        #expect(cachedAfterFirst?.cacheReadTokens == 60)
        #expect(cachedAfterFirst?.outputTokens == 52)

        _ = try await source.loadEntries()
        let cachedAfterSecond = await cache.loadCachedDailies(provider: "codex")?.dailies.first
        #expect(cachedAfterSecond?.inputTokens == 320)
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

        // Disjoint input remainder: (300-50) + (30-10) = 270 alongside 60 cached.
        #expect(entries.count == 2)
        #expect(entries.reduce(0) { $0 + $1.inputTokens } == 270)
        #expect(entries.reduce(0) { $0 + $1.cacheReadTokens } == 60)
        #expect(entries.reduce(0) { $0 + $1.outputTokens } == 45)
    }

    @Test
    func `codex usage recomputes todays mutable files even after cache scan date`() async throws {
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
        #expect(secondEntries.count == 1)
        #expect(cached?.inputTokens == 100) // 120 input minus the 20-cached subset
        #expect(cached?.cacheReadTokens == 20)
        #expect(cached?.outputTokens == 10)
    }

    @Test
    func `codex empty today scan clears stale mutable day`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_252_000)
        try Self.writeSession(root: root, date: now, input: 40, modifiedAt: now, fileManager: fm)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 30,
            now: now,
            cache: cache)

        _ = try await source.loadEntries()

        let parts = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let dayDir = root
            .appendingPathComponent(String(format: "%04d", parts.year ?? 1970), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.day ?? 1), isDirectory: true)
        try fm.removeItem(at: dayDir)

        let emptyEntries = try await source.loadEntries()
        let cached = await cache.loadCachedDailies(provider: "codex")
        #expect(emptyEntries.isEmpty)
        #expect(cached?.dailies.isEmpty == true)
    }

    // Regression: codex resumes one long-lived rollout and appends to it for days,
    // but the file stays filed under its START date's folder. The old date-folder
    // walk stopped opening that folder once it aged past the scan window, so every
    // byte of current usage went unread and the timeline collapsed to zero. The
    // file must be selected by mtime (it was just written), wherever it is filed.
    @Test
    func `codex scans a resumed rollout filed under an old date folder`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_900_000) // 2026-01-10T00:00:00Z
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        // File the rollout under a START date six days ago — well outside the
        // 3-day rebuild window the old folder-walk would have opened.
        let startDate = now.addingTimeInterval(-6 * 86400) // 2026-01-04
        let parts = calendar.dateComponents([.year, .month, .day], from: startDate)
        let oldDayDir = root
            .appendingPathComponent(String(format: "%04d", parts.year ?? 1970), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.month ?? 1), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", parts.day ?? 1), isDirectory: true)
        try fm.createDirectory(at: oldDayDir, withIntermediateDirectories: true)

        // But its content is recent: cumulative token_count lines dated yesterday
        // and today (both inside the window). Deltas → two entries.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        func tokenLine(at date: Date, totalInput: Int, totalOutput: Int) throws -> String {
            try Self.jsonLine([
                "type": "event_msg",
                "timestamp": formatter.string(from: date),
                "payload": [
                    "type": "token_count",
                    "info": [
                        "model": "openai/gpt-5.2-codex",
                        "total_token_usage": [
                            "input_tokens": totalInput,
                            "cached_input_tokens": 0,
                            "output_tokens": totalOutput,
                        ],
                    ],
                ],
            ])
        }
        let yesterday = now.addingTimeInterval(-1 * 86400 + 3600) // 2026-01-09
        let today = now.addingTimeInterval(3600) // 2026-01-10
        let body = try tokenLine(at: yesterday, totalInput: 100, totalOutput: 10) + "\n"
            + tokenLine(at: today, totalInput: 250, totalOutput: 25) + "\n"
        let fileURL = oldDayDir.appendingPathComponent("rollout-resumed.jsonl")
        try body.write(to: fileURL, atomically: true, encoding: .utf8)
        // Mtime is now — the file was just appended to, even though it lives in an
        // old folder. This is the signal mtime-based selection keys on.
        try fm.setAttributes([.modificationDate: now], ofItemAtPath: fileURL.path)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 3,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()

        // Both recent deltas captured despite the file living in a stale folder.
        #expect(entries.count == 2)
        #expect(entries.map(\.inputTokens).reduce(0, +) == 250) // 100 + (250-100)
        #expect(entries.map(\.outputTokens).reduce(0, +) == 25) // 10 + (25-10)
    }

    // Regression: a modern rollout interleaves multiple cumulative
    // total_token_usage streams (parallel sub-agents), so the running total jumps
    // backwards and cumulative deltas explode. Usage must come from the
    // self-contained per-request last_token_usage, and a windowed scan must not
    // over-count by treating a mid-session cumulative as a first delta.
    @Test
    func `codex uses per-request last token usage, not cumulative totals`() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-usage-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let now = Date(timeIntervalSince1970: 1_767_900_000) // 2026-01-10T00:00:00Z
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
        func line(at date: Date, lastIn: Int, lastOut: Int, totalIn: Int) throws -> String {
            try Self.jsonLine([
                "type": "event_msg",
                "timestamp": formatter.string(from: date),
                "payload": [
                    "type": "token_count",
                    "info": [
                        "model": "gpt-5.5",
                        "total_token_usage": ["input_tokens": totalIn, "output_tokens": 9999],
                        "last_token_usage": ["input_tokens": lastIn, "output_tokens": lastOut],
                    ],
                ],
            ])
        }
        // Cumulative totals jump around (10000 -> 5000) and dwarf the real
        // per-request deltas. With maxAgeDays 3 the 2026-01-06 line is out of window.
        let body = try [
            line(at: now.addingTimeInterval(-4 * 86400), lastIn: 7777, lastOut: 1, totalIn: 3000), // 01-06, skipped
            line(at: now.addingTimeInterval(-1 * 86400 + 3600), lastIn: 100, lastOut: 10, totalIn: 10000), // 01-09
            line(at: now.addingTimeInterval(3600), lastIn: 200, lastOut: 20, totalIn: 5000), // 01-10
        ].joined(separator: "\n") + "\n"
        let fileURL = dayDir.appendingPathComponent("rollout-interleaved.jsonl")
        try body.write(to: fileURL, atomically: true, encoding: .utf8)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: 3,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()

        // Only the two in-window lines, summed from last_token_usage — not the
        // cumulative totals and not the out-of-window line.
        #expect(entries.count == 2)
        #expect(entries.map(\.inputTokens).reduce(0, +) == 300) // 100 + 200
        #expect(entries.map(\.outputTokens).reduce(0, +) == 30) // 10 + 20
    }

    /// Regression (H1): OpenAI reports cached_input_tokens as a SUBSET of
    /// input_tokens. The ledger sums input/output/cache as DISJOINT classes, so a
    /// request with 100K input of which 90K was cached must total 101K — storing
    /// the full input alongside the cache reads double-counted the cached 90K.
    @Test
    func `codex stores cached tokens disjoint from input`() async throws {
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
        let tokenCount = try Self.jsonLine([
            "type": "event_msg",
            "timestamp": formatter.string(from: now),
            "payload": [
                "type": "token_count",
                "info": [
                    "model": "gpt-5.5",
                    "last_token_usage": [
                        "input_tokens": 100_000,
                        "cached_input_tokens": 90000,
                        "output_tokens": 1000,
                    ],
                ],
            ],
        ])
        let fileURL = dayDir.appendingPathComponent("session.jsonl")
        try "\(tokenCount)\n".write(to: fileURL, atomically: true, encoding: .utf8)

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
        #expect(entries.first?.inputTokens == 10000) // non-cached remainder only
        #expect(entries.first?.cacheReadTokens == 90000)
        #expect(entries.first?.outputTokens == 1000)
        #expect(entries.first?.totalTokens == 101_000)
    }

    /// Regression (M2): a legacy cumulative-only rollout spanning several days,
    /// scanned with a window covering only the last day. Pre-window lines must
    /// advance the delta cursor SILENTLY so the first in-window line books only
    /// its true delta — not the file's entire history as one giant entry.
    @Test
    func `codex legacy cumulative scan books only the in-window delta`() async throws {
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
        func cumulativeLine(at date: Date, totalInput: Int, totalOutput: Int) throws -> String {
            try Self.jsonLine([
                "type": "event_msg",
                "timestamp": formatter.string(from: date),
                "payload": [
                    "type": "token_count",
                    "info": [
                        "model": "openai/gpt-5.2-codex",
                        "total_token_usage": [
                            "input_tokens": totalInput,
                            "cached_input_tokens": 0,
                            "output_tokens": totalOutput,
                        ],
                    ],
                ],
            ])
        }
        // Three days of cumulative totals; maxAgeDays nil → refreshToday window
        // covers only the final line.
        let body = try [
            cumulativeLine(at: now.addingTimeInterval(-2 * 86400), totalInput: 1000, totalOutput: 100),
            cumulativeLine(at: now.addingTimeInterval(-1 * 86400), totalInput: 2000, totalOutput: 200),
            cumulativeLine(at: now, totalInput: 2600, totalOutput: 260),
        ].joined(separator: "\n") + "\n"
        let fileURL = dayDir.appendingPathComponent("legacy-rollout.jsonl")
        try body.write(to: fileURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: now], ofItemAtPath: fileURL.path)

        let cache = LedgerCache(cacheDir: root.appendingPathComponent("ledger-cache", isDirectory: true))
        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: nil,
            now: now,
            cache: cache)
        let entries = try await source.loadEntries()

        // Only the last day's true delta — not the whole file's 2600/260 history.
        #expect(entries.count == 1)
        #expect(entries.first?.inputTokens == 600) // 2600 - 2000
        #expect(entries.first?.outputTokens == 60) // 260 - 200
    }

    static func jsonLine(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CodexUsageLogSourceTests", code: 1)
        }
        return text
    }

    static func writeSession(
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
