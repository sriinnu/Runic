import Foundation
import Testing

@testable import RunicCore

@Suite
struct UsageLedgerProjectNameTests {
    @Test
    func projectSummariesPreferNonEmptyProjectName() {
        let now = Date()
        let entries = [
            UsageLedgerEntry(
                provider: .codex,
                timestamp: now,
                sessionID: "s1",
                projectID: "proj-123",
                projectName: "   ",
                model: "gpt-5",
                inputTokens: 10,
                outputTokens: 5,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: 0.01,
                requestID: "r1",
                messageID: nil,
                version: nil,
                source: .codexLog),
            UsageLedgerEntry(
                provider: .codex,
                timestamp: now.addingTimeInterval(1),
                sessionID: "s1",
                projectID: "proj-123",
                projectName: "Core Platform",
                model: "gpt-5",
                inputTokens: 20,
                outputTokens: 10,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: 0.03,
                requestID: "r2",
                messageID: nil,
                version: nil,
                source: .codexLog),
        ]

        let projectSummary = UsageLedgerAggregator.projectSummaries(entries: entries).first
        #expect(projectSummary?.projectID == "proj-123")
        #expect(projectSummary?.projectName == "Core Platform")

        let modelSummary = UsageLedgerAggregator.modelSummaries(entries: entries, groupByProject: true).first
        #expect(modelSummary?.projectID == "proj-123")
        #expect(modelSummary?.projectName == "Core Platform")
    }
}
