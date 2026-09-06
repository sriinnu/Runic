import Foundation
import RunicCore

extension SettingsStore {
    private static let kimiChinaOverrideMigratedKey = "kimiChinaOverrideMigrated"
    private static let regionalMigrationLog = RunicLog.logger("regional-migration")

    /// Before the Kimi (China) slot existed, the only way to track a China-platform
    /// Moonshot key was to point the international slot's base-URL override at
    /// `api.moonshot.cn`. Fold that configuration into the dedicated slot once:
    /// move the key, clear the override, flip the enabled toggles. Skipped when
    /// the China slot already has a key (the user set it up by hand) or when the
    /// override isn't a moonshot.cn host.
    func migrateKimiChinaOverrideIfNeeded() {
        guard !self.userDefaults.bool(forKey: Self.kimiChinaOverrideMigratedKey) else { return }
        self.userDefaults.set(true, forKey: Self.kimiChinaOverrideMigratedKey)

        let override = self.kimiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard override.contains("moonshot.cn") else { return }

        do {
            guard let key = try self.credentialStores.kimi.loadToken(), !key.isEmpty else { return }
            guard try self.credentialStores.kimiCN.loadToken() == nil else {
                Self.regionalMigrationLog.info(
                    "Kimi China override found but the China slot already has a key; leaving both.")
                return
            }
            try self.credentialStores.kimiCN.storeToken(key)
            try self.credentialStores.kimi.storeToken(nil)
        } catch {
            Self.regionalMigrationLog.error("Kimi China migration failed: \(error.localizedDescription)")
            return
        }

        self.kimiBaseURL = ""
        self.credentialValues.kimiAPIToken = ""
        self.autoEnableProviderIfNeeded(cliName: "kimi-cn")
        let kimiMetadata = ProviderDescriptorRegistry.descriptor(for: .kimi).metadata
        if self.isProviderEnabled(provider: .kimi, metadata: kimiMetadata) {
            self.setProviderEnabled(provider: .kimi, metadata: kimiMetadata, enabled: false)
        }
        Self.regionalMigrationLog.info(
            "Moved the Kimi key configured for api.moonshot.cn into the Kimi (China) account.")
    }
}
