import AppKit
import RunicCore
import SwiftUI

// MARK: - Avionics kit

/// Flight deck's kit: a glass-cockpit primary flight display (MK II). Two
/// faces addressed by PostScript name — B612 for copy, B612 Mono for every
/// readout — plus the marks the display is composed from: the machined
/// bezel with calibration reticles, ECAM annunciator tags and memos, the
/// locked flight mode annunciator strip, vertical and horizontal tapes with
/// caution bands, the laser-etched attitude ball, the burn-velocity strip,
/// the mono ledger and outlined buttons.
enum RunicFlightDeck {
    enum Weight { case regular, bold }

    /// B612, the Airbus cockpit face. Static instances.
    static func sans(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        Font.custom(weight == .bold ? "B612-Bold" : "B612-Regular", fixedSize: size)
    }

    /// B612 Mono: tapes, tags, clocks, every number.
    static func mono(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        Font.custom(weight == .bold ? "B612Mono-Bold" : "B612Mono-Regular", fixedSize: size)
    }

    // MARK: Fixed symbology

    /// Attitude ball ground, a burnt umber that sits back on an OLED stage
    /// (the sky is the theme's `secondary`).
    static let ground = Color(red: 0.420, green: 0.271, blue: 0.137)
    /// The fixed aircraft symbol.
    static let aircraftYellow = Color(red: 1.0, green: 0.831, blue: 0.0)
    /// Annunciators that are off, "----" readouts.
    static let dim = Color(red: 0.42, green: 0.45, blue: 0.49)
    /// Hairline between ledger and waypoint rows.
    static let hairline = Color(red: 0.102, green: 0.122, blue: 0.145)
    /// The lit inner edge of a machined bezel.
    static let bezelLight = Color.white.opacity(0.05)

    /// Tracked caps run a little wide on a display.
    static let tagTracking: CGFloat = 0.9
    static let labelTracking: CGFloat = 1.3

    // MARK: Text helpers

    /// "15:21Z" — the display clock, always Zulu.
    static func zulu(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date) + "Z"
    }

    /// "07" — the Zulu clock's seconds, printed apart in the accent.
    static func zuluSeconds(_ date: Date) -> String {
        String(format: "%02d", Calendar(identifier: .gregorian).component(.second, from: date))
    }

    /// "CODEX" — a provider as a callsign.
    static func callsign(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// "SES" / "WK" / "DAY" — a window title as a short code.
    static func windowCode(_ title: String) -> String {
        let key = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "session", "5h", "5-hour", "5 hour": return "SES"
        case "weekly", "week", "7d", "7-day", "7 day": return "WK"
        case "daily", "day", "24h": return "DAY"
        case "monthly", "month": return "MO"
        default:
            let letters = key.uppercased().filter { $0.isLetter || $0.isNumber }
            return String(letters.prefix(5))
        }
    }

    /// The pace delta from "Pace: Behind (-34%) · Lasts to reset": negative
    /// when behind, positive when ahead, nil when there is no pace line.
    static func paceDelta(from detail: String?) -> Double? {
        guard let detail, detail.lowercased().hasPrefix("pace") else { return nil }
        guard let open = detail.range(of: "("), let close = detail.range(of: "%)"),
              open.upperBound < close.lowerBound
        else { return 0 }
        let raw = detail[open.upperBound..<close.lowerBound]
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "\u{2212}", with: "-")
        return Double(raw) ?? 0
    }

    /// "BEHIND · LASTS TO RESET" from the same line.
    static func paceCaption(from detail: String?) -> String? {
        guard let detail, detail.lowercased().hasPrefix("pace") else { return nil }
        var text = detail
        if let colon = text.range(of: ":") { text = String(text[colon.upperBound...]) }
        while let open = text.range(of: "("), let close = text.range(of: ")", range: open.upperBound..<text.endIndex) {
            text.removeSubrange(open.lowerBound..<close.upperBound)
        }
        let parts = text.split(separator: "\u{00B7}").map {
            $0.trimmingCharacters(in: .whitespaces).uppercased()
        }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    /// "2H 14M" / "WED 20:21" from "resets in 2h 14m · 18:46" or "↻ 2h 14m":
    /// the first clause only, so it fits an FMA cell.
    static func compactReset(_ text: String?) -> String? {
        guard var value = text?.split(separator: "\u{00B7}").first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        for prefix in ["\u{21BB}", "resets at", "resets in", "resets", "reset in", "in "]
            where value.lowercased().hasPrefix(prefix)
        {
            value = String(value.dropFirst(prefix.count))
        }
        value = value.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value.uppercased()
    }

    /// "00:18" under a day, "3D05H" beyond.
    static func eta(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(ceil(seconds / 60)))
        if minutes >= 1440 {
            let days = minutes / 1440
            let hours = (minutes / 60) % 24
            return String(format: "%dD%02dH", days, hours)
        }
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// "15:39" today, "WED 20:21" another day.
    static func wallClock(_ date: Date, now: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = Calendar.current.isDate(date, inSameDayAs: now) ? "HH:mm" : "EEE HH:mm"
        return formatter.string(from: date).uppercased()
    }

    /// "272K" from "Context health: max ctx ~272K"; the last token that
    /// carries a digit, stripped of the tilde.
    static func readout(from line: String?) -> String? {
        guard let line else { return nil }
        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\u{00B7}" })
        guard let token = tokens.last(where: { $0.contains(where: \.isNumber) }) else { return nil }
        let cleaned = token.replacingOccurrences(of: "~", with: "").trimmingCharacters(in: .punctuationCharacters)
        return cleaned.isEmpty ? nil : cleaned.uppercased()
    }

    /// Compact FMA balance readout preserving currency symbols and ISO codes
    /// while trimming trailing `" left"` prose ("12.50 EUR" -> "12.50 EUR", "$12.34 left" -> "$12.34").
    static func compactBalance(from summary: String?) -> String? {
        guard var trimmed = summary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        if trimmed.lowercased().hasSuffix(" left") {
            trimmed = String(trimmed.dropLast(" left".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed.isEmpty ? nil : trimmed.uppercased()
    }

    /// 2 from "2 banked resets · usable until Nov 28": the leading count of
    /// a banked-resets summary, nil when there is none.
    static func heldCount(from summary: String?) -> Int? {
        guard let summary else { return nil }
        let digits = summary.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber }
        guard let count = Int(digits), count > 0 else { return nil }
        return count
    }

    /// "USABLE UNTIL NOV 28" — whatever follows the count clause of a
    /// banked-resets summary, for the ledger's second column.
    static func heldDetail(from summary: String?) -> String? {
        guard let summary else { return nil }
        let parts = summary.split(separator: "\u{00B7}").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count > 1 else { return nil }
        let rest = parts.dropFirst().joined(separator: " \u{00B7} ")
        return rest.isEmpty ? nil : rest.uppercased()
    }

    /// Splits "Context health: max ctx ~272K" into a label and its value.
    static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let range = line.range(of: ": "),
              line.distance(from: line.startIndex, to: range.lowerBound) <= 28
        else { return nil }
        return (String(line[..<range.lowerBound]), String(line[range.upperBound...]))
    }

    /// The slot a metric was built from, for the burn history.
    static func slot(forMetricID id: String) -> QuotaWindowSlot? {
        switch id {
        case "primary": .primary
        case "secondary": .secondary
        case "tertiary": .tertiary
        default: nil
        }
    }

    /// Used-percent per hour over the last hour, from the recorded burn
    /// history, or nil when there is not enough of it for a vector.
    static func burnRate(provider: UsageProvider, slot: QuotaWindowSlot, now: Date = .init()) -> Double? {
        let samples = QuotaSampleStore.shared.samples(
            provider: provider,
            slot: slot,
            since: now.addingTimeInterval(-6 * 3600))
        guard let latest = samples.last, let resetsAt = latest.resetsAt else { return nil }
        let window = RateWindow(
            usedPercent: latest.usedPercent,
            windowMinutes: latest.windowMinutes,
            resetsAt: resetsAt,
            resetDescription: nil)
        guard let series = QuotaBurnSeries.make(samples: samples, window: window, now: now),
              let projection = series.projections.first
        else { return nil }
        return projection.ratePercentPerHour
    }

    /// Used-percent burned in each of the last `hours` hours, oldest first,
    /// from the recorded samples. Only rises count: the drop at a reset is
    /// not negative burn. Nil when nothing burned in the span.
    static func burnHistory(
        provider: UsageProvider,
        slot: QuotaWindowSlot,
        hours: Int = 24,
        now: Date = .init()) -> [Double]?
    {
        guard hours > 0 else { return nil }
        let start = now.addingTimeInterval(-Double(hours) * 3600)
        let samples = QuotaSampleStore.shared.samples(provider: provider, slot: slot, since: start)
            .sorted { $0.at < $1.at }
        guard samples.count >= 2 else { return nil }
        var buckets = Array(repeating: 0.0, count: hours)
        for (previous, sample) in zip(samples, samples.dropFirst()) {
            let delta = sample.usedPercent - previous.usedPercent
            guard delta > 0 else { continue }
            let index = Int(sample.at.timeIntervalSince(start) / 3600)
            guard buckets.indices.contains(index) else { continue }
            buckets[index] += delta
        }
        return buckets.contains { $0 > 0 } ? buckets : nil
    }
}

// MARK: - Bezel

/// The machined display bezel: a cardStroke frame hairline, a faint lit
/// hairline one point inside it, and calibration reticles in the corners.
struct FlightDeckBezel: ViewModifier {
    var fill: Color?
    var reticles = true
    @Environment(\.runicTheme) private var runicTheme

    func body(content: Content) -> some View {
        content
            .background(Rectangle().fill(self.fill ?? self.runicTheme.cardFill))
            .overlay(Rectangle().strokeBorder(self.runicTheme.cardStroke, lineWidth: 1))
            .overlay(Rectangle().strokeBorder(RunicFlightDeck.bezelLight, lineWidth: 1).padding(1))
            .overlay {
                if self.reticles { FlightDeckReticles() }
            }
    }
}

extension View {
    /// Frames a display area in the machined bezel.
    func flightDeckBezel(fill: Color? = nil, reticles: Bool = true) -> some View {
        self.modifier(FlightDeckBezel(fill: fill, reticles: reticles))
    }
}

/// Corner calibration reticles: four hairline L-marks just inside a frame.
struct FlightDeckReticles: View {
    var length: CGFloat = 6
    var inset: CGFloat = 3.5
    var color: Color?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Canvas { context, size in
            guard size.width > self.length * 3, size.height > self.length * 3 else { return }
            let l = self.length
            let i = self.inset
            let r = size.width - i
            let b = size.height - i
            var path = Path()
            path.move(to: CGPoint(x: i, y: i + l))
            path.addLine(to: CGPoint(x: i, y: i))
            path.addLine(to: CGPoint(x: i + l, y: i))
            path.move(to: CGPoint(x: r - l, y: i))
            path.addLine(to: CGPoint(x: r, y: i))
            path.addLine(to: CGPoint(x: r, y: i + l))
            path.move(to: CGPoint(x: r, y: b - l))
            path.addLine(to: CGPoint(x: r, y: b))
            path.addLine(to: CGPoint(x: r - l, y: b))
            path.move(to: CGPoint(x: i + l, y: b))
            path.addLine(to: CGPoint(x: i, y: b))
            path.addLine(to: CGPoint(x: i, y: b - l))
            context.stroke(
                path,
                with: .color(self.color ?? self.runicTheme.secondaryText.opacity(0.5)),
                lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Labels and tags

/// Tracked mono caps: section labels, captions, the clock.
struct FlightDeckLabel: View {
    let text: String
    var size: CGFloat = 9
    var color: Color?
    var weight: RunicFlightDeck.Weight = .regular
    var tracking: CGFloat = RunicFlightDeck.labelTracking
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicFlightDeck.mono(self.size, self.weight))
            .skinFace()
            .tracking(self.tracking)
            .foregroundStyle(self.color ?? self.runicTheme.secondaryText)
            .lineLimit(1)
    }
}

/// An annunciator: a small bordered caps tag. Lit in cyan, amber or
/// magenta; `caution` is the filled amber MASTER CAUT; `off` is dimmed.
struct FlightDeckTag: View {
    enum Tone { case cyan, amber, magenta, caution, off }

    let text: String
    var tone: Tone = .cyan
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let color = self.color
        Text(self.text.uppercased())
            .font(RunicFlightDeck.mono(9, self.tone == .caution ? .bold : .regular))
            .skinFace()
            .tracking(RunicFlightDeck.tagTracking)
            .lineLimit(1)
            .foregroundStyle(self.tone == .caution ? self.runicTheme.surface : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Rectangle().fill(self.tone == .caution ? color : color.opacity(self.fillOpacity)))
            .overlay(Rectangle().strokeBorder(color, lineWidth: 1))
            .accessibilityLabel(self.accessibilityText)
    }

    private var color: Color {
        FlightDeckTag.color(for: self.tone, theme: self.runicTheme)
    }

    static func color(for tone: Tone, theme: RunicThemePalette) -> Color {
        switch tone {
        case .cyan: theme.accent
        case .amber, .caution: theme.highlight
        case .magenta: theme.warm
        case .off: RunicFlightDeck.dim
        }
    }

    private var fillOpacity: Double {
        switch self.tone {
        case .cyan: 0.07
        case .amber, .magenta: 0.09
        case .caution, .off: 0
        }
    }

    private var accessibilityText: String {
        switch self.tone {
        case .caution: "Master caution: \(self.text)"
        case .off: "\(self.text), off"
        default: self.text
        }
    }
}

/// Hairline between rows.
struct FlightDeckRule: View {
    var color: Color = RunicFlightDeck.hairline

    var body: some View {
        Rectangle()
            .fill(self.color)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// An ECAM memo: a coloured lead bar, a tracked title in the memo's tone,
/// and its lines beneath, on a faint wash of the same tone. Warnings are
/// magenta, cautions amber, advisories cyan.
struct FlightDeckMemo<Content: View>: View {
    let title: String
    var tone: FlightDeckTag.Tone = .cyan
    @ViewBuilder let content: () -> Content
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let color = FlightDeckTag.color(for: self.tone, theme: self.runicTheme)
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                FlightDeckLabel(text: self.title, size: 9, color: color, weight: .bold, tracking: 1.1)
                self.content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 7)
        .padding(.trailing, 8)
        .padding(.leading, 1)
        .background(Rectangle().fill(color.opacity(0.06)))
        .overlay(Rectangle().strokeBorder(color.opacity(0.45), lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Tapes

/// A vertical tape: a spine with a long tick every 10 and a short one every
/// 5, labels every 20, the amber and magenta caution bands along the spine
/// at the spent end, a cyan pointer box carrying the value, a dashed amber
/// PLAN line and a green trend vector whose length is the burn rate. Ticks
/// face outward from the ball, so a left tape and a right tape mirror.
struct FlightDeckTape: View {
    let title: String
    let percent: Double
    let style: UsageMenuCardView.Model.PercentStyle
    /// Spine on the trailing edge (a left-hand tape).
    var ticksTrailing = true
    /// Used-percent per hour; nil draws no vector.
    var ratePerHour: Double?
    /// Where the plan line sits, as a display percent.
    var marker: Double?
    var width: CGFloat = 60
    var height: CGFloat = 250
    @Environment(\.runicTheme) private var runicTheme

    private let top: CGFloat = 22
    private let bottom: CGFloat = 18

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        Canvas { context, size in
            self.drawTitle(&context, size: size)
            self.drawScale(&context, size: size)
            self.drawMarker(&context, size: size)
            self.drawVector(&context, size: size, percent: clamped)
            self.drawPointer(&context, size: size, percent: clamped)
        }
        .skinFace()
        .frame(width: self.width, height: self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.title) tape, \(self.style.accessibilityLabel)")
        .accessibilityValue("\(Int(clamped.rounded())) percent \(self.style.labelSuffix)")
    }

    private func y(_ percent: Double, in size: CGSize) -> CGFloat {
        let span = size.height - self.top - self.bottom
        return (self.top + span * (1 - CGFloat(min(100, max(0, percent)) / 100))).rounded() + 0.5
    }

    /// The spine's x: the edge facing the ball.
    private func spineX(_ size: CGSize) -> CGFloat {
        (self.ticksTrailing ? size.width - 10 : 10) + 0.5
    }

    /// Toward the outer edge of the tape (away from the ball).
    private var outward: CGFloat {
        self.ticksTrailing ? -1 : 1
    }

    /// The spent end of the scale: the top for "used", the bottom for "left".
    private var cautionAtTop: Bool {
        self.style == .used
    }

    private func drawTitle(_ context: inout GraphicsContext, size: CGSize) {
        context.draw(
            Text(self.title.uppercased())
                .font(RunicFlightDeck.mono(8))
                .fontDesign(nil)
                .foregroundStyle(self.runicTheme.secondaryText),
            at: CGPoint(x: self.ticksTrailing ? 1 : size.width - 1, y: 7),
            anchor: self.ticksTrailing ? .leading : .trailing)
    }

    private func drawScale(_ context: inout GraphicsContext, size: CGSize) {
        let spine = self.spineX(size)
        var spinePath = Path()
        spinePath.move(to: CGPoint(x: spine, y: self.y(100, in: size) - 4))
        spinePath.addLine(to: CGPoint(x: spine, y: self.y(0, in: size) + 4))
        context.stroke(spinePath, with: .color(self.runicTheme.secondaryText.opacity(0.6)), lineWidth: 1)
        for step in stride(from: 0, through: 100, by: 5) {
            let value = Double(step)
            let cy = self.y(value, in: size)
            let major = step % 10 == 0
            let tone = self.tone(forScale: value)
            var tick = Path()
            tick.move(to: CGPoint(x: spine, y: cy))
            tick.addLine(to: CGPoint(x: spine + self.outward * (major ? 7 : 4), y: cy))
            context.stroke(tick, with: .color(major ? tone : tone.opacity(0.6)), lineWidth: 1)
            if step % 20 == 0 {
                context.draw(
                    Text("\(step)").font(RunicFlightDeck.mono(8)).fontDesign(nil).foregroundStyle(tone),
                    at: CGPoint(x: spine + self.outward * 10, y: cy),
                    anchor: self.ticksTrailing ? .trailing : .leading)
            }
        }
        let amber = self.cautionAtTop ? (80.0, 90.0) : (10.0, 20.0)
        let magenta = self.cautionAtTop ? (90.0, 100.0) : (0.0, 10.0)
        let bandX = self.ticksTrailing ? spine + 1.5 : spine - 4.5
        for (band, color) in [(amber, self.runicTheme.highlight), (magenta, self.runicTheme.warm)] {
            let rect = CGRect(
                x: bandX,
                y: self.y(band.1, in: size),
                width: 3,
                height: self.y(band.0, in: size) - self.y(band.1, in: size))
            context.fill(Path(rect), with: .color(color))
        }
    }

    private func tone(forScale value: Double) -> Color {
        let spent = self.cautionAtTop ? value : 100 - value
        if spent >= 90 { return self.runicTheme.warm }
        if spent >= 80 { return self.runicTheme.highlight }
        return self.runicTheme.secondaryText
    }

    private func drawMarker(_ context: inout GraphicsContext, size: CGSize) {
        guard let marker else { return }
        let cy = self.y(marker, in: size)
        let spine = self.spineX(size)
        let outer: CGFloat = self.ticksTrailing ? 1 : size.width - 1
        var line = Path()
        line.move(to: CGPoint(x: outer, y: cy))
        line.addLine(to: CGPoint(x: spine, y: cy))
        context.stroke(
            line,
            with: .color(self.runicTheme.highlight),
            style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
        context.draw(
            Text("PLAN").font(RunicFlightDeck.mono(7)).fontDesign(nil).foregroundStyle(self.runicTheme.highlight),
            at: CGPoint(x: (outer + spine) / 2, y: cy - 6))
    }

    private func drawVector(_ context: inout GraphicsContext, size: CGSize, percent: Double) {
        guard let rate = self.ratePerHour, rate >= 0.5 else { return }
        let green = self.runicTheme.tertiary
        // The rate reads at the foot of the tape, clear of the scale.
        let label = rate < 1 ? String(format: "+%.1f/H", rate) : "+\(Int(rate.rounded()))/H"
        context.draw(
            Text(label).font(RunicFlightDeck.mono(8, .bold)).fontDesign(nil).foregroundStyle(green),
            at: CGPoint(x: self.ticksTrailing ? 1 : size.width - 1, y: size.height - 6),
            anchor: self.ticksTrailing ? .leading : .trailing)
        // The vector points where the pointer will be in an hour.
        let direction: Double = self.style == .used ? 1 : -1
        let target = min(100, max(0, percent + rate * direction))
        let y0 = self.y(percent, in: size)
        let y1 = self.y(target, in: size)
        guard abs(y0 - y1) >= 6 else { return }
        let x: CGFloat = self.ticksTrailing ? size.width - 2.5 : 2.5
        var line = Path()
        line.move(to: CGPoint(x: x, y: y0))
        line.addLine(to: CGPoint(x: x, y: y1 + (y1 < y0 ? 5 : -5)))
        context.stroke(line, with: .color(green), lineWidth: 1.5)
        var head = Path()
        let tip = y1 < y0 ? -1.0 : 1.0
        head.move(to: CGPoint(x: x, y: y1))
        head.addLine(to: CGPoint(x: x - 2.5, y: y1 - 6 * tip))
        head.addLine(to: CGPoint(x: x + 2.5, y: y1 - 6 * tip))
        head.closeSubpath()
        context.fill(head, with: .color(green))
    }

    private func drawPointer(_ context: inout GraphicsContext, size: CGSize, percent: Double) {
        let cy = self.y(percent, in: size)
        let spine = self.spineX(size)
        let h: CGFloat = 16
        let outer: CGFloat = self.ticksTrailing ? 1 : size.width - 1
        let tip = spine + self.outward * 1.5
        let inner = spine + self.outward * 8
        var box = Path()
        box.move(to: CGPoint(x: outer, y: cy - h / 2))
        box.addLine(to: CGPoint(x: inner, y: cy - h / 2))
        box.addLine(to: CGPoint(x: tip, y: cy))
        box.addLine(to: CGPoint(x: inner, y: cy + h / 2))
        box.addLine(to: CGPoint(x: outer, y: cy + h / 2))
        box.closeSubpath()
        context.fill(box, with: .color(self.runicTheme.accent))
        context.draw(
            Text("\(Int(percent.rounded()))")
                .font(RunicFlightDeck.mono(12, .bold))
                .fontDesign(nil)
                .foregroundStyle(self.runicTheme.surface),
            at: CGPoint(x: (outer + inner) / 2, y: cy))
    }
}

/// A horizontal tape for the navigation display: the same scale and bands
/// laid flat in a deep well, the pointer box outlined in the provider's
/// colour.
struct FlightDeckHorizontalTape: View {
    let percent: Double?
    let showsUsed: Bool
    let tint: Color
    let accessibilityLabel: String
    var height: CGFloat = 34
    @Environment(\.runicTheme) private var runicTheme

    private let leading: CGFloat = 6
    private let trailing: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            let frame = CGRect(origin: .zero, size: size)
            context.fill(Path(frame), with: .color(self.runicTheme.surface))
            context.stroke(
                Path(frame.insetBy(dx: 0.5, dy: 0.5)),
                with: .color(self.runicTheme.cardStroke),
                lineWidth: 1)
            let scaleY = size.height - 8
            for step in stride(from: 0, through: 100, by: 5) {
                let x = self.x(Double(step), in: size)
                let tone = self.tone(forScale: Double(step))
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: scaleY))
                let length: CGFloat = step % 50 == 0 ? 7 : (step % 10 == 0 ? 4 : 2)
                tick.addLine(to: CGPoint(x: x, y: scaleY + length))
                context.stroke(tick, with: .color(step % 10 == 0 ? tone : tone.opacity(0.55)), lineWidth: 1)
                if step % 20 == 0 {
                    context.draw(
                        Text("\(step)").font(RunicFlightDeck.mono(7)).fontDesign(nil).foregroundStyle(tone),
                        at: CGPoint(x: x, y: scaleY - 5))
                }
            }
            let amber = self.showsUsed ? (80.0, 90.0) : (10.0, 20.0)
            let magenta = self.showsUsed ? (90.0, 100.0) : (0.0, 10.0)
            for (band, color) in [(amber, self.runicTheme.highlight), (magenta, self.runicTheme.warm)] {
                let x0 = self.x(band.0, in: size)
                let x1 = self.x(band.1, in: size)
                context.fill(Path(CGRect(x: x0, y: 1, width: x1 - x0, height: 2)), with: .color(color))
            }
            guard let percent = self.percent else {
                context.draw(
                    Text("----")
                        .font(RunicFlightDeck.mono(11, .bold))
                        .fontDesign(nil)
                        .foregroundStyle(RunicFlightDeck.dim),
                    at: CGPoint(x: size.width / 2, y: size.height / 2 - 3))
                return
            }
            let clamped = min(100, max(0, percent))
            let px = self.x(clamped, in: size)
            let track = CGRect(x: self.leading, y: 4, width: px - self.leading, height: scaleY - 6)
            context.fill(Path(track), with: .color(self.tint.opacity(0.16)))
            var edge = Path()
            edge.move(to: CGPoint(x: px, y: 4))
            edge.addLine(to: CGPoint(x: px, y: scaleY))
            context.stroke(edge, with: .color(self.tint.opacity(0.7)), lineWidth: 1)
            let boxW: CGFloat = 30
            let boxH: CGFloat = 15
            let left = min(max(px - boxW / 2, 2), size.width - boxW - 2)
            let boxY = (scaleY - boxH) / 2
            var box = Path()
            box.move(to: CGPoint(x: left, y: boxY))
            box.addLine(to: CGPoint(x: left + boxW, y: boxY))
            box.addLine(to: CGPoint(x: left + boxW, y: boxY + boxH))
            box.addLine(to: CGPoint(x: px + 4, y: boxY + boxH))
            box.addLine(to: CGPoint(x: px, y: boxY + boxH + 4))
            box.addLine(to: CGPoint(x: px - 4, y: boxY + boxH))
            box.addLine(to: CGPoint(x: left, y: boxY + boxH))
            box.closeSubpath()
            context.fill(box, with: .color(self.runicTheme.surface))
            context.stroke(box, with: .color(self.tint), lineWidth: 1.2)
            context.draw(
                Text("\(Int(clamped.rounded()))")
                    .font(RunicFlightDeck.mono(11, .bold))
                    .fontDesign(nil)
                    .foregroundStyle(self.runicTheme.accent),
                at: CGPoint(x: left + boxW / 2, y: boxY + boxH / 2))
        }
        .skinFace()
        .frame(height: self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue(self.percent.map { "\(Int($0.rounded())) percent" } ?? "no quota")
    }

    private func x(_ percent: Double, in size: CGSize) -> CGFloat {
        let span = size.width - self.leading - self.trailing
        return (self.leading + span * CGFloat(min(100, max(0, percent)) / 100)).rounded() + 0.5
    }

    private func tone(forScale value: Double) -> Color {
        let spent = self.showsUsed ? value : 100 - value
        if spent >= 90 { return self.runicTheme.warm }
        if spent >= 80 { return self.runicTheme.highlight }
        return self.runicTheme.secondaryText
    }
}

// MARK: - Attitude indicator

/// The attitude indicator: a laser-etched degree ring with a graduation
/// every 5°, a deep sky-over-ground ball behind a 1pt pitch ladder, the
/// fixed aircraft symbol, a magenta flight-director chevron, and the PACE
/// pill under the ring. Level means on pace; behind pushes the horizon up
/// (nose down) by the shortfall, ahead pulls it down.
struct FlightDeckAttitude: View {
    /// Negative when behind, positive when ahead, 0 on pace, nil unknown.
    let paceDelta: Double?
    var size: CGFloat = 170
    @Environment(\.runicTheme) private var runicTheme

    private let pillHeight: CGFloat = 18

    var body: some View {
        let ringRadius = self.size / 2 - 1
        let radius = ringRadius - 13
        let center = CGPoint(x: self.size / 2, y: self.size / 2)
        let shift = min(35, max(-35, self.paceDelta ?? 0)) / 100
        let horizonY = (center.y + CGFloat(shift) * radius).rounded() + 0.5
        VStack(spacing: 4) {
            ZStack {
                Canvas { context, _ in
                    self.drawRing(&context, center: center, ringRadius: ringRadius, ballRadius: radius)
                    var ball = context
                    ball.clip(to: Path(ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2)))
                    ball.fill(
                        Path(CGRect(origin: .zero, size: CGSize(width: self.size, height: self.size))),
                        with: .color(self.runicTheme.surface))
                    ball.fill(
                        Path(CGRect(x: 0, y: -self.size, width: self.size, height: horizonY + self.size)),
                        with: .color(self.runicTheme.secondary.opacity(0.55)))
                    ball.fill(
                        Path(CGRect(x: 0, y: horizonY, width: self.size, height: self.size * 2)),
                        with: .color(RunicFlightDeck.ground.opacity(0.6)))
                    var horizon = Path()
                    horizon.move(to: CGPoint(x: 0, y: horizonY))
                    horizon.addLine(to: CGPoint(x: self.size, y: horizonY))
                    ball.stroke(horizon, with: .color(self.runicTheme.primaryText), lineWidth: 1.5)
                    self.drawLadder(&ball, center: center, radius: radius, horizonY: horizonY)
                }
                .skinFace()

                Circle()
                    .strokeBorder(self.runicTheme.cardStroke, lineWidth: 1)
                    .frame(width: radius * 2 + 2, height: radius * 2 + 2)

                Canvas { context, _ in
                    self.drawDirector(&context, center: center, radius: radius)
                    self.drawAircraft(&context, center: center, radius: radius)
                }
            }
            .frame(width: self.size, height: self.size)

            self.pacePill
        }
        .frame(width: self.size, height: self.size + 4 + self.pillHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    /// The etched degree ring: a hairline circle, a graduation every 5°
    /// (long every 30°), and the white index triangle at the top.
    private func drawRing(
        _ context: inout GraphicsContext,
        center: CGPoint,
        ringRadius: CGFloat,
        ballRadius: CGFloat)
    {
        let etch = self.runicTheme.secondaryText
        context.stroke(
            Path(ellipseIn: CGRect(
                x: center.x - ringRadius + 0.5,
                y: center.y - ringRadius + 0.5,
                width: ringRadius * 2 - 1,
                height: ringRadius * 2 - 1)),
            with: .color(etch.opacity(0.35)),
            lineWidth: 1)
        for degree in stride(from: 0, to: 360, by: 5) {
            let major = degree % 30 == 0
            let mid = degree % 10 == 0
            let angle = Double(degree - 90) * .pi / 180
            let dx = CGFloat(cos(angle))
            let dy = CGFloat(sin(angle))
            let outer = ringRadius - 2
            let inner = outer - (major ? 7 : (mid ? 4.5 : 2.5))
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + dx * inner, y: center.y + dy * inner))
            tick.addLine(to: CGPoint(x: center.x + dx * outer, y: center.y + dy * outer))
            context.stroke(tick, with: .color(etch.opacity(major ? 0.9 : 0.5)), lineWidth: 1)
        }
        var index = Path()
        let topY = center.y - ringRadius + 2
        index.move(to: CGPoint(x: center.x, y: topY + 7))
        index.addLine(to: CGPoint(x: center.x - 4.5, y: topY))
        index.addLine(to: CGPoint(x: center.x + 4.5, y: topY))
        index.closeSubpath()
        context.fill(index, with: .color(self.runicTheme.primaryText))
        var sky = Path()
        let ballTop = center.y - ballRadius
        sky.move(to: CGPoint(x: center.x, y: ballTop - 1))
        sky.addLine(to: CGPoint(x: center.x - 4, y: ballTop - 7))
        sky.addLine(to: CGPoint(x: center.x + 4, y: ballTop - 7))
        sky.closeSubpath()
        context.stroke(sky, with: .color(self.runicTheme.primaryText.opacity(0.8)), lineWidth: 1)
    }

    private func drawLadder(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, horizonY: CGFloat) {
        let step = radius * 0.26
        let ink = self.runicTheme.primaryText.opacity(0.92)
        let rungs: [(Int, CGFloat, Bool)] = [
            (5, radius * 0.12, true), (10, radius * 0.30, true), (15, radius * 0.12, true), (20, radius * 0.22, true),
            (5, radius * 0.12, false), (10, radius * 0.30, false), (15, radius * 0.12, false),
            (20, radius * 0.22, false),
        ]
        for (degrees, half, above) in rungs {
            let offset = step * CGFloat(degrees) / 10
            let y = ((above ? horizonY - offset : horizonY + offset) - 0.5).rounded() + 0.5
            var rung = Path()
            rung.move(to: CGPoint(x: center.x - half, y: y))
            rung.addLine(to: CGPoint(x: center.x + half, y: y))
            let isMajor = degrees % 10 == 0
            if isMajor {
                // End caps point toward the horizon, Airbus style.
                let cap: CGFloat = above ? 3 : -3
                rung.move(to: CGPoint(x: center.x - half, y: y))
                rung.addLine(to: CGPoint(x: center.x - half, y: y + cap))
                rung.move(to: CGPoint(x: center.x + half, y: y))
                rung.addLine(to: CGPoint(x: center.x + half, y: y + cap))
            }
            context.stroke(
                rung,
                with: .color(ink),
                style: StrokeStyle(lineWidth: 1, dash: above || !isMajor ? [] : [4, 3]))
            guard isMajor else { continue }
            for side in [-1.0, 1.0] {
                context.draw(
                    Text("\(degrees)").font(RunicFlightDeck.mono(7)).fontDesign(nil).foregroundStyle(ink),
                    at: CGPoint(x: center.x + CGFloat(side) * (half + 4), y: y),
                    anchor: side < 0 ? .trailing : .leading)
            }
        }
    }

    /// The flight director: a magenta chevron steering back toward level.
    private func drawDirector(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        guard let delta = self.paceDelta else { return }
        let command = CGFloat(min(35, max(-35, delta)) / 100) * radius * -0.35
        let apex = CGPoint(x: center.x, y: center.y - radius * 0.2 + command)
        let half = radius * 0.24
        let drop = radius * 0.24
        var chevron = Path()
        chevron.move(to: CGPoint(x: apex.x - half, y: apex.y + drop))
        chevron.addLine(to: apex)
        chevron.addLine(to: CGPoint(x: apex.x + half, y: apex.y + drop))
        chevron.addLine(to: CGPoint(x: apex.x, y: apex.y + drop * 0.62))
        chevron.closeSubpath()
        context.stroke(
            chevron,
            with: .color(self.runicTheme.warm),
            style: StrokeStyle(lineWidth: 1.5, lineJoin: .miter))
    }

    private func drawAircraft(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let yellow = RunicFlightDeck.aircraftYellow
        let style = StrokeStyle(lineWidth: 2.5, lineCap: .butt, lineJoin: .miter)
        let wing = radius * 0.66
        let elbow = radius * 0.3
        let drop = radius * 0.09
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            var arm = Path()
            arm.move(to: CGPoint(x: center.x + s * wing, y: center.y))
            arm.addLine(to: CGPoint(x: center.x + s * elbow, y: center.y))
            arm.addLine(to: CGPoint(x: center.x + s * elbow, y: center.y + drop))
            context.stroke(arm, with: .color(yellow), style: style)
        }
        context.fill(
            Path(CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)),
            with: .color(yellow))
    }

    @ViewBuilder private var pacePill: some View {
        let (text, color): (String, Color) = {
            guard let delta = self.paceDelta else { return ("PACE ----", RunicFlightDeck.dim) }
            let rounded = Int(abs(delta).rounded())
            if rounded == 0 { return ("ON PACE", self.runicTheme.accent) }
            let sign = delta < 0 ? "\u{2212}" : "+"
            return ("PACE \(sign)\(rounded)%", delta < 0 ? self.runicTheme.highlight : self.runicTheme.tertiary)
        }()
        Text(text)
            .font(RunicFlightDeck.mono(10, .bold))
            .skinFace()
            .tracking(0.8)
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: self.pillHeight)
            .background(Capsule().fill(self.runicTheme.surface))
            .background(Capsule().fill(color.opacity(0.1)))
            .overlay(Capsule().strokeBorder(color.opacity(0.85), lineWidth: 1))
    }

    private var accessibilityText: String {
        guard let delta = self.paceDelta else { return "Pace attitude: no pace information" }
        let rounded = Int(abs(delta).rounded())
        if rounded == 0 { return "Pace attitude: on pace, level" }
        return delta < 0
            ? "Pace attitude: behind by \(rounded) percent, nose down"
            : "Pace attitude: ahead by \(rounded) percent, nose up"
    }
}

// MARK: - FMA, burn strip, table rows

/// One flight mode annunciator cell: an optional tiny label over a mono
/// value. `bordered` boxes it on its own; inside a `FlightDeckFMAStrip`
/// the strip draws the dividers. `boxed` rings the value, the way the FMA
/// marks an engaged mode.
struct FlightDeckCell: View {
    let label: String?
    let value: String?
    var color: Color?
    var bordered = true
    var boxed = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let tone = self.value == nil ? RunicFlightDeck.dim : (self.color ?? self.runicTheme.accent)
        VStack(spacing: 2) {
            if let label {
                FlightDeckLabel(text: label, size: 7.5, tracking: 0.6)
                    .minimumScaleFactor(0.7)
            }
            Text(self.value?.uppercased() ?? "----")
                .font(RunicFlightDeck.mono(self.label == nil ? 10.5 : 11.5, .bold))
                .skinFace()
                .tracking(0.4)
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, self.boxed ? 5 : 0)
                .padding(.vertical, self.boxed ? 1.5 : 0)
                .overlay {
                    if self.boxed {
                        Rectangle().strokeBorder(tone.opacity(0.8), lineWidth: 1)
                    }
                }
        }
        .padding(.vertical, self.label == nil ? 6 : 5)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .overlay {
            if self.bordered {
                Rectangle().strokeBorder(self.runicTheme.cardStroke, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.label ?? "Mode"): \(self.value ?? "unknown")")
    }
}

/// The flight mode annunciator: cells locked flush in one bezel, split by
/// hairline dividers, every column the same width.
struct FlightDeckFMAStrip: View {
    struct Item: Identifiable {
        let id: Int
        var label: String?
        var value: String?
        var color: Color?
        var boxed = false
    }

    let items: [Item]
    var fill: Color?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(self.items) { item in
                if item.id != self.items.first?.id {
                    Rectangle()
                        .fill(self.runicTheme.cardStroke)
                        .frame(width: 1)
                        .padding(.vertical, 4)
                        .accessibilityHidden(true)
                }
                FlightDeckCell(
                    label: item.label,
                    value: item.value,
                    color: item.color,
                    bordered: false,
                    boxed: item.boxed)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .flightDeckBezel(fill: self.fill ?? self.runicTheme.surface, reticles: false)
        .accessibilityElement(children: .contain)
    }
}

/// The 24-hour burn velocity strip: one bar per hour on a faint grid, the
/// height the share burned that hour, the peak hour lit amber.
struct FlightDeckBurnStrip: View {
    let values: [Double]
    var height: CGFloat = 46
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let peak = self.values.max() ?? 0
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                FlightDeckLabel(text: "24H burn velocity", size: 8.5)
                Spacer(minLength: 6)
                FlightDeckLabel(
                    text: String(format: "PEAK +%.0f%%/H", peak),
                    size: 8.5,
                    color: self.runicTheme.highlight,
                    tracking: 0.6)
            }
            Canvas { context, size in
                let count = max(1, self.values.count)
                let grid = self.runicTheme.cardStroke.opacity(0.55)
                for row in 0...2 {
                    let y = (size.height * CGFloat(row) / 2).rounded() + (row == 2 ? -0.5 : 0.5)
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(grid), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
                let slot = size.width / CGFloat(count)
                for (index, value) in self.values.enumerated() {
                    let x = slot * CGFloat(index)
                    let tick = CGRect(x: x + 1, y: size.height - 1, width: max(1, slot - 2), height: 1)
                    context.fill(Path(tick), with: .color(self.runicTheme.secondaryText.opacity(0.35)))
                    guard value > 0, peak > 0 else { continue }
                    let h = max(2, (size.height - 3) * CGFloat(value / peak))
                    let bar = CGRect(x: x + 1, y: size.height - 1 - h, width: max(1, slot - 2), height: h)
                    let color = value >= peak ? self.runicTheme.highlight : self.runicTheme.accent
                    context.fill(Path(bar), with: .color(color.opacity(0.28)))
                    context.fill(
                        Path(CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: 1.5)),
                        with: .color(color))
                }
            }
            .frame(height: self.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("24 hour burn velocity, peak \(Int(peak.rounded())) percent per hour")
    }
}

/// A row of the mono ledger: key left in the secondary tone, value right
/// in tabular mono; an ECAM tone paints a lead tick and the key.
struct FlightDeckRow: View {
    let key: String
    let value: String
    var valueColor: Color?
    var detail: String?
    var isLast = false
    /// An ECAM tone for annunciated rows (banked resets, API credits).
    var tone: FlightDeckTag.Tone?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let toneColor = self.tone.map { FlightDeckTag.color(for: $0, theme: self.runicTheme) }
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let toneColor {
                    Rectangle()
                        .fill(toneColor)
                        .frame(width: 5, height: 5)
                        .offset(y: -1)
                        .accessibilityHidden(true)
                }
                Text(self.key.uppercased())
                    .font(RunicFlightDeck.mono(9))
                    .skinFace()
                    .tracking(0.6)
                    .foregroundStyle(toneColor ?? self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text(self.value)
                    .font(RunicFlightDeck.mono(10.5, .bold))
                    .skinFace()
                    .foregroundStyle(self.valueColor ?? self.runicTheme.primaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let detail = self.detail, !detail.isEmpty {
                Text(detail)
                    .font(RunicFlightDeck.sans(10))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, toneColor == nil ? 0 : 13)
            }
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            if !self.isLast { FlightDeckRule() }
        }
    }
}

// MARK: - Buttons

/// A mono outlined rectangle; `primary` fills it cyan. Hover lights the
/// outline cyan. `compact` is the short control used inside memos;
/// `fullWidth` stretches it and lets a long title wrap instead of clip.
struct FlightDeckButton: View {
    let title: String
    var primary = false
    var systemImage: String?
    var minWidth: CGFloat?
    var compact = false
    var fullWidth = false
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let cyan = self.runicTheme.accent
        let ink = self.runicTheme.primaryText
        Button(action: self.action) {
            HStack(spacing: self.compact ? 5 : 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: self.compact ? 9 : 10, weight: .bold))
                }
                Text(self.title.uppercased())
                    .font(RunicFlightDeck.mono(self.compact ? 9.5 : 10.5, self.primary ? .bold : .regular))
                    .skinFace()
                    .tracking(RunicFlightDeck.tagTracking)
                    .lineLimit(self.fullWidth ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: self.fullWidth)
                if self.fullWidth { Spacer(minLength: 0) }
            }
            .foregroundStyle(self.primary ? self.runicTheme.surface : (self.isHovered ? cyan : ink))
            .padding(.horizontal, self.compact ? 9 : 12)
            .padding(.vertical, self.fullWidth ? 6 : 0)
            .frame(minWidth: self.minWidth, minHeight: self.compact ? 24 : 30)
            .frame(maxWidth: self.fullWidth ? .infinity : nil, alignment: .leading)
            .background(Rectangle().fill(self.primary ? (self.isHovered ? cyan.opacity(0.85) : cyan) : Color.clear))
            .overlay(Rectangle().strokeBorder(
                self.primary || self.isHovered ? cyan : self.runicTheme.cardStroke,
                lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

/// A compact COPY control that writes `text` to the pasteboard and flips
/// to a checkmark for a moment.
struct FlightDeckCopyButton: View {
    let text: String
    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        FlightDeckButton(
            title: self.didCopy ? "Copied" : "Copy",
            systemImage: self.didCopy ? "checkmark" : "doc.on.doc",
            compact: true)
        {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(self.text, forType: .string)
            self.didCopy = true
            self.resetTask?.cancel()
            self.resetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                self.didCopy = false
            }
        }
        .accessibilityLabel(self.didCopy ? "Copied" : "Copy error")
    }
}
