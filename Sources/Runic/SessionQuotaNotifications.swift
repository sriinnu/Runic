import Foundation
import RunicCore
@preconcurrency import UserNotifications

enum SessionQuotaTransition: Equatable {
    case none
    case depleted
    case restored
}

/// What kind of quota the primary window tracks, for notification wording.
enum SessionQuotaKind: Equatable {
    /// A rolling window that resets on its own (Claude/Codex sessions).
    case session
    /// A lifetime credit balance that never resets (OpenRouter, Vercel AI).
    case credits
}

enum SessionQuotaNotificationLogic {
    static let depletedThreshold: Double = 0.0001

    static func isDepleted(_ remaining: Double?) -> Bool {
        guard let remaining else { return false }
        return remaining <= Self.depletedThreshold
    }

    static func transition(previousRemaining: Double?, currentRemaining: Double?) -> SessionQuotaTransition {
        guard let currentRemaining else { return .none }
        guard let previousRemaining else { return .none }

        let wasDepleted = previousRemaining <= Self.depletedThreshold
        let isDepleted = currentRemaining <= Self.depletedThreshold

        if !wasDepleted, isDepleted { return .depleted }
        if wasDepleted, !isDepleted { return .restored }
        return .none
    }

    /// Whether a window carries evidence of a real, measured quota.
    ///
    /// `hasKnownLimit` is the primary signal: `false` means the percent is a
    /// placeholder (never a real quota, whatever other metadata says) and
    /// `true` means the provider vouched for a real denominator (even when all
    /// reset metadata is nil, as with some Zai windows). Only when the flag is
    /// absent do we fall back to the metadata heuristic: hardcoded stubs have
    /// no window duration, no reset time, and no reset/balance text — a
    /// depletion alert for one of those is pure noise, so callers must skip
    /// both the notification and the last-known bookkeeping for them.
    static func hasRealQuota(_ window: RateWindow) -> Bool {
        if let hasKnownLimit = window.hasKnownLimit { return hasKnownLimit }
        if window.windowMinutes != nil || window.resetsAt != nil { return true }
        if let description = window.resetDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return true
        }
        return false
    }

    /// Classify the primary window so exhausted lifetime credits aren't
    /// announced as a depleted "session" that will come back on its own.
    static func quotaKind(windowMinutes: Int?, resetsAt: Date?, supportsCredits: Bool) -> SessionQuotaKind {
        guard supportsCredits, windowMinutes == nil, resetsAt == nil else { return .session }
        return .credits
    }

    static func notificationContent(
        transition: SessionQuotaTransition,
        providerName: String,
        quotaKind: SessionQuotaKind) -> (title: String, body: String)?
    {
        switch (transition, quotaKind) {
        case (.none, _):
            nil
        case (.depleted, .session):
            ("\(providerName) session depleted", "0% left. Will notify when it's available again.")
        case (.depleted, .credits):
            ("\(providerName) credits exhausted", "0% left. Add credits to keep using it.")
        case (.restored, .session):
            ("\(providerName) session restored", "Session quota is available again.")
        case (.restored, .credits):
            ("\(providerName) credits restored", "Credit balance is available again.")
        }
    }
}

@MainActor
final class SessionQuotaNotifier {
    private let logger = RunicLog.logger("sessionQuotaNotifications")

    init() {}

    func post(
        transition: SessionQuotaTransition,
        provider: UsageProvider,
        quotaKind: SessionQuotaKind = .session,
        badge: NSNumber? = nil)
    {
        guard transition != .none else { return }

        let providerName = ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName

        guard let (title, body) = SessionQuotaNotificationLogic.notificationContent(
            transition: transition,
            providerName: providerName,
            quotaKind: quotaKind)
        else { return }

        let providerText = provider.rawValue
        let transitionText = String(describing: transition)
        let idPrefix = "session-\(providerText)-\(transitionText)"
        self.logger.info("enqueuing", metadata: ["prefix": idPrefix])
        AppNotifications.shared.post(idPrefix: idPrefix, title: title, body: body, badge: badge)
    }
}
