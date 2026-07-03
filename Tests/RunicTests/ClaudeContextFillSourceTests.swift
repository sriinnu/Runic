import Foundation
import Testing
@testable import RunicCore

struct ClaudeContextFillSourceTests {
    @Test
    func `latest usage entry wins and sums prompt side tokens`() throws {
        let now = Date(timeIntervalSince1970: 1_767_122_400) // 2026-01-01T00:00:00Z
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let older = Self.usageLine(UsageFixture(
            timestamp: now.addingTimeInterval(-600),
            model: "claude-sonnet-4-5",
            input: 100,
            cacheCreation: 10,
            cacheRead: 50,
            output: 5,
            sessionID: "session-a"))
        let latest = Self.usageLine(UsageFixture(
            timestamp: now.addingTimeInterval(-60),
            model: "claude-opus-4-6",
            input: 1200,
            cacheCreation: 3000,
            cacheRead: 90000,
            output: 999,
            sessionID: "session-a"))
        let trailingNonUsage = #"{"type":"user","timestamp":"ignored","message":{"role":"user"}}"#
        let trailingApiError = Self.usageLine(UsageFixture(
            timestamp: now.addingTimeInterval(-30),
            model: "<synthetic>",
            input: 999_999,
            sessionID: "session-a",
            isApiErrorMessage: true))

        try Self.writeTranscript(
            root: root,
            project: "-Users-me-work-runic",
            fileName: "session-a.jsonl",
            lines: [older, latest, trailingNonUsage, trailingApiError],
            modifiedAt: now.addingTimeInterval(-60))

        let sample = ClaudeContextFillSource(environment: [:], basePaths: [root]).latestSample(now: now)

        #expect(sample?.occupiedTokens == 1200 + 3000 + 90000)
        #expect(sample?.model == "claude-opus-4-6")
        #expect(sample?.sessionID == "session-a")
        #expect(sample?.transcriptContextWindow == nil)
        #expect(sample?.timestamp == now.addingTimeInterval(-60))
    }

    @Test
    func `most recently modified transcript is selected`() throws {
        let now = Date(timeIntervalSince1970: 1_767_122_400)
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try Self.writeTranscript(
            root: root,
            project: "-Users-me-work-old",
            fileName: "session-old.jsonl",
            lines: [Self.usageLine(UsageFixture(
                timestamp: now.addingTimeInterval(-900),
                model: "claude-sonnet-4-5",
                input: 111,
                output: 1,
                sessionID: "session-old"))],
            modifiedAt: now.addingTimeInterval(-900))
        try Self.writeTranscript(
            root: root,
            project: "-Users-me-work-live",
            fileName: "session-live.jsonl",
            lines: [Self.usageLine(UsageFixture(
                timestamp: now.addingTimeInterval(-30),
                model: "claude-opus-4-6",
                input: 222,
                cacheRead: 40000,
                output: 1,
                sessionID: "session-live"))],
            modifiedAt: now.addingTimeInterval(-30))

        let sample = ClaudeContextFillSource(environment: [:], basePaths: [root]).latestSample(now: now)

        #expect(sample?.sessionID == "session-live")
        #expect(sample?.occupiedTokens == 222 + 40000)
    }

    @Test
    func `idle transcript yields no sample`() throws {
        let now = Date(timeIntervalSince1970: 1_767_122_400)
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        try Self.writeTranscript(
            root: root,
            project: "-Users-me-work-idle",
            fileName: "session-idle.jsonl",
            lines: [Self.usageLine(UsageFixture(
                timestamp: now.addingTimeInterval(-45 * 60),
                model: "claude-opus-4-6",
                input: 500,
                cacheRead: 90000,
                output: 10,
                sessionID: "session-idle"))],
            modifiedAt: now.addingTimeInterval(-45 * 60))

        let sample = ClaudeContextFillSource(environment: [:], basePaths: [root]).latestSample(now: now)

        #expect(sample == nil)
    }

    @Test
    func `tail reader drops the partial first line when starting mid file`() throws {
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("tail.jsonl")
        try "0123456789\nBBBB\nCCCC\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let partial = ContextFillTailReader.tailLines(of: fileURL, tailBytes: 12)
        #expect(partial.compactMap { String(data: $0, encoding: .utf8) } == ["BBBB", "CCCC"])

        let full = ContextFillTailReader.tailLines(of: fileURL, tailBytes: 4096)
        #expect(full.compactMap { String(data: $0, encoding: .utf8) } == ["0123456789", "BBBB", "CCCC"])
    }

    // MARK: - Fixtures

    private static func makeRoot() throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-claude-context-fill-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @discardableResult
    private static func writeTranscript(
        root: URL,
        project: String,
        fileName: String,
        lines: [String],
        modifiedAt: Date) throws -> URL
    {
        let fm = FileManager.default
        let projectDir = root
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(project, isDirectory: true)
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let fileURL = projectDir.appendingPathComponent(fileName)
        try (lines.joined(separator: "\n") + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: fileURL.path)
        return fileURL
    }

    private struct UsageFixture {
        let timestamp: Date
        let model: String
        let input: Int
        var cacheCreation = 0
        var cacheRead = 0
        var output = 0
        let sessionID: String
        var isApiErrorMessage = false
    }

    private static func usageLine(_ fixture: UsageFixture) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let ts = formatter.string(from: fixture.timestamp)
        return """
        {"type":"assistant","timestamp":"\(ts)","sessionId":"\(fixture.sessionID)",\
        "isApiErrorMessage":\(fixture.isApiErrorMessage),\
        "message":{"id":"msg_\(Int(fixture.timestamp.timeIntervalSince1970))",\
        "model":"\(fixture.model)","usage":{"input_tokens":\(fixture.input),"output_tokens":\(fixture.output),\
        "cache_creation_input_tokens":\(fixture.cacheCreation),"cache_read_input_tokens":\(fixture.cacheRead)}}}
        """
    }
}
