import Foundation
import Observation
import RunicCore

@MainActor
@Observable
final class SettingsStore {
    var appPreferenceValues: SettingsStoreAppPreferenceValues

    var refreshPreferenceValues: SettingsStoreRefreshPreferenceValues

    var usageFeatureValues: SettingsStoreUsageFeatureValues

    var appearanceValues: SettingsStoreAppearanceValues

    var providerCredentialMigrationNotice: String?

    /// Keep credential fields cold at startup; provider fetchers read keychain values only when needed.
    var credentialValues = SettingsStoreCredentialValues()

    var providerConnectionValues: SettingsStoreProviderConnectionValues

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
        self.appPreferenceValues = SettingsStoreAppPreferenceValues(defaults: defaults)
        self.refreshPreferenceValues = SettingsStoreRefreshPreferenceValues(defaults: defaults)
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
