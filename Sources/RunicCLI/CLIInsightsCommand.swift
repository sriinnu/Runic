import Foundation
import Helix
import RunicCore

extension RunicCLI {
    static func runInsights(_ invocation: CommandInvocation) async {
        let providerArg = invocation.parsedValues.options["provider"]?.first?.lowercased()
        let viewArg = invocation.parsedValues.options["view"]?.first?.lowercased() ?? "daily"
        let projectFilter = invocation.parsedValues.options["project"]?.first
        let timezoneArg = invocation.parsedValues.options["timezone"]?.first
        let granularityArg = invocation.parsedValues.options["granularity"]?.first?.lowercased()
        let gitDirectoryArg = invocation.parsedValues.options["gitDirectory"]?.first
        let isJson = invocation.parsedValues.flags.contains("json")
        let isPretty = invocation.parsedValues.flags.contains("pretty")
        let includeBudget = invocation.parsedValues.flags.contains("budget")
        let withCommits = invocation.parsedValues.flags.contains("withCommits")

        let timeZone = timezoneArg.flatMap(TimeZone.init(identifier:)) ?? .current
        let providers = Self.resolveInsightsProviders(providerArg)
        let now = Date()
        let sources = Self.insightsSources(for: providers, now: now)

        var entries: [UsageLedgerEntry] = []
        var errors: [String] = []
        for (provider, source) in sources {
            do {
                let loaded = try await source.loadEntries()
                entries.append(contentsOf: loaded)
            } catch {
                errors.append("Error reading \(provider.rawValue) logs: \(error.localizedDescription)")
            }
        }

        if entries.isEmpty {
            if errors.isEmpty {
                Self.exit(code: 1, message: "No insights available.")
            }
            Self.exit(code: 1, message: errors.joined(separator: "\n"))
        }

        if !errors.isEmpty, !isJson {
            for err in errors {
                Self.printError(err)
            }
        }

        if let projectFilter, !projectFilter.isEmpty {
            entries = entries.filter { $0.projectID == projectFilter }
        }

        if withCommits {
            let gitDirectory = gitDirectoryArg.map { URL(fileURLWithPath: $0) }
            let entriesWithCommits = GitHubIntegration.linkCommitsToUsage(entries: entries, gitDirectory: gitDirectory)
            RunicCLIInsightsRenderer.renderWithCommits(entriesWithCommits, isJson: isJson, isPretty: isPretty)
            return
        }

        switch viewArg {
        case "daily":
            if let granularity = granularityArg, granularity == "hourly" {
                let summaries = UsageLedgerAggregator.hourlySummaries(entries: entries, timeZone: timeZone)
                RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
            } else {
                let summaries = UsageLedgerAggregator.dailySummaries(entries: entries, timeZone: timeZone)
                RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
            }
        case "session":
            let summaries = UsageLedgerAggregator.sessionSummaries(entries: entries)
            RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "blocks":
            let summaries = UsageLedgerAggregator.blockSummaries(entries: entries, blockHours: 5, now: now)
            RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "models":
            let summaries = UsageLedgerAggregator.modelSummaries(entries: entries, groupByProject: true)
            RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "projects":
            let summaries = UsageLedgerAggregator.projectSummaries(entries: entries)
            if includeBudget {
                let budgetData = Self.enrichProjectsWithBudget(summaries)
                RunicCLIInsightsRenderer.renderOutput(budgetData, isJson: isJson, isPretty: isPretty)
            } else {
                RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
            }
        case "compaction":
            let summaries = UsageLedgerAggregator.compactionSummaries(entries: entries)
            RunicCLIInsightsRenderer.renderOutput(summaries, isJson: isJson, isPretty: isPretty)
        case "comparative":
            let comparisons = Self.modelCostComparison(entries: entries)
            RunicCLIInsightsRenderer.renderOutput(comparisons, isJson: isJson, isPretty: isPretty)
        case "efficiency":
            let efficiencies = Self.modelEfficiencyMetrics(entries: entries)
            RunicCLIInsightsRenderer.renderOutput(efficiencies, isJson: isJson, isPretty: isPretty)
        default:
            Self.exit(code: 1, message: "Unknown insights view: \(viewArg)")
        }
    }

    private static func resolveInsightsProviders(_ raw: String?) -> [UsageProvider] {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "claude"
        return Self.resolveProviderList(trimmed, defaultProviders: ProviderDescriptorRegistry.all.map(\.id))
    }

    private static func insightsSources(
        for providers: [UsageProvider],
        now: Date) -> [(UsageProvider, any UsageLedgerSource)]
    {
        var sources: [(UsageProvider, any UsageLedgerSource)] = []
        for provider in providers {
            if let source = UsageLedgerSourceFactory.source(for: provider, now: now, maxAgeDays: nil) {
                sources.append((provider, source))
            }
        }
        return sources
    }
}
