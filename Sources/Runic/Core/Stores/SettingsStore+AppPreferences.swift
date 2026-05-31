import Foundation

struct SettingsStoreAppPreferenceValues {
    var providerOrderRaw: [String]
    var launchAtLogin: Bool
    var debugMenuEnabled: Bool
    var debugLoadingPatternRaw: String?
    var selectedMenuProviderRaw: String?
    var providerDetectionCompleted: Bool

    init(defaults: SettingsStoreDefaultsSnapshot) {
        self.providerOrderRaw = defaults.providerOrderRaw
        self.launchAtLogin = defaults.launchAtLogin
        self.debugMenuEnabled = defaults.debugMenuEnabled
        self.debugLoadingPatternRaw = defaults.debugLoadingPatternRaw
        self.selectedMenuProviderRaw = defaults.selectedMenuProviderRaw
        self.providerDetectionCompleted = defaults.providerDetectionCompleted
    }
}

extension SettingsStore {
    /// Persisted provider display order.
    ///
    /// Stored as raw `UsageProvider` strings so new providers can be appended automatically without breaking.
    var providerOrderRaw: [String] {
        get { self.appPreferenceValues.providerOrderRaw }
        set {
            self.appPreferenceValues.providerOrderRaw = newValue
            self.userDefaults.set(newValue, forKey: "providerOrder")
        }
    }

    var launchAtLogin: Bool {
        get { self.appPreferenceValues.launchAtLogin }
        set {
            self.appPreferenceValues.launchAtLogin = newValue
            self.userDefaults.set(newValue, forKey: "launchAtLogin")
        }
    }

    /// Hidden toggle to reveal debug-only menu items (enable via defaults write com.sriinnu.athena.Runic
    /// debugMenuEnabled
    /// -bool YES).
    var debugMenuEnabled: Bool {
        get { self.appPreferenceValues.debugMenuEnabled }
        set {
            self.appPreferenceValues.debugMenuEnabled = newValue
            self.userDefaults.set(newValue, forKey: "debugMenuEnabled")
        }
    }

    var debugLoadingPatternRaw: String? {
        get { self.appPreferenceValues.debugLoadingPatternRaw }
        set {
            self.appPreferenceValues.debugLoadingPatternRaw = newValue
            if let newValue {
                self.userDefaults.set(newValue, forKey: "debugLoadingPattern")
            } else {
                self.userDefaults.removeObject(forKey: "debugLoadingPattern")
            }
        }
    }

    var selectedMenuProviderRaw: String? {
        get { self.appPreferenceValues.selectedMenuProviderRaw }
        set {
            self.appPreferenceValues.selectedMenuProviderRaw = newValue
            if let newValue {
                self.userDefaults.set(newValue, forKey: "selectedMenuProvider")
            } else {
                self.userDefaults.removeObject(forKey: "selectedMenuProvider")
            }
        }
    }

    var providerDetectionCompleted: Bool {
        get { self.appPreferenceValues.providerDetectionCompleted }
        set {
            self.appPreferenceValues.providerDetectionCompleted = newValue
            self.userDefaults.set(newValue, forKey: "providerDetectionCompleted")
        }
    }
}
