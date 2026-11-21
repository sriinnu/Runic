import RunicCore
import SwiftUI

/// Resets through glass: every window counting down in its own matte well —
/// the window and what is left on the left, the countdown as a tabular
/// numeral on the right, the elapsed share of the window as a capillary —
/// and banked resets in tinted wells with their count on a capsule.
struct LiquidGlassResetsPage: View {
    let resets: RunicSkinResets
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 8) {
                LiquidGlassSectionTitle(
                    title: "Resets",
                    systemImage: "clock.arrow.circlepath",
                    trailing: ResetScheduleMenuView.headerSummary(
                        entries: self.resets.entries,
                        credits: self.resets.credits,
                        now: now))

                ForEach(self.resets.entries) { entry in
                    LiquidGlassResetWell(entry: entry, now: now, showsProvider: self.resets.showsProvider)
                }

                ForEach(self.resets.credits) { credit in
                    LiquidGlassCreditWell(entry: credit, now: now, showsProvider: self.resets.showsProvider)
                }
            }
            .skinFace()
            .frame(width: self.resets.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
    }
}

private struct LiquidGlassResetWell: View {
    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        LiquidGlassWell(padding: 10, tint: self.entry.isExhausted ? self.runicTheme.warm : nil) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        self.title
                            .foregroundStyle(self.runicTheme.primaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let remaining = self.entry.remainingPercent {
                            Text(self.entry.isExhausted ? "exhausted" : "\(Int(remaining.rounded()))% left")
                                .font(RunicLiquidGlass.numeric(11))
                                .skinFace()
                                .foregroundStyle(self.entry.isExhausted
                                    ? self.runicTheme.warm
                                    : self.runicTheme.secondaryText)
                        } else if let text = self.entry.fallbackText {
                            Text(text)
                                .font(RunicLiquidGlass.body(11))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(self.countdownText)
                            .font(RunicLiquidGlass.numeric(17, .semibold))
                            .skinFace()
                            .foregroundStyle(self.countdownColor)
                            .lineLimit(1)
                        if let resetsAt = self.entry.resetsAt {
                            Text(UsageFormatter.resetExpiryString(from: resetsAt, now: self.now))
                                .font(RunicLiquidGlass.body(10.5))
                                .skinFace()
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                if let elapsed = self.entry.elapsedFraction(now: self.now) {
                    BorosilicateCapillaryBar(
                        percent: elapsed * 100,
                        tint: self.entry.isExhausted ? self.runicTheme.warm : self.entry.brandColor,
                        accessibilityLabel: "Window elapsed",
                        height: 6)
                        .frame(height: 8)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private var title: Text {
        // Runs of a concatenated `Text` resolve their own design, so the
        // pin goes on each run (see `skinFace()`).
        if self.showsProvider {
            return Text(self.entry.providerName).font(RunicLiquidGlass.body(12.5, .semibold)).fontDesign(nil)
                + Text(" \u{00B7} \(self.entry.windowTitle)").font(RunicLiquidGlass.body(12.5)).fontDesign(nil)
        }
        return Text(self.entry.windowTitle).font(RunicLiquidGlass.body(12.5, .semibold)).fontDesign(nil)
    }

    private var countdownText: String {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return "\u{2014}" }
        if seconds <= 0 { return "now" }
        return ResetScheduleMenuView.compactDuration(seconds)
    }

    private var countdownColor: Color {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return self.runicTheme.secondaryText }
        if self.entry.isExhausted { return self.runicTheme.warm }
        if seconds <= 30 * 60 { return self.runicTheme.highlight }
        return self.runicTheme.primaryText
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
        return parts.joined(separator: ", ")
    }
}

private struct LiquidGlassCreditWell: View {
    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        LiquidGlassWell(padding: 10, tint: self.runicTheme.tertiary) {
            HStack(alignment: .center, spacing: 10) {
                Text("\(self.entry.availableCount)")
                    .font(RunicLiquidGlass.numeric(15, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.tertiary)
                    .frame(minWidth: 34, minHeight: 26)
                    .background(Capsule(style: .continuous).fill(self.runicTheme.tertiary.opacity(0.12)))
                    .overlay(LiquidGlassFresnelRim(shape: Capsule(style: .continuous), intensity: 0.7))
                VStack(alignment: .leading, spacing: 2) {
                    let noun = self.entry.availableCount == 1 ? "Banked reset" : "Banked resets"
                    Text(self.showsProvider ? "\(noun) \u{00B7} \(self.entry.providerName)" : noun)
                        .font(RunicLiquidGlass.body(12.5, .semibold))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                    Text(self.detailText)
                        .font(RunicLiquidGlass.body(11))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                if let deadline = self.entry.nearestExpiry ?? self.entry.latestExpiry {
                    let remaining = deadline.timeIntervalSince(self.now)
                    Text(remaining <= 0 ? "now" : ResetScheduleMenuView.compactDuration(remaining))
                        .font(RunicLiquidGlass.numeric(15, .semibold))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.entry.providerName), \(self.entry.summaryText)")
    }

    private var detailText: String {
        let dates = self.entry.expiries.map { $0.formatted(.dateTime.month(.abbreviated).day()) }
        let distinct = Array(NSOrderedSet(array: dates)) as? [String] ?? dates
        if !distinct.isEmpty {
            return "redeem at the provider \u{00B7} expires " + distinct.joined(separator: " \u{00B7} ")
        }
        return "redeem at the provider"
    }
}
