import Observation
import RunicCore

// MARK: - Observation helpers

@MainActor
extension UsageStore {
    var menuObservationToken: Int {
        _ = self.snapshots
        _ = self.errors
        _ = self.lastSourceLabels
        _ = self.lastFetchAttempts
        _ = self.tokenSnapshots
        _ = self.tokenErrors
        _ = self.tokenRefreshInFlight
        _ = self.customProviderSnapshots
        _ = self.customProviderErrors
        _ = self.ledgerDailySummaries
        _ = self.ledgerAllDailySummaries
        _ = self.ledgerHourlySummaries
        _ = self.ledgerActiveBlocks
        _ = self.ledgerTopModels
        _ = self.ledgerTopProjects
        _ = self.ledgerModelBreakdowns
        _ = self.ledgerProjectBreakdowns
        _ = self.ledgerSpendForecasts
        _ = self.ledgerProjectSpendForecasts
        _ = self.ledgerTopProjectSpendForecasts
        _ = self.ledgerAnomalies
        _ = self.ledgerErrors
        _ = self.ledgerUpdatedAt
        _ = self.credits
        _ = self.lastCreditsError
        _ = self.openAIDashboard
        _ = self.lastOpenAIDashboardError
        _ = self.openAIDashboardRequiresLogin
        _ = self.openAIDashboardCookieImportStatus
        _ = self.openAIDashboardCookieImportDebugLog
        _ = self.codexVersion
        _ = self.claudeVersion
        _ = self.geminiVersion
        _ = self.zaiVersion
        _ = self.antigravityVersion
        _ = self.isRefreshing
        _ = self.refreshingProviders
        _ = self.pathDebugInfo
        _ = self.statuses
        _ = self.probeLogs
        _ = self.autoRefreshSuspensionReason
        _ = self.lastRefreshTrigger
        _ = self.lastRefreshAt
        _ = self.lastAutoRefreshDisableReason
        _ = self.lastAutoRefreshDisableAt
        return 0
    }

    func observeSettingsChanges() {
        withObservationTracking {
            _ = self.settings.refreshFrequency
            _ = self.settings.autoDisableRefreshWhenIdleEnabled
            _ = self.settings.autoDisableRefreshWhenIdleMinutes
            _ = self.settings.autoDisableRefreshOnSleepEnabled
            _ = self.settings.autoRefreshWarningEnabled
            _ = self.settings.autoRefreshWarningThreshold
            _ = self.settings.autoSuspendInactiveProvidersEnabled
            _ = self.settings.autoSuspendInactiveProvidersMinutes
            _ = self.settings.statusChecksEnabled
            _ = self.settings.sessionQuotaNotificationsEnabled
            _ = self.settings.usageBarsShowUsed
            _ = self.settings.costUsageEnabled
            _ = self.settings.randomBlinkEnabled
            _ = self.settings.claudeWebExtrasEnabled
            _ = self.settings.claudeUsageDataSource
            _ = self.settings.mergeIcons
            _ = self.settings.debugLoadingPattern
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeSettingsChanges()
                await self.handleSettingsChange()
            }
        }
    }
}

