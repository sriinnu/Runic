import Foundation
import RunicCore

extension UsageStore {
    var ledgerMaxAgeDays: Int {
        max(self.settings.ledgerMaxAgeDays, self.requestedLedgerMaxAgeDays ?? 0)
    }

    func ensureLedgerHistoryCovers(days: Int) {
        let requestedDays = max(1, days)
        guard requestedDays > self.ledgerMaxAgeDays else { return }
        self.requestedLedgerMaxAgeDays = requestedDays
        self.scheduleLedgerRefresh(force: true, inactiveProviders: [])
    }

    func scheduleLedgerRefresh(
        force: Bool,
        inactiveProviders: Set<UsageProvider>)
    {
        let now = Date()
        let scanDays = self.ledgerMaxAgeDays
        let sources = self.ledgerSources(now: now, inactiveProviders: inactiveProviders)
        let providers = sources.map(\.0)
        if providers.isEmpty { return }
        if !self.shouldStartLedgerRefresh(force: force, providers: providers, now: now) { return }
        if self.ledgerRefreshTask != nil { return }

        self.primeLedgerCacheIfNeeded(providers: providers, now: now)
        self.startLedgerRefreshTask(sources: sources, now: now, scanDays: scanDays)
    }

    private func shouldStartLedgerRefresh(
        force: Bool,
        providers: [UsageProvider],
        now: Date) -> Bool
    {
        guard !force else { return true }
        return providers.contains { provider in
            guard let last = self.ledgerUpdatedAt[provider] else { return true }
            return now.timeIntervalSince(last) >= self.ledgerRefreshTTL
        }
    }

    private func primeLedgerCacheIfNeeded(
        providers: [UsageProvider],
        now: Date)
    {
        let providersToCache = providers
            .filter { self.ledgerAllDailySummaries[$0] == nil || self.ledgerAllDailySummaries[$0]?.isEmpty == true }
        guard !providersToCache.isEmpty else { return }

        Task { [weak self] in
            let cache = LedgerCache.shared
            for provider in providersToCache {
                let providerKey = provider.rawValue
                guard let cached = await cache.loadCachedDailies(provider: providerKey) else { continue }
                let summaries = cached.dailies.compactMap { $0.toLedgerDailySummary(provider: provider) }
                guard !summaries.isEmpty else { continue }
                await self?.applyCachedLedgerSummaries(
                    summaries,
                    provider: provider,
                    now: now)
            }
        }
    }

    private func applyCachedLedgerSummaries(
        _ summaries: [UsageLedgerDailySummary],
        provider: UsageProvider,
        now: Date) async
    {
        await MainActor.run { [weak self] in
            guard let self else { return }
            let hasCachedSummaries = self.ledgerAllDailySummaries[provider]?.isEmpty == false
            guard !hasCachedSummaries else { return }
            self.ledgerAllDailySummaries[provider] = summaries

            let todayStart = Calendar.current.startOfDay(for: now)
            if self.ledgerDailySummaries[provider] == nil,
               let todaySummary = summaries.first(where: { $0.dayStart == todayStart })
            {
                self.ledgerDailySummaries[provider] = todaySummary
            }
        }
    }

    private func startLedgerRefreshTask(
        sources: [(UsageProvider, any UsageLedgerSource)],
        now: Date,
        scanDays: Int)
    {
        self.ledgerRefreshTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let result = await self.loadLedgerInsights(sources: sources, now: now, scanDays: scanDays)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.applyLedgerRefreshResult(result)
            }
            await self.recomputeQuotaGauges()
        }
    }

    private func applyLedgerRefreshResult(_ result: LedgerRefreshResult) {
        self.ledgerRefreshTask = nil
        // Apply every provider that produced data — not just the ones we queried
        // a source for. Models attributed OUT of another source's logs (qwen/glm/
        // kimi/deepseek calls routed through Claude Code) arrive via entry.provider
        // and land in the per-provider buckets even though they have no source of
        // their own; without unioning the data keys here, that usage would be
        // computed and then silently dropped. A provider the user never toggled
        // is switched on by that evidence; one the user explicitly disabled stays
        // off and accumulates nothing. Ledger data needs no live credential, so
        // gate on the saved toggle rather than on live-fetch availability.
        var providers = Set(result.providers)
        providers.formUnion(result.dailyByProvider.keys)
        providers.formUnion(result.modelBreakdownsByProvider.keys)
        for provider in providers {
            self.autoEnableProviderWithLedgerData(provider)
        }
        let assignments = Self.ledgerSlotAssignments(
            dataProviders: providers,
            hasData: { result.hasData(for: $0) },
            isEnabled: {
                self.settings.isProviderEnabledCached(provider: $0, metadataByProvider: self.providerMetadata)
            })
        for (slot, dataProvider) in assignments {
            self.applyLedgerRefreshResult(result, from: dataProvider, to: slot)
        }
        self.sendBudgetNotificationsIfNeeded()
        if self.ledgerMaxAgeDays > result.scanDays {
            self.scheduleLedgerRefresh(force: true, inactiveProviders: [])
        }
    }

    /// Which provider's ledger data each enabled slot displays (slot → data provider).
    ///
    /// Log-derived usage has no region: `kimi-k3` routed through Claude Code is
    /// the same model name on api.moonshot.cn and api.moonshot.ai, so it's
    /// attributed to the brand root (`.kimi`). A user who only tracks the China
    /// slot has the root switched off, which used to drop that usage entirely and
    /// leave the China card blank. When a brand's data provider is disabled, its
    /// data goes to the brand's enabled slot instead, unless that slot has usage
    /// of its own. Enabled providers always keep their own data.
    static func ledgerSlotAssignments(
        dataProviders: Set<UsageProvider>,
        hasData: (UsageProvider) -> Bool,
        isEnabled: (UsageProvider) -> Bool) -> [UsageProvider: UsageProvider]
    {
        var assignments: [UsageProvider: UsageProvider] = [:]
        for provider in dataProviders where isEnabled(provider) {
            assignments[provider] = provider
        }
        for provider in dataProviders.sorted(by: { $0.rawValue < $1.rawValue })
            where !isEnabled(provider) && hasData(provider)
        {
            guard let slot = provider.brandSlots.first(where: { $0 != provider && isEnabled($0) }),
                  !hasData(slot)
            else { continue }
            assignments[slot] = provider
        }
        return assignments
    }

    private func applyLedgerRefreshResult(
        _ result: LedgerRefreshResult,
        from dataProvider: UsageProvider,
        to provider: UsageProvider)
    {
        self.ledgerErrors[provider] = result.errorsByProvider[dataProvider]
        self.ledgerDailySummaries[provider] = result.dailyByProvider[dataProvider]
        self.ledgerAllDailySummaries.setNonEmpty(result.allDailySummariesByProvider[dataProvider], forKey: provider)
        self.ledgerHourlySummaries.setNonEmpty(result.hourlySummariesByProvider[dataProvider], forKey: provider)
        self.ledgerActiveBlocks[provider] = result.activeBlocksByProvider[dataProvider]
        self.ledgerTopModels[provider] = result.topModelsByProvider[dataProvider]
        self.ledgerTopProjects[provider] = result.topProjectsByProvider[dataProvider]
        self.ledgerModelBreakdowns[provider] = result.modelBreakdownsByProvider[dataProvider]
        self.ledgerProjectBreakdowns[provider] = result.projectBreakdownsByProvider[dataProvider]
        self.ledgerSpendForecasts[provider] = result.spendForecastsByProvider[dataProvider]
        self.ledgerProjectSpendForecasts[provider] = result.projectSpendForecastsByProvider[dataProvider]
        self.ledgerTopProjectSpendForecasts[provider] = result.topProjectSpendForecastsByProvider[dataProvider]
        self.ledgerAnomalies[provider] = result.anomaliesByProvider[dataProvider]
        self.ledgerCompactions[provider] = result.compactionsByProvider[dataProvider]

        if let lastActivity = result.lastActivityByProvider[dataProvider] {
            self.lastLedgerActivityAt[provider] = lastActivity
        }
        self.ledgerUpdatedAt[provider] = result.updatedAt
    }

    private func sendBudgetNotificationsIfNeeded() {
        guard self.settings.budgetNotificationsEnabled else { return }
        BudgetNotificationManager.shared.checkAndNotify(
            forecasts: self.ledgerProjectSpendForecasts,
            settings: self.settings)
    }

    struct ProviderHistoryMonthCacheEntry {
        let fetchedAt: Date
        let snapshot: ProviderHistoryMonthSnapshot
    }

    private func ledgerSources(
        now: Date,
        inactiveProviders: Set<UsageProvider>) -> [(UsageProvider, any UsageLedgerSource)]
    {
        let historySupport = UsageStoreProviderHistorySupport(
            configuredOTelLogPaths: self.settings.otelGenAILogPaths,
            environment: self.processEnvironment,
            maxScanDays: self.providerHistoryMaxScanDays)
        return UsageProvider.allCases.compactMap { provider -> (UsageProvider, any UsageLedgerSource)? in
            guard self.isEnabled(provider), !inactiveProviders.contains(provider) else { return nil }
            guard let source = historySupport.source(
                provider: provider,
                now: now,
                maxAgeDays: self.ledgerMaxAgeDays)
            else { return nil }
            return (provider, source)
        }
    }

    private func loadLedgerInsights(
        sources: [(UsageProvider, any UsageLedgerSource)],
        now: Date,
        scanDays: Int) async -> LedgerRefreshResult
    {
        await UsageStoreLedgerInsightLoader().load(
            sources: sources,
            now: now,
            scanDays: scanDays)
    }
}
