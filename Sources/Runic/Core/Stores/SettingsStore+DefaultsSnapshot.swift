import Foundation
import RunicCore

struct SettingsStoreDefaultsSnapshot {
    let providerOrderRaw: [String]
    let refreshFrequency: RefreshFrequency
    let autoDisableRefreshWhenIdleEnabled: Bool
    let autoDisableRefreshWhenIdleMinutes: Int
    let autoDisableRefreshOnSleepEnabled: Bool
    let autoRefreshWarningEnabled: Bool
    let autoRefreshWarningThreshold: Int
    let autoSuspendInactiveProvidersEnabled: Bool
    let autoSuspendInactiveProvidersMinutes: Int
    let launchAtLogin: Bool
    let debugMenuEnabled: Bool
    let debugLoadingPatternRaw: String?
    let statusChecksEnabled: Bool
    let sessionQuotaNotificationsEnabled: Bool
    let budgetNotificationsEnabled: Bool
    let usageBarsShowUsed: Bool
    let usageMetricDisplayMode: UsageMetricDisplayMode
    let menuMode: MenuMode
    let chartStyle: ChartStyle
    let numberFormat: NumberFormat
    let dateFormat: DateFormat
    let theme: Theme
    let selectedFontFamily: String
    let menuBarShowsBrandIconWithPercent: Bool
    let menuBarVibrantIconEnabled: Bool
    let costUsageEnabled: Bool
    let otelGenAILogPaths: String
    let insightsMenuMaxItems: Int
    let insightsReportDays: Int
    let ledgerMaxAgeDays: Int
    let randomBlinkEnabled: Bool
    let claudeWebExtrasEnabled: Bool
    let showOptionalCreditsAndExtraUsage: Bool
    let openAIWebAccessEnabled: Bool
    let codexUsageDataSourceRaw: String?
    let claudeUsageDataSourceRaw: String?
    let mergeIcons: Bool
    let switcherShowsIcons: Bool
    let providerSwitcherLayout: ProviderSwitcherLayout
    let providerSwitcherIconSize: ProviderSwitcherIconSize
    let providersPaneSidebar: Bool
    let azureOpenAIEndpoint: String
    let azureOpenAIDeployment: String
    let azureOpenAIAPIVersion: String
    let bedrockRegion: String
    let bedrockAWSProfile: String
    let bedrockModelID: String
    let vertexaiProject: String
    let vertexaiLocation: String
    let selectedMenuProviderRaw: String?
    let providerDetectionCompleted: Bool

    static func load(from userDefaults: UserDefaults) -> Self {
        let sessionQuotaNotificationsEnabled = Self.bool(
            "sessionQuotaNotificationsEnabled",
            defaultValue: true,
            persistDefaultWhenMissing: true,
            userDefaults: userDefaults)
        let showOptionalCreditsAndExtraUsage = Self.bool(
            "showOptionalCreditsAndExtraUsage",
            defaultValue: true,
            persistDefaultWhenMissing: true,
            userDefaults: userDefaults)
        let openAIWebAccessEnabled = Self.bool(
            "openAIWebAccessEnabled",
            defaultValue: true,
            persistDefaultWhenMissing: true,
            userDefaults: userDefaults)
        let theme = Self.theme(userDefaults: userDefaults)
        let selectedFontFamily = Self.selectedFontFamily(userDefaults: userDefaults)
        let selectedMenuProviderRaw = userDefaults
            .string(forKey: "selectedMenuProvider")
            .flatMap { UsageProvider(rawValue: $0)?.rawValue }

        return Self(
            providerOrderRaw: userDefaults.stringArray(forKey: "providerOrder") ?? [],
            refreshFrequency: Self.enumValue(
                "refreshFrequency",
                defaultValue: RefreshFrequency.manual,
                userDefaults: userDefaults),
            autoDisableRefreshWhenIdleEnabled: Self.bool(
                "autoDisableRefreshWhenIdleEnabled",
                defaultValue: true,
                userDefaults: userDefaults),
            autoDisableRefreshWhenIdleMinutes: Self.int(
                "autoDisableRefreshWhenIdleMinutes",
                defaultValue: 5,
                userDefaults: userDefaults),
            autoDisableRefreshOnSleepEnabled: Self.bool(
                "autoDisableRefreshOnSleepEnabled",
                defaultValue: true,
                userDefaults: userDefaults),
            autoRefreshWarningEnabled: Self.bool(
                "autoRefreshWarningEnabled",
                defaultValue: true,
                userDefaults: userDefaults),
            autoRefreshWarningThreshold: Self.int(
                "autoRefreshWarningThreshold",
                defaultValue: 10,
                userDefaults: userDefaults),
            autoSuspendInactiveProvidersEnabled: Self.bool(
                "autoSuspendInactiveProvidersEnabled",
                defaultValue: true,
                userDefaults: userDefaults),
            autoSuspendInactiveProvidersMinutes: Self.int(
                "autoSuspendInactiveProvidersMinutes",
                defaultValue: 720,
                userDefaults: userDefaults),
            launchAtLogin: Self.bool("launchAtLogin", defaultValue: false, userDefaults: userDefaults),
            debugMenuEnabled: Self.bool("debugMenuEnabled", defaultValue: false, userDefaults: userDefaults),
            debugLoadingPatternRaw: userDefaults.string(forKey: "debugLoadingPattern"),
            statusChecksEnabled: Self.bool("statusChecksEnabled", defaultValue: true, userDefaults: userDefaults),
            sessionQuotaNotificationsEnabled: sessionQuotaNotificationsEnabled,
            budgetNotificationsEnabled: Self.bool(
                "budgetNotificationsEnabled",
                defaultValue: false,
                userDefaults: userDefaults),
            usageBarsShowUsed: Self.bool("usageBarsShowUsed", defaultValue: true, userDefaults: userDefaults),
            usageMetricDisplayMode: Self.enumValue(
                "usageMetricDisplayMode",
                defaultValue: UsageMetricDisplayMode.barsAndPercent,
                userDefaults: userDefaults),
            menuMode: Self.enumValue("menuMode", defaultValue: MenuMode.operator, userDefaults: userDefaults),
            chartStyle: Self.enumValue("chartStyle", defaultValue: ChartStyle.line, userDefaults: userDefaults),
            numberFormat: Self.enumValue(
                "numberFormat",
                defaultValue: NumberFormat.abbreviated,
                userDefaults: userDefaults),
            dateFormat: Self.enumValue("dateFormat", defaultValue: DateFormat.relative, userDefaults: userDefaults),
            theme: theme,
            selectedFontFamily: selectedFontFamily,
            menuBarShowsBrandIconWithPercent: Self.bool(
                "menuBarShowsBrandIconWithPercent",
                defaultValue: false,
                userDefaults: userDefaults),
            menuBarVibrantIconEnabled: Self.bool(
                "menuBarVibrantIconEnabled",
                defaultValue: true,
                userDefaults: userDefaults),
            costUsageEnabled: Self.bool("tokenCostUsageEnabled", defaultValue: true, userDefaults: userDefaults),
            otelGenAILogPaths: userDefaults.string(forKey: "otelGenAILogPaths") ?? "",
            insightsMenuMaxItems: Self.int("insightsMenuMaxItems", defaultValue: 4, userDefaults: userDefaults),
            insightsReportDays: Self.int("insightsReportDays", defaultValue: 7, userDefaults: userDefaults),
            ledgerMaxAgeDays: Self.int("ledgerMaxAgeDays", defaultValue: 30, userDefaults: userDefaults),
            randomBlinkEnabled: Self.bool("randomBlinkEnabled", defaultValue: false, userDefaults: userDefaults),
            claudeWebExtrasEnabled: Self.bool(
                "claudeWebExtrasEnabled",
                defaultValue: false,
                userDefaults: userDefaults),
            showOptionalCreditsAndExtraUsage: showOptionalCreditsAndExtraUsage,
            openAIWebAccessEnabled: openAIWebAccessEnabled,
            codexUsageDataSourceRaw: userDefaults.string(forKey: "codexUsageDataSource")
                ?? CodexUsageDataSource.oauth.rawValue,
            claudeUsageDataSourceRaw: userDefaults.string(forKey: "claudeUsageDataSource")
                ?? ClaudeUsageDataSource.oauth.rawValue,
            mergeIcons: Self.bool("mergeIcons", defaultValue: true, userDefaults: userDefaults),
            switcherShowsIcons: Self.bool("switcherShowsIcons", defaultValue: true, userDefaults: userDefaults),
            providerSwitcherLayout: Self.enumValue(
                "providerSwitcherLayout",
                defaultValue: ProviderSwitcherLayout.top,
                userDefaults: userDefaults),
            providerSwitcherIconSize: Self.enumValue(
                "providerSwitcherIconSize",
                defaultValue: ProviderSwitcherIconSize.medium,
                userDefaults: userDefaults),
            providersPaneSidebar: Self.bool("providersPaneSidebar", defaultValue: false, userDefaults: userDefaults),
            azureOpenAIEndpoint: userDefaults.string(forKey: "azureOpenAIEndpoint") ?? "",
            azureOpenAIDeployment: userDefaults.string(forKey: "azureOpenAIDeployment") ?? "",
            azureOpenAIAPIVersion: userDefaults.string(forKey: "azureOpenAIAPIVersion") ?? "2024-10-21",
            bedrockRegion: userDefaults.string(forKey: "bedrockRegion") ?? "",
            bedrockAWSProfile: userDefaults.string(forKey: "bedrockAWSProfile") ?? "",
            bedrockModelID: userDefaults.string(forKey: "bedrockModelID") ?? "",
            vertexaiProject: userDefaults.string(forKey: "vertexaiProject") ?? "",
            vertexaiLocation: userDefaults.string(forKey: "vertexaiLocation") ?? "",
            selectedMenuProviderRaw: selectedMenuProviderRaw,
            providerDetectionCompleted: Self.bool(
                "providerDetectionCompleted",
                defaultValue: false,
                userDefaults: userDefaults))
    }

    private static func bool(
        _ key: String,
        defaultValue: Bool,
        persistDefaultWhenMissing: Bool = false,
        userDefaults: UserDefaults) -> Bool
    {
        guard let value = userDefaults.object(forKey: key) as? Bool else {
            if persistDefaultWhenMissing {
                userDefaults.set(defaultValue, forKey: key)
            }
            return defaultValue
        }
        return value
    }

    private static func int(_ key: String, defaultValue: Int, userDefaults: UserDefaults) -> Int {
        userDefaults.object(forKey: key) as? Int ?? defaultValue
    }

    private static func enumValue<Value: RawRepresentable>(
        _ key: String,
        defaultValue: Value,
        userDefaults: UserDefaults) -> Value where Value.RawValue == String
    {
        let raw = userDefaults.string(forKey: key)
        return raw.flatMap(Value.init(rawValue:)) ?? defaultValue
    }

    private static func theme(userDefaults: UserDefaults) -> Theme {
        let raw = userDefaults.string(forKey: "theme") ?? ""
        if Theme.retiredRawValues.contains(raw) {
            userDefaults.set(Theme.daybreak.rawValue, forKey: "theme")
            return .daybreak
        }
        if let resolved = Theme(rawValue: raw) {
            return resolved
        }
        userDefaults.set(Theme.default.rawValue, forKey: "theme")
        return Theme.default
    }

    private static func selectedFontFamily(userDefaults: UserDefaults) -> String {
        let stored = userDefaults.string(forKey: "selectedFontFamily")
        let migrated = RunicFontChoice.migratedFamily(stored)
        if (stored ?? "") != migrated {
            userDefaults.set(migrated, forKey: "selectedFontFamily")
        }
        return migrated
    }
}
