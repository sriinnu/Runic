import AppKit
import RunicCore
import SwiftUI

// MARK: - Avionics kit

/// Flight deck's kit: a primary flight display. Two faces addressed by
/// PostScript name — B612 for copy, B612 Mono for every readout — plus the
/// marks the display is composed from: annunciator tags, vertical and
/// horizontal tapes with caution bands, the attitude ball, FMA cells, the
/// mono table, outlined buttons.
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

    /// Attitude ball ground (the sky is the theme's `secondary`).
    static let ground = Color(red: 0.545, green: 0.353, blue: 0.169)
    /// The fixed aircraft symbol.
    static let aircraftYellow = Color(red: 1.0, green: 0.831, blue: 0.0)
    /// Annunciators that are off, "----" readouts.
    static let dim = Color(red: 0.42, green: 0.44, blue: 0.46)
    /// Hairline between waypoint rows.
    static let hairline = Color(red: 0.133, green: 0.149, blue: 0.165)

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
/// magenta; `master` is the filled amber MASTER CAUT; `off` is dimmed.
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
            .overlay(Rectangle().stroke(color, lineWidth: 1))
            .accessibilityLabel(self.accessibilityText)
    }

    private var color: Color {
        switch self.tone {
        case .cyan: self.runicTheme.accent
        case .amber, .caution: self.runicTheme.highlight
        case .magenta: self.runicTheme.warm
        case .off: RunicFlightDeck.dim
        }
    }

    private var fillOpacity: Double {
        switch self.tone {
        case .cyan: 0.06
        case .amber, .magenta: 0.08
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

// MARK: - Tapes

/// A vertical tape: the 0–100 scale with a tick every 10, the amber and
/// magenta caution bands at the spent end, a pointer box carrying the value
/// in cyan, and a green trend vector whose length is the burn rate. Ticks
/// face inward, so a left tape and a right tape mirror each other.
struct FlightDeckTape: View {
    let title: String
    let percent: Double
    let style: UsageMenuCardView.Model.PercentStyle
    /// Ticks and bands on the trailing edge (a left-hand tape).
    var ticksTrailing = true
    /// Used-percent per hour; nil draws no vector.
    var ratePerHour: Double?
    /// Where the plan line sits, as a display percent.
    var marker: Double?
    var width: CGFloat = 60
    var height: CGFloat = 250
    @Environment(\.runicTheme) private var runicTheme

    private let top: CGFloat = 20
    private let bottom: CGFloat = 8

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        Canvas { context, size in
            self.drawFrame(&context, size: size)
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
        return self.top + span * (1 - CGFloat(min(100, max(0, percent)) / 100))
    }

    /// The spent end of the scale: the top for "used", the bottom for "left".
    private var cautionAtTop: Bool {
        self.style == .used
    }

    private func drawFrame(_ context: inout GraphicsContext, size: CGSize) {
        let frame = CGRect(origin: .zero, size: size)
        context.fill(Path(frame), with: .color(self.runicTheme.surfaceAlt))
        context.stroke(Path(frame.insetBy(dx: 0.5, dy: 0.5)), with: .color(self.runicTheme.cardStroke), lineWidth: 1)
        context.draw(
            Text(self.title.uppercased())
                .font(RunicFlightDeck.mono(8))
                .fontDesign(nil)
                .foregroundStyle(self.runicTheme.secondaryText),
            at: CGPoint(x: self.ticksTrailing ? 6 : size.width - 6, y: 7),
            anchor: self.ticksTrailing ? .leading : .trailing)
    }

    private func drawScale(_ context: inout GraphicsContext, size: CGSize) {
        let tickInner: CGFloat = self.ticksTrailing ? size.width - 8 : 8
        let tickOuter: CGFloat = self.ticksTrailing ? size.width - 14 : 14
        let bandX: CGFloat = self.ticksTrailing ? size.width - 8 : 4
        let labelX: CGFloat = self.ticksTrailing ? tickOuter - 3 : tickOuter + 3
        for step in stride(from: 0, through: 100, by: 10) {
            let value = Double(step)
            let cy = self.y(value, in: size)
            let tone = self.tone(forScale: value)
            var tick = Path()
            tick.move(to: CGPoint(x: tickOuter, y: cy))
            tick.addLine(to: CGPoint(x: tickInner, y: cy))
            context.stroke(tick, with: .color(tone), lineWidth: 1)
            context.draw(
                Text("\(step)").font(RunicFlightDeck.mono(8)).fontDesign(nil).foregroundStyle(tone),
                at: CGPoint(x: labelX, y: cy),
                anchor: self.ticksTrailing ? .trailing : .leading)
        }
        let amber = self.cautionAtTop ? (80.0, 90.0) : (10.0, 20.0)
        let magenta = self.cautionAtTop ? (90.0, 100.0) : (0.0, 10.0)
        for (band, color) in [(amber, self.runicTheme.highlight), (magenta, self.runicTheme.warm)] {
            let rect = CGRect(
                x: bandX,
                y: self.y(band.1, in: size),
                width: 4,
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
        let x0: CGFloat = self.ticksTrailing ? 4 : 8
        let x1: CGFloat = self.ticksTrailing ? size.width - 8 : size.width - 4
        var line = Path()
        line.move(to: CGPoint(x: x0, y: cy))
        line.addLine(to: CGPoint(x: x1, y: cy))
        context.stroke(
            line,
            with: .color(self.runicTheme.highlight),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        context.draw(
            Text("PLAN").font(RunicFlightDeck.mono(7)).fontDesign(nil).foregroundStyle(self.runicTheme.highlight),
            at: CGPoint(x: (x0 + x1) / 2, y: cy - 6))
    }

    private func drawVector(_ context: inout GraphicsContext, size: CGSize, percent: Double) {
        guard let rate = self.ratePerHour, rate >= 0.5 else { return }
        // The vector points where the pointer will be in an hour.
        let direction: Double = self.style == .used ? 1 : -1
        let target = min(100, max(0, percent + rate * direction))
        let y0 = self.y(percent, in: size)
        let y1 = self.y(target, in: size)
        guard abs(y0 - y1) >= 6 else { return }
        let x: CGFloat = self.ticksTrailing ? size.width - 3 : 3
        let green = self.runicTheme.tertiary
        var line = Path()
        line.move(to: CGPoint(x: x, y: y0))
        line.addLine(to: CGPoint(x: x, y: y1 + (y1 < y0 ? 5 : -5)))
        context.stroke(line, with: .color(green), lineWidth: 2)
        var head = Path()
        let tip = y1 < y0 ? -1.0 : 1.0
        head.move(to: CGPoint(x: x, y: y1))
        head.addLine(to: CGPoint(x: x - 3, y: y1 - 6 * tip))
        head.addLine(to: CGPoint(x: x + 3, y: y1 - 6 * tip))
        head.closeSubpath()
        context.fill(head, with: .color(green))
        // The rate sits on the open side of the tape, level with the tip,
        // clear of the scale labels.
        if abs(y0 - y1) >= 22 {
            let label = rate < 1 ? String(format: "+%.1f/h", rate) : "+\(Int(rate.rounded()))/h"
            context.draw(
                Text(label).font(RunicFlightDeck.mono(7)).fontDesign(nil).foregroundStyle(green),
                at: CGPoint(x: self.ticksTrailing ? 5 : size.width - 5, y: y1),
                anchor: self.ticksTrailing ? .leading : .trailing)
        }
    }

    private func drawPointer(_ context: inout GraphicsContext, size: CGSize, percent: Double) {
        let cy = self.y(percent, in: size)
        let h: CGFloat = 17
        let outer: CGFloat = self.ticksTrailing ? 4 : size.width - 4
        let inner: CGFloat = self.ticksTrailing ? size.width - 10 : 10
        let tip: CGFloat = self.ticksTrailing ? size.width - 2 : 2
        var box = Path()
        box.move(to: CGPoint(x: outer, y: cy - h / 2))
        box.addLine(to: CGPoint(x: inner, y: cy - h / 2))
        box.addLine(to: CGPoint(x: tip, y: cy))
        box.addLine(to: CGPoint(x: inner, y: cy + h / 2))
        box.addLine(to: CGPoint(x: outer, y: cy + h / 2))
        box.closeSubpath()
        context.fill(box, with: .color(self.runicTheme.surface))
        context.stroke(box, with: .color(self.runicTheme.primaryText), lineWidth: 1.5)
        context.draw(
            Text("\(Int(percent.rounded()))")
                .font(RunicFlightDeck.mono(12, .bold))
                .fontDesign(nil)
                .foregroundStyle(self.runicTheme.accent),
            at: CGPoint(x: (outer + inner) / 2, y: cy))
    }
}

/// A horizontal tape for the navigation display: the same scale and bands
/// laid flat, the pointer box outlined in the provider's colour.
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
            context.fill(Path(frame), with: .color(self.runicTheme.surfaceAlt))
            context.stroke(
                Path(frame.insetBy(dx: 0.5, dy: 0.5)),
                with: .color(self.runicTheme.cardStroke),
                lineWidth: 1)
            let scaleY = size.height - 8
            for step in stride(from: 0, through: 100, by: 10) {
                let x = self.x(Double(step), in: size)
                let tone = self.tone(forScale: Double(step))
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: scaleY))
                tick.addLine(to: CGPoint(x: x, y: scaleY + (step % 50 == 0 ? 7 : 4)))
                context.stroke(tick, with: .color(tone), lineWidth: 1)
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
                context.fill(Path(CGRect(x: x0, y: 1, width: x1 - x0, height: 3)), with: .color(color))
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
            context.fill(Path(track), with: .color(self.tint.opacity(0.14)))
            let boxW: CGFloat = 30
            let boxH: CGFloat = 16
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
            context.stroke(box, with: .color(self.tint), lineWidth: 1.5)
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
        return self.leading + span * CGFloat(min(100, max(0, percent)) / 100)
    }

    private func tone(forScale value: Double) -> Color {
        let spent = self.showsUsed ? value : 100 - value
        if spent >= 90 { return self.runicTheme.warm }
        if spent >= 80 { return self.runicTheme.highlight }
        return self.runicTheme.secondaryText
    }
}

// MARK: - Attitude indicator

/// The attitude ball: sky over ground behind a pitch ladder, the fixed
/// aircraft symbol, and the PACE box. Level means on pace; behind pushes
/// the horizon up (nose down) by the shortfall, ahead pulls it down.
struct FlightDeckAttitude: View {
    /// Negative when behind, positive when ahead, 0 on pace, nil unknown.
    let paceDelta: Double?
    var size: CGFloat = 170
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let radius = self.size / 2 - 2
        let center = CGPoint(x: self.size / 2, y: self.size / 2)
        let shift = min(35, max(-35, self.paceDelta ?? 0)) / 100
        let horizonY = center.y + CGFloat(shift) * radius
        ZStack {
            Canvas { context, _ in
                var ball = context
                ball.clip(to: Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2)))
                ball.fill(
                    Path(CGRect(x: 0, y: -self.size, width: self.size, height: horizonY + self.size)),
                    with: .color(self.runicTheme.secondary))
                ball.fill(
                    Path(CGRect(x: 0, y: horizonY, width: self.size, height: self.size * 2)),
                    with: .color(RunicFlightDeck.ground))
                var horizon = Path()
                horizon.move(to: CGPoint(x: 0, y: horizonY))
                horizon.addLine(to: CGPoint(x: self.size, y: horizonY))
                ball.stroke(horizon, with: .color(self.runicTheme.primaryText), lineWidth: 2)
                self.drawLadder(&ball, center: center, radius: radius, horizonY: horizonY)
            }
            .skinFace()

            Circle()
                .stroke(self.runicTheme.cardStroke, lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)

            Canvas { context, _ in
                let yellow = RunicFlightDeck.aircraftYellow
                let style = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                let wing = radius * 0.62
                let elbow = radius * 0.28
                let drop = radius * 0.09
                var left = Path()
                left.move(to: CGPoint(x: center.x - wing, y: center.y))
                left.addLine(to: CGPoint(x: center.x - elbow, y: center.y))
                left.addLine(to: CGPoint(x: center.x - elbow + drop, y: center.y + drop))
                left.addLine(to: CGPoint(x: center.x - elbow + drop * 2, y: center.y))
                context.stroke(left, with: .color(yellow), style: style)
                var right = Path()
                right.move(to: CGPoint(x: center.x + wing, y: center.y))
                right.addLine(to: CGPoint(x: center.x + elbow, y: center.y))
                right.addLine(to: CGPoint(x: center.x + elbow - drop, y: center.y + drop))
                right.addLine(to: CGPoint(x: center.x + elbow - drop * 2, y: center.y))
                context.stroke(right, with: .color(yellow), style: style)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
                    with: .color(yellow))
            }

            self.paceBox
                .offset(y: radius * 0.64)
        }
        .frame(width: self.size, height: self.size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityText)
    }

    private func drawLadder(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat, horizonY: CGFloat) {
        let step = radius * 0.27
        let ink = self.runicTheme.primaryText
        let rungs: [(Int, CGFloat, Bool)] = [
            (10, radius * 0.28, true), (20, radius * 0.19, true),
            (10, radius * 0.28, false), (20, radius * 0.19, false), (30, radius * 0.14, false),
        ]
        for (degrees, half, above) in rungs {
            let y = above ? horizonY - step * CGFloat(degrees / 10) : horizonY + step * CGFloat(degrees / 10)
            var rung = Path()
            rung.move(to: CGPoint(x: center.x - half, y: y))
            rung.addLine(to: CGPoint(x: center.x + half, y: y))
            context.stroke(
                rung,
                with: .color(ink),
                style: StrokeStyle(lineWidth: 1.5, dash: above ? [] : [6, 4]))
            context.draw(
                Text("\(degrees)").font(RunicFlightDeck.mono(8)).fontDesign(nil).foregroundStyle(ink),
                at: CGPoint(x: center.x + half + 4, y: y),
                anchor: .leading)
        }
    }

    @ViewBuilder private var paceBox: some View {
        let (text, color): (String, Color) = {
            guard let delta = self.paceDelta else { return ("PACE ----", RunicFlightDeck.dim) }
            let rounded = Int(abs(delta).rounded())
            if rounded == 0 { return ("PACE OK", self.runicTheme.accent) }
            let sign = delta < 0 ? "\u{2212}" : "+"
            return ("PACE \(sign)\(rounded)%", delta < 0 ? self.runicTheme.highlight : self.runicTheme.tertiary)
        }()
        Text(text)
            .font(RunicFlightDeck.mono(10))
            .skinFace()
            .foregroundStyle(color)
            .lineLimit(1)
            .frame(width: 74, height: 18)
            .background(Rectangle().fill(self.runicTheme.surface))
            .overlay(Rectangle().stroke(color, lineWidth: 1))
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

// MARK: - FMA cells, table rows

/// One flight mode annunciator cell: a tiny label over a mono value.
struct FlightDeckCell: View {
    let label: String
    let value: String?
    var color: Color?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 2) {
            FlightDeckLabel(text: self.label, size: 8, tracking: 0.6)
            Text(self.value?.uppercased() ?? "----")
                .font(RunicFlightDeck.mono(12, .bold))
                .skinFace()
                .foregroundStyle(self.value == nil ? RunicFlightDeck.dim : (self.color ?? self.runicTheme.accent))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .overlay(Rectangle().stroke(self.runicTheme.cardStroke, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.label): \(self.value ?? "unknown")")
    }
}

/// A row of the mono table: key left in the secondary tone, value right.
struct FlightDeckRow: View {
    let key: String
    let value: String
    var valueColor: Color?
    var detail: String?
    var isLast = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(self.key.uppercased())
                    .font(RunicFlightDeck.mono(9))
                    .skinFace()
                    .tracking(0.6)
                    .foregroundStyle(self.runicTheme.secondaryText)
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
/// outline cyan.
struct FlightDeckButton: View {
    let title: String
    var primary = false
    var systemImage: String?
    var minWidth: CGFloat?
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let cyan = self.runicTheme.accent
        let ink = self.runicTheme.primaryText
        Button(action: self.action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(self.title.uppercased())
                    .font(RunicFlightDeck.mono(10.5, self.primary ? .bold : .regular))
                    .skinFace()
                    .tracking(RunicFlightDeck.tagTracking)
                    .lineLimit(1)
            }
            .foregroundStyle(self.primary ? self.runicTheme.surface : (self.isHovered ? cyan : ink))
            .padding(.horizontal, 12)
            .frame(minWidth: self.minWidth, minHeight: 30)
            .background(Rectangle().fill(self.primary ? (self.isHovered ? cyan.opacity(0.85) : cyan) : Color.clear))
            .overlay(Rectangle().stroke(
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
