import Foundation
import SwiftUI
import RunicCore

/// iOS-specific usage store with background refresh and notifications
@MainActor
@Observable
final class iOSUsageStore {
    var snapshots: [UsageProvider: EnhancedUsageSnapshot] = [:]
    var errors: [UsageProvider: Error] = [:]
    var isRefreshing = false
    var lastRefreshDate: Date?

    private let fetcher: UsageFetcher
    private let notificationManager: NotificationManager

    init() {
        self.fetcher = UsageFetcher()
        self.notificationManager = NotificationManager()
    }

    /// Initial refresh on app launch
    func initialRefresh() async {
        await refresh()
    }

    /// Refresh all enabled providers
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let providers = UsageProvider.allCases.filter { isEnabled($0) }

        await withTaskGroup(of: (UsageProvider, Result<EnhancedUsageSnapshot, Error>).self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let snapshot = try await self.fetchSnapshot(for: provider)
                        return (provider, .success(snapshot))
                    } catch {
                        return (provider, .failure(error))
                    }
                }
            }

            for await (provider, result) in group {
                switch result {
                case .success(let snapshot):
                    snapshots[provider] = snapshot
                    errors[provider] = nil

                    // Check for alerts
                    await checkAndNotify(snapshot: snapshot)

                case .failure(let error):
                    errors[provider] = error
                }
            }
        }

        lastRefreshDate = Date()
    }

    /// Refresh a specific provider
    func refresh(provider: UsageProvider) async {
        do {
            let snapshot = try await fetchSnapshot(for: provider)
            snapshots[provider] = snapshot
            errors[provider] = nil
            await checkAndNotify(snapshot: snapshot)
        } catch {
            errors[provider] = error
        }
    }

    /// Fetch enhanced snapshot for a provider
    private func fetchSnapshot(for provider: UsageProvider) async throws -> EnhancedUsageSnapshot {
        // TODO: Implement actual fetching logic
        // For now, return mock data

        let usedPercent = Double.random(in: 0...100)
        let resetAt = Date().addingTimeInterval(Double.random(in: 3600...86400))

        return EnhancedUsageSnapshot(
            provider: provider,
            primary: RateWindow(usedPercent: usedPercent, windowMinutes: 300),
            accountType: .subscription,
            accountEmail: "user@example.com",
            primaryReset: UsageResetInfo(
                resetType: .sessionBased,
                resetAt: resetAt,
                windowDuration: 5 * 3600
            ),
            primaryModel: ModelUsageInfo(
                modelName: "claude-3-5-sonnet",
                modelFamily: .claude3,
                tier: .sonnet
            ),
            updatedAt: Date(),
            fetchSource: "oauth"
        )
    }

    /// Check if usage warrants a notification
    private func checkAndNotify(snapshot: EnhancedUsageSnapshot) async {
        // Critical threshold: 90%
        if snapshot.primary.usedPercent >= 90 {
            await notificationManager.sendUsageAlert(
                provider: snapshot.provider,
                usagePercent: snapshot.primary.usedPercent,
                severity: .critical
            )
        }
        // Warning threshold: 75%
        else if snapshot.primary.usedPercent >= 75 {
            await notificationManager.sendUsageAlert(
                provider: snapshot.provider,
                usagePercent: snapshot.primary.usedPercent,
                severity: .warning
            )
        }
    }

    private func isEnabled(_ provider: UsageProvider) -> Bool {
        // TODO: Read from UserDefaults
        return true
    }
}

// MARK: - Notification Manager

@MainActor
final class NotificationManager {
    func sendUsageAlert(
        provider: UsageProvider,
        usagePercent: Double,
        severity: UsageAlert.Severity
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "\(provider.rawValue.capitalized) Usage Alert"

        switch severity {
        case .critical:
            content.body = "⚠️ Critical: \(Int(usagePercent))% used. Approaching limit!"
            content.sound = .defaultCritical
        case .warning:
            content.body = "⚡ Warning: \(Int(usagePercent))% used. Monitor closely."
            content.sound = .default
        default:
            content.body = "\(Int(usagePercent))% used"
            content.sound = .default
        }

        content.categoryIdentifier = "USAGE_ALERT"
        content.userInfo = [
            "provider": provider.rawValue,
            "usagePercent": usagePercent
        ]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
}

// MARK: - Alert Manager

@MainActor
@Observable
final class AlertManager {
    var activeAlerts: [UsageAlert] = []

    func addAlert(_ alert: UsageAlert) {
        activeAlerts.append(alert)
    }

    func dismissAlert(_ id: String) {
        activeAlerts.removeAll { $0.id == id }
    }

    func clearAll() {
        activeAlerts.removeAll()
    }
}
