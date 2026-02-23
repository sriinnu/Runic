import Foundation

public struct TeamShowbackTotals: Sendable, Codable, Hashable {
    public let totalTokens: Int
    public let totalCostUSD: Double
    public let totalRequests: Int
    public let memberCount: Int
    public let projectCount: Int

    public init(
        totalTokens: Int,
        totalCostUSD: Double,
        totalRequests: Int,
        memberCount: Int,
        projectCount: Int)
    {
        self.totalTokens = totalTokens
        self.totalCostUSD = totalCostUSD
        self.totalRequests = totalRequests
        self.memberCount = memberCount
        self.projectCount = projectCount
    }
}

public struct TeamShowbackProviderBreakdown: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let tokens: Int
    public let costUSD: Double
    public let requestCount: Int

    public init(provider: UsageProvider, tokens: Int, costUSD: Double, requestCount: Int) {
        self.provider = provider
        self.tokens = tokens
        self.costUSD = costUSD
        self.requestCount = requestCount
    }
}

public struct TeamShowbackMemberSummary: Sendable, Codable, Hashable {
    public let userID: String
    public let role: TeamRole?
    public let tokens: Int
    public let costUSD: Double
    public let requestCount: Int
    public let projectCount: Int

    public init(
        userID: String,
        role: TeamRole?,
        tokens: Int,
        costUSD: Double,
        requestCount: Int,
        projectCount: Int)
    {
        self.userID = userID
        self.role = role
        self.tokens = tokens
        self.costUSD = costUSD
        self.requestCount = requestCount
        self.projectCount = projectCount
    }
}

public struct TeamShowbackProjectSummary: Sendable, Codable, Hashable {
    public let projectID: String
    public let ownerUserID: String
    public let ownerRole: TeamRole?
    public let tokens: Int
    public let costUSD: Double
    public let requestCount: Int
    public let providers: [TeamShowbackProviderBreakdown]

    public init(
        projectID: String,
        ownerUserID: String,
        ownerRole: TeamRole?,
        tokens: Int,
        costUSD: Double,
        requestCount: Int,
        providers: [TeamShowbackProviderBreakdown])
    {
        self.projectID = projectID
        self.ownerUserID = ownerUserID
        self.ownerRole = ownerRole
        self.tokens = tokens
        self.costUSD = costUSD
        self.requestCount = requestCount
        self.providers = providers
    }
}

public struct TeamShowbackProviderSummary: Sendable, Codable, Hashable {
    public let provider: UsageProvider
    public let tokens: Int
    public let costUSD: Double
    public let requestCount: Int
    public let memberCount: Int
    public let projectCount: Int

    public init(
        provider: UsageProvider,
        tokens: Int,
        costUSD: Double,
        requestCount: Int,
        memberCount: Int,
        projectCount: Int)
    {
        self.provider = provider
        self.tokens = tokens
        self.costUSD = costUSD
        self.requestCount = requestCount
        self.memberCount = memberCount
        self.projectCount = projectCount
    }
}

public struct TeamShowbackReport: Sendable, Codable, Hashable {
    public let teamID: String
    public let teamName: String
    public let generatedAt: Date
    public let period: DateInterval
    public let totals: TeamShowbackTotals
    public let members: [TeamShowbackMemberSummary]
    public let projects: [TeamShowbackProjectSummary]
    public let providers: [TeamShowbackProviderSummary]

    public init(
        teamID: String,
        teamName: String,
        generatedAt: Date,
        period: DateInterval,
        totals: TeamShowbackTotals,
        members: [TeamShowbackMemberSummary],
        projects: [TeamShowbackProjectSummary],
        providers: [TeamShowbackProviderSummary])
    {
        self.teamID = teamID
        self.teamName = teamName
        self.generatedAt = generatedAt
        self.period = period
        self.totals = totals
        self.members = members
        self.projects = projects
        self.providers = providers
    }
}

public struct TeamShowbackExportBundle: Sendable, Hashable {
    public let report: TeamShowbackReport
    public let json: String
    public let csv: String

    public init(report: TeamShowbackReport, json: String, csv: String) {
        self.report = report
        self.json = json
        self.csv = csv
    }
}

public enum TeamShowbackExporter {
    public static func buildReport(
        team: Team,
        projectOwnerships: [ProjectOwnership],
        entries: [UsageLedgerEntry],
        period: DateInterval,
        generatedAt: Date = Date()) -> TeamShowbackReport
    {
        let relevantOwnerships = projectOwnerships.filter { ownership in
            ownership.teamID == team.id
        }
        let ownershipByProjectID = Dictionary(uniqueKeysWithValues: relevantOwnerships.map { ($0.projectID, $0) })

        let relevantEntries = entries.filter { entry in
            guard entry.timestamp >= period.start, entry.timestamp < period.end else { return false }
            guard let projectID = entry.projectID else { return false }
            return ownershipByProjectID[projectID] != nil
        }

        let roleByUserID = Dictionary(uniqueKeysWithValues: team.members.map { ($0.userID, $0.role) })
        var memberAccumulators: [String: MemberAccumulator] = [:]
        var projectAccumulators: [String: ProjectAccumulator] = [:]
        var providerAccumulators: [UsageProvider: ProviderAccumulator] = [:]

        for entry in relevantEntries {
            guard let projectID = entry.projectID,
                  let ownership = ownershipByProjectID[projectID]
            else {
                continue
            }

            let ownerUserID = ownership.ownerUserID
            let role = roleByUserID[ownerUserID] ?? (ownerUserID == team.ownerUserID ? .owner : nil)
            let tokens = entry.totalTokens
            let costUSD = max(0, entry.costUSD ?? 0)

            memberAccumulators[ownerUserID, default: MemberAccumulator(role: role)].consume(
                tokens: tokens,
                costUSD: costUSD,
                projectID: projectID)

            projectAccumulators[projectID, default: ProjectAccumulator(
                projectID: projectID,
                ownerUserID: ownerUserID,
                ownerRole: role)].consume(
                provider: entry.provider,
                tokens: tokens,
                costUSD: costUSD)

            providerAccumulators[entry.provider, default: ProviderAccumulator(provider: entry.provider)].consume(
                tokens: tokens,
                costUSD: costUSD,
                userID: ownerUserID,
                projectID: projectID)
        }

        let members = memberAccumulators.map { userID, acc in
            TeamShowbackMemberSummary(
                userID: userID,
                role: acc.role,
                tokens: acc.tokens,
                costUSD: acc.costUSD,
                requestCount: acc.requestCount,
                projectCount: acc.projectIDs.count)
        }
        .sorted { lhs, rhs in
            if lhs.tokens != rhs.tokens { return lhs.tokens > rhs.tokens }
            return lhs.userID < rhs.userID
        }

        let projects = projectAccumulators.map { _, acc in
            TeamShowbackProjectSummary(
                projectID: acc.projectID,
                ownerUserID: acc.ownerUserID,
                ownerRole: acc.ownerRole,
                tokens: acc.tokens,
                costUSD: acc.costUSD,
                requestCount: acc.requestCount,
                providers: acc.providerBreakdown.sorted { lhs, rhs in
                    if lhs.tokens != rhs.tokens { return lhs.tokens > rhs.tokens }
                    return lhs.provider.rawValue < rhs.provider.rawValue
                })
        }
        .sorted { lhs, rhs in
            if lhs.tokens != rhs.tokens { return lhs.tokens > rhs.tokens }
            return lhs.projectID < rhs.projectID
        }

        let providers = providerAccumulators.map { _, acc in
            TeamShowbackProviderSummary(
                provider: acc.provider,
                tokens: acc.tokens,
                costUSD: acc.costUSD,
                requestCount: acc.requestCount,
                memberCount: acc.memberIDs.count,
                projectCount: acc.projectIDs.count)
        }
        .sorted { lhs, rhs in
            if lhs.tokens != rhs.tokens { return lhs.tokens > rhs.tokens }
            return lhs.provider.rawValue < rhs.provider.rawValue
        }

        let totals = TeamShowbackTotals(
            totalTokens: relevantEntries.reduce(0) { $0 + $1.totalTokens },
            totalCostUSD: relevantEntries.reduce(0) { $0 + max(0, $1.costUSD ?? 0) },
            totalRequests: relevantEntries.count,
            memberCount: members.count,
            projectCount: projects.count)

        return TeamShowbackReport(
            teamID: team.id,
            teamName: team.name,
            generatedAt: generatedAt,
            period: period,
            totals: totals,
            members: members,
            projects: projects,
            providers: providers)
    }

    public static func makeExportBundle(
        team: Team,
        projectOwnerships: [ProjectOwnership],
        entries: [UsageLedgerEntry],
        period: DateInterval,
        generatedAt: Date = Date(),
        prettyJSON: Bool = true) throws -> TeamShowbackExportBundle
    {
        let report = self.buildReport(
            team: team,
            projectOwnerships: projectOwnerships,
            entries: entries,
            period: period,
            generatedAt: generatedAt)
        let json = try self.encodeJSON(report, pretty: prettyJSON)
        let csv = self.encodeCSV(report)
        return TeamShowbackExportBundle(report: report, json: json, csv: csv)
    }

    public static func encodeJSON(_ report: TeamShowbackReport, pretty: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        return String(decoding: data, as: UTF8.self)
    }

    public static func encodeCSV(_ report: TeamShowbackReport) -> String {
        var rows: [[String]] = []
        rows.append([
            "section",
            "id",
            "name",
            "provider",
            "role",
            "tokens",
            "cost_usd",
            "requests",
            "project_count",
            "member_count",
            "period_start",
            "period_end",
            "generated_at",
        ])

        rows.append([
            "summary",
            report.teamID,
            report.teamName,
            "",
            "",
            "\(report.totals.totalTokens)",
            self.costText(report.totals.totalCostUSD),
            "\(report.totals.totalRequests)",
            "\(report.totals.projectCount)",
            "\(report.totals.memberCount)",
            self.iso8601(report.period.start),
            self.iso8601(report.period.end),
            self.iso8601(report.generatedAt),
        ])

        for member in report.members {
            rows.append([
                "member",
                member.userID,
                member.userID,
                "",
                member.role?.rawValue ?? "",
                "\(member.tokens)",
                self.costText(member.costUSD),
                "\(member.requestCount)",
                "\(member.projectCount)",
                "",
                "",
                "",
                "",
            ])
        }

        for project in report.projects {
            rows.append([
                "project",
                project.projectID,
                project.ownerUserID,
                "",
                project.ownerRole?.rawValue ?? "",
                "\(project.tokens)",
                self.costText(project.costUSD),
                "\(project.requestCount)",
                "",
                "",
                "",
                "",
                "",
            ])
            for provider in project.providers {
                rows.append([
                    "project_provider",
                    project.projectID,
                    project.ownerUserID,
                    provider.provider.rawValue,
                    "",
                    "\(provider.tokens)",
                    self.costText(provider.costUSD),
                    "\(provider.requestCount)",
                    "",
                    "",
                    "",
                    "",
                    "",
                ])
            }
        }

        for provider in report.providers {
            rows.append([
                "provider",
                provider.provider.rawValue,
                provider.provider.rawValue,
                provider.provider.rawValue,
                "",
                "\(provider.tokens)",
                self.costText(provider.costUSD),
                "\(provider.requestCount)",
                "\(provider.projectCount)",
                "\(provider.memberCount)",
                "",
                "",
                "",
            ])
        }

        return rows.map { row in
            row.map(self.csvEscape(_:)).joined(separator: ",")
        }.joined(separator: "\n")
    }

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func costText(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func csvEscape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

private struct MemberAccumulator {
    let role: TeamRole?
    var tokens: Int = 0
    var costUSD: Double = 0
    var requestCount: Int = 0
    var projectIDs: Set<String> = []

    mutating func consume(tokens: Int, costUSD: Double, projectID: String) {
        self.tokens += tokens
        self.costUSD += costUSD
        self.requestCount += 1
        self.projectIDs.insert(projectID)
    }
}

private struct ProjectAccumulator {
    let projectID: String
    let ownerUserID: String
    let ownerRole: TeamRole?
    var tokens: Int = 0
    var costUSD: Double = 0
    var requestCount: Int = 0
    var providers: [UsageProvider: TeamShowbackProviderBreakdown] = [:]

    mutating func consume(provider: UsageProvider, tokens: Int, costUSD: Double) {
        self.tokens += tokens
        self.costUSD += costUSD
        self.requestCount += 1
        let current = self.providers[provider] ?? TeamShowbackProviderBreakdown(
            provider: provider,
            tokens: 0,
            costUSD: 0,
            requestCount: 0)
        self.providers[provider] = TeamShowbackProviderBreakdown(
            provider: provider,
            tokens: current.tokens + tokens,
            costUSD: current.costUSD + costUSD,
            requestCount: current.requestCount + 1)
    }

    var providerBreakdown: [TeamShowbackProviderBreakdown] {
        Array(self.providers.values)
    }
}

private struct ProviderAccumulator {
    let provider: UsageProvider
    var tokens: Int = 0
    var costUSD: Double = 0
    var requestCount: Int = 0
    var memberIDs: Set<String> = []
    var projectIDs: Set<String> = []

    mutating func consume(tokens: Int, costUSD: Double, userID: String, projectID: String) {
        self.tokens += tokens
        self.costUSD += costUSD
        self.requestCount += 1
        self.memberIDs.insert(userID)
        self.projectIDs.insert(projectID)
    }
}
