import Foundation
import RunicCore

extension UsageStoreLedgerInsightLoader {
    func loadLedgerEntries(
        from sources: [(UsageProvider, any UsageLedgerSource)]) async -> LedgerEntryLoad
    {
        let providers = sources.map(\.0)
        var entries: [UsageLedgerEntry] = []
        var errors: [UsageProvider: String] = [:]

        await withTaskGroup(of: (UsageProvider, Result<[UsageLedgerEntry], Error>).self) { group in
            for (provider, source) in sources {
                group.addTask {
                    do {
                        let loaded = try await source.loadEntries()
                        return (provider, .success(loaded))
                    } catch {
                        return (provider, .failure(error))
                    }
                }
            }

            for await (provider, result) in group {
                switch result {
                case let .success(loaded):
                    entries.append(contentsOf: loaded)
                case let .failure(error):
                    errors[provider] = error.localizedDescription
                }
            }
        }

        return LedgerEntryLoad(
            providers: providers,
            entries: entries,
            errors: errors)
    }

    func ledgerDailyBuckets(
        entries: [UsageLedgerEntry],
        providers: [UsageProvider],
        now: Date,
        calendar: Calendar,
        timeZone: TimeZone) async -> LedgerDailyBuckets
    {
        let todayStart = calendar.startOfDay(for: now)
        var dailyByProvider: [UsageProvider: UsageLedgerDailySummary] = [:]
        var allDailySummariesByProvider: [UsageProvider: [UsageLedgerDailySummary]] = [:]
        for summary in UsageLedgerAggregator.dailySummaries(
            entries: entries,
            timeZone: timeZone,
            groupByProject: false)
        {
            allDailySummariesByProvider[summary.provider, default: []].append(summary)
            if summary.dayStart == todayStart {
                dailyByProvider[summary.provider] = summary
            }
        }

        for provider in providers {
            guard let cached = await LedgerCache.shared.loadCachedDailies(provider: provider.rawValue) else { continue }
            let summaries = cached.dailies.compactMap { $0.toLedgerDailySummary(provider: provider) }
            guard !summaries.isEmpty else { continue }
            var byDay = Dictionary(uniqueKeysWithValues: summaries.map { ($0.dayKey, $0) })
            for summary in allDailySummariesByProvider[provider] ?? [] {
                byDay[summary.dayKey] = summary
            }
            allDailySummariesByProvider[provider] = byDay.values.sorted { $0.dayStart < $1.dayStart }
            if dailyByProvider[provider] == nil {
                dailyByProvider[provider] = byDay.values.first { $0.dayStart == todayStart }
            }
        }

        return LedgerDailyBuckets(
            dailyByProvider: dailyByProvider,
            allDailySummariesByProvider: allDailySummariesByProvider,
            mergedDailySummaries: allDailySummariesByProvider.values.flatMap { $0 })
    }

    func hourlySummariesByProvider(
        entries: [UsageLedgerEntry],
        timeZone: TimeZone) -> [UsageProvider: [UsageLedgerHourlySummary]]
    {
        var hourlySummariesByProvider: [UsageProvider: [UsageLedgerHourlySummary]] = [:]
        for summary in UsageLedgerAggregator.hourlySummaries(
            entries: entries,
            timeZone: timeZone,
            groupByProject: false)
        {
            hourlySummariesByProvider[summary.provider, default: []].append(summary)
        }
        return hourlySummariesByProvider
    }

    func activeBlocksByProvider(
        entries: [UsageLedgerEntry],
        now: Date) -> [UsageProvider: UsageLedgerBlockSummary]
    {
        var activeByProvider: [UsageProvider: UsageLedgerBlockSummary] = [:]
        let blocks = UsageLedgerAggregator.blockSummaries(entries: entries, blockHours: 5, now: now)
        for block in blocks where block.isActive {
            if activeByProvider[block.provider] == nil {
                activeByProvider[block.provider] = block
            }
        }
        return activeByProvider
    }

    func compactionsByProvider(entries: [UsageLedgerEntry]) -> [UsageProvider: UsageLedgerCompactionSummary] {
        var compactionsByProvider: [UsageProvider: UsageLedgerCompactionSummary] = [:]
        for summary in UsageLedgerAggregator.compactionSummaries(entries: entries) {
            compactionsByProvider[summary.provider] = summary
        }
        return compactionsByProvider
    }

    func lastActivityByProvider(entries: [UsageLedgerEntry]) -> [UsageProvider: Date] {
        var lastActivityByProvider: [UsageProvider: Date] = [:]
        for entry in entries {
            if let current = lastActivityByProvider[entry.provider] {
                if entry.timestamp > current { lastActivityByProvider[entry.provider] = entry.timestamp }
            } else {
                lastActivityByProvider[entry.provider] = entry.timestamp
            }
        }
        return lastActivityByProvider
    }
}
