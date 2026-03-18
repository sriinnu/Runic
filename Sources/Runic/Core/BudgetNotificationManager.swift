import Foundation
import RunicCore

/// Monitors spend forecasts and posts macOS notifications when projected costs breach budget limits.
@MainActor
final class BudgetNotificationManager {
    static let shared = BudgetNotificationManager()

    private let logger = RunicLog.logger("budget-notifications")

    /// UserDefaults key prefix for tracking which breaches have already been notified.
    private static let notifiedKeyPrefix = "budgetBreachNotified-"

    /// The calendar month key used to scope notifications (e.g. "2026-03").
    /// Notifications reset each month so users are re-notified in new billing cycles.
    private var currentMonthKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private init() {}

    /// Check all spend forecasts and post notifications for newly detected breaches.
    ///
    /// - Parameters:
    ///   - forecasts: Per-provider arrays of project-level spend forecasts.
    ///   - settings: The settings store, used to check if budget notifications are enabled.
    func checkAndNotify(
        forecasts: [UsageProvider: [UsageLedgerSpendForecast]],
        settings: SettingsStore)
    {
        guard settings.budgetNotificationsEnabled else { return }

        let monthKey = self.currentMonthKey
        for (provider, providerForecasts) in forecasts {
            for forecast in providerForecasts {
                guard forecast.budgetWillBreach else { continue }
                guard let budgetLimit = forecast.budgetLimitUSD, budgetLimit > 0 else { continue }

                let projectKey = forecast.projectKey ?? forecast.projectID ?? "global"
                let notificationKey = Self.notifiedKeyPrefix + "\(monthKey)-\(provider.rawValue)-\(projectKey)"

                // Skip if already notified this month for this project
                if UserDefaults.standard.bool(forKey: notificationKey) {
                    continue
                }

                let projectName = forecast.projectName
                    ?? forecast.projectID
                    ?? ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName

                let overshoot = forecast.projected30DayCostUSD - budgetLimit
                let limitStr = UsageFormatter.usdString(budgetLimit)
                let overshootStr = UsageFormatter.usdString(max(0, overshoot))

                let title = "Budget Alert: \(projectName)"
                let body = "Projected to exceed \(limitStr) limit by \(overshootStr) this month"

                self.logger.info("posting budget breach notification",
                    metadata: [
                        "provider": provider.rawValue,
                        "project": projectKey,
                        "limit": limitStr,
                        "projected": UsageFormatter.usdString(forecast.projected30DayCostUSD),
                    ])

                AppNotifications.shared.post(
                    idPrefix: "budget-\(provider.rawValue)-\(projectKey)",
                    title: title,
                    body: body)

                // Mark as notified for this month
                UserDefaults.standard.set(true, forKey: notificationKey)
            }
        }
    }
}
