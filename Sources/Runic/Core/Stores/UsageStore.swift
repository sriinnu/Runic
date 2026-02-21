import AppKit
import RunicCore
import Foundation
import Observation
import Silo
import CoreGraphics

/// **UsageStore** - Main state management for AI provider usage tracking
///
/// **Purpose:**
/// Central store managing all provider usage data, snapshots, errors, and refresh logic.
/// This is the single source of truth for the app's state.
///
/// **Responsibilities:**
/// - Fetch usage snapshots from all providers (Claude, Codex, Cursor, Gemini, etc.)
/// - Manage authentication state and cookies via Silo
/// - Track token usage across all providers
/// - Coordinate "ping" operations (manual and automatic)
/// - Handle errors and stale data detection
/// - Provide Observable state for SwiftUI views
///
/// **Performance Philosophy:**
/// - **Zero Token Leakage** - Always use cookies/cached data first before API calls
/// - **Single Ping Strategy** - One ping per provider per session, cache rest
/// - **Stale Detection** - Mark data stale after 5 minutes (PerformanceConstants.staleDuration)
///
/// **Known Issues:**
/// - **God Class** - 2089 lines, needs refactoring (see PLAN.md)
///   - Planned split: `UsageStateStore`, `UsageFetchingActor`, `TokenUsageService`
///
/// **Dependencies:**
/// - `RunicCore` - Provider descriptors and status probes
/// - `Silo` - Browser cookie access
/// - `Observation` - SwiftUI state updates
///
/// **Usage:**
/// ```swift
/// @Observable
/// final class UsageStore {
///     var snapshots: [UsageProvider: ProviderSnapshot] = [:]
///     var errors: [UsageProvider: Error] = [:]
///     
///     func ping(provider: UsageProvider) async { ... }
/// }
/// ```

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
        _ = self.ledgerActiveBlocks
        _ = self.ledgerTopModels
        _ = self.ledgerTopProjects
        _ = self.ledgerModelBreakdowns
        _ = self.ledgerProjectBreakdowns
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

enum ProviderStatusIndicator: String {
    case none
    case minor
    case major
    case critical
    case maintenance
    case unknown

    var hasIssue: Bool {
        switch self {
        case .none: false
        default: true
        }
    }

    var label: String {
        switch self {
        case .none: "Operational"
        case .minor: "Partial outage"
        case .major: "Major outage"
        case .critical: "Critical issue"
        case .maintenance: "Maintenance"
        case .unknown: "Status unknown"
        }
    }
}

enum RefreshTrigger: String {
    case manual
    case menuOpen
    case autoTimer
    case settingsChange
    case login
    case resume
    case startup

    var isAuto: Bool {
        switch self {
        case .manual, .login: false
        case .menuOpen, .autoTimer, .settingsChange, .resume, .startup: true
        }
    }

    var menuLabel: String {
        switch self {
        case .manual: "Manual"
        case .menuOpen: "Menu open"
        case .autoTimer: "Auto"
        case .settingsChange: "Settings"
        case .login: "Login"
        case .resume: "Resume"
        case .startup: "Startup"
        }
    }
}

enum AutoRefreshSuspensionReason: String {
    case systemSleep
    case screenSleep
    case sessionInactive

    var label: String {
        switch self {
        case .systemSleep: "Sleeping"
        case .screenSleep: "Display asleep"
        case .sessionInactive: "Session inactive"
        }
    }
}

enum AutoRefreshDisableReason: String {
    case idle
    case systemSleep
    case screenSleep
    case sessionInactive

    var label: String {
        switch self {
        case .idle: "idle"
        case .systemSleep: "sleep"
        case .screenSleep: "display sleep"
        case .sessionInactive: "lock"
        }
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

struct ProviderStatus {
    let indicator: ProviderStatusIndicator
    let description: String?
    let updatedAt: Date?
}

/// Tracks consecutive failures so we can ignore a single flake when we previously had fresh data.
struct ConsecutiveFailureGate {
    private(set) var streak: Int = 0

    mutating func recordSuccess() {
        self.streak = 0
    }

    mutating func reset() {
        self.streak = 0
    }

    /// Returns true when the caller should surface the error to the UI.
    mutating func shouldSurfaceError(onFailureWithPriorData hadPriorData: Bool) -> Bool {
        self.streak += 1
        if hadPriorData, self.streak == 1 { return false }
        return true
    }
}

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
    private(set) var ledgerActiveBlocks: [UsageProvider: UsageLedgerBlockSummary] = [:]
    private(set) var ledgerTopModels: [UsageProvider: UsageLedgerModelSummary] = [:]
    private(set) var ledgerTopProjects: [UsageProvider: UsageLedgerProjectSummary] = [:]
    private(set) var ledgerModelBreakdowns: [UsageProvider: [UsageLedgerModelSummary]] = [:]
    private(set) var ledgerProjectBreakdowns: [UsageProvider: [UsageLedgerProjectSummary]] = [:]
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
    @ObservationIgnored private var lastKnownSessionRemaining: [UsageProvider: Double] = [:]
    @ObservationIgnored private(set) var lastTokenFetchAt: [UsageProvider: Date] = [:]
    @ObservationIgnored private let tokenFetchTTL: TimeInterval = 60 * 60
    @ObservationIgnored private let tokenFetchTimeout: TimeInterval = 10 * 60
    @ObservationIgnored private let ledgerRefreshTTL: TimeInterval = 90
    @ObservationIgnored private let ledgerMaxAgeDays: Int = 3
    @ObservationIgnored nonisolated(unsafe) private let performanceStorage: PerformanceStorageImpl?

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
        self.sessionQuotaNotifier = sessionQuotaNotifier
        self.providerMetadata = registry.metadata
        self.lastRefreshFrequency = settings.refreshFrequency

        // Initialize performance tracking (optional, gracefully fails if unavailable)
        self.performanceStorage = try? PerformanceStorageImpl()
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

    /// Returns the login method (plan type) for the specified provider, if available.
    private func loginMethod(for provider: UsageProvider) -> String? {
        self.snapshots[provider]?.loginMethod(for: provider)
    }

    /// Returns true if the Claude account appears to be a subscription (Max, Pro, Ultra, Team).
    /// Returns false for API users or when plan cannot be determined.
    func isClaudeSubscription() -> Bool {
        Self.isSubscriptionPlan(self.loginMethod(for: .claude))
    }

    /// Determines if a login method string indicates a Claude subscription plan.
    /// Known subscription indicators: Max, Pro, Ultra, Team (case-insensitive).
    nonisolated static func isSubscriptionPlan(_ loginMethod: String?) -> Bool {
        guard let method = loginMethod?.lowercased(), !method.isEmpty else {
            return false
        }
        let subscriptionIndicators = ["max", "pro", "ultra", "team"]
        return subscriptionIndicators.contains { method.contains($0) }
    }

    func version(for provider: UsageProvider) -> String? {
        switch provider {
        case .codex: self.codexVersion
        case .claude: self.claudeVersion
        case .zai: self.zaiVersion
        case .gemini: self.geminiVersion
        case .antigravity: self.antigravityVersion
        case .cursor: self.cursorVersion
        case .factory: nil
        case .copilot: nil
        case .minimax: nil
        case .openrouter: nil
        case .groq: nil
        }
    }

    var preferredSnapshot: UsageSnapshot? {
        for provider in self.enabledProviders() {
            if let snap = self.snapshots[provider] { return snap }
        }
        return nil
    }

    var iconStyle: IconStyle {
        let enabled = self.enabledProviders()
        if enabled.count > 1 { return .combined }
        if let provider = enabled.first {
            return self.style(for: provider)
        }
        return .codex
    }

    var isStale: Bool {
        (self.isEnabled(.codex) && self.lastCodexError != nil) ||
            (self.isEnabled(.claude) && self.lastClaudeError != nil) ||
            (self.isEnabled(.zai) && self.errors[.zai] != nil) ||
            (self.isEnabled(.gemini) && self.errors[.gemini] != nil) ||
            (self.isEnabled(.antigravity) && self.errors[.antigravity] != nil) ||
            (self.isEnabled(.cursor) && self.errors[.cursor] != nil) ||
            (self.isEnabled(.factory) && self.errors[.factory] != nil) ||
            (self.isEnabled(.copilot) && self.errors[.copilot] != nil)
    }

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

    func snapshot(for provider: UsageProvider) -> UsageSnapshot? {
        self.snapshots[provider]
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

    func fetchAttempts(for provider: UsageProvider) -> [ProviderFetchAttempt] {
        self.lastFetchAttempts[provider] ?? []
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
            if ZaiSettingsReader.apiToken(environment: ProcessInfo.processInfo.environment) != nil {
                return true
            }
            return !self.settings.zaiAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    func ledgerDailySummary(for provider: UsageProvider) -> UsageLedgerDailySummary? {
        self.ledgerDailySummaries[provider]
    }

    func ledgerActiveBlock(for provider: UsageProvider) -> UsageLedgerBlockSummary? {
        self.ledgerActiveBlocks[provider]
    }

    func ledgerTopModel(for provider: UsageProvider) -> UsageLedgerModelSummary? {
        self.ledgerTopModels[provider]
    }

    func ledgerTopProject(for provider: UsageProvider) -> UsageLedgerProjectSummary? {
        self.ledgerTopProjects[provider]
    }

    func ledgerModelBreakdown(for provider: UsageProvider) -> [UsageLedgerModelSummary] {
        self.ledgerModelBreakdowns[provider] ?? []
    }

    func ledgerProjectBreakdown(for provider: UsageProvider) -> [UsageLedgerProjectSummary] {
        self.ledgerProjectBreakdowns[provider] ?? []
    }


    func ledgerError(for provider: UsageProvider) -> String? {
        self.ledgerErrors[provider]
    }

    func ledgerUpdatedAt(for provider: UsageProvider) -> Date? {
        self.ledgerUpdatedAt[provider]
    }

    func ledgerReliabilityScore(for provider: UsageProvider) -> UsageLedgerReliabilityScore? {
        UsageLedgerInsightsAdvisor.reliabilityScore(
            provider: provider,
            daily: self.ledgerDailySummary(for: provider),
            activeBlock: self.ledgerActiveBlock(for: provider),
            modelBreakdown: self.ledgerModelBreakdown(for: provider),
            projectBreakdown: self.ledgerProjectBreakdown(for: provider),
            providerError: self.error(for: provider),
            ledgerError: self.ledgerError(for: provider))
    }

    func ledgerRoutingRecommendation(for provider: UsageProvider) -> UsageLedgerRoutingRecommendation? {
        UsageLedgerInsightsAdvisor.routingRecommendation(
            modelBreakdown: self.ledgerModelBreakdown(for: provider))
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

        self.scheduleLedgerRefresh(force: forceTokenUsage, inactiveProviders: inactiveProviders)

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

        do {
            let usageData = try await fetcher.fetchUsage()
            let endTime = Date()

            // Track successful latency
            await self.trackLatency(
                provider: .codex,  // TODO: Add custom provider tracking
                requestID: requestID,
                startTime: startTime,
                endTime: endTime,
                success: true
            )

            let snapshot = CustomProviderSnapshot.from(usageData: usageData.toCustomUsageData(), config: config)
            await MainActor.run {
                self.customProviderSnapshots[id] = snapshot
                self.customProviderErrors.removeValue(forKey: id)
            }
        } catch {
            let endTime = Date()

            // Track failed latency and error
            await self.trackLatency(
                provider: .codex,  // TODO: Add custom provider tracking
                requestID: requestID,
                startTime: startTime,
                endTime: endTime,
                success: false
            )
            await self.trackError(provider: .codex, error: error)  // TODO: Add custom provider tracking

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
            return "your Mac went to sleep"
        case .screenSleep:
            return "the display went to sleep"
        case .sessionInactive:
            return "your session became inactive"
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
                return false
            case let (l?, r?):
                return abs(l.usedPercent - r.usedPercent) >= 0.1
            case (nil, _), (_, nil):
                return true
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
        let sources = self.ledgerSources(now: now, inactiveProviders: inactiveProviders)
        let providers = sources.map(\.0)
        if providers.isEmpty { return }
        if !force {
            let shouldRefresh = providers.contains { provider in
                guard let last = self.ledgerUpdatedAt[provider] else { return true }
                return now.timeIntervalSince(last) >= self.ledgerRefreshTTL
            }
            if !shouldRefresh { return }
        }
        if self.ledgerRefreshTask != nil { return }

        self.ledgerRefreshTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let result = await self.loadLedgerInsights(sources: sources, now: now)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.ledgerRefreshTask = nil
                for provider in result.providers {
                    if let error = result.errorsByProvider[provider] {
                        self.ledgerErrors[provider] = error
                    } else {
                        self.ledgerErrors.removeValue(forKey: provider)
                    }

                    if let daily = result.dailyByProvider[provider] {
                        self.ledgerDailySummaries[provider] = daily
                    } else {
                        self.ledgerDailySummaries.removeValue(forKey: provider)
                    }

                    if let block = result.activeBlocksByProvider[provider] {
                        self.ledgerActiveBlocks[provider] = block
                    } else {
                        self.ledgerActiveBlocks.removeValue(forKey: provider)
                    }

                    if let topModel = result.topModelsByProvider[provider] {
                        self.ledgerTopModels[provider] = topModel
                    } else {
                        self.ledgerTopModels.removeValue(forKey: provider)
                    }

                    if let topProject = result.topProjectsByProvider[provider] {
                        self.ledgerTopProjects[provider] = topProject
                    } else {
                        self.ledgerTopProjects.removeValue(forKey: provider)
                    }

                    if let breakdown = result.modelBreakdownsByProvider[provider] {
                        self.ledgerModelBreakdowns[provider] = breakdown
                    } else {
                        self.ledgerModelBreakdowns.removeValue(forKey: provider)
                    }

                    if let breakdown = result.projectBreakdownsByProvider[provider] {
                        self.ledgerProjectBreakdowns[provider] = breakdown
                    } else {
                        self.ledgerProjectBreakdowns.removeValue(forKey: provider)
                    }

                    if let lastActivity = result.lastActivityByProvider[provider] {
                        self.lastLedgerActivityAt[provider] = lastActivity
                    }

                    self.ledgerUpdatedAt[provider] = result.updatedAt
                }
            }
        }
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
            for provider in UsageProvider.allCases {
                if Task.isCancelled { break }
                await self.refreshTokenUsage(
                    provider,
                    force: force,
                    trigger: trigger,
                    inactiveProviders: inactiveProviders)
            }
        }
    }

    deinit {
        self.timerTask?.cancel()
        self.tokenTimerTask?.cancel()
        self.tokenRefreshSequenceTask?.cancel()
        self.ledgerRefreshTask?.cancel()
    }

    private struct LedgerRefreshResult: Sendable {
        let dailyByProvider: [UsageProvider: UsageLedgerDailySummary]
        let activeBlocksByProvider: [UsageProvider: UsageLedgerBlockSummary]
        let topModelsByProvider: [UsageProvider: UsageLedgerModelSummary]
        let topProjectsByProvider: [UsageProvider: UsageLedgerProjectSummary]
        let modelBreakdownsByProvider: [UsageProvider: [UsageLedgerModelSummary]]
        let projectBreakdownsByProvider: [UsageProvider: [UsageLedgerProjectSummary]]
        let errorsByProvider: [UsageProvider: String]
        let lastActivityByProvider: [UsageProvider: Date]
        let updatedAt: Date
        let providers: [UsageProvider]
    }

    private func ledgerSources(
        now: Date,
        inactiveProviders: Set<UsageProvider>) -> [(UsageProvider, any UsageLedgerSource)]
    {
        let candidates: [(UsageProvider, any UsageLedgerSource)] = [
            (.claude, ClaudeUsageLogSource(maxAgeDays: self.ledgerMaxAgeDays, now: now)),
            (.codex, CodexUsageLogSource(maxAgeDays: self.ledgerMaxAgeDays, now: now)),
        ]
        return candidates.filter { self.isEnabled($0.0) && !inactiveProviders.contains($0.0) }
    }

    private func loadLedgerInsights(
        sources: [(UsageProvider, any UsageLedgerSource)],
        now: Date) async -> LedgerRefreshResult
    {
        guard !sources.isEmpty else {
            return LedgerRefreshResult(
                dailyByProvider: [:],
                activeBlocksByProvider: [:],
                topModelsByProvider: [:],
                topProjectsByProvider: [:],
                modelBreakdownsByProvider: [:],
                projectBreakdownsByProvider: [:],
                errorsByProvider: [:],
                lastActivityByProvider: [:],
                updatedAt: now,
                providers: [])
        }

        let providers = sources.map(\.0)
        var entries: [UsageLedgerEntry] = []
        var errors: [UsageProvider: String] = [:]

        await withTaskGroup(of: (UsageProvider, Result<[UsageLedgerEntry], Error>).self) { group in
            for (provider, source) in sources {
                group.addTask {
                    do {
                        let loaded = try await source.loadEntries()
                        return (provider, .success(loaded))
                    } catch {
                        return (provider, .failure(error))
                    }
                }
            }

            for await (provider, result) in group {
                switch result {
                case let .success(loaded):
                    entries.append(contentsOf: loaded)
                case let .failure(error):
                    errors[provider] = error.localizedDescription
                }
            }
        }

        var lastActivityByProvider: [UsageProvider: Date] = [:]
        for entry in entries {
            if let current = lastActivityByProvider[entry.provider] {
                if entry.timestamp > current { lastActivityByProvider[entry.provider] = entry.timestamp }
            } else {
                lastActivityByProvider[entry.provider] = entry.timestamp
            }
        }

        let timeZone = TimeZone.current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let todayStart = calendar.startOfDay(for: now)

        let dailySummaries = UsageLedgerAggregator.dailySummaries(
            entries: entries,
            timeZone: timeZone,
            groupByProject: false)
        var dailyByProvider: [UsageProvider: UsageLedgerDailySummary] = [:]
        for summary in dailySummaries where summary.dayStart == todayStart {
            dailyByProvider[summary.provider] = summary
        }

        let blocks = UsageLedgerAggregator.blockSummaries(entries: entries, blockHours: 5, now: now)
        var activeByProvider: [UsageProvider: UsageLedgerBlockSummary] = [:]
        for block in blocks where block.isActive {
            if activeByProvider[block.provider] == nil {
                activeByProvider[block.provider] = block
            }
        }

        let todayEntries = entries.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
        let budgetProjectNames = self.projectNameOverridesFromBudgets()
        let modelSummaries = UsageLedgerAggregator.modelSummaries(entries: todayEntries)
        var topModelsByProvider: [UsageProvider: UsageLedgerModelSummary] = [:]
        for summary in modelSummaries {
            if topModelsByProvider[summary.provider] == nil {
                topModelsByProvider[summary.provider] = summary
            }
        }

        let projectSummaries = UsageLedgerAggregator.projectSummaries(entries: todayEntries)
            .map { self.resolvedProjectSummary($0, budgetProjectNames: budgetProjectNames) }
        var topProjectsByProvider: [UsageProvider: UsageLedgerProjectSummary] = [:]
        for summary in projectSummaries {
            if topProjectsByProvider[summary.provider] == nil {
                topProjectsByProvider[summary.provider] = summary
            }
        }

        let modelBreakdowns = UsageLedgerAggregator.modelSummaries(entries: todayEntries, groupByProject: true)
            .map { self.resolvedModelSummary($0, budgetProjectNames: budgetProjectNames) }
        var modelBreakdownsByProvider: [UsageProvider: [UsageLedgerModelSummary]] = [:]
        for summary in modelBreakdowns {
            modelBreakdownsByProvider[summary.provider, default: []].append(summary)
        }

        var projectBreakdownsByProvider: [UsageProvider: [UsageLedgerProjectSummary]] = [:]
        for summary in projectSummaries {
            projectBreakdownsByProvider[summary.provider, default: []].append(summary)
        }

        return LedgerRefreshResult(
            dailyByProvider: dailyByProvider,
            activeBlocksByProvider: activeByProvider,
            topModelsByProvider: topModelsByProvider,
            topProjectsByProvider: topProjectsByProvider,
            modelBreakdownsByProvider: modelBreakdownsByProvider,
            projectBreakdownsByProvider: projectBreakdownsByProvider,
            errorsByProvider: errors,
            lastActivityByProvider: lastActivityByProvider,
            updatedAt: now,
            providers: providers)
    }

    private func projectNameOverridesFromBudgets() -> [String: String] {
        var namesByProjectID: [String: String] = [:]
        for budget in ProjectBudgetStore.getAllBudgets() {
            let trimmed = budget.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                namesByProjectID[budget.projectID] = trimmed
            }
        }
        return namesByProjectID
    }

    private func resolvedProjectSummary(
        _ summary: UsageLedgerProjectSummary,
        budgetProjectNames: [String: String]) -> UsageLedgerProjectSummary
    {
        let budgetName = summary.projectID.flatMap { budgetProjectNames[$0] }
        let identity = UsageLedgerProjectIdentityResolver.resolve(
            provider: summary.provider,
            projectID: summary.projectID,
            projectName: summary.projectName,
            budgetNameOverride: budgetName)
        return UsageLedgerProjectSummary(
            provider: summary.provider,
            projectKey: summary.projectKey ?? identity.key,
            projectID: identity.projectID ?? summary.projectID,
            projectName: identity.displayName ?? summary.projectName,
            projectNameConfidence: identity.confidence,
            projectNameSource: identity.source,
            projectNameProvenance: identity.provenance,
            entryCount: summary.entryCount,
            totals: summary.totals,
            modelsUsed: summary.modelsUsed)
    }

    private func resolvedModelSummary(
        _ summary: UsageLedgerModelSummary,
        budgetProjectNames: [String: String]) -> UsageLedgerModelSummary
    {
        let budgetName = summary.projectID.flatMap { budgetProjectNames[$0] }
        let identity = UsageLedgerProjectIdentityResolver.resolve(
            provider: summary.provider,
            projectID: summary.projectID,
            projectName: summary.projectName,
            budgetNameOverride: budgetName)
        return UsageLedgerModelSummary(
            provider: summary.provider,
            projectKey: summary.projectKey ?? identity.key,
            projectID: identity.projectID ?? summary.projectID,
            projectName: identity.displayName ?? summary.projectName,
            projectNameConfidence: identity.confidence,
            projectNameSource: identity.source,
            projectNameProvenance: identity.provenance,
            model: summary.model,
            entryCount: summary.entryCount,
            totals: summary.totals)
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

    private func refreshOpenAIDashboardIfNeeded(force: Bool = false) async {
        guard self.isEnabled(.codex), self.settings.openAIWebAccessEnabled else {
            await MainActor.run {
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
            return
        }

        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        self.handleOpenAIWebTargetEmailChangeIfNeeded(targetEmail: targetEmail)

        let now = Date()
        let minInterval = max(self.settings.refreshFrequency.seconds ?? 0, 120)
        if !force,
           !self.openAIWebAccountDidChange,
           self.lastOpenAIDashboardError == nil,
           let snapshot = self.lastOpenAIDashboardSnapshot,
           now.timeIntervalSince(snapshot.updatedAt) < minInterval
        {
            return
        }

        if self.openAIWebDebugLines.isEmpty {
            self.resetOpenAIWebDebugLog(context: "refresh")
        } else {
            let stamp = Date().formatted(date: .abbreviated, time: .shortened)
            self.logOpenAIWeb("[\(stamp)] OpenAI web refresh start")
        }
        let log: (String) -> Void = { [weak self] line in
            guard let self else { return }
            self.logOpenAIWeb(line)
        }

        do {
            let normalized = targetEmail?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            var effectiveEmail = targetEmail

            // Use a per-email persistent `WKWebsiteDataStore` so multiple dashboard sessions can coexist.
            // Strategy:
            // - Try the existing per-email WebKit cookie store first (fast; avoids Keychain prompts).
            // - On login-required or account mismatch, import cookies from the configured browser order and retry once.
            if self.openAIWebAccountDidChange, let targetEmail, !targetEmail.isEmpty {
                // On account switches, proactively re-import cookies so we don't show stale data from the previous
                // user.
                if let imported = await self.importOpenAIDashboardCookiesIfNeeded(
                    targetEmail: targetEmail,
                    force: true)
                {
                    effectiveEmail = imported
                }
                self.openAIWebAccountDidChange = false
            }

            var dash = try await OpenAIDashboardFetcher().loadLatestDashboard(
                accountEmail: effectiveEmail,
                logger: log,
                debugDumpHTML: false)

            if self.dashboardEmailMismatch(expected: normalized, actual: dash.signedInEmail) {
                if let imported = await self.importOpenAIDashboardCookiesIfNeeded(
                    targetEmail: targetEmail,
                    force: true)
                {
                    effectiveEmail = imported
                }
                dash = try await OpenAIDashboardFetcher().loadLatestDashboard(
                    accountEmail: effectiveEmail,
                    logger: log,
                    debugDumpHTML: false)
            }

            if self.dashboardEmailMismatch(expected: normalized, actual: dash.signedInEmail) {
                let signedIn = dash.signedInEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
                await MainActor.run {
                    self.openAIDashboard = nil
                    self.lastOpenAIDashboardError = [
                        "OpenAI dashboard signed in as \(signedIn), but Codex uses \(normalized ?? "unknown").",
                        "Switch accounts in your browser and re-enable “Access OpenAI via web”.",
                    ].joined(separator: " ")
                    self.openAIDashboardRequiresLogin = true
                }
                return
            }

            await self.applyOpenAIDashboard(dash, targetEmail: effectiveEmail)
        } catch let OpenAIDashboardFetcher.FetchError.noDashboardData(body) {
            // Often indicates a missing/stale session without an obvious login prompt. Retry once after
            // importing cookies from the user's browser.
            let targetEmail = self.codexAccountEmailForOpenAIDashboard()
            var effectiveEmail = targetEmail
            if let imported = await self.importOpenAIDashboardCookiesIfNeeded(targetEmail: targetEmail, force: true) {
                effectiveEmail = imported
            }
            do {
                let dash = try await OpenAIDashboardFetcher().loadLatestDashboard(
                    accountEmail: effectiveEmail,
                    logger: log,
                    debugDumpHTML: true)
                await self.applyOpenAIDashboard(dash, targetEmail: effectiveEmail)
            } catch let OpenAIDashboardFetcher.FetchError.noDashboardData(retryBody) {
                let finalBody = retryBody.isEmpty ? body : retryBody
                let message = self.openAIDashboardFriendlyError(
                    body: finalBody,
                    targetEmail: targetEmail,
                    cookieImportStatus: self.openAIDashboardCookieImportStatus)
                    ?? OpenAIDashboardFetcher.FetchError.noDashboardData(body: finalBody).localizedDescription
                await self.applyOpenAIDashboardFailure(message: message)
            } catch {
                await self.applyOpenAIDashboardFailure(message: error.localizedDescription)
            }
        } catch OpenAIDashboardFetcher.FetchError.loginRequired {
            let targetEmail = self.codexAccountEmailForOpenAIDashboard()
            var effectiveEmail = targetEmail
            if let imported = await self.importOpenAIDashboardCookiesIfNeeded(targetEmail: targetEmail, force: true) {
                effectiveEmail = imported
            }
            do {
                let dash = try await OpenAIDashboardFetcher().loadLatestDashboard(
                    accountEmail: effectiveEmail,
                    logger: log,
                    debugDumpHTML: true)
                await self.applyOpenAIDashboard(dash, targetEmail: effectiveEmail)
            } catch OpenAIDashboardFetcher.FetchError.loginRequired {
                await MainActor.run {
                    self.lastOpenAIDashboardError = [
                        "OpenAI web access requires a signed-in chatgpt.com session.",
                        "Sign in using \(self.codexBrowserCookieOrder.loginHint), " +
                            "then re-enable “Access OpenAI via web”.",
                    ].joined(separator: " ")
                    self.openAIDashboard = self.lastOpenAIDashboardSnapshot
                    self.openAIDashboardRequiresLogin = true
                }
            } catch {
                await self.applyOpenAIDashboardFailure(message: error.localizedDescription)
            }
        } catch {
            await self.applyOpenAIDashboardFailure(message: error.localizedDescription)
        }
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
            self.openAIDashboardCookieImportStatus = "Codex account changed; importing browser cookies…"
            self.lastOpenAIDashboardCookieImportAttemptAt = nil
            self.lastOpenAIDashboardCookieImportEmail = nil
        }
    }

    func importOpenAIDashboardBrowserCookiesNow() async {
        self.resetOpenAIWebDebugLog(context: "manual import")
        let targetEmail = self.codexAccountEmailForOpenAIDashboard()
        _ = await self.importOpenAIDashboardCookiesIfNeeded(targetEmail: targetEmail, force: true)
        await self.refreshOpenAIDashboardIfNeeded(force: true)
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

        let claudeWebExtrasEnabled = self.settings.claudeWebExtrasEnabled
        let claudeUsageDataSource = self.settings.claudeUsageDataSource
        let claudeDebugMenuEnabled = self.settings.debugMenuEnabled
        return await Task.detached(priority: .utility) { () -> String in
            switch provider {
            case .codex:
                let raw = await self.codexFetcher.debugRawRateLimits()
                await MainActor.run { self.probeLogs[.codex] = raw }
                return raw
            case .claude:
                let text = await self.runWithTimeout(seconds: 15) {
                    var lines: [String] = []
                    let hasKey = ClaudeWebAPIFetcher.hasSessionKey { msg in lines.append(msg) }
                    let hasOAuthCredentials = (try? ClaudeOAuthCredentialsStore.load()) != nil

                    let strategy = ClaudeProviderDescriptor.resolveUsageStrategy(
                        debugMenuEnabled: claudeDebugMenuEnabled,
                        selectedDataSource: claudeUsageDataSource,
                        webExtrasEnabled: claudeWebExtrasEnabled,
                        hasWebSession: hasKey,
                        hasOAuthCredentials: hasOAuthCredentials)

                    await MainActor.run {
                        if self.settings.claudeUsageDataSource != strategy.dataSource {
                            self.settings.claudeUsageDataSource = strategy.dataSource
                        }
                    }

                    lines.append("strategy=\(strategy.dataSource.rawValue)")
                    lines.append("hasSessionKey=\(hasKey)")
                    lines.append("hasOAuthCredentials=\(hasOAuthCredentials)")
                    if strategy.useWebExtras {
                        lines.append("web_extras=enabled")
                    }
                    lines.append("")

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

                            return lines.joined(separator: "\n")
                        } catch {
                            lines.append("Web API failed: \(error.localizedDescription)")
                            return lines.joined(separator: "\n")
                        }
                    case .cli:
                        let cli = await self.claudeFetcher.debugRawProbe(model: "sonnet")
                        lines.append(cli)
                        return lines.joined(separator: "\n")
                    case .oauth:
                        lines.append("OAuth source selected.")
                        return lines.joined(separator: "\n")
                    }
                }
                await MainActor.run { self.probeLogs[.claude] = text }
                return text
            case .zai:
                let resolution = ProviderTokenResolver.zaiResolution()
                let hasAny = resolution != nil
                let source = resolution?.source.rawValue ?? "none"
                let text = "Z_AI_API_KEY=\(hasAny ? "present" : "missing") source=\(source)"
                await MainActor.run { self.probeLogs[.zai] = text }
                return text
            case .gemini:
                let text = "Gemini debug log not yet implemented"
                await MainActor.run { self.probeLogs[.gemini] = text }
                return text
            case .antigravity:
                let text = "Antigravity debug log not yet implemented"
                await MainActor.run { self.probeLogs[.antigravity] = text }
                return text
            case .cursor:
                let text = "Cursor debug log not yet implemented"
                await MainActor.run { self.probeLogs[.cursor] = text }
                return text
            case .factory:
                let text = "Droid debug log not yet implemented"
                await MainActor.run { self.probeLogs[.factory] = text }
                return text
            case .copilot:
                let text = "Copilot debug log not yet implemented"
                await MainActor.run { self.probeLogs[.copilot] = text }
                return text
            case .minimax:
                let text = "MiniMax debug log not yet implemented"
                await MainActor.run { self.probeLogs[.minimax] = text }
                return text
            case .openrouter:
                let text = "OpenRouter debug log not yet implemented"
                await MainActor.run { self.probeLogs[.openrouter] = text }
                return text
            case .groq:
                let text = "Groq debug log not yet implemented"
                await MainActor.run { self.probeLogs[.groq] = text }
                return text
            }
        }.value
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
                    try await fetcher.loadTokenSnapshot(provider: provider, now: now, forceRefresh: force)
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
        requestID: String,
        startTime: Date,
        endTime: Date,
        success: Bool
    ) async {
        guard let storage = self.performanceStorage else { return }

        let metric = LatencyMetric(
            id: UUID().uuidString,
            requestID: requestID,
            provider: provider,
            model: nil,
            startTime: startTime,
            endTime: endTime,
            durationMs: Int(endTime.timeIntervalSince(startTime) * 1000),
            success: success,
            createdAt: Date()
        )

        try? await storage.save(latency: metric)
    }

    /// Track API errors for performance monitoring
    private nonisolated func trackError(provider: UsageProvider, error: Error) async {
        guard let storage = self.performanceStorage else { return }

        let errorType = self.classifyError(error)
        let errorEvent = ErrorEvent(
            id: UUID().uuidString,
            provider: provider,
            errorType: errorType,
            errorMessage: error.localizedDescription,
            retryCount: 0,
            timestamp: Date()
        )

        try? await storage.save(error: errorEvent)
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
