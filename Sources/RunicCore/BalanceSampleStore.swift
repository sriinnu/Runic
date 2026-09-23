import Foundation

/// One reading of a provider's prepaid balance.
public struct BalanceSample: Codable, Sendable, Equatable {
    public let at: Date
    public let available: Double
    public let currency: String?

    public init(at: Date, available: Double, currency: String?) {
        self.at = at
        self.available = available
        self.currency = currency
    }
}

/// Append-only balance readings per provider, one JSONL file each under
/// Application Support (`Runic/balance-samples`). Spend is the sum of the drops
/// between readings, so every change matters; an unchanged balance is only
/// re-recorded every `heartbeat` to keep coverage honest ("tracked since").
/// `memoryOnly` keeps screenshot renders and tests off the disk.
public final class BalanceSampleStore: @unchecked Sendable {
    public static let shared = BalanceSampleStore()

    /// Long enough to cover a whole calendar month plus the trailing week.
    public static let retention: TimeInterval = 62 * 86400
    static let heartbeat: TimeInterval = 30 * 60
    private static let rewriteThreshold = 4000

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.sriinnu.runic.balance-samples", qos: .utility)
    private let directory: URL?
    private var cache: [UsageProvider: [BalanceSample]] = [:]
    private var loaded: Set<UsageProvider> = []
    private var appendedSinceRewrite: [UsageProvider: Int] = [:]

    public var memoryOnly: Bool

    public init(directory: URL? = nil, memoryOnly: Bool = false) {
        self.directory = directory ?? Self.defaultDirectory()
        self.memoryOnly = memoryOnly
    }

    public func record(provider: UsageProvider, balance: ProviderBalance, at date: Date = .init()) {
        self.record(
            provider: provider,
            sample: BalanceSample(at: date, available: balance.available, currency: balance.currency))
    }

    public func record(provider: UsageProvider, sample: BalanceSample) {
        self.lock.lock()
        self.loadIfNeededLocked(provider)
        if let last = self.cache[provider]?.last {
            let unchanged = abs(last.available - sample.available) < 0.000_001 && last.currency == sample.currency
            if sample.at < last.at || (unchanged && sample.at.timeIntervalSince(last.at) < Self.heartbeat) {
                self.lock.unlock()
                return
            }
        }
        self.cache[provider, default: []].append(sample)
        let appended = (self.appendedSinceRewrite[provider] ?? 0) + 1
        self.appendedSinceRewrite[provider] = appended
        let needsRewrite = appended >= Self.rewriteThreshold
        if needsRewrite { self.appendedSinceRewrite[provider] = 0 }
        let rewriteSnapshot = needsRewrite ? self.cache[provider] : nil
        self.lock.unlock()

        guard !self.memoryOnly, let url = self.fileURL(for: provider) else { return }
        self.queue.async {
            if let rewriteSnapshot {
                Self.rewrite(rewriteSnapshot, to: url)
            } else {
                Self.append(sample, to: url)
            }
        }
    }

    /// Readings oldest first.
    public func samples(provider: UsageProvider) -> [BalanceSample] {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.loadIfNeededLocked(provider)
        return self.cache[provider] ?? []
    }

    // MARK: - Disk

    private func loadIfNeededLocked(_ provider: UsageProvider) {
        guard !self.loaded.contains(provider) else { return }
        self.loaded.insert(provider)
        guard !self.memoryOnly, let url = self.fileURL(for: provider),
              let data = try? Data(contentsOf: url), !data.isEmpty else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let cutoff = Date().addingTimeInterval(-Self.retention)
        let samples = data.split(separator: UInt8(ascii: "\n"))
            .compactMap { try? decoder.decode(BalanceSample.self, from: Data($0)) }
            .filter { $0.at >= cutoff }
            .sorted { $0.at < $1.at }
        self.cache[provider] = samples
    }

    private func fileURL(for provider: UsageProvider) -> URL? {
        self.directory?.appendingPathComponent("\(provider.rawValue).jsonl")
    }

    private static func append(_ sample: BalanceSample, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard var data = try? encoder.encode(sample) else { return }
        data.append(UInt8(ascii: "\n"))
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func rewrite(_ samples: [BalanceSample], to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let cutoff = Date().addingTimeInterval(-Self.retention)
        var out = Data()
        for sample in samples where sample.at >= cutoff {
            guard let data = try? encoder.encode(sample) else { continue }
            out.append(data)
            out.append(UInt8(ascii: "\n"))
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? out.write(to: url, options: .atomic)
    }

    private static func defaultDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Runic/balance-samples", isDirectory: true)
    }
}

/// Spend and runway derived from balance readings.
///
/// Every drop between consecutive readings is spend, spread evenly over the
/// gap between them; every rise is a top-up and is excluded. A top-up and spend
/// landing between the same two readings net out, so spend is a floor, not an
/// invoice. Totals only cover time Runic was recording (`trackedSince`); the
/// `...IsPartial` flags say when that started after the period began.
public struct BalanceSpendSummary: Sendable, Equatable {
    public let currency: String?
    public let spentToday: Double
    public let spentThisMonth: Double
    public let toppedUpThisMonth: Double
    /// Average spend per day over the trailing week of coverage; nil until there
    /// are `minimumRateCoverage` of readings with some spend.
    public let dailyBurnRate: Double?
    /// Days the current balance lasts at `dailyBurnRate`.
    public let runwayDays: Double?
    public let trackedSince: Date
    public let todayIsPartial: Bool
    public let monthIsPartial: Bool
    /// Set when totals are provider-reported and narrower than the account.
    public var scope: String?
    /// True when derived from balance readings, false when the provider
    /// reported the totals itself. Shown as "Estimated" / "Official".
    public var isEstimated = true
    /// Whether a reading since the start of today (this month) exists. Without
    /// one, today's figure is unknown, not zero, and the card says so.
    public var todayKnown = true
    public var monthKnown = true
    /// Time of the newest reading behind the figures (derived summaries only).
    public var latestReadingAt: Date?

    /// Totals the provider reports itself (exact, whole periods, no tracking gap).
    /// The burn rate still prefers recorded readings; without enough of them it
    /// falls back to month-to-date spend over the days elapsed.
    public static func make(
        reported: ProviderBalance.ReportedSpend,
        balance: ProviderBalance,
        samples: [BalanceSample],
        now: Date = Date(),
        calendar: Calendar = .current) -> BalanceSpendSummary
    {
        let derived = self.make(samples: samples, now: now, calendar: calendar)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let monthStart = utc.dateInterval(of: .month, for: now)?.start ?? now
        let elapsedDays = now.timeIntervalSince(monthStart) / 86400
        let rate = derived?.dailyBurnRate
            ?? (elapsedDays >= 1 && reported.thisMonth > 0 ? reported.thisMonth / elapsedDays : nil)
        var summary = BalanceSpendSummary(
            currency: balance.currency,
            spentToday: reported.today,
            spentThisMonth: reported.thisMonth,
            toppedUpThisMonth: derived?.toppedUpThisMonth ?? 0,
            dailyBurnRate: rate,
            runwayDays: rate.map { max(0, balance.available) / $0 },
            trackedSince: samples.first?.at ?? now,
            todayIsPartial: false,
            monthIsPartial: false)
        summary.scope = reported.scope
        summary.isEstimated = false
        return summary
    }

    static let rateWindow: TimeInterval = 7 * 86400
    static let minimumRateCoverage: TimeInterval = 12 * 3600

    public static func make(
        samples: [BalanceSample],
        now: Date = Date(),
        calendar: Calendar = .current) -> BalanceSpendSummary?
    {
        // Only the latest currency's run of readings is comparable.
        guard let latest = samples.last else { return nil }
        var run: [BalanceSample] = []
        for sample in samples.reversed() {
            guard sample.currency == latest.currency else { break }
            run.append(sample)
        }
        run.reverse()
        guard let first = run.first, run.count >= 2 else { return nil }

        let dayStart = calendar.startOfDay(for: now)
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? dayStart
        let rateStart = max(first.at, now.addingTimeInterval(-Self.rateWindow))

        var today = 0.0
        var month = 0.0
        var toppedUp = 0.0
        var rateSpend = 0.0
        for (previous, current) in zip(run, run.dropFirst()) {
            let delta = previous.available - current.available
            if delta > 0.000_001 {
                // The drop happened somewhere between the two readings, so
                // spread it over that gap: a gap across midnight splits
                // between yesterday and today instead of landing on today.
                today += delta * Self.share(from: previous.at, to: current.at, after: dayStart)
                month += delta * Self.share(from: previous.at, to: current.at, after: monthStart)
                rateSpend += delta * Self.share(from: previous.at, to: current.at, after: rateStart)
            } else if delta < -0.000_001, current.at >= monthStart {
                // A top-up is a single event; it lands when it was seen.
                toppedUp += -delta
            }
        }

        let coverage = now.timeIntervalSince(rateStart)
        let rate: Double? = coverage >= Self.minimumRateCoverage && rateSpend > 0
            ? rateSpend / (coverage / 86400)
            : nil
        let runway = rate.map { max(0, latest.available) / $0 }

        var summary = BalanceSpendSummary(
            currency: latest.currency,
            spentToday: today,
            spentThisMonth: month,
            toppedUpThisMonth: toppedUp,
            dailyBurnRate: rate,
            runwayDays: runway,
            trackedSince: first.at,
            todayIsPartial: first.at > dayStart,
            monthIsPartial: first.at > monthStart)
        summary.latestReadingAt = latest.at
        summary.todayKnown = latest.at >= dayStart
        summary.monthKnown = latest.at >= monthStart
        return summary
    }

    /// Fraction of the interval `from...to` that falls at or after `start`.
    static func share(from: Date, to: Date, after start: Date) -> Double {
        let length = to.timeIntervalSince(from)
        guard length > 0 else { return to >= start ? 1 : 0 }
        let inside = to.timeIntervalSince(max(from, start))
        return min(1, max(0, inside / length))
    }
}
