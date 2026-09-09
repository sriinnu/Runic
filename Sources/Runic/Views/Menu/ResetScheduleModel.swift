import AppKit
import RunicCore
import SwiftUI

/// One quota window that knows when it resets, flattened out of a provider
/// snapshot so the menu can list every reset across every provider in one
/// place: what's left, how long until it flips, and the wall-clock moment.
struct ResetScheduleEntry: Identifiable, Equatable {
    let id: String
    let provider: UsageProvider
    let providerName: String
    let brandColor: Color
    /// "Session", "Weekly", a model name, a quota label — whatever the
    /// provider calls this window.
    let windowTitle: String
    /// Percent consumed, or nil when the window has no real denominator.
    let usedPercent: Double?
    /// The moment the window resets. Nil only for text-only rows whose
    /// provider says "resets weekly" without ever giving a date.
    let resetsAt: Date?
    /// Window length in minutes when the provider reports it (5h session,
    /// 7d weekly). Drives the elapsed ring.
    let windowMinutes: Int?
    /// Provider's own phrase, kept for rows without a date.
    let fallbackText: String?

    var remainingPercent: Double? {
        self.usedPercent.map { max(0, 100 - $0) }
    }

    var isExhausted: Bool {
        (self.remainingPercent ?? 100) <= 0
    }

    /// 0...1 progress through the window, when both the reset time and the
    /// window length are known. Nil otherwise so the ring can fall back to
    /// a static glyph.
    func elapsedFraction(now: Date) -> Double? {
        guard let resetsAt, let minutes = self.windowMinutes, minutes > 0 else { return nil }
        let duration = TimeInterval(minutes) * 60
        let remaining = resetsAt.timeIntervalSince(now)
        guard remaining > 0, remaining <= duration else { return remaining <= 0 ? 1 : nil }
        return min(1, max(0, (duration - remaining) / duration))
    }

    /// Seconds until reset; nil for text-only rows, 0 once it's passed.
    func secondsUntilReset(now: Date) -> TimeInterval? {
        self.resetsAt.map { max(0, $0.timeIntervalSince(now)) }
    }
}

/// Banked resets for one provider, flattened for the Resets panel: how many
/// the user can spend right now and when the bank runs out.
struct ResetCreditEntry: Identifiable, Equatable {
    let id: String
    let provider: UsageProvider
    let providerName: String
    let brandColor: Color
    let availableCount: Int
    /// Provider's name for the credit ("Full reset"), when it gives one.
    let title: String?
    /// Soonest expiry among usable credits — the deadline that matters.
    let nearestExpiry: Date?
    /// Last expiry — "usable until" for the whole bank.
    let latestExpiry: Date?
    /// Expiries of every usable credit, soonest first, for the per-credit line.
    let expiries: [Date]

    var summaryText: String {
        self.availableCount == 1 ? "1 reset available" : "\(self.availableCount) resets available"
    }

    /// Row title when the provider name is already on the line: the badge
    /// carries the count, so "2 resets" is enough and survives mono widths.
    var compactSummaryText: String {
        self.availableCount == 1 ? "1 reset" : "\(self.availableCount) resets"
    }

    static func summaryLine(for credits: UsageResetCredits, now: Date = .init()) -> String? {
        guard credits.hasAny else { return nil }
        let count = credits.availableCount == 1 ? "1 banked reset" : "\(credits.availableCount) banked resets"
        if let latest = credits.latestExpiry(now: now) {
            return "\(count) · usable until \(UsageFormatter.resetExpiryString(from: latest, now: now))"
        }
        return count
    }
}

enum ResetScheduleBuilder {
    /// One entry per provider that reports banked resets, most credits first.
    static func credits(_ inputs: [ProviderInput], now: Date = .init()) -> [ResetCreditEntry] {
        inputs.compactMap { input -> ResetCreditEntry? in
            guard let credits = input.snapshot?.resetCredits, credits.hasAny else { return nil }
            let descriptor = ProviderDescriptorRegistry.descriptor(for: input.provider)
            let available = credits.available(now: now)
            return ResetCreditEntry(
                id: "\(input.provider.rawValue)-credits",
                provider: input.provider,
                providerName: UsageProvider.compactDisplayName(input.metadata.displayName),
                brandColor: Color(
                    red: Double(descriptor.branding.color.red),
                    green: Double(descriptor.branding.color.green),
                    blue: Double(descriptor.branding.color.blue)),
                availableCount: credits.availableCount,
                title: available.first?.title ?? credits.credits.first?.title,
                nearestExpiry: credits.nearestExpiry(now: now),
                latestExpiry: credits.latestExpiry(now: now),
                expiries: available.compactMap(\.expiresAt))
        }
        .sorted { lhs, rhs in
            if lhs.availableCount != rhs.availableCount { return lhs.availableCount > rhs.availableCount }
            return lhs.id < rhs.id
        }
    }

    struct ProviderInput {
        let provider: UsageProvider
        let metadata: ProviderMetadata
        let snapshot: UsageSnapshot?
        var quotaWindows: [RateWindow]?
    }

    /// Flatten every reset-bearing window across the given providers. Dated
    /// rows come first, soonest reset on top; text-only rows trail in
    /// provider order.
    static func entries(_ inputs: [ProviderInput], now: Date = .init()) -> [ResetScheduleEntry] {
        var dated: [ResetScheduleEntry] = []
        var undated: [ResetScheduleEntry] = []
        for input in inputs {
            for entry in self.entries(for: input, now: now) {
                if entry.resetsAt != nil { dated.append(entry) } else { undated.append(entry) }
            }
        }
        dated.sort { lhs, rhs in
            guard let l = lhs.resetsAt, let r = rhs.resetsAt else { return false }
            if l != r { return l < r }
            return lhs.id < rhs.id
        }
        return dated + undated
    }

    static func entries(for input: ProviderInput, now: Date = .init()) -> [ResetScheduleEntry] {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: input.provider)
        let brand = Color(
            red: Double(descriptor.branding.color.red),
            green: Double(descriptor.branding.color.green),
            blue: Double(descriptor.branding.color.blue))
        let name = UsageProvider.compactDisplayName(input.metadata.displayName)
        var results: [ResetScheduleEntry] = []

        func append(_ window: RateWindow?, slot: String, defaultTitle: String) {
            guard let window, self.isResetShaped(window, now: now) else { return }
            let label = window.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = label.isEmpty ? defaultTitle : UsageFormatter.modelDisplayName(label)
            let date = window.resetsAt ?? UsageResetParsing.date(fromRelative: window.resetDescription, now: now)
            let hasLimit = window.hasKnownLimit != false
            results.append(ResetScheduleEntry(
                id: "\(input.provider.rawValue)-\(slot)",
                provider: input.provider,
                providerName: name,
                brandColor: brand,
                windowTitle: title,
                usedPercent: hasLimit ? min(100, max(0, window.usedPercent)) : nil,
                resetsAt: date,
                windowMinutes: window.windowMinutes,
                fallbackText: date == nil
                    ? window.resetDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
                    : nil))
        }

        if let quota = input.quotaWindows, !quota.isEmpty {
            for (index, window) in quota.prefix(3).enumerated() {
                append(window, slot: "quota-\(index)", defaultTitle: "Quota \(index + 1)")
            }
        }
        if let snapshot = input.snapshot {
            // Some providers ship an empty metadata label for a window they
            // don't normally have; never let a row go untitled.
            let sessionTitle = input.metadata.sessionLabel.isEmpty ? "Session" : input.metadata.sessionLabel
            let weeklyTitle = input.metadata.weeklyLabel.isEmpty ? "Weekly" : input.metadata.weeklyLabel
            append(snapshot.primary, slot: "primary", defaultTitle: sessionTitle)
            append(snapshot.secondary, slot: "secondary", defaultTitle: weeklyTitle)
            let tertiaryTitle = input.metadata.supportsOpus ? (input.metadata.opusLabel ?? "Sonnet") : "Model"
            append(snapshot.tertiary, slot: "tertiary", defaultTitle: tertiaryTitle)
        }
        return results
    }

    /// A window "provides resets" when it can name a moment (a date, or a
    /// phrase we can turn into one) or at least says it cycles ("resets
    /// weekly"). Balances and counters are not resets and stay out.
    static func isResetShaped(_ window: RateWindow, now: Date = .init()) -> Bool {
        if window.resetsAt != nil { return true }
        if UsageResetParsing.date(fromRelative: window.resetDescription, now: now) != nil { return true }
        guard let desc = window.resetDescription?.lowercased() else { return false }
        if desc.contains("$") || desc.contains("balance") { return false }
        return desc.contains("reset") || desc == "weekly" || desc == "monthly" || desc == "daily"
    }
}
