import Foundation
import Testing
@testable import RunicCore

struct UsageLedgerProjectNameTests {
    @Test
    func `project summaries prefer non empty project name`() {
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

    @Test
    func `project summaries group by inferred name when project ID is missing`() {
        let now = Date()
        let entries = [
            UsageLedgerEntry(
                provider: .codex,
                timestamp: now,
                sessionID: "s1",
                projectID: nil,
                projectName: "Alpha Workspace",
                model: "gpt-5",
                inputTokens: 50,
                outputTokens: 10,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: 0.10,
                requestID: "ra",
                messageID: nil,
                version: nil,
                source: .codexLog),
            UsageLedgerEntry(
                provider: .codex,
                timestamp: now.addingTimeInterval(5),
                sessionID: "s2",
                projectID: nil,
                projectName: "Beta Workspace",
                model: "gpt-5",
                inputTokens: 40,
                outputTokens: 15,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: 0.12,
                requestID: "rb",
                messageID: nil,
                version: nil,
                source: .codexLog),
        ]

        let summaries = UsageLedgerAggregator.projectSummaries(entries: entries)
        #expect(summaries.count == 2)
        let names = Set(summaries.map(\.projectName).compactMap(\.self))
        #expect(names.contains("Alpha Workspace"))
        #expect(names.contains("Beta Workspace"))
    }

    @Test
    func `project summaries infer project name from path like identifier`() {
        let now = Date()
        let entries = [
            UsageLedgerEntry(
                provider: .codex,
                timestamp: now,
                sessionID: "s1",
                projectID: "/Users/me/workspace/Runic-App",
                projectName: nil,
                model: "gpt-5",
                inputTokens: 100,
                outputTokens: 30,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: 0.30,
                requestID: "r-path",
                messageID: nil,
                version: nil,
                source: .codexLog),
        ]

        let summary = UsageLedgerAggregator.projectSummaries(entries: entries).first
        #expect(summary != nil)
        #expect(summary?.projectKey != nil)
        #expect(summary?.projectNameSource == .inferredFromPath)
        #expect(summary?.displayProjectName == "Runic-App")
    }

    @Test
    func `project display name falls back to readable identifier`() {
        let summary = UsageLedgerProjectSummary(
            provider: .codex,
            projectID: "runic-core",
            projectName: nil,
            projectNameConfidence: .low,
            projectNameSource: .projectID,
            projectNameProvenance: "entry.projectID",
            entryCount: 1,
            totals: UsageLedgerTotals(
                inputTokens: 1,
                outputTokens: 1,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: nil),
            modelsUsed: [])

        #expect(summary.displayProjectName == "runic-core")
    }

    @Test
    func `project display name keeps opaque identifiers hidden`() {
        let summary = UsageLedgerProjectSummary(
            provider: .codex,
            projectID: "8f189f6bb4e9fa93a9a4bf5cf97a0b4d",
            projectName: nil,
            projectNameConfidence: .low,
            projectNameSource: .projectID,
            projectNameProvenance: "entry.projectID",
            entryCount: 1,
            totals: UsageLedgerTotals(
                inputTokens: 1,
                outputTokens: 1,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
                costUSD: nil),
            modelsUsed: [])

        #expect(summary.displayProjectName == "Unknown project")
    }
}
