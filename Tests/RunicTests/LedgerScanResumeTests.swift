import Foundation
import Testing
@testable import RunicCore

/// Byte-offset resume for the ledger log scanners (Codex + Claude).
struct LedgerScanResumeTests {
    // MARK: - Helpers

    private static func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("runic-scan-resume-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func codexTokenLine(
        at date: Date,
        input: Int,
        cached: Int,
        output: Int,
        requestID: String,
        cumulative: Bool = false) -> String
    {
        let usage = "{\"input_tokens\":\(input),\"cached_input_tokens\":\(cached),\"output_tokens\":\(output)}"
        let info = cumulative
            ? "{\"model\":\"gpt-5\",\"total_token_usage\":\(usage)}"
            : "{\"model\":\"gpt-5\",\"request_id\":\"\(requestID)\",\"last_token_usage\":\(usage)}"
        return "{\"type\":\"event_msg\",\"timestamp\":\"\(Self.isoString(from: date))\"," +
            "\"payload\":{\"type\":\"token_count\",\"info\":\(info)}}"
    }

    private static func claudeLine(
        at date: Date,
        input: Int,
        output: Int,
        messageID: String) -> String
    {
        "{\"timestamp\":\"\(self.isoString(from: date))\",\"sessionId\":\"s1\"," +
            "\"requestId\":\"req-\(messageID)\"," +
            "\"message\":{\"id\":\"\(messageID)\",\"model\":\"claude-sonnet-4-5\"," +
            "\"usage\":{\"input_tokens\":\(input),\"output_tokens\":\(output)}}}"
    }

    private static func parseCodex(
        url: URL,
        minDate: Date?,
        store: LedgerScanResumeStore) throws -> [UsageLedgerEntry]
    {
        let parser = CodexUsageLogParser(resumeStore: store)
        var seen = Set<String>()
        let file = CodexUsageSessionFile(url: url, sessionID: "session", modifiedAt: Date())
        return try parser.parseFile(file, minDate: minDate, dayKey: nil, seenKeys: &seen).entries
    }

    private static func parseClaude(
        url: URL,
        minDate: Date?,
        store: LedgerScanResumeStore,
        cacheDir: URL) throws -> [UsageLedgerEntry]
    {
        let source = ClaudeUsageLogSource(
            environment: [:],
            basePaths: [],
            now: Date(),
            cache: LedgerCache(cacheDir: cacheDir),
            resumeStore: store)
        let file = ClaudeUsageLogSource.UsageFile(
            url: url,
            projectID: "proj",
            projectName: "proj",
            sessionID: "s1",
            modifiedAt: Date())
        return try source.parseFile(file, minDate: minDate, dayKey: nil).entries
    }

    private static func totals(_ entries: [UsageLedgerEntry]) -> (input: Int, output: Int, cacheRead: Int) {
        (
            entries.reduce(0) { $0 + $1.inputTokens },
            entries.reduce(0) { $0 + $1.outputTokens },
            entries.reduce(0) { $0 + $1.cacheReadTokens })
    }

    // MARK: - Codex

    @Test
    func `codex append-only growth resumes without re-reading the prefix and totals match a fresh scan`() throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("rollout.jsonl")
        let base = Date(timeIntervalSince1970: 1_767_122_400)

        // Padding pushes the mutated line beyond the 1KB fingerprint prefix.
        var lines = (0..<20).map { index in
            Self.codexTokenLine(
                at: base.addingTimeInterval(Double(index)),
                input: 100,
                cached: 0,
                output: 10,
                requestID: "r\(index)")
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let store = LedgerScanResumeStore()
        let first = try Self.parseCodex(url: url, minDate: nil, store: store)
        #expect(first.count == 20)

        // Mutate a line BEYOND the fingerprint prefix in-place (same byte
        // length). A resumed scan must not observe this — proof the prefix was
        // not re-read.
        let mutated = Self.codexTokenLine(
            at: base.addingTimeInterval(15),
            input: 900,
            cached: 0,
            output: 90,
            requestID: "r15")
        #expect(mutated.utf8.count == lines[15].utf8.count)
        lines[15] = mutated

        // Append new lines (normal live-session growth).
        let appended = (20..<25).map { index in
            Self.codexTokenLine(
                at: base.addingTimeInterval(Double(index)),
                input: 50,
                cached: 0,
                output: 5,
                requestID: "r\(index)")
        }
        lines += appended
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let resumed = try Self.parseCodex(url: url, minDate: nil, store: store)
        #expect(resumed.count == 25)
        let resumedTotals = Self.totals(resumed)
        // Prefix values are the ORIGINAL ones (input 100), not the mutated 900:
        // 20×100 + 5×50 input, 20×10 + 5×5 output.
        #expect(resumedTotals.input == 2250)
        #expect(resumedTotals.output == 225)

        // Identity check: a from-scratch scan of the same UNMUTATED history
        // would produce the same totals as append-growth resume.
        let freshStore = LedgerScanResumeStore()
        let fresh = try Self.parseCodex(url: url, minDate: nil, store: freshStore)
        #expect(fresh.count == 25)
        #expect(Self.totals(fresh).input == 2250 + 800) // fresh scan sees the mutation
    }

    @Test
    func `codex legacy cumulative counters resume mid-file with carried cursor`() throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("rollout.jsonl")
        let base = Date(timeIntervalSince1970: 1_767_122_400)

        let first = Self.codexTokenLine(at: base, input: 100, cached: 0, output: 10, requestID: "-", cumulative: true)
        try (first + "\n").write(to: url, atomically: true, encoding: .utf8)

        let store = LedgerScanResumeStore()
        let firstScan = try Self.parseCodex(url: url, minDate: nil, store: store)
        #expect(Self.totals(firstScan).input == 100)

        // Cumulative total grows to 150; a resumed scan must book the DELTA
        // (50), not the whole 150 — that requires the carried previousTotals.
        let second = Self.codexTokenLine(
            at: base.addingTimeInterval(5), input: 150, cached: 0, output: 25, requestID: "-", cumulative: true)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((second + "\n").utf8))
        try handle.close()

        let resumed = try Self.parseCodex(url: url, minDate: nil, store: store)
        let resumedTotals = Self.totals(resumed)
        #expect(resumedTotals.input == 150)
        #expect(resumedTotals.output == 25)

        let fresh = try Self.parseCodex(url: url, minDate: nil, store: LedgerScanResumeStore())
        #expect(Self.totals(fresh).input == resumedTotals.input)
        #expect(Self.totals(fresh).output == resumedTotals.output)
    }

    @Test
    func `codex truncated or rotated file triggers a full re-read`() throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("rollout.jsonl")
        let base = Date(timeIntervalSince1970: 1_767_122_400)

        let original = (0..<10).map { index in
            Self.codexTokenLine(
                at: base.addingTimeInterval(Double(index)),
                input: 100,
                cached: 0,
                output: 10,
                requestID: "r\(index)")
        }
        try (original.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let store = LedgerScanResumeStore()
        _ = try Self.parseCodex(url: url, minDate: nil, store: store)

        // Truncation: rewrite with fewer, different lines (smaller file).
        let truncated = (0..<3).map { index in
            Self.codexTokenLine(
                at: base.addingTimeInterval(Double(index)),
                input: 7,
                cached: 0,
                output: 3,
                requestID: "t\(index)")
        }
        try (truncated.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let afterTruncate = try Self.parseCodex(url: url, minDate: nil, store: store)
        #expect(afterTruncate.count == 3)
        #expect(Self.totals(afterTruncate).input == 21)

        // Rotation: replace with a LARGER file whose prefix differs.
        let rotated = (0..<30).map { index in
            Self.codexTokenLine(
                at: base.addingTimeInterval(Double(index)),
                input: 11,
                cached: 0,
                output: 1,
                requestID: "n\(index)")
        }
        try (rotated.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let afterRotate = try Self.parseCodex(url: url, minDate: nil, store: store)
        #expect(afterRotate.count == 30)
        #expect(Self.totals(afterRotate).input == 330)
    }

    @Test
    func `codex scan window reaching further back than the cached window re-reads fully`() throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("rollout.jsonl")
        let base = Date(timeIntervalSince1970: 1_767_122_400)

        let lines = (0..<10).map { index in
            Self.codexTokenLine(
                at: base.addingTimeInterval(Double(index) * 3600),
                input: 10,
                cached: 0,
                output: 1,
                requestID: "r\(index)")
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let store = LedgerScanResumeStore()
        // Narrow window first: only entries at/after base+5h.
        let narrow = try Self.parseCodex(url: url, minDate: base.addingTimeInterval(5 * 3600), store: store)
        #expect(narrow.count == 5)

        // Wider window afterwards must NOT be served from the narrow cache.
        let wide = try Self.parseCodex(url: url, minDate: base, store: store)
        #expect(wide.count == 10)
        #expect(Self.totals(wide).input == 100)
    }

    // MARK: - Claude

    @Test
    func `claude append-only growth resumes and totals match a fresh scan`() throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("session.jsonl")
        let cacheDir = root.appendingPathComponent("cache", isDirectory: true)
        let base = Date(timeIntervalSince1970: 1_767_122_400)

        var lines = (0..<20).map { index in
            Self.claudeLine(at: base.addingTimeInterval(Double(index)), input: 100, output: 10, messageID: "m\(index)")
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let store = LedgerScanResumeStore()
        let first = try Self.parseClaude(url: url, minDate: nil, store: store, cacheDir: cacheDir)
        #expect(first.count == 20)

        // Mutate a line beyond the 1KB fingerprint in-place (same length) to
        // prove the resumed scan does not re-read the prefix.
        let mutated = Self.claudeLine(at: base.addingTimeInterval(15), input: 900, output: 90, messageID: "x15")
        #expect(mutated.utf8.count == lines[15].utf8.count)
        lines[15] = mutated
        lines += (20..<25).map { index in
            Self.claudeLine(at: base.addingTimeInterval(Double(index)), input: 50, output: 5, messageID: "m\(index)")
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let resumed = try Self.parseClaude(url: url, minDate: nil, store: store, cacheDir: cacheDir)
        #expect(resumed.count == 25)
        let resumedTotals = Self.totals(resumed)
        #expect(resumedTotals.input == 20 * 100 + 5 * 50)
        #expect(resumedTotals.output == 20 * 10 + 5 * 5)

        let fresh = try Self.parseClaude(url: url, minDate: nil, store: LedgerScanResumeStore(), cacheDir: cacheDir)
        #expect(fresh.count == 25)
        #expect(Self.totals(fresh).input == resumedTotals.input + 800) // fresh scan sees the mutation
    }

    @Test
    func `claude truncated file triggers a full re-read`() throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("session.jsonl")
        let cacheDir = root.appendingPathComponent("cache", isDirectory: true)
        let base = Date(timeIntervalSince1970: 1_767_122_400)

        let lines = (0..<10).map { index in
            Self.claudeLine(at: base.addingTimeInterval(Double(index)), input: 100, output: 10, messageID: "m\(index)")
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let store = LedgerScanResumeStore()
        _ = try Self.parseClaude(url: url, minDate: nil, store: store, cacheDir: cacheDir)

        let replacement = (0..<4).map { index in
            Self.claudeLine(at: base.addingTimeInterval(Double(index)), input: 5, output: 2, messageID: "t\(index)")
        }
        try (replacement.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let reread = try Self.parseClaude(url: url, minDate: nil, store: store, cacheDir: cacheDir)
        #expect(reread.count == 4)
        #expect(Self.totals(reread).input == 20)
    }

    @Test
    func `day rollover narrows the carried window instead of forcing a re-read`() throws {
        let root = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("rollout.jsonl")
        let base = Date(timeIntervalSince1970: 1_767_122_400)

        let lines = (0..<10).map { index in
            Self.codexTokenLine(
                at: base.addingTimeInterval(Double(index) * 3600),
                input: 10,
                cached: 0,
                output: 1,
                requestID: "r\(index)")
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        let store = LedgerScanResumeStore()
        let wide = try Self.parseCodex(url: url, minDate: base, store: store)
        #expect(wide.count == 10)

        // A later scan with a NARROWER window (e.g. after midnight) still
        // resumes; carried entries are simply filtered down.
        let narrow = try Self.parseCodex(url: url, minDate: base.addingTimeInterval(6 * 3600), store: store)
        #expect(narrow.count == 4)
        #expect(Self.totals(narrow).input == 40)
    }
}
