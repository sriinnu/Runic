import Foundation
import Observation
import RunicCore

// Structural lint debt: UsageStore remains the largest runtime coordinator.
// **UsageStore** - Main state management for AI provider usage tracking
//
// **Purpose:**
// Central store managing all provider usage data, snapshots, errors, and refresh logic.
// This is the single source of truth for the app's state.
//
// **Responsibilities:**
// - Fetch usage snapshots from all providers (Claude, Codex, Cursor, Gemini, etc.)
// - Manage authentication state and cookies via Silo
// - Track token usage across all providers
// - Coordinate "ping" operations (manual and automatic)
// - Handle errors and stale data detection
// - Provide Observable state for SwiftUI views
//
// **Performance Philosophy:**
// - **Zero Token Leakage** - Always use cookies/cached data first before API calls
// - **Single Ping Strategy** - One ping per provider per session, cache rest
// - **Stale Detection** - Mark data stale after 5 minutes (PerformanceConstants.staleDuration)
//
// **Known Issues:**
// - Still a large runtime coordinator; keep splitting focused domains into `UsageStore+*.swift`.
//
// **Dependencies:**
// - `RunicCore` - Provider descriptors and status probes
// - `Silo` - Browser cookie access
// - `Observation` - SwiftUI state updates
//
// **Usage:**
// ```swift
// @Observable
// final class UsageStore {
//     var snapshots: [UsageProvider: ProviderSnapshot] = [:]
//     var errors: [UsageProvider: Error] = [:]
//
//     func ping(provider: UsageProvider) async { ... }
// }
// ```

#if DEBUG
extension UsageStore {
    func _setSnapshotForTesting(_ snapshot: UsageSnapshot?, provider: UsageProvider) {
        self.snapshots[provider] = snapshot?.scoped(to: provider)
    }

    func _setTokenSnapshotForTesting(_ snapshot: CostUsageTokenSnapshot?, provider: UsageProvider) {
        self.tokenSnapshots[provider] = snapshot
    }

    func _setTokenErrorForTesting(_ error: String?, provider: UsageProvider) {
        self.tokenErrors[provider] = error
    }

    func _setErrorForTesting(_ error: String?, provider: UsageProvider) {
        self.errors[provider] = error
    }
}
#endif

@MainActor
@Observable
final class UsageStore {
    var snapshots: [UsageProvider: UsageSnapshot] = [:]
    var errors: [UsageProvider: String] = [:]
    var lastSourceLabels: [UsageProvider: String] = [:]
    private(set) var lastFetchAttempts: [UsageProvider: [ProviderFetchAttempt]] = [:]
    var tokenSnapshots: [UsageProvider: CostUsageTokenSnapshot] = [:]
    // Custom provider snapshots
    private(set) var customProviderSnapshots: [String: CustomProviderSnapshot] = [:]
    private(set) var customProviderErrors: [String: String] = [:]
    var tokenErrors: [UsageProvider: String] = [:]
    var tokenRefreshInFlight: Set<UsageProvider> = []
    private(set) var ledgerDailySummaries: [UsageProvider: UsageLedgerDailySummary] = [:]
    private(set) var ledgerAllDailySummaries: [UsageProvider: [UsageLedgerDailySummary]] = [:]
    private(set) var ledgerHourlySummaries: [UsageProvider: [UsageLedgerHourlySummary]] = [:]
    private(set) var ledgerActiveBlocks: [UsageProvider: UsageLedgerBlockSummary] = [:]
    private(set) var ledgerTopModels: [UsageProvider: UsageLedgerModelSummary] = [:]
    private(set) var ledgerTopProjects: [UsageProvider: UsageLedgerProjectSummary] = [:]
    private(set) var ledgerModelBreakdowns: [UsageProvider: [UsageLedgerModelSummary]] = [:]
    private(set) var ledgerProjectBreakdowns: [UsageProvider: [UsageLedgerProjectSummary]] = [:]
    private(set) var ledgerSpendForecasts: [UsageProvider: UsageLedgerSpendForecast] = [:]
    private(set) var ledgerProjectSpendForecasts: [UsageProvider: [UsageLedgerSpendForecast]] = [:]
    private(set) var ledgerTopProjectSpendForecasts: [UsageProvider: UsageLedgerSpendForecast] = [:]
    private(set) var ledgerAnomalies: [UsageProvider: UsageLedgerAnomalySummary] = [:]
    private(set) var ledgerCompactions: [UsageProvider: UsageLedgerCompactionSummary] = [:]
    private(set) var ledgerErrors: [UsageProvider: String] = [:]
    private(set) var ledgerUpdatedAt: [UsageProvider: Date] = [:]
    var credits: CreditsSnapshot?
    var lastCreditsError: String?
    var openAIDashboard: OpenAIDashboardSnapshot?
    var lastOpenAIDashboardError: String?
    var openAIDashboardRequiresLogin: Bool = false
    var openAIDashboardCookieImportStatus: String?
    var openAIDashboardCookieImportDebugLog: String?
    var codexVersion: String?
    var claudeVersion: String?
    var geminiVersion: String?
    var zaiVersion: String?
    var antigravityVersion: String?
    var cursorVersion: String?
    var isRefreshing = false
    private(set) var refreshingProviders: Set<UsageProvider> = []
    var debugForceAnimation = false
    var pathDebugInfo: PathDebugSnapshot = .empty
    var statuses: [UsageProvider: ProviderStatus] = [:]
    var probeLogs: [UsageProvider: String] = [:]
    @ObservationIgnored var lastCreditsSnapshot: CreditsSnapshot?
    @ObservationIgnored var creditsFailureStreak: Int = 0
    @ObservationIgnored var lastOpenAIDashboardSnapshot: OpenAIDashboardSnapshot?
    @ObservationIgnored var lastOpenAIDashboardTargetEmail: String?
    @ObservationIgnored var lastOpenAIDashboardCookieImportAttemptAt: Date?
    @ObservationIgnored var lastOpenAIDashboardCookieImportEmail: String?
    @ObservationIgnored var openAIWebAccountDidChange: Bool = false
    var autoRefreshSuspensionReason: AutoRefreshSuspensionReason?
    private(set) var lastRefreshTrigger: RefreshTrigger?
    private(set) var lastRefreshAt: Date?
    var lastAutoRefreshDisableReason: AutoRefreshDisableReason?
    var lastAutoRefreshDisableAt: Date?
    @ObservationIgnored var autoRefreshRunCount: Int = 0
    @ObservationIgnored var autoRefreshWarningSent: Bool = false
    @ObservationIgnored var suppressNextSettingsRefresh: Bool = false
    @ObservationIgnored var lastUsageDeltaAt: [UsageProvider: Date] = [:]
    @ObservationIgnored var lastLedgerActivityAt: [UsageProvider: Date] = [:]
    @ObservationIgnored var lastRefreshFrequency: RefreshFrequency = .manual
    @ObservationIgnored var lastAutoRefreshWarningEnabled: Bool = true
    @ObservationIgnored var lastAutoRefreshWarningThreshold: Int = 10

    @ObservationIgnored let codexFetcher: UsageFetcher
    @ObservationIgnored let claudeFetcher: any ClaudeUsageFetching
    @ObservationIgnored let costUsageFetcher: CostUsageFetcher
    @ObservationIgnored private let registry: ProviderRegistry
    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored let processEnvironment: [String: String]
    @ObservationIgnored private let sessionQuotaNotifier: SessionQuotaNotifier
    @ObservationIgnored private let sessionQuotaLogger = RunicLog.logger("sessionQuota")
    @ObservationIgnored let openAIWebLogger = RunicLog.logger("openai-web")
    @ObservationIgnored let tokenCostLogger = RunicLog.logger("token-cost")
    @ObservationIgnored var openAIWebDebugLines: [String] = []
    @ObservationIgnored var failureGates: [UsageProvider: ConsecutiveFailureGate] = [:]
    @ObservationIgnored var tokenFailureGates: [UsageProvider: ConsecutiveFailureGate] = [:]
    @ObservationIgnored private var providerSpecs: [UsageProvider: ProviderSpec] = [:]
    @ObservationIgnored let providerMetadata: [UsageProvider: ProviderMetadata]
    @ObservationIgnored var timerTask: Task<Void, Never>?
    @ObservationIgnored var tokenTimerTask: Task<Void, Never>?
    @ObservationIgnored var tokenRefreshSequenceTask: Task<Void, Never>?
    @ObservationIgnored private var ledgerRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var runtimeStarted = false
    @ObservationIgnored private var requestedLedgerMaxAgeDays: Int?
    @ObservationIgnored var providerHistoryMonthCache: [
        UsageProvider: [String: ProviderHistoryMonthCacheEntry]
    ] =
        [:]
    @ObservationIgnored private var lastKnownSessionRemaining: [UsageProvider: Double] = [:]
    @ObservationIgnored var lastTokenFetchAt: [UsageProvider: Date] = [:]
    @ObservationIgnored let tokenFetchTTL: TimeInterval = 60 * 60
    @ObservationIgnored let tokenFetchTimeout: TimeInterval = 10 * 60
    @ObservationIgnored private let ledgerRefreshTTL: TimeInterval = 90
    @ObservationIgnored private var ledgerMaxAgeDays: Int {
        max(self.settings.ledgerMaxAgeDays, self.requestedLedgerMaxAgeDays ?? 0)
    }

    @ObservationIgnored let providerHistoryCacheTTL: TimeInterval = 90
    @ObservationIgnored let providerHistoryMaxScanDays: Int = 180
    @ObservationIgnored nonisolated(unsafe) let performanceStorage: PerformanceStorageImpl?

    init(
        fetcher: UsageFetcher,
        claudeFetcher: any ClaudeUsageFetching = ClaudeUsageFetcher(),
        costUsageFetcher: CostUsageFetcher = CostUsageFetcher(),
        settings: SettingsStore,
        registry: ProviderRegistry = .shared,
        sessionQuotaNotifier: SessionQuotaNotifier = SessionQuotaNotifier())
    {
        self.codexFetcher = fetcher
        self.claudeFetcher = claudeFetcher
        self.costUsageFetcher = costUsageFetcher
        self.settings = settings
        self.registry = registry
        self.processEnvironment = ProcessInfo.processInfo.environment
        self.sessionQuotaNotifier = sessionQuotaNotifier
        self.providerMetadata = registry.metadata
        self.lastRefreshFrequency = settings.refreshFrequency

        // Initialize performance tracking (optional, gracefully fails if unavailable)
        self.performanceStorage = PerformanceStorageImpl()
        self.lastAutoRefreshWarningEnabled = settings.autoRefreshWarningEnabled
        self.lastAutoRefreshWarningThreshold = settings.autoRefreshWarningThreshold
        self
            .failureGates = Dictionary(uniqueKeysWithValues: UsageProvider.allCases
                .map { ($0, ConsecutiveFailureGate()) })
        self.tokenFailureGates = Dictionary(uniqueKeysWithValues: UsageProvider.allCases
            .map { ($0, ConsecutiveFailureGate()) })
        self.providerSpecs = registry.specs(
            settings: settings,
            metadata: self.providerMetadata,
            codexFetcher: fetcher,
            claudeFetcher: claudeFetcher)
        self.bindSettings()
    }

    func startRuntime() {
        guard !self.runtimeStarted else { return }
        self.runtimeStarted = true
        self.detectVersions()
        self.refreshPathDebugInfo()
        LoginShellPathCache.shared.captureOnce { [weak self] _ in
            Task { @MainActor in self?.refreshPathDebugInfo() }
        }
        if self.settings.refreshFrequency != .manual {
            Task { await self.refresh(trigger: .startup) }
        }
        self.startTimer()
        self.startTokenTimer()
    }

    deinit {
        self.timerTask?.cancel()
        self.tokenTimerTask?.cancel()
        self.tokenRefreshSequenceTask?.cancel()
        self.ledgerRefreshTask?.cancel()
    }
}

extension UsageStore {
    func enabledProviders() -> [UsageProvider] {
        // Use cached enablement to avoid repeated UserDefaults lookups in animation ticks.
        let enabled = self.settings.enabledProvidersOrdered(metadataByProvider: self.providerMetadata)
        return enabled.filter { self.isProviderAvailable($0) }
    }

    var statusChecksEnabled: Bool {
        self.settings.statusChecksEnabled
    }

    func metadata(for provider: UsageProvider) -> ProviderMetadata {
        self.providerMetadata[provider]!
    }

    func sourceLabel(for provider: UsageProvider) -> String {
        var label = self.lastSourceLabels[provider] ?? ""
        if label.isEmpty {
            let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
            let modes = descriptor.fetchPlan.sourceModes
            if modes.count == 1, let mode = modes.first {
                label = mode.rawValue
            } else if provider == .claude {
                label = self.settings.claudeUsageDataSource.rawValue
            } else {
                label = "auto"
            }
        }

        // When OpenAI web extras are active, show a blended label like `oauth + openai-web`.
        if provider == .codex,
           self.settings.openAIWebAccessEnabled,
           self.openAIDashboard != nil,
           !self.openAIDashboardRequiresLogin,
           !label.contains("openai-web")
        {
            return "\(label) + openai-web"
        }
        return label
    }

    func style(for provider: UsageProvider) -> IconStyle {
        self.providerSpecs[provider]?.style ?? .codex
    }

    func isStale(provider: UsageProvider) -> Bool {
        self.errors[provider] != nil
    }

    func isEnabled(_ provider: UsageProvider) -> Bool {
        let enabled = self.settings.isProviderEnabledCached(
            provider: provider,
            metadataByProvider: self.providerMetadata)
        guard enabled else { return false }
        return self.isProviderAvailable(provider)
    }

    private func isProviderAvailable(_ provider: UsageProvider) -> Bool {
        if provider == .zai {
            if ZaiSettingsReader.apiToken(environment: self.processEnvironment) != nil {
                return true
            }
            return !self.settings.zaiAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    func ensureLedgerHistoryCovers(days: Int) {
        let requestedDays = max(1, days)
        guard requestedDays > self.ledgerMaxAgeDays else { return }
        self.requestedLedgerMaxAgeDays = requestedDays
        self.scheduleLedgerRefresh(force: true, inactiveProviders: [])
    }

    /// Refresh a single provider (used when user clicks Ping on a specific provider tab).
    func refreshSingleProvider(_ provider: UsageProvider) async {
        self.isRefreshing = true
        defer { self.isRefreshing = false }
        await self.refreshProvider(provider, trigger: .manual)
        await self.refreshStatus(provider, trigger: .manual)
        self.scheduleLedgerRefresh(force: true, inactiveProviders: [])
    }

    func refresh(trigger: RefreshTrigger = .manual, forceTokenUsage: Bool = false) async {
        guard !self.isRefreshing else { return }
        let now = Date()
        if trigger.isAuto, !self.shouldRunAutoRefresh(trigger: trigger, now: now) {
            return
        }
        if trigger.isAuto {
            self.recordAutoRefreshRunIfNeeded(trigger: trigger)
        }

        self.lastRefreshTrigger = trigger
        self.lastRefreshAt = now
        self.isRefreshing = true
        defer { self.isRefreshing = false }

        let inactiveProviders = trigger.isAuto ? self.inactiveProviders(now: now) : []
        let skipCodexExtras = trigger.isAuto && inactiveProviders.contains(.codex)

        await withTaskGroup(of: Void.self) { group in
            for provider in UsageProvider.allCases {
                if inactiveProviders.contains(provider) { continue }
                group.addTask { await self.refreshProvider(provider, trigger: trigger) }
                group.addTask { await self.refreshStatus(provider, trigger: trigger) }
            }
            if !skipCodexExtras {
                group.addTask { await self.refreshCreditsIfNeeded() }
            }
        }

        // Token-cost usage can be slow; run it outside the refresh group so we don't block menu updates.
        self.scheduleTokenRefresh(force: forceTokenUsage, trigger: trigger, inactiveProviders: inactiveProviders)

        // OpenAI web scrape depends on the current Codex account email (which can change after login/account switch).
        // Run this after Codex usage refresh so we don't accidentally scrape with stale credentials.
        if !skipCodexExtras {
            await self.refreshOpenAIDashboardIfNeeded(force: forceTokenUsage)
        }

        if self.openAIDashboardRequiresLogin, !skipCodexExtras {
            await self.refreshProvider(.codex, trigger: trigger)
            await self.refreshCreditsIfNeeded()
        }

        self.scheduleLedgerRefresh(force: !trigger.isAuto || forceTokenUsage, inactiveProviders: inactiveProviders)

        // Refresh custom providers
        await self.refreshCustomProviders()

        self.persistWidgetSnapshot(reason: "refresh")
    }

    /// Refresh all enabled custom providers
    func refreshCustomProviders() async {
        let providers = CustomProviderStore.getEnabledProviders()
        await withTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask {
                    await self.refreshCustomProvider(id: provider.id)
                }
            }
        }
    }

    /// Refresh a single custom provider
    func refreshCustomProvider(id: String) async {
        guard let config = CustomProviderStore.getProvider(id: id), config.enabled else {
            return
        }

        let fetcher = GenericProviderFetcher(config: config)
        let startTime = Date()
        let requestID = UUID().uuidString
        let providerLabel = Self.customProviderMetricLabel(config)

        do {
            let usageData = try await fetcher.fetchUsage()
            let endTime = Date()

            await self.trackLatency(
                provider: .openrouter,
                providerLabel: providerLabel,
                requestID: requestID,
                startTime: startTime,
                endTime: endTime,
                success: true)

            let snapshot = CustomProviderSnapshot.from(usageData: usageData.toCustomUsageData(), config: config)
            await MainActor.run {
                self.customProviderSnapshots[id] = snapshot
                self.customProviderErrors.removeValue(forKey: id)
            }
        } catch {
            let endTime = Date()

            await self.trackLatency(
                provider: .openrouter,
                providerLabel: providerLabel,
                requestID: requestID,
                startTime: startTime,
                endTime: endTime,
                success: false)
            await self.trackError(provider: .openrouter, providerLabel: providerLabel, error: error)

            await MainActor.run {
                self.customProviderErrors[id] = error.localizedDescription
            }
        }
    }

    /// Clear a custom provider snapshot
    func clearCustomProviderSnapshot(id: String) {
        self.customProviderSnapshots.removeValue(forKey: id)
        self.customProviderErrors.removeValue(forKey: id)
    }

    /// For demo/testing: drop the snapshot so the loading animation plays, then restore the last snapshot.
    func replayLoadingAnimation(duration: TimeInterval = 3) {
        let current = self.preferredSnapshot
        self.snapshots.removeAll()
        self.debugForceAnimation = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if let current, let provider = self.enabledProviders().first {
                self.snapshots[provider] = current
            }
            self.debugForceAnimation = false
        }
    }

    // MARK: - Private

    private func bindSettings() {
        self.observeSettingsChanges()
    }

    private func scheduleLedgerRefresh(
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

    private func refreshProvider(_ provider: UsageProvider, trigger _: RefreshTrigger) async {
        guard let spec = self.providerSpecs[provider] else { return }

        if !spec.isEnabled() {
            self.refreshingProviders.remove(provider)
            await MainActor.run {
                self.snapshots.removeValue(forKey: provider)
                self.errors[provider] = nil
                self.lastSourceLabels.removeValue(forKey: provider)
                self.lastFetchAttempts.removeValue(forKey: provider)
                self.tokenSnapshots.removeValue(forKey: provider)
                self.tokenErrors[provider] = nil
                self.failureGates[provider]?.reset()
                self.tokenFailureGates[provider]?.reset()
                self.statuses.removeValue(forKey: provider)
                self.lastKnownSessionRemaining.removeValue(forKey: provider)
                self.lastTokenFetchAt.removeValue(forKey: provider)
                self.lastUsageDeltaAt.removeValue(forKey: provider)
                self.lastLedgerActivityAt.removeValue(forKey: provider)
                self.ledgerCompactions.removeValue(forKey: provider)
            }
            return
        }

        self.refreshingProviders.insert(provider)
        defer { self.refreshingProviders.remove(provider) }

        let previousSnapshot = self.snapshots[provider]
        let outcome = await spec.fetch()
        await MainActor.run {
            self.lastFetchAttempts[provider] = outcome.attempts
        }

        switch outcome.result {
        case let .success(result):
            let scoped = result.usage.scoped(to: provider)
            await MainActor.run {
                self.handleSessionQuotaTransition(provider: provider, snapshot: scoped)
                self.snapshots[provider] = scoped
                self.lastSourceLabels[provider] = result.sourceLabel
                self.errors[provider] = nil
                self.failureGates[provider]?.recordSuccess()
                self.recordUsageActivity(
                    provider: provider,
                    previous: previousSnapshot,
                    current: scoped)
            }
        case let .failure(error):
            await MainActor.run {
                let hadPriorData = self.snapshots[provider] != nil
                let shouldSurface = self.failureGates[provider]?
                    .shouldSurfaceError(onFailureWithPriorData: hadPriorData) ?? true
                if shouldSurface {
                    self.errors[provider] = error.localizedDescription
                    self.snapshots.removeValue(forKey: provider)
                } else {
                    self.errors[provider] = nil
                }
            }
        }
    }

    private func handleSessionQuotaTransition(provider: UsageProvider, snapshot: UsageSnapshot) {
        let currentRemaining = snapshot.primary.remainingPercent
        let previousRemaining = self.lastKnownSessionRemaining[provider]

        defer { self.lastKnownSessionRemaining[provider] = currentRemaining }

        guard self.settings.sessionQuotaNotificationsEnabled else {
            if SessionQuotaNotificationLogic.isDepleted(currentRemaining) ||
                SessionQuotaNotificationLogic.isDepleted(previousRemaining)
            {
                let providerText = provider.rawValue
                let message =
                    "notifications disabled: provider=\(providerText) " +
                    "prev=\(previousRemaining ?? -1) curr=\(currentRemaining)"
                self.sessionQuotaLogger.debug(message)
            }
            return
        }

        guard previousRemaining != nil else {
            if SessionQuotaNotificationLogic.isDepleted(currentRemaining) {
                let providerText = provider.rawValue
                let message = "startup depleted: provider=\(providerText) curr=\(currentRemaining)"
                self.sessionQuotaLogger.info(message)
                self.sessionQuotaNotifier.post(transition: .depleted, provider: provider)
            }
            return
        }

        let transition = SessionQuotaNotificationLogic.transition(
            previousRemaining: previousRemaining,
            currentRemaining: currentRemaining)
        guard transition != .none else {
            if SessionQuotaNotificationLogic.isDepleted(currentRemaining) ||
                SessionQuotaNotificationLogic.isDepleted(previousRemaining)
            {
                let providerText = provider.rawValue
                let message =
                    "no transition: provider=\(providerText) " +
                    "prev=\(previousRemaining ?? -1) curr=\(currentRemaining)"
                self.sessionQuotaLogger.debug(message)
            }
            return
        }

        let providerText = provider.rawValue
        let transitionText = String(describing: transition)
        let message =
            "transition \(transitionText): provider=\(providerText) " +
            "prev=\(previousRemaining ?? -1) curr=\(currentRemaining)"
        self.sessionQuotaLogger.info(message)

        self.sessionQuotaNotifier.post(transition: transition, provider: provider)
    }
}
