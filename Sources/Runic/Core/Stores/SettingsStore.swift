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

    var refreshPreferenceValues: SettingsStoreRefreshPreferenceValues

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

    var usageFeatureValues: SettingsStoreUsageFeatureValues

    var appearanceValues: SettingsStoreAppearanceValues

    var providerCredentialMigrationNotice: String?

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
        self.refreshPreferenceValues = SettingsStoreRefreshPreferenceValues(defaults: defaults)
        self.launchAtLogin = defaults.launchAtLogin
        self.debugMenuEnabled = defaults.debugMenuEnabled
        self.debugLoadingPatternRaw = defaults.debugLoadingPatternRaw
        self.usageFeatureValues = SettingsStoreUsageFeatureValues(defaults: defaults)
        self.appearanceValues = SettingsStoreAppearanceValues(defaults: defaults)
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
