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
    var providerOrderRaw: [String] {
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

    var debugLoadingPatternRaw: String? {
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

    var appearanceValues: SettingsStoreAppearanceValues

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

    var codexUsageDataSourceRaw: String? {
        didSet {
            if let raw = self.codexUsageDataSourceRaw {
                self.userDefaults.set(raw, forKey: "codexUsageDataSource")
            } else {
                self.userDefaults.removeObject(forKey: "codexUsageDataSource")
            }
        }
    }

    var claudeUsageDataSourceRaw: String? {
        didSet {
            if let raw = self.claudeUsageDataSourceRaw {
                self.userDefaults.set(raw, forKey: "claudeUsageDataSource")
            } else {
                self.userDefaults.removeObject(forKey: "claudeUsageDataSource")
            }
        }
    }

    // Keep credential fields cold at startup; provider fetchers read keychain values only when needed.
    var credentialValues = SettingsStoreCredentialValues()

    var providerConnectionValues: SettingsStoreProviderConnectionValues

    var selectedMenuProviderRaw: String? {
        didSet {
            if let raw = self.selectedMenuProviderRaw {
                self.userDefaults.set(raw, forKey: "selectedMenuProvider")
            } else {
                self.userDefaults.removeObject(forKey: "selectedMenuProvider")
            }
        }
    }

    var providerDetectionCompleted: Bool {
        didSet { self.userDefaults.set(self.providerDetectionCompleted, forKey: "providerDetectionCompleted") }
    }

    @ObservationIgnored let userDefaults: UserDefaults
    @ObservationIgnored let toggleStore: ProviderToggleStore
    @ObservationIgnored let credentialStores: SettingsStoreCredentialStores
    @ObservationIgnored var credentialPersistTasks = SettingsStoreCredentialPersistTasks()
    // Cache enablement so tight UI loops (menu bar animations) don't hit UserDefaults each tick.
    @ObservationIgnored var cachedProviderEnablement: [UsageProvider: Bool] = [:]
    @ObservationIgnored var cachedProviderEnablementRevision: Int = -1
    @ObservationIgnored var cachedEnabledProviders: [UsageProvider] = []
    @ObservationIgnored var cachedEnabledProvidersRevision: Int = -1
    @ObservationIgnored var cachedEnabledProvidersOrderRaw: [String] = []
    // Cache order to avoid re-building sets/arrays every animation tick.
    @ObservationIgnored var cachedProviderOrder: [UsageProvider] = []
    @ObservationIgnored var cachedProviderOrderRaw: [String] = []
    var providerToggleRevision: Int = 0

    init(userDefaults: UserDefaults, credentialStores: SettingsStoreCredentialStores) {
        self.userDefaults = userDefaults
        self.credentialStores = credentialStores
        let defaults = SettingsStoreDefaultsSnapshot.load(from: userDefaults)
        self.providerOrderRaw = defaults.providerOrderRaw
        self.refreshFrequency = defaults.refreshFrequency
        self.autoDisableRefreshWhenIdleEnabled = defaults.autoDisableRefreshWhenIdleEnabled
        self.autoDisableRefreshWhenIdleMinutes = defaults.autoDisableRefreshWhenIdleMinutes
        self.autoDisableRefreshOnSleepEnabled = defaults.autoDisableRefreshOnSleepEnabled
        self.autoRefreshWarningEnabled = defaults.autoRefreshWarningEnabled
        self.autoRefreshWarningThreshold = defaults.autoRefreshWarningThreshold
        self.autoSuspendInactiveProvidersEnabled = defaults.autoSuspendInactiveProvidersEnabled
        self.autoSuspendInactiveProvidersMinutes = defaults.autoSuspendInactiveProvidersMinutes
        self.launchAtLogin = defaults.launchAtLogin
        self.debugMenuEnabled = defaults.debugMenuEnabled
        self.debugLoadingPatternRaw = defaults.debugLoadingPatternRaw
        self.statusChecksEnabled = defaults.statusChecksEnabled
        self.sessionQuotaNotificationsEnabled = defaults.sessionQuotaNotificationsEnabled
        self.budgetNotificationsEnabled = defaults.budgetNotificationsEnabled
        self.appearanceValues = SettingsStoreAppearanceValues(defaults: defaults)
        self.costUsageEnabled = defaults.costUsageEnabled
        self.otelGenAILogPaths = defaults.otelGenAILogPaths
        self.insightsMenuMaxItems = defaults.insightsMenuMaxItems
        self.insightsReportDays = defaults.insightsReportDays
        self.ledgerMaxAgeDays = defaults.ledgerMaxAgeDays
        self.claudeWebExtrasEnabled = defaults.claudeWebExtrasEnabled
        self.showOptionalCreditsAndExtraUsage = defaults.showOptionalCreditsAndExtraUsage
        self.openAIWebAccessEnabled = defaults.openAIWebAccessEnabled
        self.codexUsageDataSourceRaw = defaults.codexUsageDataSourceRaw
        self.claudeUsageDataSourceRaw = defaults.claudeUsageDataSourceRaw
        self.providerConnectionValues = SettingsStoreProviderConnectionValues(defaults: defaults)
        let credentialMigration = ProviderCredentialKeychainMigration.migrateKnownLegacyItems()
        if credentialMigration.needsUserRepair {
            let blocked = credentialMigration.blockedAccounts.count
            let failed = credentialMigration.failedAccounts.count
            self.providerCredentialMigrationNotice =
                "Some saved provider keys need a one-time re-save after keychain hardening " +
                "(\(blocked) blocked, \(failed) failed). Re-save affected API keys below; " +
                "Runic will not prompt in the background."
        }
        self.selectedMenuProviderRaw = defaults.selectedMenuProviderRaw
        self.providerDetectionCompleted = defaults.providerDetectionCompleted
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
