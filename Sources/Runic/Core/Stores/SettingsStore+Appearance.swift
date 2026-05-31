import Foundation
import RunicCore

struct SettingsStoreAppearanceValues {
    var usageBarsShowUsed: Bool
    var usageMetricDisplayMode: UsageMetricDisplayMode
    var menuMode: MenuMode
    var chartStyle: ChartStyle
    var numberFormat: NumberFormat
    var dateFormat: DateFormat
    var theme: Theme
    var selectedFontFamily: String
    var visualSettingsRevision: Int
    var menuBarShowsBrandIconWithPercent: Bool
    var menuBarVibrantIconEnabled: Bool
    var randomBlinkEnabled: Bool
    var mergeIcons: Bool
    var switcherShowsIcons: Bool
    var providerSwitcherLayout: ProviderSwitcherLayout
    var providerSwitcherIconSize: ProviderSwitcherIconSize
    var providersPaneSidebar: Bool

    init(defaults: SettingsStoreDefaultsSnapshot) {
        self.usageBarsShowUsed = defaults.usageBarsShowUsed
        self.usageMetricDisplayMode = defaults.usageMetricDisplayMode
        self.menuMode = defaults.menuMode
        self.chartStyle = defaults.chartStyle
        self.numberFormat = defaults.numberFormat
        self.dateFormat = defaults.dateFormat
        self.theme = defaults.theme
        self.selectedFontFamily = defaults.selectedFontFamily
        self.visualSettingsRevision = 0
        self.menuBarShowsBrandIconWithPercent = defaults.menuBarShowsBrandIconWithPercent
        self.menuBarVibrantIconEnabled = defaults.menuBarVibrantIconEnabled
        self.randomBlinkEnabled = defaults.randomBlinkEnabled
        self.mergeIcons = defaults.mergeIcons
        self.switcherShowsIcons = defaults.switcherShowsIcons
        self.providerSwitcherLayout = defaults.providerSwitcherLayout
        self.providerSwitcherIconSize = defaults.providerSwitcherIconSize
        self.providersPaneSidebar = defaults.providersPaneSidebar
    }
}

extension SettingsStore {
    /// When enabled, progress bars show "percent used" instead of "percent left".
    var usageBarsShowUsed: Bool {
        get { self.appearanceValues.usageBarsShowUsed }
        set {
            self.appearanceValues.usageBarsShowUsed = newValue
            self.userDefaults.set(newValue, forKey: "usageBarsShowUsed")
        }
    }

    var usageMetricDisplayMode: UsageMetricDisplayMode {
        get { self.appearanceValues.usageMetricDisplayMode }
        set {
            self.appearanceValues.usageMetricDisplayMode = newValue
            self.userDefaults.set(newValue.rawValue, forKey: "usageMetricDisplayMode")
        }
    }

    var menuMode: MenuMode {
        get { self.appearanceValues.menuMode }
        set {
            self.appearanceValues.menuMode = newValue
            self.userDefaults.set(newValue.rawValue, forKey: "menuMode")
        }
    }

    var chartStyle: ChartStyle {
        get { self.appearanceValues.chartStyle }
        set {
            self.appearanceValues.chartStyle = newValue
            self.userDefaults.set(newValue.rawValue, forKey: "chartStyle")
        }
    }

    var numberFormat: NumberFormat {
        get { self.appearanceValues.numberFormat }
        set {
            self.appearanceValues.numberFormat = newValue
            self.userDefaults.set(newValue.rawValue, forKey: "numberFormat")
        }
    }

    var dateFormat: DateFormat {
        get { self.appearanceValues.dateFormat }
        set {
            self.appearanceValues.dateFormat = newValue
            self.userDefaults.set(newValue.rawValue, forKey: "dateFormat")
        }
    }

    var theme: Theme {
        get { self.appearanceValues.theme }
        set {
            self.appearanceValues.theme = newValue
            self.userDefaults.set(newValue.rawValue, forKey: "theme")
            RunicApp.applyTheme(newValue)
            RunicFont.applyTheme(newValue.palette)
            IconRenderer.themePalette = newValue.palette
            self.bumpVisualSettingsRevision()
        }
    }

    var selectedFontFamily: String {
        get { self.appearanceValues.selectedFontFamily }
        set {
            let migrated = RunicFontChoice.migratedFamily(newValue)
            self.appearanceValues.selectedFontFamily = migrated
            self.userDefaults.set(migrated, forKey: "selectedFontFamily")
            RunicFont.family = migrated
            self.bumpVisualSettingsRevision()
        }
    }

    var visualSettingsRevision: Int {
        self.appearanceValues.visualSettingsRevision
    }

    /// Optional: use provider branding icons with a percentage in the menu bar.
    var menuBarShowsBrandIconWithPercent: Bool {
        get { self.appearanceValues.menuBarShowsBrandIconWithPercent }
        set {
            self.appearanceValues.menuBarShowsBrandIconWithPercent = newValue
            self.userDefaults.set(newValue, forKey: "menuBarShowsBrandIconWithPercent")
        }
    }

    /// Optional: render the menu bar icon with a vibrant, data-reactive color.
    var menuBarVibrantIconEnabled: Bool {
        get { self.appearanceValues.menuBarVibrantIconEnabled }
        set {
            self.appearanceValues.menuBarVibrantIconEnabled = newValue
            self.userDefaults.set(newValue, forKey: "menuBarVibrantIconEnabled")
        }
    }

    var randomBlinkEnabled: Bool {
        get { self.appearanceValues.randomBlinkEnabled }
        set {
            self.appearanceValues.randomBlinkEnabled = newValue
            self.userDefaults.set(newValue, forKey: "randomBlinkEnabled")
        }
    }

    /// Optional: collapse provider icons into a single menu bar item with an in-menu switcher.
    var mergeIcons: Bool {
        get { self.appearanceValues.mergeIcons }
        set {
            self.appearanceValues.mergeIcons = newValue
            self.userDefaults.set(newValue, forKey: "mergeIcons")
        }
    }

    /// Optional: show provider icons in the in-menu switcher.
    var switcherShowsIcons: Bool {
        get { self.appearanceValues.switcherShowsIcons }
        set {
            self.appearanceValues.switcherShowsIcons = newValue
            self.userDefaults.set(newValue, forKey: "switcherShowsIcons")
        }
    }

    /// Optional: position the provider switcher either on top or in a left sidebar.
    var providerSwitcherLayout: ProviderSwitcherLayout {
        get { self.appearanceValues.providerSwitcherLayout }
        set {
            self.appearanceValues.providerSwitcherLayout = newValue
            self.userDefaults.set(newValue.rawValue, forKey: "providerSwitcherLayout")
        }
    }

    /// Optional: size of provider icons in the switcher.
    var providerSwitcherIconSize: ProviderSwitcherIconSize {
        get { self.appearanceValues.providerSwitcherIconSize }
        set {
            self.appearanceValues.providerSwitcherIconSize = newValue
            self.userDefaults.set(newValue.rawValue, forKey: "providerSwitcherIconSize")
        }
    }

    /// Show the built-in providers pane as a sidebar (true) or flat list (false).
    var providersPaneSidebar: Bool {
        get { self.appearanceValues.providersPaneSidebar }
        set {
            self.appearanceValues.providersPaneSidebar = newValue
            self.userDefaults.set(newValue, forKey: "providersPaneSidebar")
        }
    }

    private func bumpVisualSettingsRevision() {
        self.appearanceValues.visualSettingsRevision &+= 1
    }
}
