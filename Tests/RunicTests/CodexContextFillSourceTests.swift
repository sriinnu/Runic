import Foundation
import Testing
@testable import RunicCore

struct CodexContextFillSourceTests {
    @Test
    func `latest token count wins with transcript window and turn context model`() throws {
        let now = Date(timeIntervalSince1970: 1_767_122_400) // 2026-01-01T00:00:00Z
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let lines = try [
            Self.jsonLine([
                "type": "turn_context",
                "timestamp": Self.iso(now.addingTimeInterval(-300)),
                "payload": ["model": "gpt-5.2-codex"],
            ]),
            Self.tokenCountLine(
                timestamp: now.addingTimeInterval(-240),
                lastInput: 10000,
                lastCached: 2000,
                lastOutput: 100,
                contextWindow: 258_400),
            Self.tokenCountLine(
                timestamp: now.addingTimeInterval(-60),
                lastInput: 25859,
                lastCached: 7040,
                lastOutput: 184,
                contextWindow: 258_400),
        ]
        try Self.writeRollout(
            root: root,
            fileName: "rollout-2026-01-01-live",
            lines: lines,
            modifiedAt: now.addingTimeInterval(-60))

        let sample = CodexContextFillSource(environment: [:], sessionsRoot: root).latestSample(now: now)

        #expect(sample?.occupiedTokens == 25859)
        #expect(sample?.transcriptContextWindow == 258_400)
        #expect(sample?.model == "gpt-5.2-codex")
        #expect(sample?.sessionID == "rollout-2026-01-01-live")
        #expect(sample?.timestamp == now.addingTimeInterval(-60))
    }

    @Test
    func `info model wins over turn context`() throws {
        let now = Date(timeIntervalSince1970: 1_767_122_400)
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let lines = try [
            Self.jsonLine([
                "type": "turn_context",
                "timestamp": Self.iso(now.addingTimeInterval(-300)),
                "payload": ["model": "gpt-5.2-codex"],
            ]),
            Self.tokenCountLine(
                timestamp: now.addingTimeInterval(-60),
                lastInput: 4200,
                lastCached: 0,
                lastOutput: 12,
                contextWindow: 128_000,
                infoModel: "gpt-5-mini"),
        ]
        try Self.writeRollout(
            root: root,
            fileName: "rollout-model-in-info",
            lines: lines,
            modifiedAt: now.addingTimeInterval(-60))

        let sample = CodexContextFillSource(environment: [:], sessionsRoot: root).latestSample(now: now)

        #expect(sample?.model == "gpt-5-mini")
        #expect(sample?.occupiedTokens == 4200)
    }

    @Test
    func `legacy cumulative total token usage yields no sample`() throws {
        // `total_token_usage.input_tokens` is a CUMULATIVE session counter (the
        // usage parser deltas it), not context occupancy — a long legacy
        // session would peg the gauge at 100%. Lines that predate
        // `last_token_usage` must yield no live sample; the heuristic fallback
        // covers those sessions instead.
        let now = Date(timeIntervalSince1970: 1_767_122_400)
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let line = try Self.jsonLine([
            "type": "event_msg",
            "timestamp": Self.iso(now.addingTimeInterval(-60)),
            "payload": [
                "type": "token_count",
                "info": [
                    "model": "gpt-5",
                    "total_token_usage": [
                        "input_tokens": 300,
                        "cached_input_tokens": 50,
                        "output_tokens": 40,
                    ],
                ],
            ],
        ])
        try Self.writeRollout(
            root: root,
            fileName: "rollout-legacy",
            lines: [line],
            modifiedAt: now.addingTimeInterval(-60))

        let sample = CodexContextFillSource(environment: [:], sessionsRoot: root).latestSample(now: now)

        #expect(sample == nil)
    }

    @Test
    func `idle rollout yields no sample`() throws {
        let now = Date(timeIntervalSince1970: 1_767_122_400)
        let root = try Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let line = try Self.tokenCountLine(
            timestamp: now.addingTimeInterval(-45 * 60),
            lastInput: 25859,
            lastCached: 7040,
            lastOutput: 184,
            contextWindow: 258_400)
        try Self.writeRollout(
            root: root,
            fileName: "rollout-idle",
            lines: [line],
            modifiedAt: now.addingTimeInterval(-45 * 60))

        let sample = CodexContextFillSource(environment: [:], sessionsRoot: root).latestSample(now: now)

        #expect(sample == nil)
    }

    // MARK: - Fixtures

    private static func makeRoot() throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("runic-codex-context-fill-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static func writeRollout(
        root: URL,
        fileName: String,
        lines: [String],
        modifiedAt: Date) throws
    {
        let fm = FileManager.default
        let dayDir = root
            .appendingPathComponent("2026", isDirectory: true)
            .appendingPathComponent("01", isDirectory: true)
            .appendingPathComponent("01", isDirectory: true)
        try fm.createDirectory(at: dayDir, withIntermediateDirectories: true)
        let fileURL = dayDir.appendingPathComponent("\(fileName).jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: fileURL.path)
    }

    private static func tokenCountLine(
        timestamp: Date,
        lastInput: Int,
        lastCached: Int,
        lastOutput: Int,
        contextWindow: Int,
        infoModel: String? = nil) throws -> String
    {
        var info: [String: Any] = [
            "total_token_usage": [
                "input_tokens": lastInput,
                "cached_input_tokens": lastCached,
                "output_tokens": lastOutput,
            ],
            "last_token_usage": [
                "input_tokens": lastInput,
                "cached_input_tokens": lastCached,
                "output_tokens": lastOutput,
            ],
            "model_context_window": contextWindow,
        ]
        if let infoModel {
            info["model"] = infoModel
        }
        return try Self.jsonLine([
            "type": "event_msg",
            "timestamp": Self.iso(timestamp),
            "payload": [
                "type": "token_count",
                "info": info,
            ],
        ])
    }

    private static func jsonLine(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CodexContextFillSourceTests", code: 1)
        }
        return text
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
