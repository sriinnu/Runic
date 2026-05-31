import Foundation

struct SettingsStoreRefreshPreferenceValues {
    var refreshFrequency: RefreshFrequency
    var autoDisableRefreshWhenIdleEnabled: Bool
    var autoDisableRefreshWhenIdleMinutes: Int
    var autoDisableRefreshOnSleepEnabled: Bool
    var autoRefreshWarningEnabled: Bool
    var autoRefreshWarningThreshold: Int
    var autoSuspendInactiveProvidersEnabled: Bool
    var autoSuspendInactiveProvidersMinutes: Int
    var statusChecksEnabled: Bool

    init(defaults: SettingsStoreDefaultsSnapshot) {
        self.refreshFrequency = defaults.refreshFrequency
        self.autoDisableRefreshWhenIdleEnabled = defaults.autoDisableRefreshWhenIdleEnabled
        self.autoDisableRefreshWhenIdleMinutes = defaults.autoDisableRefreshWhenIdleMinutes
        self.autoDisableRefreshOnSleepEnabled = defaults.autoDisableRefreshOnSleepEnabled
        self.autoRefreshWarningEnabled = defaults.autoRefreshWarningEnabled
        self.autoRefreshWarningThreshold = defaults.autoRefreshWarningThreshold
        self.autoSuspendInactiveProvidersEnabled = defaults.autoSuspendInactiveProvidersEnabled
        self.autoSuspendInactiveProvidersMinutes = defaults.autoSuspendInactiveProvidersMinutes
        self.statusChecksEnabled = defaults.statusChecksEnabled
    }
}

extension SettingsStore {
    var refreshFrequency: RefreshFrequency {
        get { self.refreshPreferenceValues.refreshFrequency }
        set {
            self.refreshPreferenceValues.refreshFrequency = newValue
            self.userDefaults.set(newValue.rawValue, forKey: "refreshFrequency")
        }
    }

    var autoDisableRefreshWhenIdleEnabled: Bool {
        get { self.refreshPreferenceValues.autoDisableRefreshWhenIdleEnabled }
        set {
            self.refreshPreferenceValues.autoDisableRefreshWhenIdleEnabled = newValue
            self.userDefaults.set(newValue, forKey: "autoDisableRefreshWhenIdleEnabled")
        }
    }

    var autoDisableRefreshWhenIdleMinutes: Int {
        get { self.refreshPreferenceValues.autoDisableRefreshWhenIdleMinutes }
        set {
            self.refreshPreferenceValues.autoDisableRefreshWhenIdleMinutes = newValue
            self.userDefaults.set(newValue, forKey: "autoDisableRefreshWhenIdleMinutes")
        }
    }

    var autoDisableRefreshOnSleepEnabled: Bool {
        get { self.refreshPreferenceValues.autoDisableRefreshOnSleepEnabled }
        set {
            self.refreshPreferenceValues.autoDisableRefreshOnSleepEnabled = newValue
            self.userDefaults.set(newValue, forKey: "autoDisableRefreshOnSleepEnabled")
        }
    }

    var autoRefreshWarningEnabled: Bool {
        get { self.refreshPreferenceValues.autoRefreshWarningEnabled }
        set {
            self.refreshPreferenceValues.autoRefreshWarningEnabled = newValue
            self.userDefaults.set(newValue, forKey: "autoRefreshWarningEnabled")
        }
    }

    var autoRefreshWarningThreshold: Int {
        get { self.refreshPreferenceValues.autoRefreshWarningThreshold }
        set {
            self.refreshPreferenceValues.autoRefreshWarningThreshold = newValue
            self.userDefaults.set(newValue, forKey: "autoRefreshWarningThreshold")
        }
    }

    var autoSuspendInactiveProvidersEnabled: Bool {
        get { self.refreshPreferenceValues.autoSuspendInactiveProvidersEnabled }
        set {
            self.refreshPreferenceValues.autoSuspendInactiveProvidersEnabled = newValue
            self.userDefaults.set(newValue, forKey: "autoSuspendInactiveProvidersEnabled")
        }
    }

    var autoSuspendInactiveProvidersMinutes: Int {
        get { self.refreshPreferenceValues.autoSuspendInactiveProvidersMinutes }
        set {
            self.refreshPreferenceValues.autoSuspendInactiveProvidersMinutes = newValue
            self.userDefaults.set(newValue, forKey: "autoSuspendInactiveProvidersMinutes")
        }
    }

    var statusChecksEnabled: Bool {
        get { self.refreshPreferenceValues.statusChecksEnabled }
        set {
            self.refreshPreferenceValues.statusChecksEnabled = newValue
            self.userDefaults.set(newValue, forKey: "statusChecksEnabled")
        }
    }
}
