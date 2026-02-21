import Foundation
import Testing

@testable import RunicCore

@Suite
struct CodexUsageLogSourceTests {
    @Test
    func codexUsageFallsBackToWorkspacePathFromTurnContext() async throws {
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

        let source = CodexUsageLogSource(
            environment: [:],
            fileManager: fm,
            sessionsRoot: root,
            maxAgeDays: nil,
            now: now)
        let entries = try await source.loadEntries()

        #expect(entries.count == 1)
        #expect(entries.first?.projectID == "/Users/me/work/Runic-App")
        #expect(entries.first?.projectName == nil)

        let summary = UsageLedgerAggregator.projectSummaries(entries: entries).first
        #expect(summary?.displayProjectName == "Runic-App")
    }

    private static func jsonLine(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CodexUsageLogSourceTests", code: 1)
        }
        return text
    }
}
