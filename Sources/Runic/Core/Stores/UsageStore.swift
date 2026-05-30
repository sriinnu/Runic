import AppKit
import CoreGraphics
import Foundation
import Observation
import RunicCore
import Silo

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

// MARK: - Observation helpers

@MainActor
extension UsageStore {
    var menuObservationToken: Int {
        _ = self.snapshots
        _ = self.errors
        _ = self.lastSourceLabels
        _ = self.lastFetchAttempts
        _ = self.tokenSnapshots
        _ = self.tokenErrors
        _ = self.tokenRefreshInFlight
        _ = self.customProviderSnapshots
        _ = self.customProviderErrors
        _ = self.ledgerDailySummaries
        _ = self.ledgerAllDailySummaries
        _ = self.ledgerHourlySummaries
        _ = self.ledgerActiveBlocks
        _ = self.ledgerTopModels
        _ = self.ledgerTopProjects
        _ = self.ledgerModelBreakdowns
        _ = self.ledgerProjectBreakdowns
        _ = self.ledgerSpendForecasts
        _ = self.ledgerProjectSpendForecasts
        _ = self.ledgerTopProjectSpendForecasts
        _ = self.ledgerAnomalies
        _ = self.ledgerErrors
        _ = self.ledgerUpdatedAt
        _ = self.credits
        _ = self.lastCreditsError
        _ = self.openAIDashboard
        _ = self.lastOpenAIDashboardError
        _ = self.openAIDashboardRequiresLogin
        _ = self.openAIDashboardCookieImportStatus
        _ = self.openAIDashboardCookieImportDebugLog
        _ = self.codexVersion
        _ = self.claudeVersion
        _ = self.geminiVersion
        _ = self.zaiVersion
        _ = self.antigravityVersion
        _ = self.isRefreshing
        _ = self.refreshingProviders
        _ = self.pathDebugInfo
        _ = self.statuses
        _ = self.probeLogs
        _ = self.autoRefreshSuspensionReason
        _ = self.lastRefreshTrigger
        _ = self.lastRefreshAt
        _ = self.lastAutoRefreshDisableReason
        _ = self.lastAutoRefreshDisableAt
        return 0
    }

    func observeSettingsChanges() {
        withObservationTracking {
            _ = self.settings.refreshFrequency
            _ = self.settings.autoDisableRefreshWhenIdleEnabled
            _ = self.settings.autoDisableRefreshWhenIdleMinutes
            _ = self.settings.autoDisableRefreshOnSleepEnabled
            _ = self.settings.autoRefreshWarningEnabled
            _ = self.settings.autoRefreshWarningThreshold
            _ = self.settings.autoSuspendInactiveProvidersEnabled
            _ = self.settings.autoSuspendInactiveProvidersMinutes
            _ = self.settings.statusChecksEnabled
            _ = self.settings.sessionQuotaNotificationsEnabled
            _ = self.settings.usageBarsShowUsed
            _ = self.settings.costUsageEnabled
            _ = self.settings.randomBlinkEnabled
            _ = self.settings.claudeWebExtrasEnabled
            _ = self.settings.claudeUsageDataSource
            _ = self.settings.mergeIcons
            _ = self.settings.debugLoadingPattern
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeSettingsChanges()
                await self.handleSettingsChange()
            }
        }
    }
}

// MARK: - OpenAI web error messaging

extension UsageStore {
    private func openAIDashboardFriendlyError(
        body: String,
        targetEmail: String?,
        cookieImportStatus: String?) -> String?
    {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let status = cookieImportStatus?.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return [
                "OpenAI web dashboard returned an empty page.",
                "Sign in to chatgpt.com and re-enable “Access OpenAI via web”.",
            ].joined(separator: " ")
        }

        let lower = trimmed.lowercased()
        let looksLikePublicLanding = lower.contains("skip to content")
            && (lower.contains("about") || lower.contains("openai") || lower.contains("chatgpt"))
        let looksLoggedOut = lower.contains("sign in")
            || lower.contains("log in")
            || lower.contains("create account")
            || lower.contains("continue with google")
            || lower.contains("continue with apple")
            || lower.contains("continue with microsoft")

        guard looksLikePublicLanding || looksLoggedOut else { return nil }
        let emailLabel = targetEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLabel = (emailLabel?.isEmpty == false) ? emailLabel! : "your OpenAI account"
        if let status, !status.isEmpty {
            if status.contains("Browser cookies do not match Codex account")
                || status.contains("Browser cookie import failed")
            {
                return [
                    status,
                    "Sign in to chatgpt.com as \(targetLabel), then re-enable “Access OpenAI via web”.",
                ].joined(separator: " ")
            }
        }
        return [
            "OpenAI web dashboard returned a public page (not signed in).",
            "Sign in to chatgpt.com as \(targetLabel), then re-enable “Access OpenAI via web”.",
        ].joined(separator: " ")
    }
}

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
    private(set) var snapshots: [UsageProvider: UsageSnapshot] = [:]
    private(set) var errors: [UsageProvider: String] = [:]
    private(set) var lastSourceLabels: [UsageProvider: String] = [:]
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
    private(set) var openAIDashboardRequiresLogin: Bool = false
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
    private(set) var probeLogs: [UsageProvider: String] = [:]
    @ObservationIgnored private var lastCreditsSnapshot: CreditsSnapshot?
    @ObservationIgnored private var creditsFailureStreak: Int = 0
    @ObservationIgnored private var lastOpenAIDashboardSnapshot: OpenAIDashboardSnapshot?
    @ObservationIgnored private var lastOpenAIDashboardTargetEmail: String?
    @ObservationIgnored private var lastOpenAIDashboardCookieImportAttemptAt: Date?
    @ObservationIgnored private var lastOpenAIDashboardCookieImportEmail: String?
    @ObservationIgnored private var openAIWebAccountDidChange: Bool = false
    private var autoRefreshSuspensionReason: AutoRefreshSuspensionReason?
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

    @ObservationIgnored private let codexFetcher: UsageFetcher
    @ObservationIgnored private let claudeFetcher: any ClaudeUsageFetching
    @ObservationIgnored private let costUsageFetcher: CostUsageFetcher
    @ObservationIgnored private let registry: ProviderRegistry
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let processEnvironment: [String: String]
    @ObservationIgnored private let sessionQuotaNotifier: SessionQuotaNotifier
    @ObservationIgnored private let sessionQuotaLogger = RunicLog.logger("sessionQuota")
    @ObservationIgnored private let openAIWebLogger = RunicLog.logger("openai-web")
    @ObservationIgnored private let tokenCostLogger = RunicLog.logger("token-cost")
    @ObservationIgnored private var openAIWebDebugLines: [String] = []
    @ObservationIgnored private var failureGates: [UsageProvider: ConsecutiveFailureGate] = [:]
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

    private var codexBrowserCookieOrder: BrowserCookieImportOrder {
        self.metadata(for: .codex).browserCookieOrder ?? Browser.defaultImportOrder
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

    private func handleSettingsChange() async {
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

    private func applyOpenAIDashboard(_ dash: OpenAIDashboardSnapshot, targetEmail: String?) async {
        await MainActor.run {
            self.openAIDashboard = dash
            self.lastOpenAIDashboardError = nil
            self.lastOpenAIDashboardSnapshot = dash
            self.openAIDashboardRequiresLogin = false
            // Only fill gaps; OAuth/CLI remain the primary sources for usage + credits.
            if self.snapshots[.codex] == nil,
               let usage = dash.toUsageSnapshot(provider: .codex, accountEmail: targetEmail)
            {
                self.snapshots[.codex] = usage
                self.errors[.codex] = nil
                self.failureGates[.codex]?.recordSuccess()
                self.lastSourceLabels[.codex] = "openai-web"
            }
            if self.credits == nil, let credits = dash.toCreditsSnapshot() {
                self.credits = credits
                self.lastCreditsSnapshot = credits
                self.lastCreditsError = nil
                self.creditsFailureStreak = 0
            }
        }

        if let email = targetEmail, !email.isEmpty {
            OpenAIDashboardCacheStore.save(OpenAIDashboardCache(accountEmail: email, snapshot: dash))
        }
    }

    private func applyOpenAIDashboardFailure(message: String) async {
        await MainActor.run {
            if let cached = self.lastOpenAIDashboardSnapshot {
                self.openAIDashboard = cached
                let stamp = cached.updatedAt.formatted(date: .abbreviated, time: .shortened)
                self.lastOpenAIDashboardError =
                    "Last OpenAI dashboard refresh failed: \(message). Cached values from \(stamp)."
            } else {
                self.lastOpenAIDashboardError = message
                self.openAIDashboard = nil
            }
        }
    }

    private struct OpenAIDashboardRefreshContext {
        let targetEmail: String?
        let normalizedEmail: String?
        var effectiveEmail: String?
        let allowBrowserCookieImport: Bool
        let log: (String) -> Void
    }

    private struct OpenAIDashboardFetchResult {
        let dashboard: OpenAIDashboardSnapshot
        let effectiveEmail: String?
    }

    private func refreshOpenAIDashboardIfNeeded(
        force: Bool = false,
        allowBrowserCookieImport: Bool = false) async
    {
        guard self.isEnabled(.codex), self.settings.openAIWebAccessEnabled else {
            self.clearOpenAIDashboardWebState()
            return
        }

        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        self.handleOpenAIWebTargetEmailChangeIfNeeded(targetEmail: targetEmail)

        guard !self.shouldSkipOpenAIDashboardRefresh(force: force, now: Date()) else { return }
        let log = self.startOpenAIDashboardRefreshLog()
        var context = OpenAIDashboardRefreshContext(
            targetEmail: targetEmail,
            normalizedEmail: self.normalizedEmail(targetEmail),
            effectiveEmail: targetEmail,
            allowBrowserCookieImport: allowBrowserCookieImport,
            log: log)
        context.effectiveEmail = await self.effectiveOpenAIDashboardEmailAfterAccountChange(context)

        do {
            let result = try await self.loadOpenAIDashboardMatchingAccount(context)
            if self.applyOpenAIDashboardMismatchIfNeeded(result.dashboard, expected: context.normalizedEmail) {
                return
            }
            await self.applyOpenAIDashboard(result.dashboard, targetEmail: result.effectiveEmail)
        } catch let OpenAIDashboardFetcher.FetchError.noDashboardData(body) {
            await self.handleOpenAIDashboardNoData(
                body: body,
                allowBrowserCookieImport: allowBrowserCookieImport,
                log: log)
        } catch OpenAIDashboardFetcher.FetchError.loginRequired {
            await self.handleOpenAIDashboardLoginRequired(
                allowBrowserCookieImport: allowBrowserCookieImport,
                log: log)
        } catch {
            await self.applyOpenAIDashboardFailure(message: error.localizedDescription)
        }
    }

    private func clearOpenAIDashboardWebState() {
        self.openAIDashboard = nil
        self.lastOpenAIDashboardError = nil
        self.lastOpenAIDashboardSnapshot = nil
        self.lastOpenAIDashboardTargetEmail = nil
        self.openAIDashboardRequiresLogin = false
        self.openAIDashboardCookieImportStatus = nil
        self.openAIDashboardCookieImportDebugLog = nil
        self.lastOpenAIDashboardCookieImportAttemptAt = nil
        self.lastOpenAIDashboardCookieImportEmail = nil
    }

    private func shouldSkipOpenAIDashboardRefresh(force: Bool, now: Date) -> Bool {
        guard !force,
              !self.openAIWebAccountDidChange,
              self.lastOpenAIDashboardError == nil,
              let snapshot = self.lastOpenAIDashboardSnapshot
        else {
            return false
        }
        let minInterval = max(self.settings.refreshFrequency.seconds ?? 0, 120)
        return now.timeIntervalSince(snapshot.updatedAt) < minInterval
    }

    private func startOpenAIDashboardRefreshLog() -> (String) -> Void {
        if self.openAIWebDebugLines.isEmpty {
            self.resetOpenAIWebDebugLog(context: "refresh")
        } else {
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            self.logOpenAIWeb("[\(stamp)] OpenAI web refresh start")
        }
        return { [weak self] line in
            guard let self else { return }
            self.logOpenAIWeb(line)
        }
    }

    private func normalizedEmail(_ email: String?) -> String? {
        email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func effectiveOpenAIDashboardEmailAfterAccountChange(
        _ context: OpenAIDashboardRefreshContext) async -> String?
    {
        guard self.openAIWebAccountDidChange,
              let targetEmail = context.targetEmail,
              !targetEmail.isEmpty
        else {
            return context.effectiveEmail
        }
        defer { self.openAIWebAccountDidChange = false }
        guard context.allowBrowserCookieImport,
              let imported = await self.importOpenAIDashboardCookiesIfNeeded(
                targetEmail: targetEmail,
                force: true)
        else {
            self.openAIDashboardCookieImportStatus =
                "Codex account changed; import browser cookies manually to refresh web extras."
            return context.effectiveEmail
        }
        return imported
    }

    private func loadOpenAIDashboardMatchingAccount(
        _ context: OpenAIDashboardRefreshContext) async throws -> OpenAIDashboardFetchResult
    {
        var context = context
        var dashboard = try await self.loadOpenAIDashboard(
            accountEmail: context.effectiveEmail,
            log: context.log,
            debugDumpHTML: false)

        if self.dashboardEmailMismatch(expected: context.normalizedEmail, actual: dashboard.signedInEmail) {
            context.effectiveEmail = await self.importedOpenAIDashboardEmailIfAllowed(
                targetEmail: context.targetEmail,
                currentEmail: context.effectiveEmail,
                allowBrowserCookieImport: context.allowBrowserCookieImport)
            dashboard = try await self.loadOpenAIDashboard(
                accountEmail: context.effectiveEmail,
                log: context.log,
                debugDumpHTML: false)
        }

        return OpenAIDashboardFetchResult(
            dashboard: dashboard,
            effectiveEmail: context.effectiveEmail)
    }

    private func importedOpenAIDashboardEmailIfAllowed(
        targetEmail: String?,
        currentEmail: String?,
        allowBrowserCookieImport: Bool) async -> String?
    {
        guard allowBrowserCookieImport,
              let imported = await self.importOpenAIDashboardCookiesIfNeeded(
                targetEmail: targetEmail,
                force: true)
        else {
            return currentEmail
        }
        return imported
    }

    private func loadOpenAIDashboard(
        accountEmail: String?,
        log: @escaping (String) -> Void,
        debugDumpHTML: Bool) async throws -> OpenAIDashboardSnapshot
    {
        try await OpenAIDashboardFetcher().loadLatestDashboard(
            accountEmail: accountEmail,
            logger: log,
            debugDumpHTML: debugDumpHTML)
    }

    private func applyOpenAIDashboardMismatchIfNeeded(
        _ dashboard: OpenAIDashboardSnapshot,
        expected normalizedEmail: String?) -> Bool
    {
        guard self.dashboardEmailMismatch(expected: normalizedEmail, actual: dashboard.signedInEmail) else {
            return false
        }
        let signedIn = dashboard.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        self.openAIDashboard = nil
        self.lastOpenAIDashboardError = [
            "OpenAI dashboard signed in as \(signedIn), but Codex uses \(normalizedEmail ?? "unknown").",
            "Switch accounts in your browser and re-enable “Access OpenAI via web”.",
        ].joined(separator: " ")
        self.openAIDashboardRequiresLogin = true
        return true
    }

    private func handleOpenAIDashboardNoData(
        body: String,
        allowBrowserCookieImport: Bool,
        log: @escaping (String) -> Void) async
    {
        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        let effectiveEmail = await self.importedOpenAIDashboardEmailIfAllowed(
            targetEmail: targetEmail,
            currentEmail: targetEmail,
            allowBrowserCookieImport: allowBrowserCookieImport)
        guard allowBrowserCookieImport else {
            let message = self.openAIDashboardNoDataMessage(body: body, targetEmail: targetEmail)
            await self.applyOpenAIDashboardFailure(message: message)
            return
        }

        do {
            let dashboard = try await self.loadOpenAIDashboard(
                accountEmail: effectiveEmail,
                log: log,
                debugDumpHTML: true)
            await self.applyOpenAIDashboard(dashboard, targetEmail: effectiveEmail)
        } catch let OpenAIDashboardFetcher.FetchError.noDashboardData(retryBody) {
            let finalBody = retryBody.isEmpty ? body : retryBody
            let message = self.openAIDashboardNoDataMessage(body: finalBody, targetEmail: targetEmail)
            await self.applyOpenAIDashboardFailure(message: message)
        } catch {
            await self.applyOpenAIDashboardFailure(message: error.localizedDescription)
        }
    }

    private func openAIDashboardNoDataMessage(body: String, targetEmail: String?) -> String {
        self.openAIDashboardFriendlyError(
            body: body,
            targetEmail: targetEmail,
            cookieImportStatus: self.openAIDashboardCookieImportStatus)
            ?? OpenAIDashboardFetcher.FetchError.noDashboardData(body: body).localizedDescription
    }

    private func handleOpenAIDashboardLoginRequired(
        allowBrowserCookieImport: Bool,
        log: @escaping (String) -> Void) async
    {
        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        let effectiveEmail = await self.importedOpenAIDashboardEmailIfAllowed(
            targetEmail: targetEmail,
            currentEmail: targetEmail,
            allowBrowserCookieImport: allowBrowserCookieImport)
        guard allowBrowserCookieImport else {
            self.applyOpenAIDashboardLoginRequired(message: [
                "OpenAI web access requires a signed-in chatgpt.com session.",
                "Use manual browser-cookie import to refresh web extras.",
            ].joined(separator: " "))
            return
        }

        do {
            let dashboard = try await self.loadOpenAIDashboard(
                accountEmail: effectiveEmail,
                log: log,
                debugDumpHTML: true)
            await self.applyOpenAIDashboard(dashboard, targetEmail: effectiveEmail)
        } catch OpenAIDashboardFetcher.FetchError.loginRequired {
            self.applyOpenAIDashboardLoginRequired(message: [
                "OpenAI web access requires a signed-in chatgpt.com session.",
                "Sign in using \(self.codexBrowserCookieOrder.loginHint), " +
                    "then re-enable “Access OpenAI via web”.",
            ].joined(separator: " "))
        } catch {
            await self.applyOpenAIDashboardFailure(message: error.localizedDescription)
        }
    }

    private func applyOpenAIDashboardLoginRequired(message: String) {
        self.lastOpenAIDashboardError = message
        self.openAIDashboard = self.lastOpenAIDashboardSnapshot
        self.openAIDashboardRequiresLogin = true
    }

    // MARK: - OpenAI web account switching

    /// Detect Codex account email changes and clear stale OpenAI web state so the UI can't show the wrong user.
    /// This does not delete other per-email WebKit cookie stores (we keep multiple accounts around).
    func handleOpenAIWebTargetEmailChangeIfNeeded(targetEmail: String?) {
        let normalized = targetEmail?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let normalized, !normalized.isEmpty else { return }

        let previous = self.lastOpenAIDashboardTargetEmail
        self.lastOpenAIDashboardTargetEmail = normalized

        if let previous,
           !previous.isEmpty,
           previous != normalized
        {
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            self.logOpenAIWeb(
                "[\(stamp)] Codex account changed: \(previous) → \(normalized); " +
                    "clearing OpenAI web snapshot")
            self.openAIWebAccountDidChange = true
            self.openAIDashboard = nil
            self.lastOpenAIDashboardSnapshot = nil
            self.lastOpenAIDashboardError = nil
            self.openAIDashboardRequiresLogin = true
            self.openAIDashboardCookieImportStatus =
                "Codex account changed; import browser cookies manually to refresh web extras."
            self.lastOpenAIDashboardCookieImportAttemptAt = nil
            self.lastOpenAIDashboardCookieImportEmail = nil
        }
    }

    func importOpenAIDashboardBrowserCookiesNow() async {
        self.resetOpenAIWebDebugLog(context: "manual import")
        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        _ = await self.importOpenAIDashboardCookiesIfNeeded(targetEmail: targetEmail, force: true)
        await self.refreshOpenAIDashboardIfNeeded(force: true, allowBrowserCookieImport: false)
    }

    private func importOpenAIDashboardCookiesIfNeeded(targetEmail: String?, force: Bool) async -> String? {
        let normalizedTarget = targetEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowAnyAccount = normalizedTarget == nil || normalizedTarget?.isEmpty == true

        let now = Date()
        let lastEmail = self.lastOpenAIDashboardCookieImportEmail
        let lastAttempt = self.lastOpenAIDashboardCookieImportAttemptAt ?? .distantPast

        let shouldAttempt: Bool = if force {
            true
        } else {
            if allowAnyAccount {
                now.timeIntervalSince(lastAttempt) > 300
            } else {
                self.openAIDashboardRequiresLogin &&
                    (lastEmail?.lowercased() != normalizedTarget?.lowercased() || now
                        .timeIntervalSince(lastAttempt) > 300)
            }
        }

        guard shouldAttempt else { return normalizedTarget }
        self.lastOpenAIDashboardCookieImportEmail = normalizedTarget
        self.lastOpenAIDashboardCookieImportAttemptAt = now

        let stamp = now.formatted(date: .abbreviated, time: .shortened)
        let targetLabel = normalizedTarget ?? "unknown"
        self.logOpenAIWeb("[\(stamp)] import start (target=\(targetLabel))")

        do {
            let log: (String) -> Void = { [weak self] message in
                guard let self else { return }
                self.logOpenAIWeb(message)
            }

            let result = try await OpenAIDashboardBrowserCookieImporter()
                .importBestCookies(
                    intoAccountEmail: normalizedTarget,
                    allowAnyAccount: allowAnyAccount,
                    logger: log)
            let effectiveEmail = result.signedInEmail?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
                ? result.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
                : normalizedTarget
            self.lastOpenAIDashboardCookieImportEmail = effectiveEmail ?? normalizedTarget
            await MainActor.run {
                let signed = result.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchText = result.matchesCodexEmail ? "matches Codex" : "does not match Codex"
                if let signed, !signed.isEmpty {
                    self.openAIDashboardCookieImportStatus =
                        allowAnyAccount
                            ? [
                                "Using \(result.sourceLabel) cookies (\(result.cookieCount)).",
                                "Signed in as \(signed).",
                            ].joined(separator: " ")
                            : [
                                "Using \(result.sourceLabel) cookies (\(result.cookieCount)).",
                                "Signed in as \(signed) (\(matchText)).",
                            ].joined(separator: " ")
                } else {
                    self.openAIDashboardCookieImportStatus =
                        "Using \(result.sourceLabel) cookies (\(result.cookieCount))."
                }
            }
            return effectiveEmail
        } catch let err as OpenAIDashboardBrowserCookieImporter.ImportError {
            switch err {
            case let .noMatchingAccount(found):
                let foundText: String = if found.isEmpty {
                    "no signed-in session detected in \(self.codexBrowserCookieOrder.loginHint)"
                } else {
                    found
                        .sorted { lhs, rhs in
                            if lhs.sourceLabel == rhs.sourceLabel { return lhs.email < rhs.email }
                            return lhs.sourceLabel < rhs.sourceLabel
                        }
                        .map { "\($0.sourceLabel): \($0.email)" }
                        .joined(separator: " • ")
                }
                self.logOpenAIWeb("[\(stamp)] import mismatch: \(foundText)")
                await MainActor.run {
                    self.openAIDashboardCookieImportStatus = allowAnyAccount
                        ? [
                            "No signed-in OpenAI web session found.",
                            "Found \(foundText).",
                        ].joined(separator: " ")
                        : [
                            "Browser cookies do not match Codex account (\(normalizedTarget ?? "unknown")).",
                            "Found \(foundText).",
                        ].joined(separator: " ")
                    // Treat mismatch like "not logged in" for the current Codex account.
                    self.openAIDashboardRequiresLogin = true
                    self.openAIDashboard = nil
                }
            case .noCookiesFound,
                 .browserAccessDenied,
                 .dashboardStillRequiresLogin:
                self.logOpenAIWeb("[\(stamp)] import failed: \(err.localizedDescription)")
                await MainActor.run {
                    self.openAIDashboardCookieImportStatus =
                        "Browser cookie import failed: \(err.localizedDescription)"
                    self.openAIDashboardRequiresLogin = true
                }
            }
        } catch {
            self.logOpenAIWeb("[\(stamp)] import failed: \(error.localizedDescription)")
            await MainActor.run {
                self.openAIDashboardCookieImportStatus =
                    "Browser cookie import failed: \(error.localizedDescription)"
            }
        }
        return nil
    }

    private func resetOpenAIWebDebugLog(context: String) {
        let stamp = Date().formatted(date: .abbreviated, time: .shortened)
        self.openAIWebDebugLines.removeAll(keepingCapacity: true)
        self.openAIDashboardCookieImportDebugLog = nil
        self.logOpenAIWeb("[\(stamp)] OpenAI web \(context) start")
    }

    private func logOpenAIWeb(_ message: String) {
        self.openAIWebLogger.debug(message)
        self.openAIWebDebugLines.append(message)
        if self.openAIWebDebugLines.count > 240 {
            self.openAIWebDebugLines.removeFirst(self.openAIWebDebugLines.count - 240)
        }
        self.openAIDashboardCookieImportDebugLog = self.openAIWebDebugLines.joined(separator: "\n")
    }

    private func dashboardEmailMismatch(expected: String?, actual: String?) -> Bool {
        guard let expected, !expected.isEmpty else { return false }
        guard let raw = actual?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return false }
        return raw.lowercased() != expected.lowercased()
    }

    func codexAccountEmailForOpenAIDashboard() -> String? {
        let direct = self.snapshots[.codex]?.accountEmail(for: .codex)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct, !direct.isEmpty { return direct }
        let fallback = self.codexFetcher.loadAccountInfo().email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fallback, !fallback.isEmpty { return fallback }
        let cached = self.openAIDashboard?.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached, !cached.isEmpty { return cached }
        let imported = self.lastOpenAIDashboardCookieImportEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let imported, !imported.isEmpty { return imported }
        return nil
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

    func debugClaudeDump() async -> String {
        await ClaudeStatusProbe.latestDumps()
    }

    func debugLog(for provider: UsageProvider) async -> String {
        if let cached = self.probeLogs[provider], !cached.isEmpty {
            return cached
        }

        let settingsSnapshot = self.providerSettingsSnapshot()
        let debugContext = self.providerDebugContext(settings: settingsSnapshot)
        let claudeWebExtrasEnabled = self.settings.claudeWebExtrasEnabled
        let claudeUsageDataSource = self.settings.claudeUsageDataSource
        let claudeDebugMenuEnabled = self.settings.debugMenuEnabled

        return await Task.detached(priority: .utility) { () -> String in
            if provider == .codex {
                return await self.debugCodexLog()
            }
            if provider == .claude {
                return await self.debugClaudeLog(
                    debugMenuEnabled: claudeDebugMenuEnabled,
                    selectedDataSource: claudeUsageDataSource,
                    webExtrasEnabled: claudeWebExtrasEnabled)
            }
            if provider == .zai {
                return await self.debugZaiTokenLog()
            }
            return await self.debugProviderProbeLog(
                provider: provider,
                context: debugContext,
                settings: settingsSnapshot)
        }.value
    }

    private func providerSettingsSnapshot() -> ProviderSettingsSnapshot {
        ProviderSettingsSnapshot(
            debugMenuEnabled: self.settings.debugMenuEnabled,
            codex: ProviderSettingsSnapshot.CodexProviderSettings(
                usageDataSource: self.settings.codexUsageDataSource),
            claude: ProviderSettingsSnapshot.ClaudeProviderSettings(
                usageDataSource: self.settings.claudeUsageDataSource,
                webExtrasEnabled: self.settings.claudeWebExtrasEnabled),
            zai: ProviderSettingsSnapshot.ZaiProviderSettings(),
            copilot: ProviderSettingsSnapshot.CopilotProviderSettings(
                apiToken: self.providerSettingValue(self.settings.copilotAPIToken)),
            azure: ProviderSettingsSnapshot.AzureProviderSettings(
                apiToken: self.providerSettingValue(self.settings.azureOpenAIAPIToken),
                endpoint: self.providerSettingValue(self.settings.azureOpenAIEndpoint),
                deployment: self.providerSettingValue(self.settings.azureOpenAIDeployment),
                apiVersion: self.providerSettingValue(self.settings.azureOpenAIAPIVersion)),
            bedrock: ProviderSettingsSnapshot.BedrockProviderSettings(
                region: self.providerSettingValue(self.settings.bedrockRegion),
                profile: self.providerSettingValue(self.settings.bedrockAWSProfile),
                modelID: self.providerSettingValue(self.settings.bedrockModelID)),
            vertexai: ProviderSettingsSnapshot.VertexAIProviderSettings(
                project: self.providerSettingValue(self.settings.vertexaiProject),
                location: self.providerSettingValue(self.settings.vertexaiLocation)))
    }

    private func providerSettingValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func providerDebugContext(settings: ProviderSettingsSnapshot) -> ProviderFetchContext {
        ProviderFetchContext(
            runtime: .app,
            sourceMode: .auto,
            includeCredits: true,
            webTimeout: 15,
            webDebugDumpHTML: false,
            verbose: false,
            env: ProcessInfo.processInfo.environment,
            settings: settings,
            fetcher: self.codexFetcher,
            claudeFetcher: self.claudeFetcher)
    }

    private nonisolated func debugCodexLog() async -> String {
        let raw = await self.codexFetcher.debugRawRateLimits()
        await self.cacheProbeLog(raw, for: .codex)
        return raw
    }

    private nonisolated func debugClaudeLog(
        debugMenuEnabled: Bool,
        selectedDataSource: ClaudeUsageDataSource,
        webExtrasEnabled: Bool) async -> String
    {
        let text = await self.runWithTimeout(seconds: 15) {
            var lines: [String] = []
            let hasKey = ClaudeWebAPIFetcher.hasSessionKey { msg in lines.append(msg) }
            let hasOAuthCredentials = (try? ClaudeOAuthCredentialsStore.load()) != nil

            let strategy = ClaudeProviderDescriptor.resolveUsageStrategy(
                debugMenuEnabled: debugMenuEnabled,
                selectedDataSource: selectedDataSource,
                webExtrasEnabled: webExtrasEnabled,
                hasWebSession: hasKey,
                hasOAuthCredentials: hasOAuthCredentials)
            let automaticCLIFallbackSkipped = strategy.dataSource == .cli && !debugMenuEnabled

            if !automaticCLIFallbackSkipped {
                await MainActor.run {
                    if self.settings.claudeUsageDataSource != strategy.dataSource {
                        self.settings.claudeUsageDataSource = strategy.dataSource
                    }
                }
            }

            lines.append("strategy=\(strategy.dataSource.rawValue)")
            lines.append("hasSessionKey=\(hasKey)")
            lines.append("hasOAuthCredentials=\(hasOAuthCredentials)")
            if strategy.useWebExtras {
                lines.append("web_extras=enabled")
            }
            if automaticCLIFallbackSkipped {
                lines.append("cli_auto_fallback=skipped_to_avoid_password_prompt")
                lines.append("")
                lines.append(
                    "Enable the Debug menu and choose Claude CLI source only " +
                        "when you want Runic to launch the Claude CLI explicitly.")
                return lines.joined(separator: "\n")
            }
            lines.append("")

            return await self.debugClaudeSelectedSourceLines(
                strategy: strategy,
                existingLines: lines)
        }
        await self.cacheProbeLog(text, for: .claude)
        return text
    }

    private nonisolated func debugClaudeSelectedSourceLines(
        strategy: ClaudeUsageStrategy,
        existingLines: [String]) async -> String
    {
        var lines = existingLines
        switch strategy.dataSource {
        case .web:
            do {
                let web = try await ClaudeWebAPIFetcher.fetchUsage { msg in lines.append(msg) }
                lines.append("")
                lines.append("Web API summary:")

                let sessionReset = web.sessionResetsAt?.description ?? "nil"
                lines.append("session_used=\(web.sessionPercentUsed)% resetsAt=\(sessionReset)")

                if let weekly = web.weeklyPercentUsed {
                    let weeklyReset = web.weeklyResetsAt?.description ?? "nil"
                    lines.append("weekly_used=\(weekly)% resetsAt=\(weeklyReset)")
                } else {
                    lines.append("weekly_used=nil")
                }

                lines.append("opus_used=\(web.opusPercentUsed?.description ?? "nil")")

                if let extra = web.extraUsageCost {
                    let resetsAt = extra.resetsAt?.description ?? "nil"
                    let period = extra.period ?? "nil"
                    let line =
                        "extra_usage used=\(extra.used) limit=\(extra.limit) " +
                            "currency=\(extra.currencyCode) period=\(period) resetsAt=\(resetsAt)"
                    lines.append(line)
                } else {
                    lines.append("extra_usage=nil")
                }
            } catch {
                lines.append("Web API failed: \(error.localizedDescription)")
            }
        case .cli:
            let cli = await self.claudeFetcher.debugRawProbe(model: "sonnet")
            lines.append(cli)
        case .oauth:
            lines.append("OAuth source selected.")
        }
        return lines.joined(separator: "\n")
    }

    private nonisolated func debugZaiTokenLog() async -> String {
        let text = self.debugTokenSummary(
            provider: "zai",
            resolution: ProviderTokenResolver.zaiResolution())
        await self.cacheProbeLog(text, for: .zai)
        return text
    }

    private nonisolated func debugProviderProbeLog(
        provider: UsageProvider,
        context: ProviderFetchContext,
        settings: ProviderSettingsSnapshot) async -> String
    {
        let text = await self.runWithTimeout(seconds: 15) {
            await self.debugProviderProbe(
                provider: provider,
                context: context,
                settings: settings)
        }
        await self.cacheProbeLog(text, for: provider)
        return text
    }

    private nonisolated func cacheProbeLog(_ text: String, for provider: UsageProvider) async {
        await MainActor.run {
            self.probeLogs[provider] = text
        }
    }

    private nonisolated func debugProviderProbe(
        provider: UsageProvider,
        context: ProviderFetchContext,
        settings: ProviderSettingsSnapshot) async -> String
    {
        var lines = [
            "provider=\(provider.rawValue)",
        ]

        lines.append(contentsOf: self.debugCredentialLines(for: provider, settings: settings))
        let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
        let outcome = await descriptor.fetchOutcome(context: context)
        lines.append(contentsOf: self.debugAttemptLines(from: outcome.attempts))

        switch outcome.result {
        case let .success(result):
            lines.append("result=success")
            lines.append("strategy_id=\(result.strategyID)")
            lines.append("strategy_kind=\(self.debugStrategyKindLabel(result.strategyKind))")
            lines.append("source_label=\(result.sourceLabel)")
            lines.append(contentsOf: self.debugUsageSummary(result.usage))
        case let .failure(error):
            lines.append("result=failure")
            lines.append("error=\(error.localizedDescription)")
        }

        return lines.joined(separator: "\n")
    }

    private nonisolated func debugCredentialLines(
        for provider: UsageProvider,
        settings: ProviderSettingsSnapshot) -> [String]
    {
        if let tokenSources = UsageDebugCredentialCatalog.tokenSourcesByProvider[provider] {
            return tokenSources.map { source in
                self.debugTokenSummary(provider: source.label, resolution: source.resolution())
            }
        }
        return self.debugProviderSettingLines(for: provider, settings: settings)
    }

    private nonisolated func debugProviderSettingLines(
        for provider: UsageProvider,
        settings: ProviderSettingsSnapshot) -> [String]
    {
        switch provider {
        case .azure:
            var lines: [String] = [
                "azure.endpoint=\(self.debugFieldValue(settings.azure?.endpoint))",
                "azure.deployment=\(self.debugFieldValue(settings.azure?.deployment))",
                "azure.apiVersion=\(self.debugFieldValue(settings.azure?.apiVersion))",
            ]
            lines.append(self.debugTokenSummary(
                provider: "azure.token",
                resolution: ProviderTokenResolver.azureOpenAIResolution()))
            return lines
        case .bedrock:
            return [
                "bedrock.region=\(self.debugFieldValue(settings.bedrock?.region))",
                "bedrock.profile=\(self.debugFieldValue(settings.bedrock?.profile))",
                "bedrock.model_filter=\(self.debugFieldValue(settings.bedrock?.modelID))",
            ]
        case .vertexai:
            return [
                "vertexai.project=\(self.debugFieldValue(settings.vertexai?.project))",
                "vertexai.location=\(self.debugFieldValue(settings.vertexai?.location))",
            ]
        case .gemini:
            return [
                "gemini.authType=\(GeminiStatusProbe.currentAuthType().rawValue)",
            ]
        case .localLLM:
            return [
                "local_llm.discovery=ollama:11434,lmstudio:1234,vllm:8000,llama.cpp:8080,openwebui:3000",
                "local_llm.api_cost=not_applicable",
            ]
        case .antigravity, .cursor, .factory:
            return ["credentials=provider_internal"]
        default:
            return []
        }
    }

    private nonisolated func debugAttemptLines(from attempts: [ProviderFetchAttempt]) -> [String] {
        var lines: [String] = []
        if attempts.isEmpty {
            lines.append("attempts=none")
            return lines
        }

        let attemptSummary = attempts.enumerated().map { index, attempt in
            let error = attempt.errorDescription ?? "nil"
            return [
                "attempt\(index + 1):",
                "id=\(attempt.strategyID)",
                "kind=\(attempt.kind)",
                "available=\(attempt.wasAvailable)",
                "error=\(error)",
            ].joined(separator: " ")
        }
        lines.append("attempts=\(attempts.count)")
        lines.append(contentsOf: attemptSummary)
        return lines
    }

    private nonisolated func debugUsageSummary(_ snapshot: UsageSnapshot) -> [String] {
        var lines: [String] = []
        lines.append(self.debugRateWindowSummary(label: "primary", window: snapshot.primary))
        if let secondary = snapshot.secondary {
            lines.append(self.debugRateWindowSummary(label: "secondary", window: secondary))
        }
        if let tertiary = snapshot.tertiary {
            lines.append(self.debugRateWindowSummary(label: "tertiary", window: tertiary))
        }
        if let identity = snapshot.identity {
            lines.append("identity.email=\(identity.accountEmail ?? "nil")")
            lines.append("identity.organization=\(identity.accountOrganization ?? "nil")")
            lines.append("identity.loginMethod=\(identity.loginMethod ?? "nil")")
        }
        if let providerCost = snapshot.providerCost {
            let resetsAt = providerCost.resetsAt?.description ?? "nil"
            lines.append(
                "provider_cost.used=\(providerCost.used) limit=\(providerCost.limit) " +
                    "currency=\(providerCost.currencyCode) " +
                    "period=\(providerCost.period ?? "nil") resetsAt=\(resetsAt)")
        }
        return lines
    }

    private nonisolated func debugRateWindowSummary(label: String, window: RateWindow) -> String {
        let resetsAt = window.resetsAt?.description ?? "nil"
        let windowMinutes = window.windowMinutes.map { "\($0)m" } ?? "nil"
        let resetDescription = window.resetDescription ?? "nil"
        let windowLabel = window.label ?? "nil"
        let used = String(format: "%.2f", window.usedPercent)
        let remaining = String(format: "%.2f", window.remainingPercent)
        return [
            "\(label).usedPercent=\(used)",
            "remainingPercent=\(remaining)",
            "window=\(windowMinutes)",
            "resetsAt=\(resetsAt)",
            "label=\(windowLabel)",
            "desc=\(resetDescription)",
        ].joined(separator: " ")
    }

    private nonisolated func debugTokenSummary(provider: String, resolution: ProviderTokenResolution?) -> String {
        let tokenState = resolution == nil ? "missing" : "present"
        let source = resolution.flatMap { r in
            let key = r.sourceKey.map { "(\($0))" } ?? ""
            return "\(r.source.rawValue)\(key)"
        } ?? "nil"
        let length = resolution?.token.count ?? 0
        return "\(provider)=\(tokenState) source=\(source) length=\(length)"
    }

    private nonisolated func debugFieldValue(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "missing" : trimmed
    }

    private nonisolated func debugStrategyKindLabel(_ kind: ProviderFetchKind) -> String {
        switch kind {
        case .cli: "cli"
        case .api: "api"
        case .web: "web"
        case .oauth: "oauth"
        case .apiToken: "apiToken"
        case .localProbe: "localProbe"
        case .webDashboard: "webDashboard"
        }
    }

    private func runWithTimeout(seconds: Double, operation: @escaping @Sendable () async -> String) async -> String {
        await withTaskGroup(of: String?.self) { group -> String in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let result = await group.next()?.flatMap(\.self)
            group.cancelAll()
            return result ?? "Probe timed out after \(Int(seconds))s"
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

// swiftlint:disable:this file_length
