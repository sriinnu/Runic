import Foundation
import RunicCore

/// Monitors spend forecasts and posts macOS notifications when projected costs breach budget limits.
@MainActor
final class BudgetNotificationManager {
    static let shared = BudgetNotificationManager()

    private let logger = RunicLog.logger("budget-notifications")

    /// UserDefaults key prefix for tracking which breaches have already been notified.
    private static let notifiedKeyPrefix = "budgetBreachNotified-"
    private static let thresholdNotifiedKeyPrefix = "budgetThresholdNotified-"

    enum NotificationReason: Equatable { case threshold, breach }

    struct NotificationCandidate: Equatable {
        let notificationKey: String
        let idPrefix: String
        let title: String
        let body: String
        let provider: UsageProvider
        let projectKey: String
        let limitUSD: Double
        let projectedUSD: Double
        let reason: NotificationReason
    }

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
        let candidates = Self.notificationCandidates(
            forecasts: forecasts,
            budgets: ProjectBudgetStore.getAllBudgets(),
            monthKey: monthKey,
            wasNotified: { UserDefaults.standard.bool(forKey: $0) })

        for candidate in candidates {
            self.logger.info(
                "posting budget notification",
                metadata: [
                    "provider": candidate.provider.rawValue,
                    "project": candidate.projectKey,
                    "limit": UsageFormatter.usdString(candidate.limitUSD),
                    "projected": UsageFormatter.usdString(candidate.projectedUSD),
                    "reason": "\(candidate.reason)",
                ])

            AppNotifications.shared.post(
                idPrefix: candidate.idPrefix,
                title: candidate.title,
                body: candidate.body)

            UserDefaults.standard.set(true, forKey: candidate.notificationKey)
        }
    }

    static func notificationCandidates(
        forecasts: [UsageProvider: [UsageLedgerSpendForecast]],
        budgets: [ProjectBudgetStore.ProjectBudget],
        monthKey: String,
        wasNotified: (String) -> Bool) -> [NotificationCandidate]
    {
        var candidates: [NotificationCandidate] = []

        for (provider, providerForecasts) in forecasts {
            for forecast in providerForecasts {
                let projectKey = forecast.projectKey ?? forecast.projectID ?? "global"
                let budget = budgets.first { budget in
                    guard budget.enabled else { return false }
                    return budget.projectID == projectKey
                        || budget.projectID == forecast.projectID
                        || budget.projectID == forecast.projectKey
                }
                let budgetLimit = budget?.monthlyLimit ?? forecast.budgetLimitUSD
                guard let budgetLimit, budgetLimit > 0 else { continue }

                let projectName = forecast.projectName
                    ?? forecast.projectID
                    ?? ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
                let idPrefix = "budget-\(provider.rawValue)-\(projectKey)"
                let projected = forecast.projected30DayCostUSD

                if forecast.budgetWillBreach || projected > budgetLimit {
                    let notificationKey = Self.notifiedKeyPrefix + "\(monthKey)-\(provider.rawValue)-\(projectKey)"
                    guard !wasNotified(notificationKey) else { continue }
                    let overshoot = projected - budgetLimit
                    let limitStr = UsageFormatter.usdString(budgetLimit)
                    let overshootStr = UsageFormatter.usdString(max(0, overshoot))
                    candidates.append(NotificationCandidate(
                        notificationKey: notificationKey,
                        idPrefix: idPrefix,
                        title: "Budget Alert: \(projectName)",
                        body: "Projected to exceed \(limitStr) limit by \(overshootStr) this month",
                        provider: provider,
                        projectKey: projectKey,
                        limitUSD: budgetLimit,
                        projectedUSD: projected,
                        reason: .breach))
                    continue
                }

                guard let budget else { continue }
                let threshold = min(1, max(0.01, budget.alertThreshold))
                guard projected >= budgetLimit * threshold else { continue }
                let thresholdKey = Int((threshold * 100).rounded())
                let notificationKey = Self.thresholdNotifiedKeyPrefix
                    + "\(monthKey)-\(provider.rawValue)-\(projectKey)-\(thresholdKey)"
                guard !wasNotified(notificationKey) else { continue }

                candidates.append(NotificationCandidate(
                    notificationKey: notificationKey,
                    idPrefix: idPrefix,
                    title: "Budget Watch: \(projectName)",
                    body: "Projected to reach \(UsageFormatter.usdString(projected)) of \(UsageFormatter.usdString(budgetLimit)) limit (\(thresholdKey)% alert threshold)",
                    provider: provider,
                    projectKey: projectKey,
                    limitUSD: budgetLimit,
                    projectedUSD: projected,
                    reason: .threshold))
            }
        }

        return candidates
    }
}
