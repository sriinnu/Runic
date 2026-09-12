import Foundation

/// The burn story for one quota window: the actual curve of readings inside
/// the current cycle, the even-burn budget line from window start to reset,
/// how far ahead or behind budget we are now, and where the recent rate
/// lands us.
public struct QuotaBurnSeries: Sendable, Equatable {
    /// One projection horizon: the rate observed over the last `horizon`
    /// seconds, and where it runs the window out. `runsOutAt` is nil when
    /// that rate lasts to the reset (or the rate is zero or negative).
    public struct Projection: Sendable, Equatable {
        public let horizon: TimeInterval
        public let ratePercentPerHour: Double
        public let runsOutAt: Date?
        /// Seconds of history the rate was measured over — shorter than
        /// `horizon` when the cycle is young.
        public let measuredSpan: TimeInterval

        public var lastsToReset: Bool {
            self.runsOutAt == nil
        }
    }

    public static let projectionHorizons: [TimeInterval] = [3600, 6 * 3600]
    /// A projection needs at least this much history to say anything.
    public static let minimumProjectionSpan: TimeInterval = 15 * 60

    public let windowStart: Date
    public let resetsAt: Date
    public let now: Date
    /// Readings inside the cycle, oldest first, ending with the live reading.
    public let points: [QuotaSample]
    public let currentUsedPercent: Double
    public let projections: [Projection]

    public var windowDuration: TimeInterval {
        self.resetsAt.timeIntervalSince(self.windowStart)
    }

    /// Where the even-burn line sits at `date`: 0 at window start, 100 at reset.
    public func budgetPercent(at date: Date) -> Double {
        guard self.windowDuration > 0 else { return 0 }
        let fraction = date.timeIntervalSince(self.windowStart) / self.windowDuration
        return min(100, max(0, fraction * 100))
    }

    /// Actual minus budget right now: positive = ahead of budget (burning
    /// faster than even), negative = under budget.
    public var paceDeltaPercent: Double {
        self.currentUsedPercent - self.budgetPercent(at: self.now)
    }

    /// The moment the budget line reaches the current percentage — "you are
    /// where an even burn would be at …". Ahead of budget means it's in the
    /// future; behind means the past.
    public var budgetMomentForCurrent: Date {
        self.windowStart.addingTimeInterval(self.windowDuration * self.currentUsedPercent / 100)
    }

    public var earliestRunOut: Projection? {
        self.projections
            .filter { $0.runsOutAt != nil }
            .min { ($0.runsOutAt ?? .distantFuture) < ($1.runsOutAt ?? .distantFuture) }
    }

    /// Build the series for `window` from its recorded samples. Returns nil
    /// when the window has no reset moment or fewer than two usable points.
    public static func make(
        samples: [QuotaSample],
        window: RateWindow,
        now: Date = .init(),
        defaultWindowMinutes: Int? = nil) -> QuotaBurnSeries?
    {
        guard let resetsAt = window.resetsAt, resetsAt > now else { return nil }
        let minutes = window.windowMinutes ?? defaultWindowMinutes
        let windowStart: Date
        if let minutes, minutes > 0 {
            windowStart = resetsAt.addingTimeInterval(-TimeInterval(minutes) * 60)
        } else {
            // Unknown length: the cycle starts at the earliest reading that
            // still belongs to this reset, capped at a week back.
            let sameCycle = samples.filter { $0.resetsAt == nil || $0.resetsAt == resetsAt }
            windowStart = max(sameCycle.first?.at ?? now, now.addingTimeInterval(-7 * 86400))
        }

        // Keep readings from this cycle only: inside the window, not from a
        // previous reset, and not after a visible reset drop.
        var points: [QuotaSample] = []
        for sample in samples where sample.at >= windowStart && sample.at <= now {
            if let sampleReset = sample.resetsAt, abs(sampleReset.timeIntervalSince(resetsAt)) > 120 {
                continue
            }
            if let last = points.last, sample.usedPercent + 25 < last.usedPercent {
                // The meter fell off a cliff: that was a reset. Start over.
                points.removeAll()
            }
            points.append(sample)
        }
        let live = QuotaSample(
            at: now,
            usedPercent: min(100, max(0, window.usedPercent)),
            resetsAt: resetsAt,
            windowMinutes: window.windowMinutes)
        if let last = points.last, now.timeIntervalSince(last.at) < 1 {
            points[points.count - 1] = live
        } else {
            points.append(live)
        }
        guard points.count >= 2 else { return nil }

        let projections = Self.projectionHorizons.map { horizon in
            Self.projection(horizon: horizon, points: points, now: now, resetsAt: resetsAt)
        }
        return QuotaBurnSeries(
            windowStart: windowStart,
            resetsAt: resetsAt,
            now: now,
            points: points,
            currentUsedPercent: live.usedPercent,
            projections: projections)
    }

    private static func projection(
        horizon: TimeInterval,
        points: [QuotaSample],
        now: Date,
        resetsAt: Date) -> Projection
    {
        let current = points[points.count - 1]
        let target = now.addingTimeInterval(-horizon)
        // Baseline: the last reading at or before the horizon start, else the
        // oldest reading we have (a young cycle measures over what exists).
        let baseline = points.last(where: { $0.at <= target && $0.at < current.at }) ?? points[0]
        let span = current.at.timeIntervalSince(baseline.at)
        guard span >= Self.minimumProjectionSpan else {
            return Projection(horizon: horizon, ratePercentPerHour: 0, runsOutAt: nil, measuredSpan: span)
        }
        let rate = (current.usedPercent - baseline.usedPercent) / (span / 3600)
        guard rate > 0.01 else {
            return Projection(horizon: horizon, ratePercentPerHour: max(0, rate), runsOutAt: nil, measuredSpan: span)
        }
        let hoursLeft = (100 - current.usedPercent) / rate
        let runsOut = now.addingTimeInterval(hoursLeft * 3600)
        return Projection(
            horizon: horizon,
            ratePercentPerHour: rate,
            runsOutAt: runsOut < resetsAt ? runsOut : nil,
            measuredSpan: span)
    }
}
