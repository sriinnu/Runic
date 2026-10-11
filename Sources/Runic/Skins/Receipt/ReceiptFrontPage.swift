import AppKit
import RunicCore
import SwiftUI

/// The overview as one receipt for every provider: the header, a line item
/// per provider's primary window, the day's average and totals as the
/// subtotal block, banked resets as "YOU SAVED", the week's activity as ink
/// bars, the next-window figure with its stamp, the barcode and the
/// thank-you line.
struct ReceiptFrontPage: View {
    let view: OverviewMenuView
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let now = Date()
        let soonest = self.soonestReset
        ReceiptPrintout {
            VStack(alignment: .leading, spacing: 0) {
                self.header(now: now)
                ReceiptDashedRule()

                if self.view.summaries.isEmpty {
                    ReceiptCentred(text: "NO ACTIVE PROVIDERS", size: RunicReceipt.bodySize)
                        .padding(.vertical, 6)
                } else {
                    ReceiptLine(label: "ITEM", value: self.view.showsUsed ? "USED" : "LEFT", bold: true, leader: false)
                    ForEach(self.view.summaries) { summary in
                        ReceiptProviderItem(
                            summary: summary,
                            showsUsed: self.view.showsUsed,
                            numberStyle: self.view.numberStyle)
                    }
                    if let onAddRegion = self.view.onAddRegion {
                        ForEach(OverviewMenuView.brandGroups(self.view.summaries)) { group in
                            if let missing = group.missingSlot {
                                Button {
                                    onAddRegion(missing)
                                } label: {
                                    ReceiptSubline(
                                        text: "ADD \(missing.region.displayName.uppercased()) ACCOUNT \u{2192}",
                                        color: RunicReceipt.stamp,
                                        bold: true)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add \(missing.region.displayName) account")
                            }
                        }
                    }
                }

                ReceiptDashedRule()
                self.subtotal

                if let saved = self.savedLine {
                    ReceiptDashedRule()
                    ReceiptLine(label: "YOU SAVED", value: saved.value, bold: true, leader: false)
                    ReceiptSubline(text: saved.detail)
                }

                if !self.view.chartPoints.isEmpty {
                    ReceiptDashedRule()
                    ReceiptLine(
                        label: "ACTIVITY (7D)",
                        value: self.todayTokens.map { "\($0) TODAY" } ?? "",
                        bold: true,
                        leader: false)
                    ReceiptActivityBars(points: self.view.chartPoints)
                        .padding(.top, 4)
                        .padding(.horizontal, 8)
                }

                ReceiptDashedRule()
                ReceiptNextWindow(soonest: soonest, exhausted: self.exhaustedCount)
                ReceiptTail(soonest: soonest, date: now)
            }
        }
        .skinFace()
        .frame(minWidth: self.view.width, maxWidth: .infinity, alignment: .leading)
        .preference(key: ReceiptBarePanelKey.self, value: true)
    }

    // MARK: Header

    private func header(now: Date) -> some View {
        let count = self.view.summaries.count
        return VStack(spacing: 0) {
            ReceiptCentred(text: "RUNIC", size: 22, bold: true, tracking: 6.6)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            ReceiptCentred(
                text: "USAGE RECEIPT \u{00B7} \(count) \(count == 1 ? "PROVIDER" : "PROVIDERS")",
                tracking: 1.1)
            ReceiptCentred(text: RunicReceipt.stampDate(now))
            ReceiptCentred(text: RunicReceipt.transactionLine)
            ReceiptCentred(text: "ITEMS: \(count) \u{00B7} ACTIVE: \(count) OF \(self.view.totalProviders)")
        }
    }

    // MARK: Subtotal

    private var subtotal: some View {
        let average = OverviewMenuView.averagePercent(self.view.summaries)
        return VStack(alignment: .leading, spacing: 0) {
            ReceiptLine(
                label: self.view.showsUsed ? "AVG USED TODAY" : "AVG LEFT TODAY",
                value: average.map { "\(Int($0.rounded()))%" } ?? "\u{2014}",
                valueBold: true)
            ReceiptLine(label: "ACTIVE", value: "\(self.view.summaries.count) OF \(self.view.totalProviders)")
            if let tokens = self.todayTokens {
                ReceiptLine(label: "TOKENS TODAY", value: tokens)
            }
            if self.exhaustedCount > 0 {
                ReceiptLine(label: "EXHAUSTED", value: "\(self.exhaustedCount)", valueColor: RunicReceipt.stamp)
            }
        }
    }

    private var todayTokens: String? {
        guard self.view.totalTodayTokens > 0 else { return nil }
        return UsageFormatter.tokenCountString(self.view.totalTodayTokens, style: self.view.numberStyle)
    }

    private var exhaustedCount: Int {
        self.view.summaries.count(where: { ReceiptProviderItem.isExhausted($0, showsUsed: self.view.showsUsed) })
    }

    private var soonestReset: TimeInterval? {
        self.view.summaries.compactMap { RunicReceipt.seconds(in: $0.resetDescription) }.min()
    }

    /// "2 RESETS (BANKED)" and the providers that bank them.
    private var savedLine: (value: String, detail: String)? {
        let banked = self.view.summaries.compactMap { summary -> (String, Int)? in
            guard let count = RunicReceipt.leadingCount(summary.bankedResetsText), count > 0 else { return nil }
            return (summary.name, count)
        }
        let total = banked.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        let names = banked.map { $0.0.uppercased() }.joined(separator: " \u{00B7} ")
        return ("\(total) \(total == 1 ? "RESET" : "RESETS") (BANKED)", "\(names) \u{00B7} redeem at provider")
    }
}

/// One provider as a line item: "CODEX 5H ........ 62%", then the reset,
/// the context and today's tokens indented beneath.
struct ReceiptProviderItem: View {
    let summary: OverviewMenuView.ProviderSummary
    let showsUsed: Bool
    let numberStyle: UsageFormatter.NumberStyle

    var body: some View {
        let exhausted = Self.isExhausted(self.summary, showsUsed: self.showsUsed)
        VStack(alignment: .leading, spacing: 0) {
            ReceiptLine(
                label: [self.summary.name, self.summary.windowLabel].compactMap(\.self).joined(separator: " ")
                    .uppercased(),
                value: self.summary.hasQuota ? "\(Int(self.summary.usedPercent))%" : "\u{2014}",
                valueBold: exhausted)
            let reset = RunicReceipt.resetDetail(self.summary.resetDescription).map { "resets \($0)" }
            if exhausted {
                ReceiptSubline(
                    text: "** EXHAUSTED ** " + (reset ?? ""),
                    color: RunicReceipt.stamp,
                    bold: true)
            }
            let tokens = self.summary.todayTokens > 0
                ? UsageFormatter.tokenCountString(self.summary.todayTokens, style: self.numberStyle) + " today"
                : nil
            let detail = [
                exhausted ? nil : reset,
                self.summary.topModelContext,
                tokens,
            ].compactMap(\.self)
            if !detail.isEmpty {
                ReceiptSubline(text: detail.joined(separator: " \u{00B7} "))
            }
        }
        .accessibilityElement(children: .combine)
    }

    static func isExhausted(_ summary: OverviewMenuView.ProviderSummary, showsUsed: Bool) -> Bool {
        guard summary.hasQuota else { return false }
        return showsUsed ? summary.usedPercent >= 99.5 : summary.usedPercent <= 0.5
    }
}
