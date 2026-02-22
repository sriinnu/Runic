import Foundation

public enum UsageLedgerAggregator {
    private struct DailyKey: Hashable {
        let provider: UsageProvider
        let projectID: String?
        let dayStart: Date
    }

    private struct SessionKey: Hashable {
        let provider: UsageProvider
        let projectID: String?
        let sessionID: String
    }

    private struct BlockKey: Hashable {
        let provider: UsageProvider
        let projectID: String?
        let sessionID: String?
    }

    private struct ModelKey: Hashable {
        let provider: UsageProvider
        let projectKey: String?
        let model: String
    }

    private struct ProjectKey: Hashable {
        let provider: UsageProvider
        let projectKey: String?
    }

    private struct HourlyKey: Hashable {
        let provider: UsageProvider
        let projectID: String?
        let hourStart: Date
    }

    private struct SpendForecastKey: Hashable {
        let provider: UsageProvider
        let projectKey: String?
    }

    public static func dailySummaries(
        entries: [UsageLedgerEntry],
        timeZone: TimeZone,
        groupByProject: Bool = true) -> [UsageLedgerDailySummary]
    {
        let calendar = calendarFor(timeZone)
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
            let dayKey = dayKeyString(from: key.dayStart, timeZone: timeZone)
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
                let projected = isActive ? acc.projectedTotalTokens(since: currentStart, now: now, duration: blockDuration) : nil
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
                projectID: acc.projectID,
                projectName: acc.projectName,
                projectNameConfidence: acc.projectNameConfidence,
                projectNameSource: acc.projectNameSource,
                projectNameProvenance: acc.projectNameProvenance,
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

    public static func providerSpendForecasts(
        entries: [UsageLedgerEntry],
        now: Date = Date(),
        timeZone: TimeZone = .current,
        projectionDays: Int = 30) -> [UsageLedgerSpendForecast]
    {
        self.spendForecasts(
            entries: entries,
            now: now,
            timeZone: timeZone,
            projectionDays: projectionDays,
            groupByProject: false)
    }

    public static func projectSpendForecasts(
        entries: [UsageLedgerEntry],
        now: Date = Date(),
        timeZone: TimeZone = .current,
        projectionDays: Int = 30) -> [UsageLedgerSpendForecast]
    {
        self.spendForecasts(
            entries: entries,
            now: now,
            timeZone: timeZone,
            projectionDays: projectionDays,
            groupByProject: true)
    }

    private static func spendForecasts(
        entries: [UsageLedgerEntry],
        now: Date,
        timeZone: TimeZone,
        projectionDays: Int,
        groupByProject: Bool) -> [UsageLedgerSpendForecast]
    {
        guard projectionDays > 0 else { return [] }
        let calendar = calendarFor(timeZone)
        var buckets: [SpendForecastKey: SpendForecastAccumulator] = [:]

        for entry in entries {
            guard self.isInSameMonth(entry.timestamp, as: now, calendar: calendar) else { continue }
            guard let cost = entry.costUSD else { continue }
            let dayStart = calendar.startOfDay(for: entry.timestamp)
            let projectIdentity: UsageLedgerProjectIdentity? = if groupByProject {
                UsageLedgerProjectIdentityResolver.resolve(
                    provider: entry.provider,
                    projectID: entry.projectID,
                    projectName: entry.projectName)
            } else {
                nil
            }
            let key = SpendForecastKey(
                provider: entry.provider,
                projectKey: projectIdentity?.key)
            buckets[key, default: SpendForecastAccumulator()]
                .consume(entry, costUSD: cost, dayStart: dayStart, identity: projectIdentity)
        }

        return buckets.compactMap { key, accumulator in
            accumulator.forecast(
                provider: key.provider,
                projectKey: key.projectKey,
                projectionDays: projectionDays)
        }
        .sorted { lhs, rhs in
            if lhs.projected30DayCostUSD != rhs.projected30DayCostUSD {
                return lhs.projected30DayCostUSD > rhs.projected30DayCostUSD
            }
            if lhs.provider != rhs.provider {
                return lhs.provider.rawValue < rhs.provider.rawValue
            }
            return (lhs.projectKey ?? lhs.projectID ?? "") < (rhs.projectKey ?? rhs.projectID ?? "")
        }
    }

    private static func isInSameMonth(_ date: Date, as reference: Date, calendar: Calendar) -> Bool {
        calendar.isDate(date, equalTo: reference, toGranularity: .month)
    }

    private static func calendarFor(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func dayKeyString(from date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendarFor(timeZone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func hourKeyString(from date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendarFor(timeZone)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:00:00"
        return formatter.string(from: date)
    }

    public static func hourlySummaries(
        entries: [UsageLedgerEntry],
        timeZone: TimeZone,
        groupByProject: Bool = true) -> [UsageLedgerHourlySummary]
    {
        let calendar = calendarFor(timeZone)
        var buckets: [HourlyKey: AggregateAccumulator] = [:]

        for entry in entries {
            // Get the start of the hour for this entry
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: entry.timestamp)
            guard let hourStart = calendar.date(from: components) else { continue }

            let key = HourlyKey(
                provider: entry.provider,
                projectID: groupByProject ? entry.projectID : nil,
                hourStart: hourStart)
            buckets[key, default: AggregateAccumulator()].consume(entry)
        }

        return buckets.map { key, acc in
            let hourKey = hourKeyString(from: key.hourStart, timeZone: timeZone)
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
}

private struct AggregateAccumulator {
    private(set) var inputTokens: Int = 0
    private(set) var outputTokens: Int = 0
    private(set) var cacheCreationTokens: Int = 0
    private(set) var cacheReadTokens: Int = 0
    private(set) var costSum: Double = 0
    private(set) var hasCost: Bool = false
    private(set) var entryCount: Int = 0
    private(set) var projectKey: String?
    private(set) var projectID: String?
    private(set) var projectName: String?
    private(set) var projectNameConfidence: UsageLedgerProjectNameConfidence = .none
    private(set) var projectNameSource: UsageLedgerProjectNameSource = .unknown
    private(set) var projectNameProvenance: String?
    private var modelSet: Set<String> = []

    init() {}

    init(entries: [UsageLedgerEntry]) {
        for entry in entries {
            self.consume(entry)
        }
    }

    mutating func consume(_ entry: UsageLedgerEntry, identity: UsageLedgerProjectIdentity? = nil) {
        self.entryCount += 1
        self.inputTokens += entry.inputTokens
        self.outputTokens += entry.outputTokens
        self.cacheCreationTokens += entry.cacheCreationTokens
        self.cacheReadTokens += entry.cacheReadTokens
        if let cost = entry.costUSD {
            self.costSum += cost
            self.hasCost = true
        }
        self.mergeProjectIdentity(from: identity, fallbackEntry: entry)
        if let model = entry.model, !model.isEmpty {
            self.modelSet.insert(model)
        }
    }

    var totals: UsageLedgerTotals {
        UsageLedgerTotals(
            inputTokens: self.inputTokens,
            outputTokens: self.outputTokens,
            cacheCreationTokens: self.cacheCreationTokens,
            cacheReadTokens: self.cacheReadTokens,
            costUSD: self.hasCost ? self.costSum : nil)
    }

    var models: [String] {
        self.modelSet.sorted()
    }

    private mutating func mergeProjectIdentity(from identity: UsageLedgerProjectIdentity?, fallbackEntry: UsageLedgerEntry) {
        if let key = identity?.key, self.projectKey == nil {
            self.projectKey = key
        }

        if self.projectID == nil {
            let preferredID = identity?.projectID?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let preferredID, !preferredID.isEmpty {
                self.projectID = preferredID
            } else if let fallbackID = fallbackEntry.projectID?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !fallbackID.isEmpty
            {
                self.projectID = fallbackID
            }
        }

        let fallbackName = fallbackEntry.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateName = identity?.displayName ?? ((fallbackName?.isEmpty ?? true) ? nil : fallbackName)
        let candidateConfidence = identity?.confidence ?? (candidateName == nil ? .none : .high)
        let candidateSource = identity?.source ?? (candidateName == nil ? .unknown : .projectName)
        let candidateProvenance = identity?.provenance

        guard let candidateName, !candidateName.isEmpty else { return }
        let shouldAdopt: Bool
        if self.projectName == nil {
            shouldAdopt = true
        } else if candidateConfidence.rank > self.projectNameConfidence.rank {
            shouldAdopt = true
        } else if candidateConfidence.rank == self.projectNameConfidence.rank,
                  candidateName.count > (self.projectName?.count ?? 0)
        {
            shouldAdopt = true
        } else {
            shouldAdopt = false
        }

        if shouldAdopt {
            self.projectName = candidateName
            self.projectNameConfidence = candidateConfidence
            self.projectNameSource = candidateSource
            self.projectNameProvenance = candidateProvenance
        }
    }

    func tokensPerMinute(since start: Date, now: Date) -> Double? {
        let elapsed = now.timeIntervalSince(start)
        guard elapsed > 1 else { return nil }
        let minutes = elapsed / 60
        guard minutes > 0 else { return nil }
        return Double(self.inputTokens + self.outputTokens) / minutes
    }

    func projectedTotalTokens(since start: Date, now: Date, duration: TimeInterval) -> Int? {
        guard let tpm = self.tokensPerMinute(since: start, now: now) else { return nil }
        let projected = tpm * (duration / 60)
        return Int(projected.rounded())
    }
}

private struct SpendForecastAccumulator {
    private(set) var observedCostUSD: Double = 0
    private(set) var observedDayStarts: Set<Date> = []
    private(set) var dailyCostByDayStart: [Date: Double] = [:]
    private(set) var projectID: String?
    private(set) var projectName: String?
    private(set) var projectNameConfidence: UsageLedgerProjectNameConfidence = .none
    private(set) var projectNameSource: UsageLedgerProjectNameSource = .unknown
    private(set) var projectNameProvenance: String?

    mutating func consume(
        _ entry: UsageLedgerEntry,
        costUSD: Double,
        dayStart: Date,
        identity: UsageLedgerProjectIdentity?)
    {
        self.observedCostUSD += costUSD
        self.observedDayStarts.insert(dayStart)
        self.dailyCostByDayStart[dayStart, default: 0] += costUSD
        self.mergeProjectIdentity(from: identity, fallbackEntry: entry)
    }

    func forecast(
        provider: UsageProvider,
        projectKey: String?,
        projectionDays: Int) -> UsageLedgerSpendForecast?
    {
        guard !self.observedDayStarts.isEmpty else { return nil }
        guard self.observedCostUSD.isFinite else { return nil }
        let observedDays = self.observedDayStarts.count
        guard observedDays > 0 else { return nil }
        let averageDailyCostUSD = self.observedCostUSD / Double(observedDays)
        guard averageDailyCostUSD.isFinite else { return nil }
        let projected30DayCostUSD = averageDailyCostUSD * Double(projectionDays)
        guard projected30DayCostUSD.isFinite else { return nil }
        let projectedQuantiles = self.projectedCostQuantiles(projectionDays: projectionDays)

        return UsageLedgerSpendForecast(
            provider: provider,
            projectKey: projectKey,
            projectID: projectKey == nil ? nil : self.projectID,
            projectName: projectKey == nil ? nil : self.projectName,
            observedDays: observedDays,
            observedCostUSD: self.observedCostUSD,
            averageDailyCostUSD: averageDailyCostUSD,
            projected30DayCostUSD: projected30DayCostUSD,
            projectedCostP50USD: projectedQuantiles?.p50,
            projectedCostP80USD: projectedQuantiles?.p80,
            projectedCostP95USD: projectedQuantiles?.p95,
            projectionDays: projectionDays)
    }

    private func projectedCostQuantiles(projectionDays: Int) -> (p50: Double, p80: Double, p95: Double)? {
        guard projectionDays > 0 else { return nil }
        let dailyCosts = self.dailyCostByDayStart.values
            .filter(\.isFinite)
            .sorted()
        guard dailyCosts.count >= 3 else { return nil }
        let projectionScale = Double(projectionDays)
        let p50 = self.percentile(sortedValues: dailyCosts, quantile: 0.50) * projectionScale
        let p80 = self.percentile(sortedValues: dailyCosts, quantile: 0.80) * projectionScale
        let p95 = self.percentile(sortedValues: dailyCosts, quantile: 0.95) * projectionScale
        guard p50.isFinite, p80.isFinite, p95.isFinite else { return nil }
        return (p50: p50, p80: p80, p95: p95)
    }

    private func percentile(sortedValues: [Double], quantile: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        guard sortedValues.count > 1 else { return sortedValues[0] }
        let q = min(max(quantile, 0), 1)
        let position = q * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }
        let lowerValue = sortedValues[lowerIndex]
        let upperValue = sortedValues[upperIndex]
        let weight = position - Double(lowerIndex)
        return lowerValue + ((upperValue - lowerValue) * weight)
    }

    private mutating func mergeProjectIdentity(from identity: UsageLedgerProjectIdentity?, fallbackEntry: UsageLedgerEntry) {
        if self.projectID == nil {
            let preferredID = identity?.projectID?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let preferredID, !preferredID.isEmpty {
                self.projectID = preferredID
            } else if let fallbackID = fallbackEntry.projectID?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !fallbackID.isEmpty
            {
                self.projectID = fallbackID
            }
        }

        let fallbackName = fallbackEntry.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateName = identity?.displayName ?? ((fallbackName?.isEmpty ?? true) ? nil : fallbackName)
        let candidateConfidence = identity?.confidence ?? (candidateName == nil ? .none : .high)
        let candidateSource = identity?.source ?? (candidateName == nil ? .unknown : .projectName)
        let candidateProvenance = identity?.provenance

        guard let candidateName, !candidateName.isEmpty else { return }
        let shouldAdopt: Bool
        if self.projectName == nil {
            shouldAdopt = true
        } else if candidateConfidence.rank > self.projectNameConfidence.rank {
            shouldAdopt = true
        } else if candidateConfidence.rank == self.projectNameConfidence.rank,
                  candidateName.count > (self.projectName?.count ?? 0)
        {
            shouldAdopt = true
        } else {
            shouldAdopt = false
        }

        if shouldAdopt {
            self.projectName = candidateName
            self.projectNameConfidence = candidateConfidence
            self.projectNameSource = candidateSource
            self.projectNameProvenance = candidateProvenance
        }
    }
}

private struct SessionAccumulator {
    private(set) var firstActivity: Date?
    private(set) var lastActivity: Date?
    private var aggregate = AggregateAccumulator()
    private var modelSet: Set<String> = []
    private var versionSet: Set<String> = []

    mutating func consume(_ entry: UsageLedgerEntry) {
        if let first = self.firstActivity {
            if entry.timestamp < first { self.firstActivity = entry.timestamp }
        } else {
            self.firstActivity = entry.timestamp
        }
        if let last = self.lastActivity {
            if entry.timestamp > last { self.lastActivity = entry.timestamp }
        } else {
            self.lastActivity = entry.timestamp
        }
        self.aggregate.consume(entry)
        if let model = entry.model, !model.isEmpty {
            self.modelSet.insert(model)
        }
        if let version = entry.version, !version.isEmpty {
            self.versionSet.insert(version)
        }
    }

    var totals: UsageLedgerTotals { self.aggregate.totals }
    var models: [String] { self.modelSet.sorted() }
    var versions: [String] { self.versionSet.sorted() }
}
