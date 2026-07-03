import Foundation
import RunicCore

struct UsageLedgerAnomalySummary: Hashable {
    enum Severity: Int, Hashable {
        case elevated = 1
        case high = 2
        case critical = 3

        var label: String {
            switch self {
            case .elevated: "Elevated"
            case .high: "High"
            case .critical: "Critical"
            }
        }
    }

    struct MetricAnomaly: Hashable {
        enum Metric: String, Hashable {
            case tokens
            case spend

            var label: String {
                switch self {
                case .tokens: "tokens"
                case .spend: "spend"
                }
            }
        }

        let metric: Metric
        let severity: Severity
        let todayValue: Double
        let baselineAverage: Double
        let percentIncrease: Double
    }

    struct Explanation: Hashable {
        struct Factor: Hashable {
            let metric: MetricAnomaly.Metric
            let severity: Severity
            let percentIncrease: Double
            let detail: String
        }

        let headline: String
        let details: [String]
        let primaryFactor: Factor
        let contributingFactors: [Factor]
    }

    let provider: UsageProvider
    let baselineDays: Int
    let tokenAnomaly: MetricAnomaly?
    let spendAnomaly: MetricAnomaly?

    var primaryAnomaly: MetricAnomaly? {
        [self.tokenAnomaly, self.spendAnomaly]
            .compactMap(\.self)
            .max { lhs, rhs in
                if lhs.severity != rhs.severity {
                    return lhs.severity.rawValue < rhs.severity.rawValue
                }
                return lhs.percentIncrease < rhs.percentIncrease
            }
    }

    func secondaryAnomaly(excluding metric: MetricAnomaly.Metric) -> MetricAnomaly? {
        let candidates = [self.tokenAnomaly, self.spendAnomaly].compactMap(\.self)
        guard !candidates.isEmpty else { return nil }
        return candidates.first { $0.metric != metric }
    }

    var explanation: Explanation? {
        guard let primary = self.primaryAnomaly else { return nil }
        let primaryFactor = self.factor(from: primary)
        var contributingFactors: [Explanation.Factor] = []
        if let secondary = self.secondaryAnomaly(excluding: primary.metric) {
            contributingFactors.append(self.factor(from: secondary))
        }
        return Explanation(
            headline: "Anomaly: \(primary.severity.label) \(primary.metric.label) spike",
            details: [primaryFactor.detail] + contributingFactors.map(\.detail),
            primaryFactor: primaryFactor,
            contributingFactors: contributingFactors)
    }

    private func factor(from anomaly: MetricAnomaly) -> Explanation.Factor {
        Explanation.Factor(
            metric: anomaly.metric,
            severity: anomaly.severity,
            percentIncrease: anomaly.percentIncrease,
            detail: self.metricDetail(for: anomaly))
    }

    private func metricDetail(for anomaly: MetricAnomaly) -> String {
        let percentText = "\(Int((anomaly.percentIncrease * 100).rounded()))%"
        let baselineLabel = "\(self.baselineDays)d avg"
        switch anomaly.metric {
        case .tokens:
            let todayTokens = UsageFormatter.tokenCountString(Int(anomaly.todayValue.rounded()))
            let baselineTokens = UsageFormatter.tokenCountString(Int(anomaly.baselineAverage.rounded()))
            return "Tokens \(todayTokens) today · +\(percentText) vs \(baselineLabel) \(baselineTokens)"
        case .spend:
            let todaySpend = UsageFormatter.usdString(anomaly.todayValue)
            let baselineSpend = UsageFormatter.usdString(anomaly.baselineAverage)
            return "Spend \(todaySpend) today · +\(percentText) vs \(baselineLabel) \(baselineSpend)"
        }
    }
}

enum UsageLedgerAnomalyDetector {
    private static let baselineDayCount = 7
    private static let minimumIncreaseThreshold = 0.60

    private struct DayUsageBucket {
        var tokens: Int = 0
        var costSum: Double = 0
        var hasCost: Bool = false

        mutating func consume(_ summary: UsageLedgerDailySummary) {
            self.tokens += summary.totals.totalTokens
            if let cost = summary.totals.costUSD {
                self.costSum += cost
                self.hasCost = true
            }
        }

        var costUSD: Double? {
            self.hasCost ? self.costSum : nil
        }
    }

    static func summaries(
        dailySummaries: [UsageLedgerDailySummary],
        now: Date,
        calendar: Calendar? = nil) -> [UsageProvider: UsageLedgerAnomalySummary]
    {
        var calendar = calendar ?? Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let todayStart = calendar.startOfDay(for: now)

        var bucketsByProvider: [UsageProvider: [Date: DayUsageBucket]] = [:]
        for summary in dailySummaries {
            let dayStart = calendar.startOfDay(for: summary.dayStart)
            bucketsByProvider[summary.provider, default: [:]][dayStart, default: DayUsageBucket()].consume(summary)
        }

        var summariesByProvider: [UsageProvider: UsageLedgerAnomalySummary] = [:]
        for (provider, dayBuckets) in bucketsByProvider {
            guard let todayBucket = dayBuckets[todayStart] else { continue }

            // The baseline needs a full week of tenure: a provider whose history
            // doesn't reach back over the whole window would get a zero-padded
            // (artificially low) baseline and fire on every new install.
            guard let baselineWindowStart = calendar.date(
                byAdding: .day,
                value: -self.baselineDayCount,
                to: todayStart),
                let earliestObservedDay = dayBuckets.keys.min(),
                earliestObservedDay <= baselineWindowStart
            else { continue }

            var baselineBuckets: [DayUsageBucket] = []
            baselineBuckets.reserveCapacity(self.baselineDayCount)
            for dayOffset in 1...self.baselineDayCount {
                guard let baselineDay = calendar.date(byAdding: .day, value: -dayOffset, to: todayStart) else {
                    baselineBuckets.removeAll(keepingCapacity: true)
                    break
                }
                if let bucket = dayBuckets[baselineDay] {
                    baselineBuckets.append(bucket)
                } else {
                    // A day with no bucket inside an established week is a real
                    // idle day: zero tokens, $0 spend. Bailing here used to
                    // silently disable anomaly detection for any provider with a
                    // single idle day in the trailing week.
                    var idleDay = DayUsageBucket()
                    idleDay.hasCost = true
                    baselineBuckets.append(idleDay)
                }
            }
            guard baselineBuckets.count == self.baselineDayCount else { continue }

            let tokenAnomaly = self.metricAnomaly(
                metric: .tokens,
                todayValue: Double(todayBucket.tokens),
                baselineValues: baselineBuckets.map { Double($0.tokens) })

            var spendAnomaly: UsageLedgerAnomalySummary.MetricAnomaly?
            if let todayCost = todayBucket.costUSD {
                spendAnomaly = self.metricAnomaly(
                    metric: .spend,
                    todayValue: todayCost,
                    baselineValues: baselineBuckets.compactMap(\.costUSD))
            }

            if tokenAnomaly != nil || spendAnomaly != nil {
                summariesByProvider[provider] = UsageLedgerAnomalySummary(
                    provider: provider,
                    baselineDays: self.baselineDayCount,
                    tokenAnomaly: tokenAnomaly,
                    spendAnomaly: spendAnomaly)
            }
        }

        return summariesByProvider
    }

    private static func metricAnomaly(
        metric: UsageLedgerAnomalySummary.MetricAnomaly.Metric,
        todayValue: Double,
        baselineValues: [Double]) -> UsageLedgerAnomalySummary.MetricAnomaly?
    {
        guard baselineValues.count == self.baselineDayCount else { return nil }
        guard baselineValues.allSatisfy(\.isFinite) else { return nil }
        guard todayValue.isFinite else { return nil }

        let baselineAverage = baselineValues.reduce(0, +) / Double(baselineValues.count)
        guard baselineAverage > 0 else { return nil }

        let increase = (todayValue - baselineAverage) / baselineAverage
        guard let severity = self.severity(for: increase) else { return nil }
        return UsageLedgerAnomalySummary.MetricAnomaly(
            metric: metric,
            severity: severity,
            todayValue: todayValue,
            baselineAverage: baselineAverage,
            percentIncrease: increase)
    }

    private static func severity(for increase: Double) -> UsageLedgerAnomalySummary.Severity? {
        guard increase.isFinite, increase >= self.minimumIncreaseThreshold else { return nil }
        if increase >= 2.0 { return .critical }
        if increase >= 1.0 { return .high }
        return .elevated
    }
}
