import RunicCore
import SwiftUI

/// Resets as a short slip: "RESETS" and the time, one line item per window
/// with its countdown as the value and what is left beneath, the banked
/// resets as "YOU SAVED", and the next reset as the closing line.
struct ReceiptResetsPage: View {
    let resets: RunicSkinResets

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            ReceiptPaper {
                VStack(alignment: .leading, spacing: 0) {
                    ReceiptCentred(text: "RESETS", size: 14, bold: true, tracking: 4)
                        .accessibilityAddTraits(.isHeader)
                    ReceiptCentred(text: RunicReceipt.stampDate(now))
                    ReceiptDashedRule()

                    if !self.resets.entries.isEmpty {
                        ReceiptLine(label: "WINDOW", value: "IN", bold: true, leader: false)
                        ForEach(self.resets.entries) { entry in
                            ReceiptResetItem(entry: entry, now: now, showsProvider: self.resets.showsProvider)
                        }
                    }

                    if !self.resets.credits.isEmpty {
                        if !self.resets.entries.isEmpty {
                            ReceiptDashedRule()
                        }
                        ForEach(self.resets.credits) { credit in
                            ReceiptCreditItem(entry: credit, now: now, showsProvider: self.resets.showsProvider)
                        }
                    }

                    if let summary = ResetScheduleMenuView.headerSummary(
                        entries: self.resets.entries,
                        credits: self.resets.credits,
                        now: now)
                    {
                        ReceiptDashedRule()
                        ReceiptCentred(
                            text: summary.uppercased(),
                            size: 12,
                            bold: true,
                            color: summary.contains("exhausted") ? RunicReceipt.stamp : RunicReceipt.ink)
                    }
                }
            }
            .skinFace()
            .frame(width: self.resets.width, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Quota resets")
        }
        .preference(key: ReceiptBarePanelKey.self, value: true)
    }
}

private struct ReceiptResetItem: View {
    let entry: ResetScheduleEntry
    let now: Date
    let showsProvider: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReceiptLine(label: self.title, value: self.countdown, valueBold: self.entry.isExhausted)
            if self.entry.isExhausted {
                ReceiptSubline(text: "** EXHAUSTED ** \(self.expiry)", color: RunicReceipt.stamp, bold: true)
            } else if let remaining = self.entry.remainingPercent {
                ReceiptSubline(text: "\(Int(remaining.rounded()))% left \u{00B7} \(self.expiry)")
            } else if let text = self.entry.fallbackText {
                ReceiptSubline(text: text)
            } else {
                ReceiptSubline(text: self.expiry)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private var title: String {
        let title = self.showsProvider
            ? "\(self.entry.providerName) \(self.entry.windowTitle)"
            : self.entry.windowTitle
        return title.uppercased()
    }

    private var countdown: String {
        guard let seconds = self.entry.secondsUntilReset(now: self.now) else { return "\u{2014}" }
        if seconds <= 0 { return "now" }
        return ResetScheduleMenuView.compactDuration(seconds)
    }

    private var expiry: String {
        self.entry.resetsAt.map { UsageFormatter.resetExpiryString(from: $0, now: self.now) } ?? ""
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

private struct ReceiptCreditItem: View {
    let entry: ResetCreditEntry
    let now: Date
    let showsProvider: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReceiptLine(
                label: "YOU SAVED",
                value: "\(self.entry.availableCount) \(self.entry.availableCount == 1 ? "RESET" : "RESETS") (BANKED)",
                bold: true,
                leader: false)
            ReceiptSubline(text: self.detailText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.entry.providerName), \(self.entry.summaryText)")
    }

    /// "CLAUDE · redeem at provider · exp Nov 5 / Nov 6"
    private var detailText: String {
        var parts: [String] = []
        if self.showsProvider { parts.append(self.entry.providerName.uppercased()) }
        parts.append("redeem at provider")
        let dates = self.entry.expiries.map { $0.formatted(.dateTime.month(.abbreviated).day()) }
        let distinct = Array(NSOrderedSet(array: dates)) as? [String] ?? dates
        if !distinct.isEmpty {
            parts.append("exp " + distinct.joined(separator: " / "))
        }
        return parts.joined(separator: " \u{00B7} ")
    }
}
