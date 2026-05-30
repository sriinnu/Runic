import Foundation
import Observation
import RunicCore

// Structural lint debt: settings storage still needs smaller persistence domains.
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
        didSet { self.userDefaults.set(
            self.autoDisableRefreshWhenIdleEnabled,
            forKey: "autoDisableRefreshWhenIdleEnabled") }
    }

    var autoDisableRefreshWhenIdleMinutes: Int {
        didSet { self.userDefaults.set(
            self.autoDisableRefreshWhenIdleMinutes,
            forKey: "autoDisableRefreshWhenIdleMinutes") }
    }

    var autoDisableRefreshOnSleepEnabled: Bool {
        didSet {
            self.userDefaults.set(self.autoDisableRefreshOnSleepEnabled, forKey: "autoDisableRefreshOnSleepEnabled")
        }
    }

    var autoRefreshWarningEnabled: Bool {
        didSet { self.userDefaults.set(self.autoRefreshWarningEnabled, forKey: "autoRefreshWarningEnabled") }
    }

    var autoRefreshWarningThreshold: Int {
        didSet { self.userDefaults.set(self.autoRefreshWarningThreshold, forKey: "autoRefreshWarningThreshold") }
    }

    var autoSuspendInactiveProvidersEnabled: Bool {
        didSet {
            self.userDefaults.set(
                self.autoSuspendInactiveProvidersEnabled,
                forKey: "autoSuspendInactiveProvidersEnabled")
        }
    }

    var autoSuspendInactiveProvidersMinutes: Int {
        didSet {
            self.userDefaults.set(
                self.autoSuspendInactiveProvidersMinutes,
                forKey: "autoSuspendInactiveProvidersMinutes")
        }
    }

    var launchAtLogin: Bool {
        didSet {
            self.userDefaults.set(self.launchAtLogin, forKey: "launchAtLogin")
        }
    }

    /// Hidden toggle to reveal debug-only menu items (enable via defaults write com.sriinnu.athena.Runic
    /// debugMenuEnabled
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

    /// When enabled, post macOS notifications when spend forecasts breach project budgets.
    var budgetNotificationsEnabled: Bool {
        didSet {
            self.userDefaults.set(self.budgetNotificationsEnabled, forKey: "budgetNotificationsEnabled")
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
        didSet {
            self.userDefaults.set(self.theme.rawValue, forKey: "theme")
            RunicApp.applyTheme(self.theme)
            RunicFont.applyTheme(self.theme.palette)
            IconRenderer.themePalette = self.theme.palette
            self.bumpVisualSettingsRevision()
        }
    }

    var selectedFontFamily: String {
        didSet {
            let migrated = RunicFontChoice.migratedFamily(self.selectedFontFamily)
            if migrated != self.selectedFontFamily {
                self.selectedFontFamily = migrated
            }
            self.userDefaults.set(self.selectedFontFamily, forKey: "selectedFontFamily")
            RunicFont.family = self.selectedFontFamily
            self.bumpVisualSettingsRevision()
        }
    }

    private(set) var visualSettingsRevision: Int = 0

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

    /// Optional: show provider token/cost summaries from local usage logs.
    var costUsageEnabled: Bool {
        didSet { self.userDefaults.set(self.costUsageEnabled, forKey: "tokenCostUsageEnabled") }
    }

    /// Comma/newline separated OpenTelemetry GenAI JSON/JSONL files or folders.
    var otelGenAILogPaths: String {
        didSet { self.userDefaults.set(self.otelGenAILogPaths, forKey: "otelGenAILogPaths") }
    }

    /// Optional: limit how many insight rows appear in the menu before "More…".
    var insightsMenuMaxItems: Int {
        didSet { self.userDefaults.set(self.insightsMenuMaxItems, forKey: "insightsMenuMaxItems") }
    }

    /// Optional: how many days to include in the insights report.
    var insightsReportDays: Int {
        didSet { self.userDefaults.set(self.insightsReportDays, forKey: "insightsReportDays") }
    }

    /// How many days of usage history to scan for ledger data (charts, breakdowns).
    /// Options: 3, 7, 30, 90, 365. Default: 30.
    var ledgerMaxAgeDays: Int {
        didSet { self.userDefaults.set(self.ledgerMaxAgeDays, forKey: "ledgerMaxAgeDays") }
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

    var providerCredentialMigrationNotice: String?

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

    // Keep secret fields cold at startup; provider fetchers read keychain values only when needed.
    /// z.ai API token (stored in Keychain).
    var zaiAPIToken = "" {
        didSet {
            self.schedulePersistZaiAPIToken()
            if !self.zaiAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "zai")
            }
        }
    }

    /// MiniMax API token (stored in Keychain).
    var minimaxAPIToken = "" {
        didSet {
            self.schedulePersistMiniMaxAPIToken()
            if !self.minimaxAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "minimax")
            }
        }
    }

    /// MiniMax manual Cookie header (stored in Keychain).
    var minimaxCookieHeader = "" {
        didSet {
            self.schedulePersistMiniMaxCookieHeader()
            if !self.minimaxCookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "minimax")
            }
        }
    }

    /// MiniMax Group ID (stored in Keychain).
    var minimaxGroupID = "" {
        didSet { self.schedulePersistMiniMaxGroupID() }
    }

    /// Copilot API token (stored in Keychain).
    var copilotAPIToken = "" {
        didSet {
            self.schedulePersistCopilotAPIToken()
            if !self.copilotAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "copilot")
            }
        }
    }

    /// OpenRouter API key (stored in Keychain).
    var openRouterAPIToken = "" {
        didSet {
            self.schedulePersistOpenRouterAPIToken()
            if !self.openRouterAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "openrouter")
            }
        }
    }

    /// Vercel AI Gateway API key (stored in Keychain).
    var vercelAIAPIToken = "" {
        didSet {
            self.schedulePersistVercelAIAPIToken()
            if !self.vercelAIAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "vercelai")
            }
        }
    }

    /// Groq API key (stored in Keychain).
    var groqAPIToken = "" {
        didSet {
            self.schedulePersistGroqAPIToken()
            if !self.groqAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "groq")
            }
        }
    }

    /// DeepSeek API key (stored in Keychain).
    var deepSeekAPIToken = "" {
        didSet {
            self.schedulePersistDeepSeekAPIToken()
            if !self.deepSeekAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "deepseek")
            }
        }
    }

    /// Fireworks API key (stored in Keychain).
    var fireworksAPIToken = "" {
        didSet {
            self.schedulePersistFireworksAPIToken()
            if !self.fireworksAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "fireworks")
            }
        }
    }

    /// Mistral API key (stored in Keychain).
    var mistralAPIToken = "" {
        didSet {
            self.schedulePersistMistralAPIToken()
            if !self.mistralAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "mistral")
            }
        }
    }

    /// Perplexity API key (stored in Keychain).
    var perplexityAPIToken = "" {
        didSet {
            self.schedulePersistPerplexityAPIToken()
            if !self.perplexityAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "perplexity")
            }
        }
    }

    /// Kimi API key (stored in Keychain).
    var kimiAPIToken = "" {
        didSet {
            self.schedulePersistKimiAPIToken()
            if !self.kimiAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "kimi")
            }
        }
    }

    /// Auggie API token (stored in Keychain).
    var auggieAPIToken = "" {
        didSet {
            self.schedulePersistAuggieAPIToken()
            if !self.auggieAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "auggie")
            }
        }
    }

    /// Together API key (stored in Keychain).
    var togetherAPIToken = "" {
        didSet {
            self.schedulePersistTogetherAPIToken()
            if !self.togetherAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "together")
            }
        }
    }

    /// Cohere API key (stored in Keychain).
    var cohereAPIToken = "" {
        didSet {
            self.schedulePersistCohereAPIToken()
            if !self.cohereAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "cohere")
            }
        }
    }

    /// xAI API key (stored in Keychain).
    var xaiAPIToken = "" {
        didSet {
            self.schedulePersistXAiAPIToken()
            if !self.xaiAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "xai")
            }
        }
    }

    /// Cerebras API key (stored in Keychain).
    var cerebrasAPIToken = "" {
        didSet {
            self.schedulePersistCerebrasAPIToken()
            if !self.cerebrasAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "cerebras")
            }
        }
    }

    /// Qwen DashScope API key (stored in Keychain).
    var qwenAPIToken = "" {
        didSet {
            self.schedulePersistQwenAPIToken()
            if !self.qwenAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "qwen")
            }
        }
    }

    /// SambaNova API key (stored in Keychain).
    var sambaNovaAPIToken = "" {
        didSet {
            self.schedulePersistSambaNovaAPIToken()
            if !self.sambaNovaAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "sambanova")
            }
        }
    }

    /// Azure OpenAI endpoint URL (stored in UserDefaults).
    var azureOpenAIEndpoint: String {
        didSet { self.userDefaults.set(self.azureOpenAIEndpoint, forKey: "azureOpenAIEndpoint") }
    }

    /// Azure OpenAI deployment name (stored in UserDefaults).
    var azureOpenAIDeployment: String {
        didSet { self.userDefaults.set(self.azureOpenAIDeployment, forKey: "azureOpenAIDeployment") }
    }

    /// Azure OpenAI API version (stored in UserDefaults).
    var azureOpenAIAPIVersion: String {
        didSet { self.userDefaults.set(self.azureOpenAIAPIVersion, forKey: "azureOpenAIAPIVersion") }
    }

    /// Azure OpenAI API key (stored in Keychain).
    var azureOpenAIAPIToken = "" {
        didSet {
            self.schedulePersistAzureOpenAIAPIToken()
            if !self.azureOpenAIAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.autoEnableProviderIfNeeded(cliName: "azure")
            }
        }
    }

    /// Amazon Bedrock region (stored in UserDefaults).
    var bedrockRegion: String {
        didSet { self.userDefaults.set(self.bedrockRegion, forKey: "bedrockRegion") }
    }

    /// Optional AWS profile for Amazon Bedrock (stored in UserDefaults).
    var bedrockAWSProfile: String {
        didSet { self.userDefaults.set(self.bedrockAWSProfile, forKey: "bedrockAWSProfile") }
    }

    /// Optional model filter for Amazon Bedrock (stored in UserDefaults).
    var bedrockModelID: String {
        didSet { self.userDefaults.set(self.bedrockModelID, forKey: "bedrockModelID") }
    }

    /// Google Cloud project for Vertex AI (stored in UserDefaults).
    var vertexaiProject: String {
        didSet { self.userDefaults.set(self.vertexaiProject, forKey: "vertexaiProject") }
    }

    /// Google Cloud location/region for Vertex AI (stored in UserDefaults).
    var vertexaiLocation: String {
        didSet { self.userDefaults.set(self.vertexaiLocation, forKey: "vertexaiLocation") }
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
    @ObservationIgnored private let vercelAITokenStore: any VercelAITokenStoring
    @ObservationIgnored private var vercelAITokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let groqTokenStore: any GroqTokenStoring
    @ObservationIgnored private var groqTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let deepSeekTokenStore: any DeepSeekTokenStoring
    @ObservationIgnored private var deepSeekTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let fireworksTokenStore: any FireworksTokenStoring
    @ObservationIgnored private var fireworksTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let mistralTokenStore: any MistralTokenStoring
    @ObservationIgnored private var mistralTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let perplexityTokenStore: any PerplexityTokenStoring
    @ObservationIgnored private var perplexityTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let kimiTokenStore: any KimiTokenStoring
    @ObservationIgnored private var kimiTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let auggieTokenStore: any AuggieTokenStoring
    @ObservationIgnored private var auggieTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let togetherTokenStore: any TogetherTokenStoring
    @ObservationIgnored private var togetherTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let cohereTokenStore: any CohereTokenStoring
    @ObservationIgnored private var cohereTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let xaiTokenStore: any XAITokenStoring
    @ObservationIgnored private var xaiTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let cerebrasTokenStore: any CerebrasTokenStoring
    @ObservationIgnored private var cerebrasTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let sambaNovaTokenStore: any SambaNovaTokenStoring
    @ObservationIgnored private var sambaNovaTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let qwenTokenStore: any QwenTokenStoring
    @ObservationIgnored private var qwenTokenPersistTask: Task<Void, Never>?
    @ObservationIgnored private let azureOpenAITokenStore: any AzureOpenAITokenStoring
    @ObservationIgnored private var azureOpenAITokenPersistTask: Task<Void, Never>?
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
        vercelAITokenStore: any VercelAITokenStoring = KeychainVercelAITokenStore(),
        groqTokenStore: any GroqTokenStoring = KeychainGroqTokenStore(),
        deepSeekTokenStore: any DeepSeekTokenStoring = KeychainDeepSeekTokenStore(),
        fireworksTokenStore: any FireworksTokenStoring = KeychainFireworksTokenStore(),
        mistralTokenStore: any MistralTokenStoring = KeychainMistralTokenStore(),
        perplexityTokenStore: any PerplexityTokenStoring = KeychainPerplexityTokenStore(),
        kimiTokenStore: any KimiTokenStoring = KeychainKimiTokenStore(),
        auggieTokenStore: any AuggieTokenStoring = KeychainAuggieTokenStore(),
        togetherTokenStore: any TogetherTokenStoring = KeychainTogetherTokenStore(),
        cohereTokenStore: any CohereTokenStoring = KeychainCohereTokenStore(),
        xaiTokenStore: any XAITokenStoring = KeychainXAITokenStore(),
        cerebrasTokenStore: any CerebrasTokenStoring = KeychainCerebrasTokenStore(),
        sambaNovaTokenStore: any SambaNovaTokenStoring = KeychainSambaNovaTokenStore(),
        qwenTokenStore: any QwenTokenStoring = KeychainQwenTokenStore(),
        azureOpenAITokenStore: any AzureOpenAITokenStoring = KeychainAzureOpenAITokenStore())
    {
        self.userDefaults = userDefaults
        self.zaiTokenStore = zaiTokenStore
        self.minimaxTokenStore = minimaxTokenStore
        self.minimaxCookieHeaderStore = minimaxCookieHeaderStore
        self.minimaxGroupIDStore = minimaxGroupIDStore
        self.copilotTokenStore = copilotTokenStore
        self.openRouterTokenStore = openRouterTokenStore
        self.vercelAITokenStore = vercelAITokenStore
        self.groqTokenStore = groqTokenStore
        self.deepSeekTokenStore = deepSeekTokenStore
        self.fireworksTokenStore = fireworksTokenStore
        self.mistralTokenStore = mistralTokenStore
        self.perplexityTokenStore = perplexityTokenStore
        self.kimiTokenStore = kimiTokenStore
        self.auggieTokenStore = auggieTokenStore
        self.togetherTokenStore = togetherTokenStore
        self.cohereTokenStore = cohereTokenStore
        self.xaiTokenStore = xaiTokenStore
        self.cerebrasTokenStore = cerebrasTokenStore
        self.sambaNovaTokenStore = sambaNovaTokenStore
        self.qwenTokenStore = qwenTokenStore
        self.azureOpenAITokenStore = azureOpenAITokenStore
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
        self.budgetNotificationsEnabled = userDefaults.object(
            forKey: "budgetNotificationsEnabled") as? Bool ?? false
        self.usageBarsShowUsed = userDefaults.object(forKey: "usageBarsShowUsed") as? Bool ?? true
        let metricDisplayRaw = userDefaults.string(forKey: "usageMetricDisplayMode")
        self.usageMetricDisplayMode = UsageMetricDisplayMode(rawValue: metricDisplayRaw ?? "") ?? .barsAndPercent
        let menuModeRaw = userDefaults.string(forKey: "menuMode")
        self.menuMode = MenuMode(rawValue: menuModeRaw ?? "") ?? .operator
        let chartStyleRaw = userDefaults.string(forKey: "chartStyle")
        self.chartStyle = ChartStyle(rawValue: chartStyleRaw ?? "") ?? .line
        let numberFormatRaw = userDefaults.string(forKey: "numberFormat")
        self.numberFormat = NumberFormat(rawValue: numberFormatRaw ?? "") ?? .abbreviated
        let dateFormatRaw = userDefaults.string(forKey: "dateFormat")
        self.dateFormat = DateFormat(rawValue: dateFormatRaw ?? "") ?? .relative
        let themeRaw = userDefaults.string(forKey: "theme") ?? ""
        if Theme.retiredRawValues.contains(themeRaw) {
            // Users on a retired theme (pine/nocturne/prism) land on Daybreak.
            self.theme = .daybreak
            userDefaults.set(Theme.daybreak.rawValue, forKey: "theme")
        } else if let resolved = Theme(rawValue: themeRaw) {
            self.theme = resolved
        } else {
            // First-launch / unrecognised value → ship the signature Retro
            // look. Users can change to anything else from Preferences.
            self.theme = Theme.default
            userDefaults.set(Theme.default.rawValue, forKey: "theme")
        }
        let storedSelectedFont = userDefaults.string(forKey: "selectedFontFamily")
        let migratedSelectedFont = RunicFontChoice.migratedFamily(storedSelectedFont)
        self.selectedFontFamily = migratedSelectedFont
        if (storedSelectedFont ?? "") != migratedSelectedFont {
            userDefaults.set(migratedSelectedFont, forKey: "selectedFontFamily")
        }
        self.menuBarShowsBrandIconWithPercent = userDefaults.object(
            forKey: "menuBarShowsBrandIconWithPercent") as? Bool ?? false
        self.menuBarVibrantIconEnabled = userDefaults.object(
            forKey: "menuBarVibrantIconEnabled") as? Bool ?? true
        self.costUsageEnabled = userDefaults.object(forKey: "tokenCostUsageEnabled") as? Bool ?? true
        self.otelGenAILogPaths = userDefaults.string(forKey: "otelGenAILogPaths") ?? ""
        self.insightsMenuMaxItems = userDefaults.object(forKey: "insightsMenuMaxItems") as? Int ?? 4
        self.insightsReportDays = userDefaults.object(forKey: "insightsReportDays") as? Int ?? 7
        self.ledgerMaxAgeDays = userDefaults.object(forKey: "ledgerMaxAgeDays") as? Int ?? 30
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
        self.providerSwitcherLayout = ProviderSwitcherLayout(rawValue: layoutRaw ?? "") ?? .top
        let iconSizeRaw = userDefaults.string(forKey: "providerSwitcherIconSize")
        self.providerSwitcherIconSize = ProviderSwitcherIconSize(rawValue: iconSizeRaw ?? "") ?? .medium
        self.providersPaneSidebar = userDefaults.object(forKey: "providersPaneSidebar") as? Bool ?? false
        self.azureOpenAIEndpoint = userDefaults.string(forKey: "azureOpenAIEndpoint") ?? ""
        self.azureOpenAIDeployment = userDefaults.string(forKey: "azureOpenAIDeployment") ?? ""
        self.azureOpenAIAPIVersion = userDefaults.string(forKey: "azureOpenAIAPIVersion")
            ?? "2024-10-21"
        self.bedrockRegion = userDefaults.string(forKey: "bedrockRegion") ?? ""
        self.bedrockAWSProfile = userDefaults.string(forKey: "bedrockAWSProfile") ?? ""
        self.bedrockModelID = userDefaults.string(forKey: "bedrockModelID") ?? ""
        self.vertexaiProject = userDefaults.string(forKey: "vertexaiProject") ?? ""
        self.vertexaiLocation = userDefaults.string(forKey: "vertexaiLocation") ?? ""
        let credentialMigration = ProviderCredentialKeychainMigration.migrateKnownLegacyItems()
        if credentialMigration.needsUserRepair {
            let blocked = credentialMigration.blockedAccounts.count
            let failed = credentialMigration.failedAccounts.count
            self.providerCredentialMigrationNotice =
                "Some saved provider keys need a one-time re-save after keychain hardening " +
                "(\(blocked) blocked, \(failed) failed). Re-save affected API keys below; " +
                "Runic will not prompt in the background."
        }
        let selectedMenuProviderRaw = userDefaults.string(forKey: "selectedMenuProvider")
        self.selectedMenuProviderRaw = selectedMenuProviderRaw.flatMap { UsageProvider(rawValue: $0)?.rawValue }
        self.providerDetectionCompleted = userDefaults.object(
            forKey: "providerDetectionCompleted") as? Bool ?? false
        self.toggleStore = ProviderToggleStore(userDefaults: userDefaults)
        self.toggleStore.purgeLegacyKeys()
        // Do not re-register login items during startup; macOS can surface a password prompt.
        // The didSet hook above handles explicit user changes from Preferences.
        self.runInitialProviderDetectionIfNeeded()
        self.applyTokenCostDefaultIfNeeded()
        if self.claudeUsageDataSource != .cli {
            self.claudeWebExtrasEnabled = false
        }
        RunicFont.family = self.selectedFontFamily
        RunicFont.applyTheme(self.theme.palette)
        IconRenderer.themePalette = self.theme.palette
    }
}

extension SettingsStore {
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
        _ = self.selectedFontFamily
        _ = self.visualSettingsRevision
        _ = self.menuBarShowsBrandIconWithPercent
        _ = self.menuBarVibrantIconEnabled
        _ = self.costUsageEnabled
        _ = self.otelGenAILogPaths
        _ = self.insightsMenuMaxItems
        _ = self.insightsReportDays
        _ = self.ledgerMaxAgeDays
        _ = self.randomBlinkEnabled
        _ = self.claudeWebExtrasEnabled
        _ = self.showOptionalCreditsAndExtraUsage
        _ = self.openAIWebAccessEnabled
        _ = self.providerCredentialMigrationNotice
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
        _ = self.vercelAIAPIToken
        _ = self.groqAPIToken
        _ = self.deepSeekAPIToken
        _ = self.fireworksAPIToken
        _ = self.mistralAPIToken
        _ = self.perplexityAPIToken
        _ = self.kimiAPIToken
        _ = self.auggieAPIToken
        _ = self.togetherAPIToken
        _ = self.cohereAPIToken
        _ = self.xaiAPIToken
        _ = self.cerebrasAPIToken
        _ = self.qwenAPIToken
        _ = self.sambaNovaAPIToken
        _ = self.azureOpenAIEndpoint
        _ = self.azureOpenAIDeployment
        _ = self.azureOpenAIAPIVersion
        _ = self.azureOpenAIAPIToken
        _ = self.bedrockRegion
        _ = self.bedrockAWSProfile
        _ = self.bedrockModelID
        _ = self.vertexaiProject
        _ = self.vertexaiLocation
        _ = self.debugLoadingPattern
        _ = self.selectedMenuProvider
        _ = self.providerToggleRevision
        return 0
    }

    private func bumpVisualSettingsRevision() {
        self.visualSettingsRevision &+= 1
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

    @MainActor
    func setLaunchAtLoginFromPreferences(_ enabled: Bool) {
        guard self.launchAtLogin != enabled else { return }
        self.launchAtLogin = enabled
        LaunchAtLoginManager.setEnabled(enabled)
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

    /// Auto-enable a provider when the user enters a non-empty API token.
    private func autoEnableProviderIfNeeded(cliName: String) {
        let toggles = (self.userDefaults.dictionary(forKey: "providerToggles") as? [String: Bool]) ?? [:]
        guard toggles[cliName] == nil else { return }
        var updated = toggles
        updated[cliName] = true
        self.userDefaults.set(updated, forKey: "providerToggles")
        self.providerToggleRevision &+= 1
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

    private func makeCredentialPersistTask(
        value: String,
        loggerName: String,
        failureMessage: String,
        persist: @escaping @Sendable (String) throws -> Void) -> Task<Void, Never>
    {
        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let error: (any Error)? = await Task.detached(priority: .utility) { () -> (any Error)? in
                do {
                    try persist(value)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let error {
                // Keep value in memory; persist best-effort.
                RunicLog.logger(loggerName).error("\(failureMessage): \(error)")
            }
        }
    }

    private func schedulePersistZaiAPIToken() {
        self.zaiTokenPersistTask?.cancel()
        let tokenStore = self.zaiTokenStore
        self.zaiTokenPersistTask = self.makeCredentialPersistTask(
            value: self.zaiAPIToken,
            loggerName: "zai-token-store",
            failureMessage: "Failed to persist z.ai token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistMiniMaxAPIToken() {
        self.minimaxTokenPersistTask?.cancel()
        let tokenStore = self.minimaxTokenStore
        self.minimaxTokenPersistTask = self.makeCredentialPersistTask(
            value: self.minimaxAPIToken,
            loggerName: "minimax-token-store",
            failureMessage: "Failed to persist MiniMax token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistMiniMaxCookieHeader() {
        self.minimaxCookieHeaderPersistTask?.cancel()
        let store = self.minimaxCookieHeaderStore
        self.minimaxCookieHeaderPersistTask = self.makeCredentialPersistTask(
            value: self.minimaxCookieHeader,
            loggerName: "minimax-cookie-store",
            failureMessage: "Failed to persist MiniMax cookie header") { header in
                try store.storeHeader(header)
            }
    }

    private func schedulePersistMiniMaxGroupID() {
        self.minimaxGroupIDPersistTask?.cancel()
        let groupStore = self.minimaxGroupIDStore
        self.minimaxGroupIDPersistTask = self.makeCredentialPersistTask(
            value: self.minimaxGroupID,
            loggerName: "minimax-groupid-store",
            failureMessage: "Failed to persist MiniMax Group ID") { groupID in
                try groupStore.storeGroupID(groupID)
            }
    }

    private func schedulePersistCopilotAPIToken() {
        self.copilotTokenPersistTask?.cancel()
        let tokenStore = self.copilotTokenStore
        self.copilotTokenPersistTask = self.makeCredentialPersistTask(
            value: self.copilotAPIToken,
            loggerName: "copilot-token-store",
            failureMessage: "Failed to persist Copilot token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistOpenRouterAPIToken() {
        self.openRouterTokenPersistTask?.cancel()
        let tokenStore = self.openRouterTokenStore
        self.openRouterTokenPersistTask = self.makeCredentialPersistTask(
            value: self.openRouterAPIToken,
            loggerName: "openrouter-token-store",
            failureMessage: "Failed to persist OpenRouter token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistVercelAIAPIToken() {
        self.vercelAITokenPersistTask?.cancel()
        let tokenStore = self.vercelAITokenStore
        self.vercelAITokenPersistTask = self.makeCredentialPersistTask(
            value: self.vercelAIAPIToken,
            loggerName: "vercelai-token-store",
            failureMessage: "Failed to persist Vercel AI token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistGroqAPIToken() {
        self.groqTokenPersistTask?.cancel()
        let tokenStore = self.groqTokenStore
        self.groqTokenPersistTask = self.makeCredentialPersistTask(
            value: self.groqAPIToken,
            loggerName: "groq-token-store",
            failureMessage: "Failed to persist Groq token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistDeepSeekAPIToken() {
        self.deepSeekTokenPersistTask?.cancel()
        let tokenStore = self.deepSeekTokenStore
        self.deepSeekTokenPersistTask = self.makeCredentialPersistTask(
            value: self.deepSeekAPIToken,
            loggerName: "deepseek-token-store",
            failureMessage: "Failed to persist DeepSeek token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistFireworksAPIToken() {
        self.fireworksTokenPersistTask?.cancel()
        let tokenStore = self.fireworksTokenStore
        self.fireworksTokenPersistTask = self.makeCredentialPersistTask(
            value: self.fireworksAPIToken,
            loggerName: "fireworks-token-store",
            failureMessage: "Failed to persist Fireworks token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistMistralAPIToken() {
        self.mistralTokenPersistTask?.cancel()
        let tokenStore = self.mistralTokenStore
        self.mistralTokenPersistTask = self.makeCredentialPersistTask(
            value: self.mistralAPIToken,
            loggerName: "mistral-token-store",
            failureMessage: "Failed to persist Mistral token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistPerplexityAPIToken() {
        self.perplexityTokenPersistTask?.cancel()
        let tokenStore = self.perplexityTokenStore
        self.perplexityTokenPersistTask = self.makeCredentialPersistTask(
            value: self.perplexityAPIToken,
            loggerName: "perplexity-token-store",
            failureMessage: "Failed to persist Perplexity token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistKimiAPIToken() {
        self.kimiTokenPersistTask?.cancel()
        let tokenStore = self.kimiTokenStore
        self.kimiTokenPersistTask = self.makeCredentialPersistTask(
            value: self.kimiAPIToken,
            loggerName: "kimi-token-store",
            failureMessage: "Failed to persist Kimi token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistAuggieAPIToken() {
        self.auggieTokenPersistTask?.cancel()
        let tokenStore = self.auggieTokenStore
        self.auggieTokenPersistTask = self.makeCredentialPersistTask(
            value: self.auggieAPIToken,
            loggerName: "auggie-token-store",
            failureMessage: "Failed to persist Auggie token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistTogetherAPIToken() {
        self.togetherTokenPersistTask?.cancel()
        let tokenStore = self.togetherTokenStore
        self.togetherTokenPersistTask = self.makeCredentialPersistTask(
            value: self.togetherAPIToken,
            loggerName: "together-token-store",
            failureMessage: "Failed to persist Together token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistCohereAPIToken() {
        self.cohereTokenPersistTask?.cancel()
        let tokenStore = self.cohereTokenStore
        self.cohereTokenPersistTask = self.makeCredentialPersistTask(
            value: self.cohereAPIToken,
            loggerName: "cohere-token-store",
            failureMessage: "Failed to persist Cohere token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistXAiAPIToken() {
        self.xaiTokenPersistTask?.cancel()
        let tokenStore = self.xaiTokenStore
        self.xaiTokenPersistTask = self.makeCredentialPersistTask(
            value: self.xaiAPIToken,
            loggerName: "xai-token-store",
            failureMessage: "Failed to persist xAI token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistCerebrasAPIToken() {
        self.cerebrasTokenPersistTask?.cancel()
        let tokenStore = self.cerebrasTokenStore
        self.cerebrasTokenPersistTask = self.makeCredentialPersistTask(
            value: self.cerebrasAPIToken,
            loggerName: "cerebras-token-store",
            failureMessage: "Failed to persist Cerebras token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistSambaNovaAPIToken() {
        self.sambaNovaTokenPersistTask?.cancel()
        let tokenStore = self.sambaNovaTokenStore
        self.sambaNovaTokenPersistTask = self.makeCredentialPersistTask(
            value: self.sambaNovaAPIToken,
            loggerName: "sambanova-token-store",
            failureMessage: "Failed to persist SambaNova token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistAzureOpenAIAPIToken() {
        self.azureOpenAITokenPersistTask?.cancel()
        let tokenStore = self.azureOpenAITokenStore
        self.azureOpenAITokenPersistTask = self.makeCredentialPersistTask(
            value: self.azureOpenAIAPIToken,
            loggerName: "azure-openai-token-store",
            failureMessage: "Failed to persist Azure OpenAI token") { token in
                try tokenStore.storeToken(token)
            }
    }

    private func schedulePersistQwenAPIToken() {
        self.qwenTokenPersistTask?.cancel()
        let tokenStore = self.qwenTokenStore
        self.qwenTokenPersistTask = self.makeCredentialPersistTask(
            value: self.qwenAPIToken,
            loggerName: "qwen-token-store",
            failureMessage: "Failed to persist Qwen token") { token in
                try tokenStore.storeToken(token)
            }
    }
}
