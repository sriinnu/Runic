import Foundation
import Testing

@testable import RunicCore

@Suite
struct TeamShowbackExporterTests {
    @Test
    func buildsShowbackReportForTeamOwnedProjects() throws {
        let period = DateInterval(
            start: self.date(year: 2026, month: 2, day: 1),
            end: self.date(year: 2026, month: 3, day: 1))
        let team = Team(
            id: "team-1",
            name: "Runic Team",
            ownerUserID: "u-owner",
            totalQuota: 500_000,
            members: [
                TeamMembership(userID: "u-owner", teamID: "team-1", role: .owner),
                TeamMembership(userID: "u-member", teamID: "team-1", role: .member),
            ])
        let ownerships = [
            ProjectOwnership(projectID: "proj-a", teamID: "team-1", ownerUserID: "u-owner"),
            ProjectOwnership(projectID: "proj-b", teamID: "team-1", ownerUserID: "u-member"),
            ProjectOwnership(projectID: "proj-outside", teamID: "team-2", ownerUserID: "u-owner"),
        ]
        let entries = [
            self.entry(
                provider: .claude,
                timestamp: self.date(year: 2026, month: 2, day: 10),
                projectID: "proj-a",
                inputTokens: 100,
                outputTokens: 50,
                costUSD: 0.30),
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 11),
                projectID: "proj-b",
                inputTokens: 140,
                outputTokens: 60,
                costUSD: 0.45),
            // Excluded: non-team project
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 12),
                projectID: "proj-outside",
                inputTokens: 999,
                outputTokens: 0,
                costUSD: 9.99),
            // Excluded: outside period
            self.entry(
                provider: .claude,
                timestamp: self.date(year: 2026, month: 3, day: 3),
                projectID: "proj-a",
                inputTokens: 77,
                outputTokens: 22,
                costUSD: 0.10),
        ]

        let report = TeamShowbackExporter.buildReport(
            team: team,
            projectOwnerships: ownerships,
            entries: entries,
            period: period,
            generatedAt: self.date(year: 2026, month: 2, day: 28))

        #expect(report.teamID == "team-1")
        #expect(report.totals.totalTokens == 350)
        #expect(report.totals.totalRequests == 2)
        #expect(abs(report.totals.totalCostUSD - 0.75) < 0.000_001)
        #expect(report.members.count == 2)
        #expect(report.projects.count == 2)
        #expect(report.providers.count == 2)

        let owner = try #require(report.members.first { $0.userID == "u-owner" })
        #expect(owner.role == .owner)
        #expect(owner.tokens == 150)
        let member = try #require(report.members.first { $0.userID == "u-member" })
        #expect(member.role == .member)
        #expect(member.tokens == 200)
    }

    @Test
    func exportsJsonAndCsvFromReport() throws {
        let period = DateInterval(
            start: self.date(year: 2026, month: 2, day: 1),
            end: self.date(year: 2026, month: 3, day: 1))
        let team = Team(
            id: "team-export",
            name: "Exports",
            ownerUserID: "owner",
            totalQuota: 100_000,
            members: [TeamMembership(userID: "owner", teamID: "team-export", role: .owner)])
        let ownerships = [ProjectOwnership(projectID: "proj-csv", teamID: "team-export", ownerUserID: "owner")]
        let entries = [
            self.entry(
                provider: .codex,
                timestamp: self.date(year: 2026, month: 2, day: 8),
                projectID: "proj-csv",
                inputTokens: 42,
                outputTokens: 8,
                costUSD: 0.09),
        ]

        let bundle = try TeamShowbackExporter.makeExportBundle(
            team: team,
            projectOwnerships: ownerships,
            entries: entries,
            period: period,
            generatedAt: self.date(year: 2026, month: 2, day: 28),
            prettyJSON: false)

        #expect(bundle.json.contains("\"teamID\":\"team-export\""))
        #expect(bundle.json.contains("\"totalTokens\":50"))
        #expect(bundle.csv.contains("section,id,name,provider,role,tokens,cost_usd,requests"))
        #expect(bundle.csv.contains("summary,team-export,Exports"))
        #expect(bundle.csv.contains("member,owner,owner"))
        #expect(bundle.csv.contains("provider,codex,codex,codex"))
    }

    private func entry(
        provider: UsageProvider,
        timestamp: Date,
        projectID: String,
        inputTokens: Int,
        outputTokens: Int,
        costUSD: Double?) -> UsageLedgerEntry
    {
        UsageLedgerEntry(
            provider: provider,
            timestamp: timestamp,
            sessionID: "session-\(projectID)",
            projectID: projectID,
            projectName: nil,
            model: "model-\(provider.rawValue)",
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            costUSD: costUSD,
            requestID: UUID().uuidString,
            messageID: nil,
            version: nil,
            source: .api)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        let tz = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: tz,
            year: year,
            month: month,
            day: day,
            hour: hour))!
    }
}
