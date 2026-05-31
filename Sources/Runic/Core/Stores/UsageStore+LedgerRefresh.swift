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
        }
    }

    private func applyLedgerRefreshResult(_ result: LedgerRefreshResult) {
        self.ledgerRefreshTask = nil
        for provider in result.providers {
            self.applyLedgerRefreshResult(result, provider: provider)
        }
        self.sendBudgetNotificationsIfNeeded()
        if self.ledgerMaxAgeDays > result.scanDays {
            self.scheduleLedgerRefresh(force: true, inactiveProviders: [])
        }
    }

    private func applyLedgerRefreshResult(
        _ result: LedgerRefreshResult,
        provider: UsageProvider)
    {
        self.ledgerErrors[provider] = result.errorsByProvider[provider]
        self.ledgerDailySummaries[provider] = result.dailyByProvider[provider]
        self.ledgerAllDailySummaries.setNonEmpty(result.allDailySummariesByProvider[provider], forKey: provider)
        self.ledgerHourlySummaries.setNonEmpty(result.hourlySummariesByProvider[provider], forKey: provider)
        self.ledgerActiveBlocks[provider] = result.activeBlocksByProvider[provider]
        self.ledgerTopModels[provider] = result.topModelsByProvider[provider]
        self.ledgerTopProjects[provider] = result.topProjectsByProvider[provider]
        self.ledgerModelBreakdowns[provider] = result.modelBreakdownsByProvider[provider]
        self.ledgerProjectBreakdowns[provider] = result.projectBreakdownsByProvider[provider]
        self.ledgerSpendForecasts[provider] = result.spendForecastsByProvider[provider]
        self.ledgerProjectSpendForecasts[provider] = result.projectSpendForecastsByProvider[provider]
        self.ledgerTopProjectSpendForecasts[provider] = result.topProjectSpendForecastsByProvider[provider]
        self.ledgerAnomalies[provider] = result.anomaliesByProvider[provider]
        self.ledgerCompactions[provider] = result.compactionsByProvider[provider]

        if let lastActivity = result.lastActivityByProvider[provider] {
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
