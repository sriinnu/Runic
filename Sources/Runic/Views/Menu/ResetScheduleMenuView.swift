import AppKit
import RunicCore
import SwiftUI

/// "Resets" panel: every quota window that knows when it flips, across one
/// provider or all of them. Each row carries what's left, a live countdown,
/// and the wall-clock expiry. Ticks every 30s so the numbers never go stale
/// while the menu is open.
@MainActor
struct ResetScheduleMenuView: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme

    let entries: [ResetScheduleEntry]
    let width: CGFloat
    /// Overview mode names the provider on each row; a single-provider card
    /// already has the provider in its header, so the title is enough.
    var showsProvider = true
    /// Banked, manually-redeemable resets — listed under the windows.
    var credits: [ResetCreditEntry] = []

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    RetroSectionHeader(text: "Resets")
                    Spacer(minLength: RunicSpacing.xs)
                    if let summary = self.headerSummary(now: now) {
                        Text(summary)
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.subduedSecondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, RunicSpacing.menuSectionHeaderInset)

                VStack(spacing: 0) {
                    ForEach(Array(self.entries.enumerated()), id: \.element.id) { index, entry in
                        ResetScheduleRow(entry: entry, now: now, showsProvider: self.showsProvider)
                            .padding(.vertical, RunicSpacing.compact)
                        if index < self.entries.count - 1 {
                            RunicDivider(opacity: 0.55)
                        }
                    }
                }
                .padding(.horizontal, RunicSpacing.menuPanelBodyInset)

                if !self.credits.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Banked")
                            .font(self.fonts.caption.weight(.semibold))
                            .foregroundStyle(self.runicTheme.secondaryText)
                        Spacer(minLength: RunicSpacing.xs)
                        Text("redeem at the provider")
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.subduedSecondaryText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, RunicSpacing.menuSectionHeaderInset)
                    .padding(.top, self.entries.isEmpty ? 0 : RunicSpacing.xxs)

                    VStack(spacing: 0) {
                        ForEach(Array(self.credits.enumerated()), id: \.element.id) { index, credit in
                            ResetCreditRow(entry: credit, now: now, showsProvider: self.showsProvider)
                                .padding(.vertical, RunicSpacing.compact)
                            if index < self.credits.count - 1 {
                                RunicDivider(opacity: 0.55)
                            }
                        }
                    }
                    .padding(.horizontal, RunicSpacing.menuPanelBodyInset)
                }
            }
            .frame(width: self.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
    }

    /// "next in 2h 14m" when something is counting down, "1 exhausted" when
    /// a window is spent, or the banked count when that's all there is.
    private func headerSummary(now: Date) -> String? {
        let soonest = self.entries.compactMap { $0.secondsUntilReset(now: now) }.min()
        guard let soonest else {
            let banked = self.credits.reduce(0) { $0 + $1.availableCount }
            return banked > 0 ? (banked == 1 ? "1 banked" : "\(banked) banked") : nil
        }
        if soonest <= 0 { return "resetting now" }
        let exhausted = self.entries.filter(\.isExhausted).count
        if exhausted > 0 {
            return exhausted == 1 ? "1 exhausted" : "\(exhausted) exhausted"
        }
        return "next in \(Self.compactDuration(soonest))"
    }

    nonisolated static func compactDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int(ceil(seconds / 60)))
        let days = minutes / 1440
        let hours = (minutes / 60) % 24
        let mins = minutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h" }
        return "\(mins)m"
    }
}

// MARK: - Row

@MainActor
private struct ResetScheduleRow: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme

    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool

    var body: some View {
        HStack(alignment: .center, spacing: RunicSpacing.xs) {
            ResetWindowRing(entry: self.entry, now: self.now)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                HStack(spacing: RunicSpacing.xxs) {
                    if self.showsProvider {
                        Text(self.entry.providerName)
                            .font(self.fonts.caption.weight(.semibold))
                            .lineLimit(1)
                        Text("·")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    }
                    Text(self.entry.windowTitle)
                        .font(self.showsProvider ? self.fonts.caption : self.fonts.caption.weight(.semibold))
                        .foregroundStyle(
                            self.showsProvider ? self.runicTheme.secondaryText : self.runicTheme.primaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                self.remainingLine
            }

            Spacer(minLength: RunicSpacing.xs)

            VStack(alignment: .trailing, spacing: RunicSpacing.xxxs) {
                Text(self.countdownText)
                    .font(self.fonts.numericFootnote.weight(.semibold))
                    .foregroundStyle(self.countdownColor)
                    .lineLimit(1)
                    .monospacedDigit()
                if let expiry = self.expiryText {
                    Text(expiry)
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    @ViewBuilder
    private var remainingLine: some View {
        if let remaining = self.entry.remainingPercent {
            HStack(spacing: RunicSpacing.xxs) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(self.runicTheme.menuTrackColor)
                        Capsule()
                            .fill(self.remainingTint)
                            .frame(width: max(3, proxy.size.width * remaining / 100))
                    }
                }
                .frame(width: 64, height: 4)
                Text(self.entry.isExhausted ? "exhausted" : "\(Int(remaining.rounded()))% left")
                    .font(self.fonts.caption2)
                    .foregroundStyle(self.entry.isExhausted ? self.runicTheme.warm : self.runicTheme.secondaryText)
                    .monospacedDigit()
            }
        } else if let text = self.entry.fallbackText {
            Text(text)
                .font(self.fonts.caption2)
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(1)
        }
    }

    private var remainingTint: Color {
        guard let remaining = self.entry.remainingPercent else { return self.runicTheme.accent }
        if remaining <= 10 { return self.runicTheme.warm }
        if remaining <= 30 { return self.runicTheme.highlight }
        return self.entry.brandColor
    }

    private var countdownText: String {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return "—" }
        if seconds <= 0 { return "now" }
        return ResetScheduleMenuView.compactDuration(seconds)
    }

    private var countdownColor: Color {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else {
            return self.runicTheme.secondaryText
        }
        if self.entry.isExhausted { return self.runicTheme.warm }
        if seconds <= 30 * 60 { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }

    private var expiryText: String? {
        self.entry.resetsAt.map { UsageFormatter.resetExpiryString(from: $0, now: self.now) }
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if self.showsProvider { parts.append(self.entry.providerName) }
        parts.append(self.entry.windowTitle)
        if let remaining = self.entry.remainingPercent {
            parts.append(self.entry.isExhausted ? "exhausted" : "\(Int(remaining.rounded())) percent left")
        }
        if let seconds = self.entry.secondsUntilReset(now: self.now) {
            parts.append("resets in \(ResetScheduleMenuView.compactDuration(seconds))")
        }
        if let expiry = self.expiryText { parts.append("at \(expiry)") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Banked credit row

@MainActor
private struct ResetCreditRow: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme

    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool

    var body: some View {
        HStack(alignment: .center, spacing: RunicSpacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(6), style: .continuous)
                    .fill(self.entry.brandColor.opacity(0.16))
                RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(6), style: .continuous)
                    .strokeBorder(self.entry.brandColor.opacity(0.55), lineWidth: 1)
                Text("\(self.entry.availableCount)")
                    .font(self.fonts.numericFootnote.weight(.bold))
                    .foregroundStyle(self.runicTheme.primaryText)
                    .monospacedDigit()
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                HStack(spacing: RunicSpacing.xxs) {
                    if self.showsProvider {
                        Text(self.entry.providerName)
                            .font(self.fonts.caption.weight(.semibold))
                            .lineLimit(1)
                        Text("·")
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    }
                    Text(self.showsProvider ? self.entry.compactSummaryText : self.entry.summaryText)
                        .font(self.showsProvider ? self.fonts.caption : self.fonts.caption.weight(.semibold))
                        .foregroundStyle(
                            self.showsProvider ? self.runicTheme.secondaryText : self.runicTheme.primaryText)
                        .lineLimit(1)
                }
                Text(self.detailText)
                    .font(self.fonts.caption2)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: RunicSpacing.xs)

            VStack(alignment: .trailing, spacing: RunicSpacing.xxxs) {
                if let latest = self.entry.latestExpiry {
                    Text(ResetScheduleMenuView.compactDuration(max(0, latest.timeIntervalSince(self.now))))
                        .font(self.fonts.numericFootnote.weight(.semibold))
                        .foregroundStyle(self.expiryColor(latest))
                        .monospacedDigit()
                    Text("until \(latest.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                        .lineLimit(1)
                } else {
                    Text("no expiry")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    /// "expire Oct 4, Oct 5" — each credit's own deadline when they differ,
    /// one date when they don't. Falls back to the provider's title when no
    /// expiry is known, so the line never goes empty.
    private var detailText: String {
        let dates = self.entry.expiries.map { $0.formatted(.dateTime.month(.abbreviated).day()) }
        let distinct = Array(NSOrderedSet(array: dates)) as? [String] ?? dates
        if !distinct.isEmpty {
            return (distinct.count == 1 ? "expires " : "expire ") + distinct.joined(separator: ", ")
        }
        if let title = self.entry.title, !title.isEmpty { return title }
        return "one-time limit reset"
    }

    private func expiryColor(_ date: Date) -> Color {
        let remaining = date.timeIntervalSince(self.now)
        if remaining <= 2 * 86400 { return self.runicTheme.warm }
        if remaining <= 7 * 86400 { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if self.showsProvider { parts.append(self.entry.providerName) }
        parts.append(self.entry.summaryText)
        if let latest = self.entry.latestExpiry {
            parts.append("usable until \(UsageFormatter.resetExpiryString(from: latest, now: self.now))")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Ring

/// Elapsed-window ring around the provider mark. Fills clockwise as the
/// window ages; a window without a known length shows a static clock face.
@MainActor
private struct ResetWindowRing: View {
    @Environment(\.runicTheme) private var runicTheme
    let entry: ResetScheduleEntry
    let now: Date

    var body: some View {
        let fraction = self.entry.elapsedFraction(now: self.now)
        ZStack {
            Circle()
                .stroke(self.runicTheme.menuTrackColor, lineWidth: 2.2)
            if let fraction {
                Circle()
                    .trim(from: 0, to: CGFloat(fraction))
                    .stroke(
                        self.ringTint,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: self.runicTheme.isTerminalHUD ? .butt : .round))
                    .rotationEffect(.degrees(-90))
                    .animation(self.runicTheme.motion.curve, value: fraction)
            }
            if let icon = ProviderBrandIcon.image(
                for: self.entry.provider,
                size: 14,
                prefersDark: self.runicTheme.prefersDarkAppearance)
            {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
        }
        .accessibilityHidden(true)
    }

    private var ringTint: Color {
        if self.entry.isExhausted { return self.runicTheme.warm }
        return self.runicTheme.isTerminalHUD ? self.runicTheme.accent : self.entry.brandColor
    }
}
