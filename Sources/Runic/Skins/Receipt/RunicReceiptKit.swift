import AppKit
import RunicCore
import SwiftUI

// MARK: - Receipt kit

/// Receipt's kit: a thermal print-out coming out of a dark printer. One face
/// — Courier Prime, Regular and Bold, addressed by PostScript name — and the
/// marks a receipt is made of: the torn edges, the dotted leader, the dashed
/// rule, the stamp, the barcode, the printer slot. The paper and its ink are
/// kit constants, not palette slots: the palette is what reads on the
/// printer body (tabs, buttons, the outlined panels).
enum RunicReceipt {
    // MARK: Paper and ink

    static let paper = Color(red: 0.984, green: 0.980, blue: 0.957) // #FBFAF4
    static let paperShade = Color(red: 0.937, green: 0.929, blue: 0.890) // #EFEDE3, the print-outs before
    static let paperShadeLight = Color(red: 0.957, green: 0.949, blue: 0.910) // #F4F2E8
    static let ink = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A
    static let inkSoft = Color(red: 0.267, green: 0.267, blue: 0.267) // #444444
    static let stamp = Color(red: 0.784, green: 0.063, blue: 0.180) // #C8102E
    static let clear = Color(red: 0.118, green: 0.471, blue: 0.251) // #1E7840, "ALL CLEAR" on paper

    // MARK: Type

    static let bodySize: CGFloat = 12.5
    static let smallSize: CGFloat = 11
    static let lineHeight: CGFloat = 1.55

    /// Courier Prime, static instances.
    static func mono(_ size: CGFloat = bodySize, bold: Bool = false) -> Font {
        Font.custom(bold ? "CourierPrime-Bold" : "CourierPrime-Regular", fixedSize: size)
    }

    /// Row height for a printed line at `size`: the artboard's 1.55 leading.
    static func lineBox(_ size: CGFloat = bodySize) -> CGFloat {
        (size * self.lineHeight).rounded()
    }

    // MARK: Transaction

    /// The build number, read once; nil in a bare `swift build` binary.
    static let build: String? = {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let build, !build.isEmpty else { return nil }
        return build
    }()

    /// ("15:21", "07") — the till clock on the tab strip, local time; the
    /// seconds print apart so they can tick in the accent.
    static func tillClock(_ date: Date) -> (minutes: String, seconds: String) {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return (
            String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0),
            String(format: "%02d", parts.second ?? 0))
    }

    /// "TXN 156 · CASHIER: RUNIC 2.10.1"
    static var transactionLine: String {
        "TXN \(self.build ?? "\u{2014}") \u{00B7} CASHIER: RUNIC \(RunicVersion.marketing)"
    }

    /// "Runic 2.10.1 · build 156"
    static var imprint: String {
        if let build { return "Runic \(RunicVersion.marketing) \u{00B7} build \(build)" }
        return "Runic \(RunicVersion.marketing)"
    }

    /// Fixed en_GB order so the stamp reads the same in every locale; it is
    /// typography, not a localised date. One formatter per process —
    /// `DateFormatter` formatting is thread-safe on current macOS.
    private nonisolated(unsafe) static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEE d MMM yyyy  HH:mm"
        return formatter
    }()

    private nonisolated(unsafe) static let digitsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyyMMdd HHmm"
        return formatter
    }()

    /// "SAT 11 OCT 2026  15:21"
    static func stampDate(_ date: Date = .init()) -> String {
        self.stampFormatter.string(from: date).uppercased()
    }

    /// "2 0 2 6 1 0 1 1 1 5 2 1 1 5 6" — the digits printed under the barcode.
    static func barcodeDigits(_ date: Date = .init()) -> String {
        var raw = self.digitsFormatter.string(from: date)
        if let build { raw += " " + build }
        return raw.filter(\.isNumber).map(String.init).joined(separator: " ")
    }

    /// The barcode's seed: the build number, so every build prints its own
    /// bars and they never shift between renders.
    static var barcodeSeed: UInt64 {
        UInt64(self.build.flatMap(Int.init) ?? 156)
    }

    // MARK: Copy

    /// "2h 14m" → seconds. Reads the compact durations the cards and the
    /// overview print ("Resets in 2h 14m · 17:35", "↻ 18m", "in 3d 5h");
    /// nil when the text names no duration.
    static func seconds(in text: String?) -> TimeInterval? {
        guard let text else { return nil }
        var total: TimeInterval = 0
        var found = false
        var digits = ""
        for char in text {
            if char.isNumber {
                digits.append(char)
                continue
            }
            if !digits.isEmpty, let value = Double(digits) {
                switch char {
                case "d":
                    total += value * 86400
                    found = true
                case "h":
                    total += value * 3600
                    found = true
                case "m":
                    total += value * 60
                    found = true
                default:
                    break
                }
            }
            digits = ""
        }
        return found ? total : nil
    }

    /// "18 MIN" under the hour, "2H 14M" above it: the next-window figure.
    static func opensIn(_ seconds: TimeInterval) -> String {
        if seconds < 3600 {
            return "\(max(1, Int((seconds / 60).rounded(.up)))) MIN"
        }
        return ResetScheduleMenuView.compactDuration(seconds).uppercased()
    }

    /// "Resets in 2h 14m · 17:35" → "2h 14m · 17:35": the subline under a
    /// line item, without the word the line already implies.
    static func resetDetail(_ text: String?) -> String? {
        guard var text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        // "↻ in 2h 14m" sheds both the arrow and the "in".
        let prefixes = ["\u{21BB} ", "Resets ", "resets ", "in "]
        var stripped = true
        while stripped {
            stripped = false
            for prefix in prefixes where text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                stripped = true
            }
        }
        return text
    }

    /// Splits "Context health: max ctx ~272K" into a label and its value.
    static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let range = line.range(of: ": "),
              line.distance(from: line.startIndex, to: range.lowerBound) <= 28
        else { return nil }
        return (String(line[..<range.lowerBound]), String(line[range.upperBound...]))
    }

    /// Leading count in "2 resets" / "1 reset".
    static func leadingCount(_ text: String?) -> Int? {
        guard let text else { return nil }
        return Int(text.prefix { $0.isNumber })
    }

    /// The body palette re-inked for the paper, so shared views that read
    /// the theme (the empty state, click-to-copy) print in ink on paper
    /// instead of paper on paper.
    static func paperPalette(_ body: RunicThemePalette) -> RunicThemePalette {
        RunicThemePalette(
            id: body.id,
            displayName: body.displayName,
            tagline: body.tagline,
            symbolName: body.symbolName,
            isCustom: body.isCustom,
            prefersDarkAppearance: false,
            primary: self.ink,
            secondary: self.inkSoft,
            accent: self.stamp,
            highlight: Color(red: 0.545, green: 0.400, blue: 0.000),
            warm: self.stamp,
            tertiary: self.clear,
            surface: self.paper,
            surfaceAlt: self.paperShadeLight,
            cardFill: self.paperShade,
            cardStroke: self.ink.opacity(0.35),
            primaryText: self.ink,
            secondaryText: self.inkSoft,
            fonts: body.fonts,
            shape: body.shape,
            motion: body.motion,
            density: body.density,
            style: body.style)
    }
}

// MARK: - Printed text

/// A run of Courier Prime on the paper.
struct ReceiptText: View {
    let text: String
    var size: CGFloat = RunicReceipt.bodySize
    var bold = false
    var color: Color = RunicReceipt.ink
    var tracking: CGFloat = 0

    var body: some View {
        Text(self.text)
            .font(RunicReceipt.mono(self.size, bold: self.bold))
            .skinFace()
            .tracking(self.tracking)
            .foregroundStyle(self.color)
    }
}

/// "ITEM ........ 62%": a label, a dotted leader, the value. The value wins
/// the width; the label truncates.
struct ReceiptLine: View {
    let label: String
    let value: String
    var bold = false
    var valueBold = false
    var size: CGFloat = RunicReceipt.bodySize
    var color: Color = RunicReceipt.ink
    var valueColor: Color?
    var leader = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ReceiptText(text: self.label, size: self.size, bold: self.bold, color: self.color)
                .lineLimit(1)
                .truncationMode(.tail)
            if self.leader {
                ReceiptLeader(color: self.color)
                    .padding(.horizontal, 4)
            } else {
                Spacer(minLength: 8)
            }
            ReceiptText(
                text: self.value,
                size: self.size,
                bold: self.bold || self.valueBold,
                color: self.valueColor ?? self.color)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .frame(height: RunicReceipt.lineBox(self.size))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.label), \(self.value)")
    }
}

/// The dotted leader between an item and its value, sitting on the baseline.
struct ReceiptLeader: View {
    var color: Color = RunicReceipt.ink

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.75))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0.75))
            }
            .stroke(self.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .butt, dash: [1.5, 2]))
        }
        .frame(height: 1.5)
        .frame(minWidth: 8, maxWidth: .infinity)
        .padding(.bottom, 1)
        .accessibilityHidden(true)
    }
}

/// The indented secondary line under an item: "resets 2h 14m · 17:35".
struct ReceiptSubline: View {
    let text: String
    var color: Color = RunicReceipt.inkSoft
    var bold = false
    /// Lines a long value may take; one keeps the receipt's rhythm.
    var lines = 1

    var body: some View {
        ReceiptText(text: self.text, size: RunicReceipt.smallSize, bold: self.bold, color: self.color)
            .lineLimit(self.lines)
            .truncationMode(.tail)
            .minimumScaleFactor(self.lines == 1 ? 0.85 : 1)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 12)
            .frame(minHeight: RunicReceipt.lineBox(RunicReceipt.smallSize), alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A centred line of the header or footer.
struct ReceiptCentred: View {
    let text: String
    var size: CGFloat = RunicReceipt.smallSize
    var bold = false
    var color: Color = RunicReceipt.ink
    var tracking: CGFloat = 0

    var body: some View {
        ReceiptText(text: self.text, size: self.size, bold: self.bold, color: self.color, tracking: self.tracking)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(minHeight: RunicReceipt.lineBox(self.size))
    }
}

/// 1.5pt dashed rule across the paper.
struct ReceiptDashedRule: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(
                path,
                with: .color(RunicReceipt.ink),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
        .frame(height: 2)
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }
}

// MARK: - Paper

/// The zig-zag the tear-off bar leaves: paper teeth, 12pt wide, 10pt tall.
struct ReceiptTear: View {
    enum Edge {
        case top
        case bottom
    }

    let edge: Edge
    var tooth: CGFloat = 12
    var depth: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let count = Int((size.width / self.tooth).rounded(.up))
            let base: CGFloat = self.edge == .top ? size.height : 0
            let tip: CGFloat = self.edge == .top ? 0 : size.height
            path.move(to: CGPoint(x: 0, y: base))
            for index in 0..<count {
                let x0 = CGFloat(index) * self.tooth
                path.addLine(to: CGPoint(x: min(size.width, x0 + self.tooth / 2), y: tip))
                path.addLine(to: CGPoint(x: min(size.width, x0 + self.tooth), y: base))
            }
            path.addLine(to: CGPoint(x: size.width, y: base))
            path.closeSubpath()
            context.fill(path, with: .color(RunicReceipt.paper))
        }
        .frame(height: self.depth)
        .accessibilityHidden(true)
    }
}

/// One receipt: torn top, the printed content, torn bottom, a drop shadow
/// onto the printer body.
struct ReceiptPaper<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            ReceiptTear(edge: .top)
            self.content
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RunicReceipt.paper)
            ReceiptTear(edge: .bottom)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 15, y: 10)
        .shadow(color: .black.opacity(0.2), radius: 0, y: 2)
    }
}

/// The printer's slot: a dark bar with an inset shadow the paper comes out of.
struct ReceiptSlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(LinearGradient(
                stops: [
                    .init(color: Color(white: 0.29), location: 0),
                    .init(color: Color(white: 0.09), location: 0.6),
                    .init(color: Color(white: 0.165), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom))
            .overlay(alignment: .top) {
                // The inset shadow: a black wash fading in under the top lip.
                LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 7)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
            }
            .frame(height: 16)
            .accessibilityHidden(true)
    }
}

/// Two faint print-outs that came before, peeking out behind the receipt
/// through the gaps of its torn top.
struct ReceiptPreviousPrints: View {
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(RunicReceipt.paperShade)
                .opacity(0.55)
                .frame(height: 40)
                .padding(.horizontal, 12)
                .rotationEffect(.degrees(-1.2))
                .offset(y: 2)
            Rectangle()
                .fill(RunicReceipt.paperShadeLight)
                .opacity(0.8)
                .frame(height: 40)
                .padding(.horizontal, 6)
                .rotationEffect(.degrees(0.8))
                .offset(y: 6)
        }
        .accessibilityHidden(true)
    }
}

/// The printer with a receipt coming out: the slot bar on top, the earlier
/// print-outs behind, the receipt under it all. The provider page and the
/// front page both print this way.
struct ReceiptPrintout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            ReceiptPreviousPrints()
            ReceiptPaper { self.content }
                .padding(.horizontal, 2)
                .padding(.top, 8)
            ReceiptSlot()
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Marks

/// A rubber stamp pressed at an angle: "1 EXHAUSTED", "ALL CLEAR".
struct ReceiptStamp: View {
    let text: String
    var color: Color = RunicReceipt.stamp

    var body: some View {
        ReceiptText(text: self.text, size: 12, bold: true, color: self.color, tracking: 1.7)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(Rectangle().stroke(self.color, lineWidth: 2))
            .rotationEffect(.degrees(-6))
            .opacity(0.85)
            .accessibilityLabel(self.text)
    }
}

/// Sixty bars of random width, seeded by the build so the code is stable,
/// centred on the paper with its digits.
struct ReceiptBarcode: View {
    var seed: UInt64 = RunicReceipt.barcodeSeed
    var height: CGFloat = 34

    var body: some View {
        let bars = Self.bars(seed: self.seed)
        let total = bars.reduce(0, +) + CGFloat(bars.count - 1)
        Canvas { context, size in
            var x: CGFloat = 0
            for width in bars {
                context.fill(
                    Path(CGRect(x: x, y: 0, width: width, height: size.height)),
                    with: .color(RunicReceipt.ink))
                x += width + 1
            }
        }
        .frame(width: total, height: self.height)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Barcode")
    }

    /// Bar widths of 1–4pt with 1pt gaps between them.
    static func bars(seed: UInt64) -> [CGFloat] {
        var rng = RunicSeededRandom(seed: seed)
        return (0..<60).map { _ in CGFloat(1 + Int(rng.nextUnit() * 4)) }
    }
}

/// The week's activity printed as ink bars with the weekday under each.
struct ReceiptActivityBars: View {
    let points: [OverviewMenuView.DailyPoint]
    var height: CGFloat = 44

    var body: some View {
        let days = Self.dailyTotals(self.points)
        let peak = max(1, days.map(\.tokens).max() ?? 1)
        Canvas { context, size in
            guard !days.isEmpty else { return }
            let labelHeight: CGFloat = 13
            let barArea = size.height - labelHeight - 3
            let slot = size.width / CGFloat(days.count)
            let barWidth = min(22, slot * 0.6)
            for (index, day) in days.enumerated() {
                let x = slot * CGFloat(index) + (slot - barWidth) / 2
                let barHeight = max(2, barArea * CGFloat(day.tokens) / CGFloat(peak))
                context.fill(
                    Path(CGRect(x: x, y: barArea - barHeight, width: barWidth, height: barHeight)),
                    with: .color(RunicReceipt.ink))
                let label = Text(Self.weekday(day.date))
                    .font(RunicReceipt.mono(9, bold: true))
                    .foregroundStyle(RunicReceipt.inkSoft)
                context.draw(label, at: CGPoint(x: x + barWidth / 2, y: size.height - labelHeight / 2))
            }
        }
        .frame(height: self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seven-day activity")
        .accessibilityValue(days.map { "\(Self.weekday($0.date)) \($0.tokens)" }.joined(separator: ", "))
    }

    struct Day {
        let date: Date
        let tokens: Int
    }

    /// Tokens per calendar day across providers, oldest first, last seven.
    static func dailyTotals(_ points: [OverviewMenuView.DailyPoint]) -> [Day] {
        let calendar = Calendar.current
        var totals: [Date: Int] = [:]
        for point in points {
            totals[calendar.startOfDay(for: point.date), default: 0] += point.tokens
        }
        return totals.keys.sorted().suffix(7).map { Day(date: $0, tokens: totals[$0] ?? 0) }
    }

    private nonisolated(unsafe) static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    static func weekday(_ date: Date) -> String {
        self.weekdayFormatter.string(from: date).uppercased()
    }
}

// MARK: - Controls

/// A printer button: paper outline and paper text on the body, or paper
/// fill with ink text when `filled`; `onPaper` inverts it for a control
/// printed on the receipt. Hover turns a filled button stamp red.
struct ReceiptButton: View {
    let title: String
    var filled = false
    var onPaper = false
    var systemImage: String?
    var height: CGFloat = 30
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let base = self.onPaper ? RunicReceipt.ink : RunicReceipt.paper
        let inverse = self.onPaper ? RunicReceipt.paper : RunicReceipt.ink
        let fill: Color = if self.filled {
            self.isHovered ? RunicReceipt.stamp : base
        } else {
            self.isHovered ? base : .clear
        }
        let foreground: Color = if self.filled {
            self.isHovered ? RunicReceipt.paper : inverse
        } else {
            self.isHovered ? inverse : base
        }
        Button(action: self.action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(self.title.uppercased())
                    .font(RunicReceipt.mono(12, bold: true))
                    .skinFace()
                    .tracking(0.7)
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(height: self.height)
            .background(RoundedRectangle(cornerRadius: 2, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(self.filled && self.isHovered ? RunicReceipt.stamp : base, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

/// "by Sriinnu", underlined, printed on the paper; opens the author's page.
struct ReceiptAuthorLink: View {
    var color: Color = RunicReceipt.inkSoft
    var size: CGFloat = 10.5
    @State private var isHovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(RunicSkinImprint.authorURL)
        } label: {
            Text("by \(RunicSkinImprint.author)")
                .font(RunicReceipt.mono(self.size))
                .skinFace()
                .underline()
                .foregroundStyle(self.isHovered ? RunicReceipt.stamp : self.color)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .accessibilityLabel("by \(RunicSkinImprint.author), opens GitHub")
    }
}

// MARK: - Receipt blocks shared by the pages

/// "NEXT WINDOW OPENS / 18 MIN" beside the stamp.
struct ReceiptNextWindow: View {
    /// Seconds until the soonest reset, or nil when nothing is counting down.
    let soonest: TimeInterval?
    let exhausted: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                ReceiptText(text: "NEXT WINDOW OPENS", size: RunicReceipt.smallSize)
                ReceiptText(text: self.soonest.map(RunicReceipt.opensIn) ?? "\u{2014}", size: 18, bold: true)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if self.exhausted > 0 {
                ReceiptStamp(text: "\(self.exhausted) EXHAUSTED")
            } else {
                ReceiptStamp(text: "ALL CLEAR", color: RunicReceipt.clear)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 6)
        .padding(.trailing, 6)
    }
}

/// The barcode and its digits, then "THANK YOU · COME BACK IN 2H 14M" and
/// the imprint with the author link: the bottom of every full receipt.
struct ReceiptTail: View {
    let soonest: TimeInterval?
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            ReceiptBarcode()
                .padding(.top, 6)
                .padding(.bottom, 2)
            ReceiptCentred(text: RunicReceipt.barcodeDigits(self.date), size: 10, tracking: 3)
            let back = self.soonest.map { "COME BACK IN \(ResetScheduleMenuView.compactDuration($0).uppercased())" }
                ?? "COME BACK SOON"
            ReceiptCentred(text: "THANK YOU \u{00B7} \(back)", size: 12, bold: true)
                .padding(.top, 10)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ReceiptText(text: RunicReceipt.imprint + " \u{00B7} ", size: 10.5, color: RunicReceipt.inkSoft)
                    .lineLimit(1)
                ReceiptAuthorLink()
                Spacer(minLength: 0)
            }
            .frame(minHeight: RunicReceipt.lineBox(10.5))
        }
    }
}
