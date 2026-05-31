import Foundation
import Observation
import RunicCore

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
// **Evolution:**
// - Observable state is still broad; move domain state into focused stores when behavior changes.
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

@MainActor
@Observable
final class UsageStore {
    var snapshots: [UsageProvider: UsageSnapshot] = [:]
    var errors: [UsageProvider: String] = [:]
    var lastSourceLabels: [UsageProvider: String] = [:]
    var lastFetchAttempts: [UsageProvider: [ProviderFetchAttempt]] = [:]
    var tokenSnapshots: [UsageProvider: CostUsageTokenSnapshot] = [:]
    // Custom provider snapshots
    var customProviderSnapshots: [String: CustomProviderSnapshot] = [:]
    var customProviderErrors: [String: String] = [:]
    var tokenErrors: [UsageProvider: String] = [:]
    var tokenRefreshInFlight: Set<UsageProvider> = []
    var ledgerDailySummaries: [UsageProvider: UsageLedgerDailySummary] = [:]
    var ledgerAllDailySummaries: [UsageProvider: [UsageLedgerDailySummary]] = [:]
    var ledgerHourlySummaries: [UsageProvider: [UsageLedgerHourlySummary]] = [:]
    var ledgerActiveBlocks: [UsageProvider: UsageLedgerBlockSummary] = [:]
    var ledgerTopModels: [UsageProvider: UsageLedgerModelSummary] = [:]
    var ledgerTopProjects: [UsageProvider: UsageLedgerProjectSummary] = [:]
    var ledgerModelBreakdowns: [UsageProvider: [UsageLedgerModelSummary]] = [:]
    var ledgerProjectBreakdowns: [UsageProvider: [UsageLedgerProjectSummary]] = [:]
    var ledgerSpendForecasts: [UsageProvider: UsageLedgerSpendForecast] = [:]
    var ledgerProjectSpendForecasts: [UsageProvider: [UsageLedgerSpendForecast]] = [:]
    var ledgerTopProjectSpendForecasts: [UsageProvider: UsageLedgerSpendForecast] = [:]
    var ledgerAnomalies: [UsageProvider: UsageLedgerAnomalySummary] = [:]
    var ledgerCompactions: [UsageProvider: UsageLedgerCompactionSummary] = [:]
    var ledgerErrors: [UsageProvider: String] = [:]
    var ledgerUpdatedAt: [UsageProvider: Date] = [:]
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
    var refreshingProviders: Set<UsageProvider> = []
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
    var lastRefreshTrigger: RefreshTrigger?
    var lastRefreshAt: Date?
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
    @ObservationIgnored let sessionQuotaNotifier: SessionQuotaNotifier
    @ObservationIgnored let sessionQuotaLogger = RunicLog.logger("sessionQuota")
    @ObservationIgnored let openAIWebLogger = RunicLog.logger("openai-web")
    @ObservationIgnored let tokenCostLogger = RunicLog.logger("token-cost")
    @ObservationIgnored var openAIWebDebugLines: [String] = []
    @ObservationIgnored var failureGates: [UsageProvider: ConsecutiveFailureGate] = [:]
    @ObservationIgnored var tokenFailureGates: [UsageProvider: ConsecutiveFailureGate] = [:]
    @ObservationIgnored var providerSpecs: [UsageProvider: ProviderSpec] = [:]
    @ObservationIgnored let providerMetadata: [UsageProvider: ProviderMetadata]
    @ObservationIgnored var timerTask: Task<Void, Never>?
    @ObservationIgnored var tokenTimerTask: Task<Void, Never>?
    @ObservationIgnored var tokenRefreshSequenceTask: Task<Void, Never>?
    @ObservationIgnored var ledgerRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var runtimeStarted = false
    @ObservationIgnored var requestedLedgerMaxAgeDays: Int?
    @ObservationIgnored var providerHistoryMonthCache: [
        UsageProvider: [String: ProviderHistoryMonthCacheEntry]
    ] =
        [:]
    @ObservationIgnored var lastKnownSessionRemaining: [UsageProvider: Double] = [:]
    @ObservationIgnored var lastTokenFetchAt: [UsageProvider: Date] = [:]
    @ObservationIgnored let tokenFetchTTL: TimeInterval = 60 * 60
    @ObservationIgnored let tokenFetchTimeout: TimeInterval = 10 * 60
    @ObservationIgnored let ledgerRefreshTTL: TimeInterval = 90

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
