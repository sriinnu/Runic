import AppKit
import CoreGraphics
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
    private(set) var tokenSnapshots: [UsageProvider: CostUsageTokenSnapshot] = [:]
    // Custom provider snapshots
    private(set) var customProviderSnapshots: [String: CustomProviderSnapshot] = [:]
    private(set) var customProviderErrors: [String: String] = [:]
    private(set) var tokenErrors: [UsageProvider: String] = [:]
    private(set) var tokenRefreshInFlight: Set<UsageProvider> = []
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
    private(set) var statuses: [UsageProvider: ProviderStatus] = [:]
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
    private(set) var lastAutoRefreshDisableReason: AutoRefreshDisableReason?
    private(set) var lastAutoRefreshDisableAt: Date?
    @ObservationIgnored private var autoRefreshRunCount: Int = 0
    @ObservationIgnored private var autoRefreshWarningSent: Bool = false
    @ObservationIgnored private var suppressNextSettingsRefresh: Bool = false
    @ObservationIgnored private var lastUsageDeltaAt: [UsageProvider: Date] = [:]
    @ObservationIgnored private var lastLedgerActivityAt: [UsageProvider: Date] = [:]
    @ObservationIgnored private var lastRefreshFrequency: RefreshFrequency = .manual
    @ObservationIgnored private var lastAutoRefreshWarningEnabled: Bool = true
    @ObservationIgnored private var lastAutoRefreshWarningThreshold: Int = 10

    @ObservationIgnored let codexFetcher: UsageFetcher
    @ObservationIgnored let claudeFetcher: any ClaudeUsageFetching
    @ObservationIgnored private let costUsageFetcher: CostUsageFetcher
    @ObservationIgnored private let registry: ProviderRegistry
    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored private let processEnvironment: [String: String]
    @ObservationIgnored private let sessionQuotaNotifier: SessionQuotaNotifier
    @ObservationIgnored private let sessionQuotaLogger = RunicLog.logger("sessionQuota")
    @ObservationIgnored let openAIWebLogger = RunicLog.logger("openai-web")
    @ObservationIgnored private let tokenCostLogger = RunicLog.logger("token-cost")
    @ObservationIgnored var openAIWebDebugLines: [String] = []
    @ObservationIgnored var failureGates: [UsageProvider: ConsecutiveFailureGate] = [:]
    @ObservationIgnored private var tokenFailureGates: [UsageProvider: ConsecutiveFailureGate] = [:]
    @ObservationIgnored private var providerSpecs: [UsageProvider: ProviderSpec] = [:]
    @ObservationIgnored private let providerMetadata: [UsageProvider: ProviderMetadata]
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var tokenTimerTask: Task<Void, Never>?
    @ObservationIgnored private var tokenRefreshSequenceTask: Task<Void, Never>?
    @ObservationIgnored private var ledgerRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var runtimeStarted = false
    @ObservationIgnored private var requestedLedgerMaxAgeDays: Int?
    @ObservationIgnored private var providerHistoryMonthCache: [
        UsageProvider: [String: ProviderHistoryMonthCacheEntry]
    ] =
        [:]
    @ObservationIgnored private var lastKnownSessionRemaining: [UsageProvider: Double] = [:]
    @ObservationIgnored private(set) var lastTokenFetchAt: [UsageProvider: Date] = [:]
    @ObservationIgnored private let tokenFetchTTL: TimeInterval = 60 * 60
    @ObservationIgnored private let tokenFetchTimeout: TimeInterval = 10 * 60
    @ObservationIgnored private let ledgerRefreshTTL: TimeInterval = 90
    @ObservationIgnored private var ledgerMaxAgeDays: Int {
        max(self.settings.ledgerMaxAgeDays, self.requestedLedgerMaxAgeDays ?? 0)
    }

    @ObservationIgnored private let providerHistoryCacheTTL: TimeInterval = 90
    @ObservationIgnored private let providerHistoryMaxScanDays: Int = 180
    @ObservationIgnored private nonisolated(unsafe) let performanceStorage: PerformanceStorageImpl?

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
    func autoRefreshStatusLine() -> String? {
        if self.settings.refreshFrequency == .manual {
            if let reason = self.lastAutoRefreshDisableReason {
                return "Auto-refresh: Manual (switched after \(reason.label))"
            }
            return "Auto-refresh: Manual"
        }
        if let reason = self.autoRefreshSuspensionReason {
            return "Auto-refresh: Paused (\(reason.label))"
        }
        return "Auto-refresh: \(self.settings.refreshFrequency.label)"
    }

    func setAutoRefreshSuspended(_ reason: AutoRefreshSuspensionReason?) {
        self.autoRefreshSuspensionReason = reason
    }

    func disableAutoRefreshForSystemPause(_ reason: AutoRefreshSuspensionReason) {
        let detail = self.systemPauseDetailText(reason)
        self.disableAutoRefresh(
            reason: self.disableReason(for: reason),
            idPrefix: "auto-refresh-system",
            body: "Runic switched auto-refresh to Manual because \(detail).")
    }

    func handleAutoRefreshSystemPause(_ reason: AutoRefreshSuspensionReason) {
        if self.settings.autoDisableRefreshOnSleepEnabled {
            self.disableAutoRefreshForSystemPause(reason)
        } else {
            self.setAutoRefreshSuspended(reason)
        }
    }

    func lastRefreshStatusLine(now: Date = .now) -> String? {
        guard let trigger = self.lastRefreshTrigger,
              let refreshedAt = self.lastRefreshAt else { return nil }
        let relative = refreshedAt.relativeDescription(now: now)
        return "Last refresh: \(trigger.menuLabel) • \(relative)"
    }

    func autoRefreshSwitchLine(now: Date = .now) -> String? {
        guard self.settings.refreshFrequency == .manual,
              let reason = self.lastAutoRefreshDisableReason,
              let disabledAt = self.lastAutoRefreshDisableAt else { return nil }
        let relative = disabledAt.relativeDescription(now: now)
        return "Auto-refresh switched to Manual after \(reason.label) • \(relative)"
    }

    func autoRefreshDisableBadgeText() -> String? {
        guard self.settings.refreshFrequency == .manual,
              let reason = self.lastAutoRefreshDisableReason else { return nil }
        return "Manual because of \(reason.label)"
    }

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

    func handleSettingsChange() async {
        let refreshChanged = self.settings.refreshFrequency != self.lastRefreshFrequency
        let warningEnabledChanged = self.settings.autoRefreshWarningEnabled != self.lastAutoRefreshWarningEnabled
        let warningThresholdChanged = self.settings.autoRefreshWarningThreshold
            != self.lastAutoRefreshWarningThreshold
        if refreshChanged || warningEnabledChanged || warningThresholdChanged {
            self.resetAutoRefreshWarningState()
            self.lastRefreshFrequency = self.settings.refreshFrequency
            self.lastAutoRefreshWarningEnabled = self.settings.autoRefreshWarningEnabled
            self.lastAutoRefreshWarningThreshold = self.settings.autoRefreshWarningThreshold
        }
        if refreshChanged, !self.suppressNextSettingsRefresh {
            self.clearAutoRefreshDisableReason()
        }
        self.startTimer()
        self.startTokenTimer()
        guard !self.suppressNextSettingsRefresh else {
            self.suppressNextSettingsRefresh = false
            return
        }
        await self.refresh(trigger: .settingsChange)
    }

    private func startTimer() {
        self.timerTask?.cancel()
        guard let wait = self.settings.refreshFrequency.seconds else { return }

        // Background poller so the menu stays responsive; canceled when settings change or store deallocates.
        self.timerTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(wait))
                await self?.refresh(trigger: .autoTimer)
            }
        }
    }

    private func startTokenTimer() {
        self.tokenTimerTask?.cancel()
        guard self.settings.refreshFrequency != .manual else { return }
        guard self.settings.costUsageEnabled else { return }
        let wait = self.tokenFetchTTL
        self.tokenTimerTask = Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(wait))
                let inactive = await self?.inactiveProviders(now: Date()) ?? []
                await self?.scheduleTokenRefresh(
                    force: false,
                    trigger: .autoTimer,
                    inactiveProviders: inactive)
            }
        }
    }

    private func shouldRunAutoRefresh(trigger: RefreshTrigger, now: Date) -> Bool {
        guard trigger.isAuto else { return true }
        guard self.settings.refreshFrequency != .manual else { return false }
        if self.autoRefreshSuspensionReason != nil { return false }

        if self.settings.autoDisableRefreshWhenIdleEnabled,
           let idleSeconds = self.currentIdleSeconds()
        {
            let thresholdMinutes = max(1, self.settings.autoDisableRefreshWhenIdleMinutes)
            let thresholdSeconds = TimeInterval(thresholdMinutes) * 60
            if idleSeconds >= thresholdSeconds {
                self.disableAutoRefreshForIdle(thresholdMinutes: thresholdMinutes)
                return false
            }
        }
        return true
    }

    private func disableAutoRefreshForIdle(thresholdMinutes: Int) {
        self.disableAutoRefresh(
            reason: .idle,
            idPrefix: "auto-refresh-idle",
            body: "Runic switched auto-refresh to Manual after \(thresholdMinutes) minutes of inactivity. "
                + "Use Refresh in the menu when you want new data.")
    }

    private func disableAutoRefresh(reason: AutoRefreshDisableReason, idPrefix: String, body: String) {
        guard self.settings.refreshFrequency != .manual else { return }
        self.suppressNextSettingsRefresh = true
        self.settings.refreshFrequency = .manual
        self.autoRefreshSuspensionReason = nil
        self.lastAutoRefreshDisableReason = reason
        self.lastAutoRefreshDisableAt = Date()
        AppNotifications.shared.post(
            idPrefix: idPrefix,
            title: "Auto-refresh switched to Manual",
            body: body)
    }

    private func clearAutoRefreshDisableReason() {
        self.lastAutoRefreshDisableReason = nil
        self.lastAutoRefreshDisableAt = nil
    }

    private func systemPauseDetailText(_ reason: AutoRefreshSuspensionReason) -> String {
        switch reason {
        case .systemSleep:
            "your Mac went to sleep"
        case .screenSleep:
            "the display went to sleep"
        case .sessionInactive:
            "your session became inactive"
        }
    }

    private func disableReason(for reason: AutoRefreshSuspensionReason) -> AutoRefreshDisableReason {
        switch reason {
        case .systemSleep: .systemSleep
        case .screenSleep: .screenSleep
        case .sessionInactive: .sessionInactive
        }
    }

    private func currentIdleSeconds() -> TimeInterval? {
        #if os(macOS)
        guard let anyInputType = CGEventType(rawValue: UInt32.max) else { return nil }
        let seconds = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputType)
        return seconds >= 0 ? seconds : nil
        #else
        return nil
        #endif
    }

    private func recordAutoRefreshRunIfNeeded(trigger: RefreshTrigger) {
        guard trigger == .autoTimer else { return }
        guard self.settings.autoRefreshWarningEnabled else { return }
        guard !self.autoRefreshWarningSent else { return }
        let threshold = max(1, self.settings.autoRefreshWarningThreshold)
        self.autoRefreshRunCount += 1
        guard self.autoRefreshRunCount >= threshold else { return }
        self.autoRefreshWarningSent = true
        AppNotifications.shared.post(
            idPrefix: "auto-refresh-warning",
            title: "Auto-refresh is enabled",
            body: "Runic has auto-refreshed \(threshold) times. Auto-refresh can touch CLIs, "
                + "logs, or browser cookies depending on provider settings. Switch to Manual if you prefer "
                + "click-only refresh.")
    }

    private func resetAutoRefreshWarningState() {
        self.autoRefreshRunCount = 0
        self.autoRefreshWarningSent = false
    }

    private func inactiveProviders(now: Date) -> Set<UsageProvider> {
        guard self.settings.autoSuspendInactiveProvidersEnabled else { return [] }
        let thresholdMinutes = max(1, self.settings.autoSuspendInactiveProvidersMinutes)
        let thresholdSeconds = TimeInterval(thresholdMinutes) * 60

        var inactive: Set<UsageProvider> = []
        for provider in UsageProvider.allCases {
            guard self.isEnabled(provider) else { continue }
            guard let lastActivity = self.lastActivityAt(for: provider) else { continue }
            if now.timeIntervalSince(lastActivity) >= thresholdSeconds {
                inactive.insert(provider)
            }
        }
        return inactive
    }

    private func lastActivityAt(for provider: UsageProvider) -> Date? {
        let ledger = self.lastLedgerActivityAt[provider]
        let delta = self.lastUsageDeltaAt[provider]
        switch (ledger, delta) {
        case let (l?, d?):
            return max(l, d)
        case let (l?, nil):
            return l
        case let (nil, d?):
            return d
        case (nil, nil):
            return nil
        }
    }

    private func recordUsageActivity(
        provider: UsageProvider,
        previous: UsageSnapshot?,
        current: UsageSnapshot)
    {
        if previous == nil || self.usageChanged(previous: previous, current: current) {
            self.lastUsageDeltaAt[provider] = current.updatedAt
        }
    }

    private func usageChanged(previous: UsageSnapshot?, current: UsageSnapshot) -> Bool {
        guard let previous else { return true }

        func windowChanged(_ lhs: RateWindow?, _ rhs: RateWindow?) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                false
            case let (l?, r?):
                abs(l.usedPercent - r.usedPercent) >= 0.1
            case (nil, _), (_, nil):
                true
            }
        }

        if windowChanged(previous.primary, current.primary) { return true }
        if windowChanged(previous.secondary, current.secondary) { return true }
        if windowChanged(previous.tertiary, current.tertiary) { return true }

        switch (previous.providerCost, current.providerCost) {
        case (nil, nil):
            return false
        case let (lhs?, rhs?):
            if lhs.used != rhs.used { return true }
            if lhs.limit != rhs.limit { return true }
            return false
        case (nil, _), (_, nil):
            return true
        }
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

    private func scheduleTokenRefresh(
        force: Bool,
        trigger: RefreshTrigger,
        inactiveProviders: Set<UsageProvider>)
    {
        if trigger.isAuto, !self.shouldRunAutoRefresh(trigger: trigger, now: Date()) {
            return
        }
        if force {
            self.tokenRefreshSequenceTask?.cancel()
            self.tokenRefreshSequenceTask = nil
        } else if self.tokenRefreshSequenceTask != nil {
            return
        }

        self.tokenRefreshSequenceTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.tokenRefreshSequenceTask = nil
                }
            }
            await withTaskGroup(of: Void.self) { group in
                for provider in UsageProvider.allCases {
                    group.addTask {
                        guard !Task.isCancelled else { return }
                        await self.refreshTokenUsage(
                            provider,
                            force: force,
                            trigger: trigger,
                            inactiveProviders: inactiveProviders)
                    }
                }
            }
        }
    }

    private struct ProviderHistoryMonthCacheEntry {
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

    private func refreshStatus(_ provider: UsageProvider, trigger _: RefreshTrigger) async {
        guard self.isEnabled(provider) else { return }
        guard self.settings.statusChecksEnabled else { return }
        guard self.settings.refreshFrequency != .manual else { return }
        guard let meta = self.providerMetadata[provider] else { return }

        do {
            let status: ProviderStatus
            if let urlString = meta.statusPageURL, let baseURL = URL(string: urlString) {
                status = try await Self.fetchStatus(from: baseURL)
            } else if let productID = meta.statusWorkspaceProductID {
                status = try await Self.fetchWorkspaceStatus(productID: productID)
            } else {
                return
            }
            await MainActor.run { self.statuses[provider] = status }
        } catch {
            // Keep the previous status to avoid flapping when the API hiccups.
            await MainActor.run {
                if self.statuses[provider] == nil {
                    self.statuses[provider] = ProviderStatus(
                        indicator: .unknown,
                        description: error.localizedDescription,
                        updatedAt: nil)
                }
            }
        }
    }

    private func refreshCreditsIfNeeded() async {
        guard self.isEnabled(.codex) else { return }
        do {
            let credits = try await self.codexFetcher.loadLatestCredits()
            await MainActor.run {
                self.credits = credits
                self.lastCreditsError = nil
                self.lastCreditsSnapshot = credits
                self.creditsFailureStreak = 0
            }
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("data not available yet") {
                await MainActor.run {
                    if let cached = self.lastCreditsSnapshot {
                        self.credits = cached
                        self.lastCreditsError = nil
                    } else {
                        self.credits = nil
                        self.lastCreditsError = "Codex credits are still loading; will retry shortly."
                    }
                }
                return
            }

            await MainActor.run {
                self.creditsFailureStreak += 1
                if let cached = self.lastCreditsSnapshot {
                    self.credits = cached
                    let stamp = cached.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    self.lastCreditsError =
                        "Last Codex credits refresh failed: \(message). Cached values from \(stamp)."
                } else {
                    self.lastCreditsError = message
                    self.credits = nil
                }
            }
        }
    }
}

extension UsageStore {
    func debugDumpClaude() async {
        let output = await self.claudeFetcher.debugRawProbe(model: "sonnet")
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("runic-claude-probe.txt")
        try? output.write(to: url, atomically: true, encoding: .utf8)
        await MainActor.run {
            let snippet = String(output.prefix(180)).replacingOccurrences(of: "\n", with: " ")
            self.errors[.claude] = "[Claude] \(snippet) (saved: \(url.path))"
            NSWorkspace.shared.open(url)
        }
    }

    func dumpLog(toFileFor provider: UsageProvider) async -> URL? {
        let text = await self.debugLog(for: provider)
        let filename = "runic-\(provider.rawValue)-probe.txt"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            _ = await MainActor.run { NSWorkspace.shared.open(url) }
            return url
        } catch {
            await MainActor.run {
                self.errors[provider] = "Failed to save log: \(error.localizedDescription)"
            }
            return nil
        }
    }

    private func detectVersions() {
        Task.detached { [claudeFetcher] in
            let codexVer = Self.readCLI("codex", args: ["-s", "read-only", "-a", "untrusted", "--version"])
            let claudeVer = claudeFetcher.detectVersion()
            let geminiVer = Self.readCLI("gemini", args: ["--version"])
            let antigravityVer = await AntigravityStatusProbe.detectVersion()
            await MainActor.run {
                self.codexVersion = codexVer
                self.claudeVersion = claudeVer
                self.geminiVersion = geminiVer
                self.zaiVersion = nil
                self.antigravityVersion = antigravityVer
            }
        }
    }

    private nonisolated static func readCLI(_ cmd: String, args: [String]) -> String? {
        let env = ProcessInfo.processInfo.environment
        var pathEnv = env
        pathEnv["PATH"] = PathBuilder.effectivePATH(purposes: [.rpc, .tty, .nodeTooling], env: env)
        let loginPATH = LoginShellPathCache.shared.current

        let resolved: String = switch cmd {
        case "codex":
            BinaryLocator.resolveCodexBinary(env: env, loginPATH: loginPATH) ?? cmd
        case "gemini":
            BinaryLocator.resolveGeminiBinary(env: env, loginPATH: loginPATH) ?? cmd
        default:
            cmd
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [resolved] + args
        process.environment = pathEnv
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty else { return nil }
        return text
    }

    private func refreshPathDebugInfo() {
        self.pathDebugInfo = PathBuilder.debugSnapshot(purposes: [.rpc, .tty, .nodeTooling])
    }

    func clearCostUsageCache() async -> String? {
        let errorMessage: String? = await Task.detached(priority: .utility) {
            let fm = FileManager.default
            let cacheDirs = [
                Self.costUsageCacheDirectory(fileManager: fm),
                Self.costUsageLedgerCacheDirectory(fileManager: fm),
                Self.costUsageRelayDirectory(fileManager: fm),
            ]

            for cacheDir in cacheDirs {
                do {
                    try fm.removeItem(at: cacheDir)
                } catch let error as NSError {
                    if error.domain == NSCocoaErrorDomain, error.code == NSFileNoSuchFileError { continue }
                    return error.localizedDescription
                }
            }
            return nil
        }.value

        guard errorMessage == nil else { return errorMessage }

        self.tokenSnapshots.removeAll()
        self.tokenErrors.removeAll()
        self.lastTokenFetchAt.removeAll()
        self.tokenFailureGates[.codex]?.reset()
        self.tokenFailureGates[.claude]?.reset()
        return nil
    }

    private func refreshTokenUsage(
        _ provider: UsageProvider,
        force: Bool,
        trigger: RefreshTrigger,
        inactiveProviders: Set<UsageProvider>) async
    {
        guard provider == .codex || provider == .claude else {
            self.tokenSnapshots.removeValue(forKey: provider)
            self.tokenErrors[provider] = nil
            self.tokenFailureGates[provider]?.reset()
            self.lastTokenFetchAt.removeValue(forKey: provider)
            return
        }

        guard self.settings.costUsageEnabled else {
            self.tokenSnapshots.removeValue(forKey: provider)
            self.tokenErrors[provider] = nil
            self.tokenFailureGates[provider]?.reset()
            self.lastTokenFetchAt.removeValue(forKey: provider)
            return
        }

        guard self.isEnabled(provider) else {
            self.tokenSnapshots.removeValue(forKey: provider)
            self.tokenErrors[provider] = nil
            self.tokenFailureGates[provider]?.reset()
            self.lastTokenFetchAt.removeValue(forKey: provider)
            return
        }

        if trigger.isAuto, inactiveProviders.contains(provider), !force {
            return
        }

        guard !self.tokenRefreshInFlight.contains(provider) else { return }

        let now = Date()
        if !force,
           let last = self.lastTokenFetchAt[provider],
           now.timeIntervalSince(last) < self.tokenFetchTTL
        {
            return
        }
        self.lastTokenFetchAt[provider] = now
        self.tokenRefreshInFlight.insert(provider)
        defer { self.tokenRefreshInFlight.remove(provider) }

        let startedAt = Date()
        let providerText = provider.rawValue
        self.tokenCostLogger
            .info("cost usage start provider=\(providerText) force=\(force)")

        do {
            let fetcher = self.costUsageFetcher
            let timeoutSeconds = self.tokenFetchTimeout
            let snapshot = try await withThrowingTaskGroup(of: CostUsageTokenSnapshot.self) { group in
                group.addTask(priority: .utility) {
                    try await fetcher.loadTokenSnapshot(provider: provider, now: now)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                    throw CostUsageError.timedOut(seconds: Int(timeoutSeconds))
                }
                defer { group.cancelAll() }
                guard let snapshot = try await group.next() else { throw CancellationError() }
                return snapshot
            }

            guard !snapshot.daily.isEmpty else {
                self.tokenSnapshots.removeValue(forKey: provider)
                self.tokenErrors[provider] = Self.tokenCostNoDataMessage(for: provider)
                self.tokenFailureGates[provider]?.recordSuccess()
                return
            }
            let duration = Date().timeIntervalSince(startedAt)
            let sessionCost = snapshot.sessionCostUSD.map(UsageFormatter.usdString) ?? "—"
            let monthCost = snapshot.last30DaysCostUSD.map(UsageFormatter.usdString) ?? "—"
            let durationText = String(format: "%.2f", duration)
            let message =
                "cost usage success provider=\(providerText) " +
                "duration=\(durationText)s " +
                "today=\(sessionCost) " +
                "30d=\(monthCost)"
            self.tokenCostLogger.info(message)
            self.tokenSnapshots[provider] = snapshot
            self.tokenErrors[provider] = nil
            self.tokenFailureGates[provider]?.recordSuccess()
            self.persistWidgetSnapshot(reason: "token-usage")
        } catch {
            if error is CancellationError { return }
            let duration = Date().timeIntervalSince(startedAt)
            let msg = error.localizedDescription
            let durationText = String(format: "%.2f", duration)
            let message = "cost usage failed provider=\(providerText) duration=\(durationText)s error=\(msg)"
            self.tokenCostLogger.error(message)
            let hadPriorData = self.tokenSnapshots[provider] != nil
            let shouldSurface = self.tokenFailureGates[provider]?
                .shouldSurfaceError(onFailureWithPriorData: hadPriorData) ?? true
            if shouldSurface {
                self.tokenErrors[provider] = error.localizedDescription
                self.tokenSnapshots.removeValue(forKey: provider)
            } else {
                self.tokenErrors[provider] = nil
            }
        }
    }

    // MARK: - Performance Tracking

    /// Track API call latency for performance monitoring
    private nonisolated func trackLatency(
        provider: UsageProvider,
        providerLabel: String? = nil,
        requestID: String,
        startTime: Date,
        endTime: Date,
        success: Bool) async
    {
        guard let storage = self.performanceStorage else { return }
        guard Self.localPerformanceTrackingEnabled() else { return }

        let metric = LatencyMetric(
            id: UUID().uuidString,
            requestID: requestID,
            provider: provider,
            providerLabel: providerLabel,
            model: nil,
            startTime: startTime,
            endTime: endTime,
            durationMs: Int(endTime.timeIntervalSince(startTime) * 1000),
            success: success,
            createdAt: Date())

        try? await storage.save(latency: metric)
    }

    /// Track API errors for performance monitoring
    private nonisolated func trackError(provider: UsageProvider, providerLabel: String? = nil, error: Error) async {
        guard let storage = self.performanceStorage else { return }
        guard Self.localPerformanceTrackingEnabled() else { return }

        let errorType = self.classifyError(error)
        let errorEvent = ErrorEvent(
            id: UUID().uuidString,
            provider: provider,
            providerLabel: providerLabel,
            errorType: errorType,
            errorMessage: error.localizedDescription,
            retryCount: 0,
            timestamp: Date())

        try? await storage.save(error: errorEvent)
    }

    private nonisolated static func localPerformanceTrackingEnabled() -> Bool {
        (UserDefaults.standard.object(forKey: "performanceTrackingEnabled") as? Bool) ?? true
    }

    private nonisolated static func customProviderMetricLabel(_ config: CustomProviderConfig) -> String {
        let raw = config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? config.id
            : config.name
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}._-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        return "custom:\(normalized.isEmpty ? config.id : normalized)"
    }

    /// Classify errors for performance tracking
    private nonisolated func classifyError(_ error: Error) -> ErrorType {
        let message = error.localizedDescription.lowercased()

        // Timeout errors
        if message.contains("timed out") || message.contains("timeout") {
            return .timeout
        }

        // Quota/rate limit errors
        if message.contains("quota") || message.contains("rate limit") || message.contains("429") {
            return .quota
        }

        // Authentication errors
        if message.contains("auth") || message.contains("unauthorized") ||
            message.contains("401") || message.contains("403")
        {
            return .auth
        }

        // Network errors
        if message.contains("network") || message.contains("connection") ||
            message.contains("offline") || message.contains("no internet")
        {
            return .network
        }

        // Parsing errors
        if message.contains("json") || message.contains("decode") || message.contains("parse") {
            return .parsing
        }

        // API errors
        if message.contains("api") || message.contains("server") {
            return .apiError
        }

        return .unknown
    }
}
