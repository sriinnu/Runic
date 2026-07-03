import Foundation

extension LedgerCache {
    func seedRelayFromLegacyCacheIfNeeded(provider: String, todayKey: String?, writtenAt: Date) {
        var seededDayKeys = self.materializedRelayState(provider: provider).touchedDayKeys

        if let ledger = self.loadCacheFileLedger(provider: provider) {
            let seedDailies = ledger.dailies.filter { daily in
                if seededDayKeys.contains(daily.dayKey) { return false }
                if let todayKey {
                    return daily.dayKey < todayKey
                }
                return true
            }
            if self.archiveDailySummariesAsRelayEvents(provider: provider, dailies: seedDailies, writtenAt: writtenAt) {
                seededDayKeys.formUnion(seedDailies.map(\.dayKey))
            }
        }

        // The legacy cost cache is frozen pre-relay data: once its historical
        // days have been seeded, re-reading it from disk on every merge forever
        // is pure waste. Stamp completion (in-memory + on disk) and skip.
        // Same-day legacy data excluded by `todayKey` is safe to leave behind:
        // today is always re-derived live from the raw provider logs.
        guard !self.isLegacyCostSeedStamped(provider: provider) else { return }
        guard let usageProvider = UsageProvider(rawValue: provider) else {
            self.stampLegacyCostSeed(provider: provider)
            return
        }
        let legacyCostDailies = self.dailiesFromLegacyCostUsageCache(provider: usageProvider)
        let seedCostDailies = legacyCostDailies.filter { daily in
            if seededDayKeys.contains(daily.dayKey) { return false }
            if let todayKey {
                return daily.dayKey < todayKey
            }
            return true
        }
        if self.archiveDailySummariesAsRelayEvents(provider: provider, dailies: seedCostDailies, writtenAt: writtenAt) {
            self.stampLegacyCostSeed(provider: provider)
        }
    }

    /// Whether the one-time legacy cost-cache seeding already completed.
    func isLegacyCostSeedStamped(provider: String) -> Bool {
        if self.legacyCostSeedStamped.contains(provider) { return true }
        if FileManager.default.fileExists(atPath: self.legacyCostSeedStampURL(provider: provider).path) {
            self.legacyCostSeedStamped.insert(provider)
            return true
        }
        return false
    }

    func stampLegacyCostSeed(provider: String) {
        self.legacyCostSeedStamped.insert(provider)
        try? Data().write(to: self.legacyCostSeedStampURL(provider: provider))
    }

    func legacyCostSeedStampURL(provider: String) -> URL {
        self.relayDir.appendingPathComponent("\(provider).legacy-seeded")
    }

    func dailiesFromLegacyCostUsageCache(provider: UsageProvider) -> [CachedDaily] {
        let cache = CostUsageCacheIO.load(provider: provider, cacheRoot: self.legacyCostCacheRoot)
        return cache.days.keys.sorted().compactMap { dayKey in
            guard let models = cache.days[dayKey], !models.isEmpty else { return nil }
            guard let daily = Self.dailyFromLegacyCostUsageModels(provider: provider, dayKey: dayKey, models: models)
            else {
                return nil
            }
            guard Self.isTrustedLegacyDaily(provider: provider.rawValue, daily: daily) else { return nil }
            return daily
        }
    }

    static func dailyFromLegacyCostUsageModels(
        provider: UsageProvider,
        dayKey: String,
        models: [String: [Int]])
        -> CachedDaily?
    {
        var input = 0
        var output = 0
        var cacheRead = 0
        var cacheCreate = 0
        var cost = 0.0
        var hasCost = false
        let modelNames = models.keys.sorted()

        for model in modelNames {
            let packed = models[model] ?? []
            switch provider {
            case .codex:
                let modelInput = packed[safe: 0] ?? 0
                let modelCacheRead = packed[safe: 1] ?? 0
                let modelOutput = packed[safe: 2] ?? 0
                input += modelInput
                cacheRead += modelCacheRead
                output += modelOutput
                if let modelCost = CostUsagePricing.codexCostUSD(
                    model: model,
                    inputTokens: modelInput,
                    cachedInputTokens: modelCacheRead,
                    outputTokens: modelOutput)
                {
                    cost += modelCost
                    hasCost = true
                }
            case .claude:
                let modelInput = packed[safe: 0] ?? 0
                let modelCacheRead = packed[safe: 1] ?? 0
                let modelCacheCreate = packed[safe: 2] ?? 0
                let modelOutput = packed[safe: 3] ?? 0
                let costNanos = packed[safe: 4] ?? 0
                input += modelInput
                cacheRead += modelCacheRead
                cacheCreate += modelCacheCreate
                output += modelOutput
                let modelCost = costNanos > 0
                    ? Double(costNanos) / 1_000_000_000.0
                    : CostUsagePricing.claudeCostUSD(
                        model: model,
                        inputTokens: modelInput,
                        cacheReadInputTokens: modelCacheRead,
                        cacheCreationInputTokens: modelCacheCreate,
                        outputTokens: modelOutput)
                if let modelCost {
                    cost += modelCost
                    hasCost = true
                }
            default:
                continue
            }
        }

        let totalTokens = input + output + cacheRead + cacheCreate
        guard totalTokens > 0 || hasCost else { return nil }
        return CachedDaily(
            dayKey: dayKey,
            inputTokens: input,
            outputTokens: output,
            cacheCreationTokens: cacheCreate,
            cacheReadTokens: cacheRead,
            costUSD: hasCost ? cost : nil,
            requestCount: max(1, modelNames.count),
            modelsUsed: modelNames)
    }

    static func isTrustedLegacyDaily(provider: String, daily: CachedDaily) -> Bool {
        guard provider == "codex" || provider == "claude" else { return true }
        if daily.totalTokens > maxTrustedLegacyDailyTokens { return false }
        if daily.requestCount > maxTrustedLegacyDailyRequests { return false }
        return true
    }

    func updateScanMetadata(
        _ ledger: inout CachedLedger,
        scanDate: Date,
        coveredMaxAgeDays: Int?)
    {
        ledger.lastScanDate = scanDate
        if let coveredMaxAgeDays {
            ledger.coveredMaxAgeDays = max(ledger.coveredMaxAgeDays ?? 0, coveredMaxAgeDays)
            ledger.lastFullScanDate = scanDate
        }
    }
}
