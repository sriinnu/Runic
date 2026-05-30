import Foundation

public enum CostUsageError: LocalizedError, Sendable {
    case unsupportedProvider(UsageProvider)
    case timedOut(seconds: Int)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedProvider(provider):
            return "Cost summary is not supported for \(provider.rawValue)."
        case let .timedOut(seconds):
            if seconds >= 60, seconds % 60 == 0 {
                return "Cost refresh timed out after \(seconds / 60)m."
            }
            return "Cost refresh timed out after \(seconds)s."
        }
    }
}

public enum CostUsageLoadMode: Sendable, Equatable {
    case refresh
    case rebuildHistory
}

public struct CostUsageFetcher: Sendable {
    public init() {}

    public func loadTokenSnapshot(
        provider: UsageProvider,
        now: Date = Date(),
        mode: CostUsageLoadMode = .refresh) async throws -> CostUsageTokenSnapshot
    {
        guard provider == .codex || provider == .claude else {
            throw CostUsageError.unsupportedProvider(provider)
        }

        let until = now
        // Rolling window: last 30 days (inclusive). Use -29 for inclusive boundaries.
        let since = Calendar.current.date(byAdding: .day, value: -29, to: now) ?? now

        let daily = try await Self.loadRelayBackedDailyReport(
            provider: provider,
            since: since,
            until: until,
            now: now,
            mode: mode)
        try Task.checkCancellation()

        return Self.tokenSnapshot(from: daily, now: now)
    }

    @available(*, deprecated, message: "Cost usage refreshes relay-backed data by default. Use mode: .rebuildHistory for explicit historical repair.")
    public func loadTokenSnapshot(
        provider: UsageProvider,
        now: Date = Date(),
        forceRefresh _: Bool) async throws -> CostUsageTokenSnapshot
    {
        try await self.loadTokenSnapshot(provider: provider, now: now, mode: .refresh)
    }

    private static func loadRelayBackedDailyReport(
        provider: UsageProvider,
        since: Date,
        until: Date,
        now: Date,
        mode: CostUsageLoadMode) async throws -> CostUsageDailyReport
    {
        await LedgerCache.shared.migrateLegacyRelaySeedsIfNeeded(
            provider: provider.rawValue,
            scanDate: now,
            todayKey: LedgerCache.dayKey(for: now))

        let scanMode: UsageLedgerLogScanMode = switch mode {
        case .refresh:
            .refreshToday
        case .rebuildHistory:
            .rebuildHistory(maxAgeDays: 30)
        }
        let source: (any UsageLedgerSource)? = switch provider {
        case .codex:
            CodexUsageLogSource(maxAgeDays: 30, now: now, scanMode: scanMode)
        case .claude:
            ClaudeUsageLogSource(maxAgeDays: 30, now: now, scanMode: scanMode)
        default:
            nil
        }

        if let source {
            do {
                _ = try await source.loadEntries()
            } catch {
                if mode == .rebuildHistory {
                    throw error
                }
                // A missing provider log directory should not discard Runic's
                // relay history. The caller will surface no-data only if the
                // relay-backed report is empty too.
            }
        }

        let cached = await LedgerCache.shared.loadCachedDailies(provider: provider.rawValue)
        return Self.dailyReport(
            from: cached?.dailies ?? [],
            provider: provider,
            since: since,
            until: until)
    }

    private static func dailyReport(
        from dailies: [CachedDaily],
        provider: UsageProvider,
        since: Date,
        until: Date) -> CostUsageDailyReport
    {
        let sinceKey = LedgerCache.dayKey(for: since)
        let untilKey = LedgerCache.dayKey(for: until)
        let entries = dailies
            .filter { $0.dayKey >= sinceKey && $0.dayKey <= untilKey }
            .sorted { $0.dayKey < $1.dayKey }
            .map { daily in
                CostUsageDailyReport.Entry(
                    date: daily.dayKey,
                    inputTokens: daily.inputTokens,
                    outputTokens: daily.outputTokens,
                    cacheReadTokens: daily.cacheReadTokens,
                    cacheCreationTokens: daily.cacheCreationTokens,
                    totalTokens: daily.totalTokens,
                    costUSD: daily.costUSD,
                    modelsUsed: daily.modelsUsed,
                    modelBreakdowns: nil)
            }

        guard !entries.isEmpty else {
            return CostUsageDailyReport(data: [], summary: nil)
        }

        let totalInput = entries.compactMap(\.inputTokens).reduce(0, +)
        let totalOutput = entries.compactMap(\.outputTokens).reduce(0, +)
        let totalCacheRead = entries.compactMap(\.cacheReadTokens).reduce(0, +)
        let totalCacheCreate = entries.compactMap(\.cacheCreationTokens).reduce(0, +)
        let totalTokens = entries.compactMap(\.totalTokens).reduce(0, +)
        let costs = entries.compactMap(\.costUSD)

        return CostUsageDailyReport(
            data: entries,
            summary: CostUsageDailyReport.Summary(
                totalInputTokens: totalInput,
                totalOutputTokens: totalOutput,
                cacheReadTokens: totalCacheRead,
                cacheCreationTokens: totalCacheCreate,
                totalTokens: totalTokens,
                totalCostUSD: costs.isEmpty ? nil : costs.reduce(0, +)))
    }

    static func tokenSnapshot(from daily: CostUsageDailyReport, now: Date) -> CostUsageTokenSnapshot {
        // Pick the most recent day; break ties by cost/tokens to keep a stable "session" row.
        let currentDay = daily.data.max { lhs, rhs in
            let lDate = CostUsageDateParser.parse(lhs.date) ?? .distantPast
            let rDate = CostUsageDateParser.parse(rhs.date) ?? .distantPast
            if lDate != rDate { return lDate < rDate }
            let lCost = lhs.costUSD ?? -1
            let rCost = rhs.costUSD ?? -1
            if lCost != rCost { return lCost < rCost }
            let lTokens = lhs.totalTokens ?? -1
            let rTokens = rhs.totalTokens ?? -1
            if lTokens != rTokens { return lTokens < rTokens }
            return lhs.date < rhs.date
        }
        // Prefer summary totals when present; fall back to summing daily entries.
        let totalFromSummary = daily.summary?.totalCostUSD
        let totalFromEntries = daily.data.compactMap(\.costUSD).reduce(0, +)
        let last30DaysCostUSD = totalFromSummary ?? (totalFromEntries > 0 ? totalFromEntries : nil)
        let totalTokensFromSummary = daily.summary?.totalTokens
        let totalTokensFromEntries = daily.data.compactMap(\.totalTokens).reduce(0, +)
        let last30DaysTokens = totalTokensFromSummary ?? (totalTokensFromEntries > 0 ? totalTokensFromEntries : nil)

        return CostUsageTokenSnapshot(
            sessionTokens: currentDay?.totalTokens,
            sessionCostUSD: currentDay?.costUSD,
            last30DaysTokens: last30DaysTokens,
            last30DaysCostUSD: last30DaysCostUSD,
            daily: daily.data,
            updatedAt: now)
    }

    static func selectCurrentSession(from sessions: [CostUsageSessionReport.Entry])
        -> CostUsageSessionReport.Entry?
    {
        if sessions.isEmpty { return nil }
        return sessions.max { lhs, rhs in
            let lDate = CostUsageDateParser.parse(lhs.lastActivity) ?? .distantPast
            let rDate = CostUsageDateParser.parse(rhs.lastActivity) ?? .distantPast
            if lDate != rDate { return lDate < rDate }
            let lCost = lhs.costUSD ?? -1
            let rCost = rhs.costUSD ?? -1
            if lCost != rCost { return lCost < rCost }
            let lTokens = lhs.totalTokens ?? -1
            let rTokens = rhs.totalTokens ?? -1
            if lTokens != rTokens { return lTokens < rTokens }
            return lhs.session < rhs.session
        }
    }

    static func selectMostRecentMonth(from months: [CostUsageMonthlyReport.Entry])
        -> CostUsageMonthlyReport.Entry?
    {
        if months.isEmpty { return nil }
        return months.max { lhs, rhs in
            let lDate = CostUsageDateParser.parseMonth(lhs.month) ?? .distantPast
            let rDate = CostUsageDateParser.parseMonth(rhs.month) ?? .distantPast
            if lDate != rDate { return lDate < rDate }
            let lCost = lhs.costUSD ?? -1
            let rCost = rhs.costUSD ?? -1
            if lCost != rCost { return lCost < rCost }
            let lTokens = lhs.totalTokens ?? -1
            let rTokens = rhs.totalTokens ?? -1
            if lTokens != rTokens { return lTokens < rTokens }
            return lhs.month < rhs.month
        }
    }
}
