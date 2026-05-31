import Foundation
import RunicCore

extension UsageStore {
    func providerHistoryMonth(
        provider: UsageProvider,
        monthStart: Date,
        forceRefresh: Bool = false) async -> ProviderHistoryMonthSnapshot
    {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let historySupport = UsageStoreProviderHistorySupport(
            configuredOTelLogPaths: self.settings.otelGenAILogPaths,
            environment: self.processEnvironment,
            maxScanDays: self.providerHistoryMaxScanDays)
        let normalizedMonthStart = historySupport.normalizedMonthStart(monthStart, calendar: calendar)
        let now = Date()
        let cacheKey = historySupport.cacheKey(for: normalizedMonthStart)

        if !forceRefresh,
           let cached = self.providerHistoryMonthCache[provider]?[cacheKey],
           now.timeIntervalSince(cached.fetchedAt) <= self.providerHistoryCacheTTL
        {
            return cached.snapshot
        }

        let scanDays = historySupport.scanDays(
            monthStart: normalizedMonthStart,
            now: now,
            calendar: calendar)

        guard let source = historySupport.source(
            provider: provider,
            now: now,
            maxAgeDays: scanDays)
        else {
            let unsupported = UsageStoreProviderHistorySupport.unsupportedSnapshot(
                provider: provider,
                monthStart: normalizedMonthStart,
                generatedAt: now)
            self.providerHistoryMonthCache[provider, default: [:]][cacheKey] = ProviderHistoryMonthCacheEntry(
                fetchedAt: now,
                snapshot: unsupported)
            return unsupported
        }

        let note = historySupport.note(scanDays: scanDays)

        let snapshot = await Task.detached(priority: .utility) {
            let timeZone = TimeZone.current
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone

            do {
                let loaded = try await source.loadEntries()
                let providerEntries = loaded.filter { $0.provider == provider }
                let monthEntries = providerEntries.filter {
                    calendar.isDate($0.timestamp, equalTo: normalizedMonthStart, toGranularity: .month)
                }
                let entryDays = UsageStoreProviderHistorySupport.providerHistoryDays(
                    entries: monthEntries,
                    timeZone: timeZone)
                let cachedDays = await UsageStoreProviderHistorySupport.cachedProviderHistoryDays(
                    provider: provider,
                    monthStart: normalizedMonthStart,
                    timeZone: timeZone)
                let days = UsageStoreProviderHistorySupport.mergedProviderHistoryDays(
                    cachedDays: cachedDays,
                    entryDays: entryDays)
                return ProviderHistoryMonthSnapshot(
                    provider: provider,
                    monthStart: normalizedMonthStart,
                    generatedAt: now,
                    days: days,
                    isSupported: true,
                    note: note,
                    error: nil)
            } catch {
                return ProviderHistoryMonthSnapshot(
                    provider: provider,
                    monthStart: normalizedMonthStart,
                    generatedAt: now,
                    days: [],
                    isSupported: true,
                    note: note,
                    error: error.localizedDescription)
            }
        }.value

        self.providerHistoryMonthCache[provider, default: [:]][cacheKey] = ProviderHistoryMonthCacheEntry(
            fetchedAt: now,
            snapshot: snapshot)
        return snapshot
    }
}
