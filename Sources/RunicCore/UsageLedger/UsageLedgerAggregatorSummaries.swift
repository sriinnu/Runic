import Foundation

extension UsageLedgerAggregator {
    public static func dailySummaries(
        entries: [UsageLedgerEntry],
        timeZone: TimeZone,
        groupByProject: Bool = true) -> [UsageLedgerDailySummary]
    {
        let calendar = self.calendarFor(timeZone)
        var buckets: [DailyKey: AggregateAccumulator] = [:]

        for entry in entries {
            let dayStart = calendar.startOfDay(for: entry.timestamp)
            let key = DailyKey(
                provider: entry.provider,
                projectID: groupByProject ? entry.projectID : nil,
                dayStart: dayStart)
            buckets[key, default: AggregateAccumulator()].consume(entry)
        }

        return buckets.map { key, acc in
            let dayKey = self.dayKeyString(from: key.dayStart, timeZone: timeZone)
            return UsageLedgerDailySummary(
                provider: key.provider,
                projectID: key.projectID,
                dayStart: key.dayStart,
                dayKey: dayKey,
                totals: acc.totals,
                modelsUsed: acc.models)
        }
        .sorted { lhs, rhs in
            if lhs.dayStart != rhs.dayStart {
                return lhs.dayStart < rhs.dayStart
            }
            if lhs.provider != rhs.provider {
                return lhs.provider.rawValue < rhs.provider.rawValue
            }
            return (lhs.projectID ?? "") < (rhs.projectID ?? "")
        }
    }

    public static func sessionSummaries(entries: [UsageLedgerEntry]) -> [UsageLedgerSessionSummary] {
        var buckets: [SessionKey: SessionAccumulator] = [:]

        for entry in entries {
            let sessionID = entry.sessionID ?? "unknown"
            let key = SessionKey(
                provider: entry.provider,
                projectID: entry.projectID,
                sessionID: sessionID)
            buckets[key, default: SessionAccumulator()].consume(entry)
        }

        return buckets.map { key, acc in
            UsageLedgerSessionSummary(
                provider: key.provider,
                sessionID: key.sessionID,
                projectID: key.projectID,
                firstActivity: acc.firstActivity ?? Date.distantPast,
                lastActivity: acc.lastActivity ?? Date.distantPast,
                totals: acc.totals,
                modelsUsed: acc.models,
                versions: acc.versions)
        }
        .sorted { lhs, rhs in
            if lhs.lastActivity != rhs.lastActivity {
                return lhs.lastActivity > rhs.lastActivity
            }
            return lhs.sessionID < rhs.sessionID
        }
    }

    public static func blockSummaries(
        entries: [UsageLedgerEntry],
        blockHours: Double = 5,
        now: Date = Date()) -> [UsageLedgerBlockSummary]
    {
        let blockDuration = blockHours * 60 * 60
        let grouped = Dictionary(grouping: entries) { entry in
            BlockKey(
                provider: entry.provider,
                projectID: entry.projectID,
                sessionID: entry.sessionID)
        }
        var summaries: [UsageLedgerBlockSummary] = []

        for (key, groupEntries) in grouped {
            let sorted = groupEntries.sorted { $0.timestamp < $1.timestamp }
            guard let first = sorted.first else { continue }

            var currentStart = first.timestamp
            var currentEntries: [UsageLedgerEntry] = [first]
            var lastTimestamp = first.timestamp

            func finalizeBlock() {
                guard !currentEntries.isEmpty else { return }
                let blockEnd = currentStart.addingTimeInterval(blockDuration)
                let isActive = now <= blockEnd && now.timeIntervalSince(lastTimestamp) <= blockDuration
                let acc = AggregateAccumulator(entries: currentEntries)
                let tokensPerMinute = isActive ? acc.tokensPerMinute(since: currentStart, now: now) : nil
                let projected = isActive ? acc.projectedTotalTokens(
                    since: currentStart,
                    now: now,
                    duration: blockDuration) : nil
                summaries.append(UsageLedgerBlockSummary(
                    provider: key.provider,
                    sessionID: key.sessionID,
                    projectID: key.projectID,
                    start: currentStart,
                    end: blockEnd,
                    isActive: isActive,
                    entryCount: currentEntries.count,
                    totals: acc.totals,
                    tokensPerMinute: tokensPerMinute,
                    projectedTotalTokens: projected))
            }

            for entry in sorted.dropFirst() {
                let timeSinceStart = entry.timestamp.timeIntervalSince(currentStart)
                let timeSinceLast = entry.timestamp.timeIntervalSince(lastTimestamp)
                if timeSinceStart > blockDuration || timeSinceLast > blockDuration {
                    finalizeBlock()
                    currentStart = entry.timestamp
                    currentEntries = [entry]
                } else {
                    currentEntries.append(entry)
                }
                lastTimestamp = entry.timestamp
            }
            finalizeBlock()
        }

        return summaries.sorted { $0.start > $1.start }
    }

    public static func modelSummaries(
        entries: [UsageLedgerEntry],
        groupByProject: Bool = false) -> [UsageLedgerModelSummary]
    {
        var buckets: [ModelKey: AggregateAccumulator] = [:]

        for entry in entries {
            guard let model = entry.model, !model.isEmpty else { continue }
            let projectIdentity: UsageLedgerProjectIdentity? = if groupByProject {
                UsageLedgerProjectIdentityResolver.resolve(
                    provider: entry.provider,
                    projectID: entry.projectID,
                    projectName: entry.projectName)
            } else {
                nil
            }
            let key = ModelKey(
                provider: entry.provider,
                projectKey: projectIdentity?.key,
                model: model)
            buckets[key, default: AggregateAccumulator()].consume(entry, identity: projectIdentity)
        }

        return buckets.map { key, acc in
            UsageLedgerModelSummary(
                provider: key.provider,
                projectKey: key.projectKey,
                projectID: groupByProject ? acc.projectID : nil,
                projectName: groupByProject ? acc.projectName : nil,
                projectNameConfidence: groupByProject ? acc.projectNameConfidence : .none,
                projectNameSource: groupByProject ? acc.projectNameSource : .unknown,
                projectNameProvenance: groupByProject ? acc.projectNameProvenance : nil,
                model: key.model,
                entryCount: acc.entryCount,
                totals: acc.totals)
        }
        .sorted { lhs, rhs in
            if lhs.totals.totalTokens != rhs.totals.totalTokens {
                return lhs.totals.totalTokens > rhs.totals.totalTokens
            }
            return lhs.model < rhs.model
        }
    }

    public static func projectSummaries(entries: [UsageLedgerEntry]) -> [UsageLedgerProjectSummary] {
        var buckets: [ProjectKey: AggregateAccumulator] = [:]

        for entry in entries {
            let projectIdentity = UsageLedgerProjectIdentityResolver.resolve(
                provider: entry.provider,
                projectID: entry.projectID,
                projectName: entry.projectName)
            let key = ProjectKey(provider: entry.provider, projectKey: projectIdentity.key)
            buckets[key, default: AggregateAccumulator()].consume(entry, identity: projectIdentity)
        }

        return buckets.map { key, acc in
            UsageLedgerProjectSummary(
                provider: key.provider,
                projectKey: key.projectKey,
                projectID: acc.projectID,
                projectName: acc.projectName,
                projectNameConfidence: acc.projectNameConfidence,
                projectNameSource: acc.projectNameSource,
                projectNameProvenance: acc.projectNameProvenance,
                entryCount: acc.entryCount,
                totals: acc.totals,
                modelsUsed: acc.models)
        }
        .sorted { lhs, rhs in
            if lhs.totals.totalTokens != rhs.totals.totalTokens {
                return lhs.totals.totalTokens > rhs.totals.totalTokens
            }
            return (lhs.projectKey ?? lhs.projectID ?? "") < (rhs.projectKey ?? rhs.projectID ?? "")
        }
    }

    public static func hourlySummaries(
        entries: [UsageLedgerEntry],
        timeZone: TimeZone,
        groupByProject: Bool = true) -> [UsageLedgerHourlySummary]
    {
        let calendar = self.calendarFor(timeZone)
        var buckets: [HourlyKey: AggregateAccumulator] = [:]

        for entry in entries {
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: entry.timestamp)
            guard let hourStart = calendar.date(from: components) else { continue }

            let key = HourlyKey(
                provider: entry.provider,
                projectID: groupByProject ? entry.projectID : nil,
                hourStart: hourStart)
            buckets[key, default: AggregateAccumulator()].consume(entry)
        }

        return buckets.map { key, acc in
            let hourKey = self.hourKeyString(from: key.hourStart, timeZone: timeZone)
            return UsageLedgerHourlySummary(
                provider: key.provider,
                projectID: key.projectID,
                hourStart: key.hourStart,
                hourKey: hourKey,
                totals: acc.totals,
                requestCount: acc.entryCount)
        }
        .sorted { lhs, rhs in
            if lhs.hourStart != rhs.hourStart {
                return lhs.hourStart < rhs.hourStart
            }
            if lhs.provider != rhs.provider {
                return lhs.provider.rawValue < rhs.provider.rawValue
            }
            return (lhs.projectID ?? "") < (rhs.projectID ?? "")
        }
    }

    public static func compactionSummaries(entries: [UsageLedgerEntry]) -> [UsageLedgerCompactionSummary] {
        var buckets: [CompactionKey: AggregateAccumulator] = [:]
        var lastEventByProvider: [UsageProvider: Date] = [:]

        for entry in entries where entry.isCompaction {
            let key = CompactionKey(provider: entry.provider)
            buckets[key, default: AggregateAccumulator()].consume(entry)
            if let current = lastEventByProvider[entry.provider] {
                if entry.timestamp > current { lastEventByProvider[entry.provider] = entry.timestamp }
            } else {
                lastEventByProvider[entry.provider] = entry.timestamp
            }
        }

        return buckets.compactMap { key, acc in
            guard let lastEventAt = lastEventByProvider[key.provider] else { return nil }
            return UsageLedgerCompactionSummary(
                provider: key.provider,
                eventCount: acc.entryCount,
                totals: acc.totals,
                lastEventAt: lastEventAt)
        }
        .sorted { lhs, rhs in
            if lhs.lastEventAt != rhs.lastEventAt {
                return lhs.lastEventAt > rhs.lastEventAt
            }
            return lhs.provider.rawValue < rhs.provider.rawValue
        }
    }
}
