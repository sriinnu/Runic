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
        let projectID: String?
        let model: String
    }

    private struct ProjectKey: Hashable {
        let provider: UsageProvider
        let projectID: String?
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
            let key = ModelKey(
                provider: entry.provider,
                projectID: groupByProject ? entry.projectID : nil,
                model: model)
            buckets[key, default: AggregateAccumulator()].consume(entry)
        }

        return buckets.map { key, acc in
            UsageLedgerModelSummary(
                provider: key.provider,
                projectID: key.projectID,
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
            let key = ProjectKey(provider: entry.provider, projectID: entry.projectID)
            buckets[key, default: AggregateAccumulator()].consume(entry)
        }

        return buckets.map { key, acc in
            UsageLedgerProjectSummary(
                provider: key.provider,
                projectID: key.projectID,
                entryCount: acc.entryCount,
                totals: acc.totals,
                modelsUsed: acc.models)
        }
        .sorted { lhs, rhs in
            if lhs.totals.totalTokens != rhs.totals.totalTokens {
                return lhs.totals.totalTokens > rhs.totals.totalTokens
            }
            return (lhs.projectID ?? "") < (rhs.projectID ?? "")
        }
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
}

private struct AggregateAccumulator {
    private(set) var inputTokens: Int = 0
    private(set) var outputTokens: Int = 0
    private(set) var cacheCreationTokens: Int = 0
    private(set) var cacheReadTokens: Int = 0
    private(set) var costSum: Double = 0
    private(set) var hasCost: Bool = false
    private(set) var entryCount: Int = 0
    private var modelSet: Set<String> = []

    init() {}

    init(entries: [UsageLedgerEntry]) {
        for entry in entries {
            self.consume(entry)
        }
    }

    mutating func consume(_ entry: UsageLedgerEntry) {
        self.entryCount += 1
        self.inputTokens += entry.inputTokens
        self.outputTokens += entry.outputTokens
        self.cacheCreationTokens += entry.cacheCreationTokens
        self.cacheReadTokens += entry.cacheReadTokens
        if let cost = entry.costUSD {
            self.costSum += cost
            self.hasCost = true
        }
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
