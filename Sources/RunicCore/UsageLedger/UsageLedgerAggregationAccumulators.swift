import Foundation

struct AggregateAccumulator {
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
    private var tokenProvenances: [MetricProvenance?] = []
    private var costProvenances: [MetricProvenance?] = []

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
        self.tokenProvenances.append(entry.tokenProvenance)
        if let cost = entry.costUSD {
            self.costSum += cost
            self.hasCost = true
            self.costProvenances.append(entry.costProvenance)
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
            costUSD: self.hasCost ? self.costSum : nil,
            tokenProvenance: MetricProvenance.combined(self.tokenProvenances),
            costProvenance: self.hasCost ? MetricProvenance.combined(self.costProvenances) : nil)
    }

    var models: [String] {
        self.modelSet.sorted()
    }

    private mutating func mergeProjectIdentity(
        from identity: UsageLedgerProjectIdentity?,
        fallbackEntry: UsageLedgerEntry)
    {
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
        let shouldAdopt = if self.projectName == nil {
            true
        } else if candidateConfidence.rank > self.projectNameConfidence.rank {
            true
        } else if candidateConfidence.rank == self.projectNameConfidence.rank,
                  candidateName.count > (self.projectName?.count ?? 0)
        {
            true
        } else {
            false
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

struct SpendForecastAccumulator {
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
        projectionDays: Int,
        todayStart: Date? = nil,
        calendar: Calendar = .current) -> UsageLedgerSpendForecast?
    {
        guard !self.observedDayStarts.isEmpty else { return nil }
        guard self.observedCostUSD.isFinite else { return nil }
        let observedDays = self.observedDayStarts.count
        guard observedDays > 0 else { return nil }

        // The projection uses a CALENDAR-day average, not an active-day average:
        // dividing by active days made a weekend-only user at $50/day across 8
        // active days project ~$1,500/30d instead of the true ~$430, tripping
        // false budget-breach alerts. Idle days count as $0, so the denominator
        // is the span of complete calendar days from the first observed day
        // through yesterday. Today's partial day is excluded from both sides of
        // the division (it would bias the rate down in the morning); when today
        // is the only observed day it's all we have, so project it as a full day.
        var completedCostUSD = self.observedCostUSD
        var spanDays = 1
        let firstDay = self.observedDayStarts.min() ?? .distantFuture
        if let todayStart, firstDay < todayStart {
            completedCostUSD -= self.dailyCostByDayStart[todayStart] ?? 0
            let daysThroughYesterday = calendar.dateComponents([.day], from: firstDay, to: todayStart).day ?? 1
            spanDays = max(1, daysThroughYesterday)
        } else if todayStart == nil, let lastDay = self.observedDayStarts.max() {
            // No reference date available: span the observed days themselves.
            let span = calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0
            spanDays = max(1, span + 1)
        }
        let averageDailyCostUSD = completedCostUSD / Double(spanDays)
        guard averageDailyCostUSD.isFinite else { return nil }
        let projected30DayCostUSD = averageDailyCostUSD * Double(projectionDays)
        guard projected30DayCostUSD.isFinite else { return nil }
        let projectedQuantiles = self.projectedCostQuantiles(
            projectionDays: projectionDays,
            todayStart: todayStart,
            calendar: calendar)

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

    private func projectedCostQuantiles(
        projectionDays: Int,
        todayStart: Date?,
        calendar: Calendar) -> (p50: Double, p80: Double, p95: Double)?
    {
        guard projectionDays > 0 else { return nil }
        // Quantiles share the mean's CALENDAR-day basis: idle days in the
        // observed span are real $0 days and enter the sample set as $0.
        // Sampling only active days made a weekend-only $50/day user project
        // P50 ≈ $1,500/30d while the (already-fixed) mean said ~$430. Today's
        // partial day is excluded exactly as it is from the mean. At least 3
        // ACTIVE days are still required before quantiles mean anything.
        var costsByDay = self.dailyCostByDayStart
        var spanDays = costsByDay.count
        let firstDay = self.observedDayStarts.min() ?? .distantFuture
        if let todayStart, firstDay < todayStart {
            costsByDay.removeValue(forKey: todayStart)
            let daysThroughYesterday = calendar.dateComponents([.day], from: firstDay, to: todayStart).day ?? 1
            spanDays = max(1, daysThroughYesterday)
        } else if todayStart == nil, let lastDay = self.observedDayStarts.max() {
            let span = calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0
            spanDays = max(1, span + 1)
        }
        let activeCosts = costsByDay.values.filter(\.isFinite)
        guard activeCosts.count >= 3 else { return nil }
        let idleDays = max(0, spanDays - activeCosts.count)
        let dailyCosts = (activeCosts + Array(repeating: 0.0, count: idleDays)).sorted()
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

    private mutating func mergeProjectIdentity(
        from identity: UsageLedgerProjectIdentity?,
        fallbackEntry: UsageLedgerEntry)
    {
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
        let shouldAdopt = if self.projectName == nil {
            true
        } else if candidateConfidence.rank > self.projectNameConfidence.rank {
            true
        } else if candidateConfidence.rank == self.projectNameConfidence.rank,
                  candidateName.count > (self.projectName?.count ?? 0)
        {
            true
        } else {
            false
        }

        if shouldAdopt {
            self.projectName = candidateName
            self.projectNameConfidence = candidateConfidence
            self.projectNameSource = candidateSource
            self.projectNameProvenance = candidateProvenance
        }
    }
}

struct SessionAccumulator {
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

    var totals: UsageLedgerTotals {
        self.aggregate.totals
    }

    var models: [String] {
        self.modelSet.sorted()
    }

    var versions: [String] {
        self.versionSet.sorted()
    }
}
