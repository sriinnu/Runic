import AppKit
import RunicCore
import Observation
import ServiceManagement

enum RefreshFrequency: String, CaseIterable, Identifiable {
    case manual
    case oneMinute
    case twoMinutes
    case fiveMinutes
    case fifteenMinutes

    var id: String { self.rawValue }

    var seconds: TimeInterval? {
        switch self {
        case .manual: nil
        case .oneMinute: 60
        case .twoMinutes: 120
        case .fiveMinutes: 300
        case .fifteenMinutes: 900
        }
    }

    var label: String {
        switch self {
        case .manual: "Manual"
        case .oneMinute: "1 min"
        case .twoMinutes: "2 min"
        case .fiveMinutes: "5 min"
        case .fifteenMinutes: "15 min"
        }
    }
}

enum UsageMetricDisplayMode: String, CaseIterable, Identifiable {
    case barsAndPercent
    case barsOnly
    case percentOnly

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .barsAndPercent: "Bars + %"
        case .barsOnly: "Bars"
        case .percentOnly: "%"
        }
    }

    var showsBars: Bool {
        switch self {
        case .barsAndPercent, .barsOnly:
            true
        case .percentOnly:
            false
        }
    }

    var showsPercent: Bool {
        switch self {
        case .barsAndPercent, .percentOnly:
            true
        case .barsOnly:
            false
        }
    }
}

enum MenuMode: String, CaseIterable, Identifiable {
    case glance
    case analyst
    case `operator`

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .glance:
            "Glance"
        case .analyst:
            "Analyst"
        case .`operator`:
            "Operator"
        }
    }
}

enum ChartStyle: String, CaseIterable, Identifiable {
    case line
    case area
    case bar

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .line: return "Line"
        case .area: return "Area"
        case .bar: return "Bar"
        }
    }
}

enum NumberFormat: String, CaseIterable, Identifiable {
    case abbreviated
    case full

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .abbreviated: return "Abbreviated"
        case .full: return "Full"
        }
    }
}

enum DateFormat: String, CaseIterable, Identifiable {
    case relative
    case absolute

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .relative: return "Relative"
        case .absolute: return "Absolute"
        }
    }
}

enum Theme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum ProviderSwitcherLayout: String, CaseIterable, Identifiable {
    case top
    case sidebar

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .top: return "Top"
        case .sidebar: return "Sidebar"
        }
    }
}

enum ProviderSwitcherIconSize: String, CaseIterable, Identifiable {
    case small
    case medium

    var id: String { self.rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        }
    }
}

@MainActor
@Observable
final class SettingsStore {
    /// Persisted provider display order.
    ///
    /// Stored as raw `UsageProvider` strings so new providers can be appended automatically without breaking.
    private var providerOrderRaw: [String] {
        didSet { self.userDefaults.set(self.providerOrderRaw, forKey: "providerOrder") }
    }

    var refreshFrequency: RefreshFrequency {
        didSet { self.userDefaults.set(self.refreshFrequency.rawValue, forKey: "refreshFrequency") }
    }

    var autoDisableRefreshWhenIdleEnabled: Bool {
        didSet { self.userDefaults.set(self.autoDisableRefreshWhenIdleEnabled, forKey: "autoDisableRefreshWhenIdleEnabled") }
    }

    var autoDisableRefreshWhenIdleMinutes: Int {
        didSet { self.userDefaults.set(self.autoDisableRefreshWhenIdleMinutes, forKey: "autoDisableRefreshWhenIdleMinutes") }
    }

    var autoDisableRefreshOnSleepEnabled: Bool {
        didSet { self.userDefaults.set(self.autoDisableRefreshOnSleepEnabled, forKey: "autoDisableRefreshOnSleepEnabled") }
    }

    var autoRefreshWarningEnabled: Bool {
        didSet { self.userDefaults.set(self.autoRefreshWarningEnabled, forKey: "autoRefreshWarningEnabled") }
    }

    var autoRefreshWarningThreshold: Int {
        didSet { self.userDefaults.set(self.autoRefreshWarningThreshold, forKey: "autoRefreshWarningThreshold") }
    }

    var autoSuspendInactiveProvidersEnabled: Bool {
        didSet {
            self.userDefaults.set(self.autoSuspendInactiveProvidersEnabled, forKey: "autoSuspendInactiveProvidersEnabled")
        }
    }

    var autoSuspendInactiveProvidersMinutes: Int {
        didSet {
            self.userDefaults.set(self.autoSuspendInactiveProvidersMinutes, forKey: "autoSuspendInactiveProvidersMinutes")
        }
    }

    var launchAtLogin: Bool {
        didSet {
            self.userDefaults.set(self.launchAtLogin, forKey: "launchAtLogin")
            LaunchAtLoginManager.setEnabled(self.launchAtLogin)
        }
    }

    /// Hidden toggle to reveal debug-only menu items (enable via defaults write com.sriinnu.athena.Runic debugMenuEnabled
    /// -bool YES).
    var debugMenuEnabled: Bool {
        didSet { self.userDefaults.set(self.debugMenuEnabled, forKey: "debugMenuEnabled") }
    }

    private var debugLoadingPatternRaw: String? {
        didSet {
            if let raw = self.debugLoadingPatternRaw {
                self.userDefaults.set(raw, forKey: "debugLoadingPattern")
            } else {
                self.userDefaults.removeObject(forKey: "debugLoadingPattern")
            }
        }
    }

    var statusChecksEnabled: Bool {
        didSet { self.userDefaults.set(self.statusChecksEnabled, forKey: "statusChecksEnabled") }
    }

    var sessionQuotaNotificationsEnabled: Bool {
        didSet {
            self.userDefaults.set(self.sessionQuotaNotificationsEnabled, forKey: "sessionQuotaNotificationsEnabled")
        }
    }

    /// When enabled, progress bars show "percent used" instead of "percent left".
    var usageBarsShowUsed: Bool {
        didSet { self.userDefaults.set(self.usageBarsShowUsed, forKey: "usageBarsShowUsed") }
    }

    var usageMetricDisplayMode: UsageMetricDisplayMode {
        didSet {
            self.userDefaults.set(self.usageMetricDisplayMode.rawValue, forKey: "usageMetricDisplayMode")
        }
    }

    var menuMode: MenuMode {
        didSet {
            self.userDefaults.set(self.menuMode.rawValue, forKey: "menuMode")
        }
    }

    var chartStyle: ChartStyle {
        didSet { self.userDefaults.set(self.chartStyle.rawValue, forKey: "chartStyle") }
    }

    var numberFormat: NumberFormat {
        didSet { self.userDefaults.set(self.numberFormat.rawValue, forKey: "numberFormat") }
    }

    var dateFormat: DateFormat {
        didSet { self.userDefaults.set(self.dateFormat.rawValue, forKey: "dateFormat") }
    }

    var theme: Theme {
        didSet { self.userDefaults.set(self.theme.rawValue, forKey: "theme") }
    }

    /// Optional: use provider branding icons with a percentage in the menu bar.
    var menuBarShowsBrandIconWithPercent: Bool {
        didSet {
            self.userDefaults.set(self.menuBarShowsBrandIconWithPercent, forKey: "menuBarShowsBrandIconWithPercent")
        }
    }

    /// Optional: render the menu bar icon with a vibrant, data-reactive color.
    var menuBarVibrantIconEnabled: Bool {
        didSet {
            self.userDefaults.set(self.menuBarVibrantIconEnabled, forKey: "menuBarVibrantIconEnabled")
        }
    }

    /// Optional: show provider cost summary from local usage logs (Codex + Claude).
    var costUsageEnabled: Bool {
        didSet { self.userDefaults.set(self.costUsageEnabled, forKey: "tokenCostUsageEnabled") }
    }

    /// Optional: limit how many insight rows appear in the menu before "More…".
    var insightsMenuMaxItems: Int {
        didSet { self.userDefaults.set(self.insightsMenuMaxItems, forKey: "insightsMenuMaxItems") }
    }

    /// Optional: how many days to include in the insights report.
    var insightsReportDays: Int {
        didSet { self.userDefaults.set(self.insightsReportDays, forKey: "insightsReportDays") }
    }

    var randomBlinkEnabled: Bool {
        didSet { self.userDefaults.set(self.randomBlinkEnabled, forKey: "randomBlinkEnabled") }
    }

    /// Optional: augment Claude usage with claude.ai web API (via browser cookies),
    /// incl. "Extra usage" spend.
    var claudeWebExtrasEnabled: Bool {
        didSet { self.userDefaults.set(self.claudeWebExtrasEnabled, forKey: "claudeWebExtrasEnabled") }
    }

    /// Optional: show Codex credits + Claude extra usage sections in the menu UI.
    var showOptionalCreditsAndExtraUsage: Bool {
        didSet {
            self.userDefaults.set(self.showOptionalCreditsAndExtraUsage, forKey: "showOptionalCreditsAndExtraUsage")
        }
    }

    /// Optional: fetch OpenAI web dashboard extras for Codex (browser cookies).
    var openAIWebAccessEnabled: Bool {
        didSet { self.userDefaults.set(self.openAIWebAccessEnabled, forKey: "openAIWebAccessEnabled") }
    }

    private var codexUsageDataSourceRaw: String? {
        didSet {
            if let raw = self.codexUsageDataSourceRaw {
                self.userDefaults.set(raw, forKey: "codexUsageDataSource")
            } else {
                self.userDefaults.removeObject(forKey: "codexUsageDataSource")
            }
        }
    }

    private var claudeUsageDataSourceRaw: String? {
        didSet {
            if let raw = self.claudeUsageDataSourceRaw {
                self.userDefaults.set(raw, forKey: "claudeUsageDataSource")
            } else {
                self.userDefaults.removeObject(forKey: "claudeUsageDataSource")
            }
        }
    }

    /// Optional: collapse provider icons into a single menu bar item with an in-menu switcher.
    var mergeIcons: Bool {
        didSet { self.userDefaults.set(self.mergeIcons, forKey: "mergeIcons") }
    }

    /// Optional: show provider icons in the in-menu switcher.
    var switcherShowsIcons: Bool {
        didSet { self.userDefaults.set(self.switcherShowsIcons, forKey: "switcherShowsIcons") }
    }

    /// Optional: position the provider switcher either on top or in a left sidebar.
    var providerSwitcherLayout: ProviderSwitcherLayout {
        didSet {
            self.userDefaults.set(self.providerSwitcherLayout.rawValue, forKey: "providerSwitcherLayout")
        }
    }

    /// Optional: size of provider icons in the switcher.
    var providerSwitcherIconSize: ProviderSwitcherIconSize {
        didSet {
            self.userDefaults.set(self.providerSwitcherIconSize.rawValue, forKey: "providerSwitcherIconSize")
        }
    }

    /// Show the built-in providers pane as a sidebar (true) or flat list (false).
    var providersPaneSidebar: Bool {
        didSet { self.userDefaults.set(self.providersPaneSidebar, forKey: "providersPaneSidebar") }
    }

    /// z.ai API token (stored in Keychain).
    var zaiAPIToken: String {
        didSet { self.schedulePersistZaiAPIToken() }
    }

    /// MiniMax API token (stored in Keychain).
    var minimaxAPIToken: String {
        didSet { self.schedulePersistMiniMaxAPIToken() }
    }

    /// MiniMax manual Cookie header (stored in Keychain).
    var minimaxCookieHeader: String {
        didSet { self.schedulePersistMiniMaxCookieHeader() }
    }

    /// MiniMax Group ID (stored in Keychain).
    var minimaxGroupID: String {
        didSet { self.schedulePersistMiniMaxGroupID() }
    }

    /// Copilot API token (stored in Keychain).
    var copilotAPIToken: String {
        didSet { self.schedulePersistCopilotAPIToken() }
    }

    /// OpenRouter API key (stored in Keychain).
    var openRouterAPIToken: String {
        didSet { self.schedulePersistOpenRouterAPIToken() }
    }

    /// Groq API key (stored in Keychain).
    var groqAPIToken: String {
        didSet { self.schedulePersistGroqAPIToken() }
    }

    private var selectedMenuProviderRaw: String? {
        didSet {
            if let raw = self.selectedMenuProviderRaw {
                self.userDefaults.set(raw, forKey: "selectedMenuProvider")
            } else {
                self.userDefaults.removeObject(forKey: "selectedMenuProvider")
            }
        }
    }

    /// Optional override for the loading animation pattern, exposed via the Debug tab.
    var debugLoadingPattern: LoadingPattern? {
        get { self.debugLoadingPatternRaw.flatMap(LoadingPattern.init(rawValue:)) }
        set {
            self.debugLoadingPatternRaw = newValue?.rawValue
        }
    }

    var selectedMenuProvider: UsageProvider? {
        get { self.selectedMenuProviderRaw.flatMap(UsageProvider.init(rawValue:)) }
        set {
            self.selectedMenuProviderRaw = newValue?.rawValue
        }
    }

    var codexUsageDataSource: CodexUsageDataSource {
        get { CodexUsageDataSource(rawValue: self.codexUsageDataSourceRaw ?? "") ?? .oauth }
        set {
            self.codexUsageDataSourceRaw = newValue.rawValue
        }
    }

    var claudeUsageDataSource: ClaudeUsageDataSource {
        get { ClaudeUsageDataSource(rawValue: self.claudeUsageDataSourceRaw ?? "") ?? .oauth }
        set {
            self.claudeUsageDataSourceRaw = newValue.rawValue
            if newValue != .cli {
                self.claudeWebExtrasEnabled = false
            }
        }
    }

    var menuObservationToken: Int {
        _ = self.providerOrderRaw
        _ = self.refreshFrequency
        _ = self.autoDisableRefreshWhenIdleEnabled
        _ = self.autoDisableRefreshWhenIdleMinutes
        _ = self.autoDisableRefreshOnSleepEnabled
        _ = self.autoRefreshWarningEnabled
        _ = self.autoRefreshWarningThreshold
        _ = self.autoSuspendInactiveProvidersEnabled
        _ = self.autoSuspendInactiveProvidersMinutes
        _ = self.launchAtLogin
        _ = self.debugMenuEnabled
        _ = self.statusChecksEnabled
        _ = self.sessionQuotaNotificationsEnabled
        _ = self.usageBarsShowUsed
        _ = self.usageMetricDisplayMode
        _ = self.menuMode
        _ = self.chartStyle
        _ = self.numberFormat
        _ = self.dateFormat
        _ = self.theme
        _ = self.menuBarShowsBrandIconWithPercent
        _ = self.menuBarVibrantIconEnabled
        _ = self.costUsageEnabled
        _ = self.insightsMenuMaxItems
        _ = self.insightsReportDays
        _ = self.randomBlinkEnabled
        _ = self.claudeWebExtrasEnabled
        _ = self.showOptionalCreditsAndExtraUsage
        _ = self.openAIWebAccessEnabled
        _ = self.codexUsageDataSource
        _ = self.claudeUsageDataSource
        _ = self.mergeIcons
        _ = self.switcherShowsIcons
        _ = self.providerSwitcherLayout
        _ = self.providerSwitcherIconSize
        _ = self.zaiAPIToken
        _ = self.minimaxAPIToken
        _ = self.minimaxCookieHeader
        _ = self.minimaxGroupID
        _ = self.copilotAPIToken
        _ = self.openRouterAPIToken
        _ = self.groqAPIToken
        _ = self.debugLoadingPattern
        _ = self.selectedMenuProvider
        _ = self.providerToggleRevision
        return 0
    }

    private var providerDetectionCompleted: Bool {
        didSet { self.userDefaults.set(self.providerDetectionCompleted, forKey: "providerDetectionCompleted") }
    }

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let toggleStore: ProviderToggleStore
    @ObservationIgnored private let zaiTokenStore: any ZaiTokenStoring
    @ObservationIgnored private var zaiTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let minimaxTokenStore: any MiniMaxTokenStoring
    @ObservationIgnored private var minimaxTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let minimaxCookieHeaderStore: any MiniMaxCookieHeaderStoring
    @ObservationIgnored private var minimaxCookieHeaderPersistTask: Task<Void, Never>?
    @ObservationIgnored private let minimaxGroupIDStore: any MiniMaxGroupIDStoring
    @ObservationIgnored private var minimaxGroupIDPersistTask: Task<Void, Never>?
    @ObservationIgnored private let copilotTokenStore: any CopilotTokenStoring
    @ObservationIgnored private var copilotTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let openRouterTokenStore: any OpenRouterTokenStoring
    @ObservationIgnored private var openRouterTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let groqTokenStore: any GroqTokenStoring
    @ObservationIgnored private var groqTokenPersistTask: Task<Void, Never>?
    // Cache enablement so tight UI loops (menu bar animations) don't hit UserDefaults each tick.
    @ObservationIgnored private var cachedProviderEnablement: [UsageProvider: Bool] = [:]
    @ObservationIgnored private var cachedProviderEnablementRevision: Int = -1
    @ObservationIgnored private var cachedEnabledProviders: [UsageProvider] = []
    @ObservationIgnored private var cachedEnabledProvidersRevision: Int = -1
    @ObservationIgnored private var cachedEnabledProvidersOrderRaw: [String] = []
    // Cache order to avoid re-building sets/arrays every animation tick.
    @ObservationIgnored private var cachedProviderOrder: [UsageProvider] = []
    @ObservationIgnored private var cachedProviderOrderRaw: [String] = []
    private var providerToggleRevision: Int = 0

    init(
        userDefaults: UserDefaults = .standard,
        zaiTokenStore: any ZaiTokenStoring = KeychainZaiTokenStore(),
        minimaxTokenStore: any MiniMaxTokenStoring = KeychainMiniMaxTokenStore(),
        minimaxCookieHeaderStore: any MiniMaxCookieHeaderStoring = KeychainMiniMaxCookieHeaderStore(),
        minimaxGroupIDStore: any MiniMaxGroupIDStoring = KeychainMiniMaxGroupIDStore(),
        copilotTokenStore: any CopilotTokenStoring = KeychainCopilotTokenStore(),
        openRouterTokenStore: any OpenRouterTokenStoring = KeychainOpenRouterTokenStore(),
        groqTokenStore: any GroqTokenStoring = KeychainGroqTokenStore())
    {
        self.userDefaults = userDefaults
        self.zaiTokenStore = zaiTokenStore
        self.minimaxTokenStore = minimaxTokenStore
        self.minimaxCookieHeaderStore = minimaxCookieHeaderStore
        self.minimaxGroupIDStore = minimaxGroupIDStore
        self.copilotTokenStore = copilotTokenStore
        self.openRouterTokenStore = openRouterTokenStore
        self.groqTokenStore = groqTokenStore
        self.providerOrderRaw = userDefaults.stringArray(forKey: "providerOrder") ?? []
        let raw = userDefaults.string(forKey: "refreshFrequency") ?? RefreshFrequency.manual.rawValue
        self.refreshFrequency = RefreshFrequency(rawValue: raw) ?? .manual
        self.autoDisableRefreshWhenIdleEnabled = userDefaults.object(
            forKey: "autoDisableRefreshWhenIdleEnabled") as? Bool ?? true
        self.autoDisableRefreshWhenIdleMinutes = userDefaults.object(
            forKey: "autoDisableRefreshWhenIdleMinutes") as? Int ?? 5
        self.autoDisableRefreshOnSleepEnabled = userDefaults.object(
            forKey: "autoDisableRefreshOnSleepEnabled") as? Bool ?? true
        self.autoRefreshWarningEnabled = userDefaults.object(
            forKey: "autoRefreshWarningEnabled") as? Bool ?? true
        self.autoRefreshWarningThreshold = userDefaults.object(
            forKey: "autoRefreshWarningThreshold") as? Int ?? 10
        self.autoSuspendInactiveProvidersEnabled = userDefaults.object(
            forKey: "autoSuspendInactiveProvidersEnabled") as? Bool ?? true
        self.autoSuspendInactiveProvidersMinutes = userDefaults.object(
            forKey: "autoSuspendInactiveProvidersMinutes") as? Int ?? 720
        self.launchAtLogin = userDefaults.object(forKey: "launchAtLogin") as? Bool ?? false
        self.debugMenuEnabled = userDefaults.object(forKey: "debugMenuEnabled") as? Bool ?? false
        self.debugLoadingPatternRaw = userDefaults.string(forKey: "debugLoadingPattern")
        self.statusChecksEnabled = userDefaults.object(forKey: "statusChecksEnabled") as? Bool ?? true
        let sessionQuotaNotificationsDefault = userDefaults.object(
            forKey: "sessionQuotaNotificationsEnabled") as? Bool
        self.sessionQuotaNotificationsEnabled = sessionQuotaNotificationsDefault ?? true
        if sessionQuotaNotificationsDefault == nil {
            self.userDefaults.set(true, forKey: "sessionQuotaNotificationsEnabled")
        }
        self.usageBarsShowUsed = userDefaults.object(forKey: "usageBarsShowUsed") as? Bool ?? false
        let metricDisplayRaw = userDefaults.string(forKey: "usageMetricDisplayMode")
        self.usageMetricDisplayMode = UsageMetricDisplayMode(rawValue: metricDisplayRaw ?? "") ?? .barsAndPercent
        let menuModeRaw = userDefaults.string(forKey: "menuMode")
        self.menuMode = MenuMode(rawValue: menuModeRaw ?? "") ?? .`operator`
        let chartStyleRaw = userDefaults.string(forKey: "chartStyle")
        self.chartStyle = ChartStyle(rawValue: chartStyleRaw ?? "") ?? .line
        let numberFormatRaw = userDefaults.string(forKey: "numberFormat")
        self.numberFormat = NumberFormat(rawValue: numberFormatRaw ?? "") ?? .abbreviated
        let dateFormatRaw = userDefaults.string(forKey: "dateFormat")
        self.dateFormat = DateFormat(rawValue: dateFormatRaw ?? "") ?? .relative
        let themeRaw = userDefaults.string(forKey: "theme")
        self.theme = Theme(rawValue: themeRaw ?? "") ?? .system
        self.menuBarShowsBrandIconWithPercent = userDefaults.object(
            forKey: "menuBarShowsBrandIconWithPercent") as? Bool ?? false
        self.menuBarVibrantIconEnabled = userDefaults.object(
            forKey: "menuBarVibrantIconEnabled") as? Bool ?? true
        self.costUsageEnabled = userDefaults.object(forKey: "tokenCostUsageEnabled") as? Bool ?? false
        self.insightsMenuMaxItems = userDefaults.object(forKey: "insightsMenuMaxItems") as? Int ?? 4
        self.insightsReportDays = userDefaults.object(forKey: "insightsReportDays") as? Int ?? 7
        self.randomBlinkEnabled = userDefaults.object(forKey: "randomBlinkEnabled") as? Bool ?? false
        self.claudeWebExtrasEnabled = userDefaults.object(forKey: "claudeWebExtrasEnabled") as? Bool ?? false
        let creditsExtrasDefault = userDefaults.object(forKey: "showOptionalCreditsAndExtraUsage") as? Bool
        self.showOptionalCreditsAndExtraUsage = creditsExtrasDefault ?? true
        if creditsExtrasDefault == nil {
            self.userDefaults.set(true, forKey: "showOptionalCreditsAndExtraUsage")
        }
        let openAIWebAccessDefault = userDefaults.object(forKey: "openAIWebAccessEnabled") as? Bool
        self.openAIWebAccessEnabled = openAIWebAccessDefault ?? true
        if openAIWebAccessDefault == nil {
            self.userDefaults.set(true, forKey: "openAIWebAccessEnabled")
        }
        let codexSourceRaw = userDefaults.string(forKey: "codexUsageDataSource")
        self.codexUsageDataSourceRaw = codexSourceRaw ?? CodexUsageDataSource.oauth.rawValue
        let claudeSourceRaw = userDefaults.string(forKey: "claudeUsageDataSource")
        self.claudeUsageDataSourceRaw = claudeSourceRaw ?? ClaudeUsageDataSource.oauth.rawValue
        self.mergeIcons = userDefaults.object(forKey: "mergeIcons") as? Bool ?? true
        self.switcherShowsIcons = userDefaults.object(forKey: "switcherShowsIcons") as? Bool ?? true
        let layoutRaw = userDefaults.string(forKey: "providerSwitcherLayout")
        self.providerSwitcherLayout = ProviderSwitcherLayout(rawValue: layoutRaw ?? "") ?? .sidebar
        let iconSizeRaw = userDefaults.string(forKey: "providerSwitcherIconSize")
        self.providerSwitcherIconSize = ProviderSwitcherIconSize(rawValue: iconSizeRaw ?? "") ?? .medium
        self.providersPaneSidebar = userDefaults.object(forKey: "providersPaneSidebar") as? Bool ?? false
        self.zaiAPIToken = (try? zaiTokenStore.loadToken()) ?? ""
        self.minimaxAPIToken = (try? minimaxTokenStore.loadToken()) ?? ""
        self.minimaxCookieHeader = (try? minimaxCookieHeaderStore.loadHeader()) ?? ""
        self.minimaxGroupID = (try? minimaxGroupIDStore.loadGroupID()) ?? ""
        self.copilotAPIToken = (try? copilotTokenStore.loadToken()) ?? ""
        self.openRouterAPIToken = (try? openRouterTokenStore.loadToken()) ?? ""
        self.groqAPIToken = (try? groqTokenStore.loadToken()) ?? ""
        self.selectedMenuProviderRaw = userDefaults.string(forKey: "selectedMenuProvider")
        self.providerDetectionCompleted = userDefaults.object(
            forKey: "providerDetectionCompleted") as? Bool ?? false
        self.toggleStore = ProviderToggleStore(userDefaults: userDefaults)
        self.toggleStore.purgeLegacyKeys()
        LaunchAtLoginManager.setEnabled(self.launchAtLogin)
        self.runInitialProviderDetectionIfNeeded()
        self.applyTokenCostDefaultIfNeeded()
        if self.claudeUsageDataSource != .cli {
            self.claudeWebExtrasEnabled = false
        }
    }

    func orderedProviders() -> [UsageProvider] {
        let raw = self.providerOrderRaw
        if raw == self.cachedProviderOrderRaw, !self.cachedProviderOrder.isEmpty {
            return self.cachedProviderOrder
        }
        let ordered = Self.effectiveProviderOrder(raw: raw)
        self.cachedProviderOrderRaw = raw
        self.cachedProviderOrder = ordered
        return ordered
    }

    func moveProvider(fromOffsets: IndexSet, toOffset: Int) {
        var order = self.orderedProviders()
        order.move(fromOffsets: fromOffsets, toOffset: toOffset)
        self.providerOrderRaw = order.map(\.rawValue)
    }

    func isProviderEnabled(provider: UsageProvider, metadata: ProviderMetadata) -> Bool {
        _ = self.providerToggleRevision
        return self.toggleStore.isEnabled(metadata: metadata)
    }

    func isProviderEnabledCached(
        provider: UsageProvider,
        metadataByProvider: [UsageProvider: ProviderMetadata]) -> Bool
    {
        self.refreshProviderEnablementCacheIfNeeded(metadataByProvider: metadataByProvider)
        return self.cachedProviderEnablement[provider] ?? false
    }

    func enabledProvidersOrdered(metadataByProvider: [UsageProvider: ProviderMetadata]) -> [UsageProvider] {
        self.refreshProviderEnablementCacheIfNeeded(metadataByProvider: metadataByProvider)
        let orderRaw = self.providerOrderRaw
        let revision = self.cachedProviderEnablementRevision
        if revision == self.cachedEnabledProvidersRevision,
           orderRaw == self.cachedEnabledProvidersOrderRaw,
           !self.cachedEnabledProviders.isEmpty
        {
            return self.cachedEnabledProviders
        }
        let enabled = self.orderedProviders().filter { self.cachedProviderEnablement[$0] ?? false }
        self.cachedEnabledProviders = enabled
        self.cachedEnabledProvidersRevision = revision
        self.cachedEnabledProvidersOrderRaw = orderRaw
        return enabled
    }

    func setProviderEnabled(provider: UsageProvider, metadata: ProviderMetadata, enabled: Bool) {
        self.providerToggleRevision &+= 1
        self.toggleStore.setEnabled(enabled, metadata: metadata)
    }

    func rerunProviderDetection() {
        self.runInitialProviderDetectionIfNeeded(force: true)
    }

    // MARK: - Private

    func isCostUsageEffectivelyEnabled(for provider: UsageProvider) -> Bool {
        self.costUsageEnabled
            && ProviderDescriptorRegistry.descriptor(for: provider).tokenCost.supportsTokenCost
    }

    private static func effectiveProviderOrder(raw: [String]) -> [UsageProvider] {
        var seen: Set<UsageProvider> = []
        var ordered: [UsageProvider] = []

        for rawValue in raw {
            guard let provider = UsageProvider(rawValue: rawValue) else { continue }
            guard !seen.contains(provider) else { continue }
            seen.insert(provider)
            ordered.append(provider)
        }

        if ordered.isEmpty {
            ordered = UsageProvider.allCases
            seen = Set(ordered)
        }

        if !seen.contains(.factory), let zaiIndex = ordered.firstIndex(of: .zai) {
            ordered.insert(.factory, at: zaiIndex)
            seen.insert(.factory)
        }

        for provider in UsageProvider.allCases where !seen.contains(provider) {
            ordered.append(provider)
        }

        return ordered
    }

    private func refreshProviderEnablementCacheIfNeeded(
        metadataByProvider: [UsageProvider: ProviderMetadata])
    {
        let revision = self.providerToggleRevision
        guard revision != self.cachedProviderEnablementRevision else { return }
        var cache: [UsageProvider: Bool] = [:]
        for (provider, metadata) in metadataByProvider {
            cache[provider] = self.toggleStore.isEnabled(metadata: metadata)
        }
        self.cachedProviderEnablement = cache
        self.cachedProviderEnablementRevision = revision
    }

    private func runInitialProviderDetectionIfNeeded(force: Bool = false) {
        guard force || !self.providerDetectionCompleted else { return }
        guard let codexMeta = ProviderRegistry.shared.metadata[.codex],
              let claudeMeta = ProviderRegistry.shared.metadata[.claude],
              let geminiMeta = ProviderRegistry.shared.metadata[.gemini],
              let antigravityMeta = ProviderRegistry.shared.metadata[.antigravity] else { return }

        LoginShellPathCache.shared.captureOnce { [weak self] _ in
            Task { @MainActor in
                await self?.applyProviderDetection(
                    codexMeta: codexMeta,
                    claudeMeta: claudeMeta,
                    geminiMeta: geminiMeta,
                    antigravityMeta: antigravityMeta)
            }
        }
    }

    private func applyProviderDetection(
        codexMeta: ProviderMetadata,
        claudeMeta: ProviderMetadata,
        geminiMeta: ProviderMetadata,
        antigravityMeta: ProviderMetadata) async
    {
        guard !self.providerDetectionCompleted else { return }
        let codexInstalled = BinaryLocator.resolveCodexBinary() != nil
        let claudeInstalled = BinaryLocator.resolveClaudeBinary() != nil
        let geminiInstalled = BinaryLocator.resolveGeminiBinary() != nil
        let antigravityRunning = await AntigravityStatusProbe.isRunning()

        // If none installed, keep Codex enabled to match previous behavior.
        let noneInstalled = !codexInstalled && !claudeInstalled && !geminiInstalled && !antigravityRunning
        let enableCodex = codexInstalled || noneInstalled
        let enableClaude = claudeInstalled
        let enableGemini = geminiInstalled
        let enableAntigravity = antigravityRunning

        self.providerToggleRevision &+= 1
        self.toggleStore.setEnabled(enableCodex, metadata: codexMeta)
        self.toggleStore.setEnabled(enableClaude, metadata: claudeMeta)
        self.toggleStore.setEnabled(enableGemini, metadata: geminiMeta)
        self.toggleStore.setEnabled(enableAntigravity, metadata: antigravityMeta)
        self.providerDetectionCompleted = true
    }

    private func applyTokenCostDefaultIfNeeded() {
        // Settings are persisted in UserDefaults.standard.
        guard UserDefaults.standard.object(forKey: "tokenCostUsageEnabled") == nil else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let hasSources = await Task.detached(priority: .utility) {
                Self.hasAnyTokenCostUsageSources()
            }.value
            guard hasSources else { return }
            guard UserDefaults.standard.object(forKey: "tokenCostUsageEnabled") == nil else { return }
            self.costUsageEnabled = true
        }
    }

    nonisolated static func hasAnyTokenCostUsageSources(
        env: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default) -> Bool
    {
        func hasAnyJsonl(in root: URL) -> Bool {
            guard fileManager.fileExists(atPath: root.path) else { return false }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants])
            else { return false }

            for case let url as URL in enumerator where url.pathExtension.lowercased() == "jsonl" {
                return true
            }
            return false
        }

        let codexRoot: URL = {
            let raw = env["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let raw, !raw.isEmpty {
                return URL(fileURLWithPath: raw).appendingPathComponent("sessions", isDirectory: true)
            }
            return fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex", isDirectory: true)
                .appendingPathComponent("sessions", isDirectory: true)
        }()
        if hasAnyJsonl(in: codexRoot) { return true }

        let claudeRoots: [URL] = {
            if let env = env["CLAUDE_CONFIG_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !env.isEmpty
            {
                return env.split(separator: ",").map { part in
                    let raw = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
                    let url = URL(fileURLWithPath: raw)
                    if url.lastPathComponent == "projects" {
                        return url
                    }
                    return url.appendingPathComponent("projects", isDirectory: true)
                }
            }

            let home = fileManager.homeDirectoryForCurrentUser
            return [
                home.appendingPathComponent(".config/claude/projects", isDirectory: true),
                home.appendingPathComponent(".claude/projects", isDirectory: true),
            ]
        }()

        return claudeRoots.contains(where: hasAnyJsonl(in:))
    }

    private func schedulePersistZaiAPIToken() {
        self.zaiTokenPersistTask?.cancel()
        let token = self.zaiAPIToken
        let tokenStore = self.zaiTokenStore
        self.zaiTokenPersistTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let error: (any Error)? = await Task.detached(priority: .utility) { () -> (any Error)? in
                do {
                    try tokenStore.storeToken(token)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let error {
                // Keep value in memory; persist best-effort.
                RunicLog.logger("zai-token-store").error("Failed to persist z.ai token: \(error)")
            }
        }
    }

    private func schedulePersistMiniMaxAPIToken() {
        self.minimaxTokenPersistTask?.cancel()
        let token = self.minimaxAPIToken
        let tokenStore = self.minimaxTokenStore
        self.minimaxTokenPersistTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let error: (any Error)? = await Task.detached(priority: .utility) { () -> (any Error)? in
                do {
                    try tokenStore.storeToken(token)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let error {
                RunicLog.logger("minimax-token-store").error("Failed to persist MiniMax token: \(error)")
            }
        }
    }

    private func schedulePersistMiniMaxCookieHeader() {
        self.minimaxCookieHeaderPersistTask?.cancel()
        let header = self.minimaxCookieHeader
        let store = self.minimaxCookieHeaderStore
        self.minimaxCookieHeaderPersistTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let error: (any Error)? = await Task.detached(priority: .utility) { () -> (any Error)? in
                do {
                    try store.storeHeader(header)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let error {
                RunicLog.logger("minimax-cookie-store").error("Failed to persist MiniMax cookie header: \(error)")
            }
        }
    }

    private func schedulePersistMiniMaxGroupID() {
        self.minimaxGroupIDPersistTask?.cancel()
        let groupID = self.minimaxGroupID
        let groupStore = self.minimaxGroupIDStore
        self.minimaxGroupIDPersistTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let error: (any Error)? = await Task.detached(priority: .utility) { () -> (any Error)? in
                do {
                    try groupStore.storeGroupID(groupID)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let error {
                RunicLog.logger("minimax-groupid-store").error("Failed to persist MiniMax Group ID: \(error)")
            }
        }
    }

    private func schedulePersistCopilotAPIToken() {
        self.copilotTokenPersistTask?.cancel()
        let token = self.copilotAPIToken
        let tokenStore = self.copilotTokenStore
        self.copilotTokenPersistTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let error: (any Error)? = await Task.detached(priority: .utility) { () -> (any Error)? in
                do {
                    try tokenStore.storeToken(token)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let error {
                RunicLog.logger("copilot-token-store").error("Failed to persist Copilot token: \(error)")
            }
        }
    }

    private func schedulePersistOpenRouterAPIToken() {
        self.openRouterTokenPersistTask?.cancel()
        let token = self.openRouterAPIToken
        let tokenStore = self.openRouterTokenStore
        self.openRouterTokenPersistTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let error: (any Error)? = await Task.detached(priority: .utility) { () -> (any Error)? in
                do {
                    try tokenStore.storeToken(token)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let error {
                RunicLog.logger("openrouter-token-store").error("Failed to persist OpenRouter token: \(error)")
            }
        }
    }

    private func schedulePersistGroqAPIToken() {
        self.groqTokenPersistTask?.cancel()
        let token = self.groqAPIToken
        let tokenStore = self.groqTokenStore
        self.groqTokenPersistTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let error: (any Error)? = await Task.detached(priority: .utility) { () -> (any Error)? in
                do {
                    try tokenStore.storeToken(token)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let error {
                RunicLog.logger("groq-token-store").error("Failed to persist Groq token: \(error)")
            }
        }
    }
}

enum LaunchAtLoginManager {
    @MainActor
    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13, *) else { return }
        let service = SMAppService.mainApp
        if enabled {
            try? service.register()
        } else {
            try? service.unregister()
        }
    }
}
