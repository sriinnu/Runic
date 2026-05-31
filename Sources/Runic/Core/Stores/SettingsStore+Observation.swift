import RunicCore

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
}
