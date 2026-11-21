import AppKit
import RunicCore
import SwiftUI

// MARK: - Meridian Typography & Dial Helpers

/// Horological chronometer primitives for Meridian (Porcelain Enamel in daylight,
/// Grand Feu Midnight in dark mode): serif numerals in Fraunces, chamfered
/// Manrope small-caps labels, Geist Mono tabular timers, a 200° power-reserve
/// arc dial with a Dauphine hand and ruby pivot jewel, and calibrated railway
/// track gauges.
enum RunicMeridian {
    // MARK: Geometry (20 outer − 12 inset)

    static let popoverRadius: CGFloat = 20
    static let panelInset: CGFloat = 12
    static let plateRadius: CGFloat = 12
    static let jewelPillRadius: CGFloat = 6

    // MARK: Bundled Font Families (OFL static faces)

    static func display(_ size: CGFloat = 28, weight: DisplayWeight = .semibold) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    static func body(_ size: CGFloat = 12, _ weight: BodyWeight = .regular) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    static func label(_ size: CGFloat = 9.5) -> Font {
        .custom(BodyWeight.semibold.postScriptName, fixedSize: size)
    }

    static func mono(_ size: CGFloat = 11.5, _ weight: MonoWeight = .medium) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    enum DisplayWeight {
        case regular
        case semibold
        case bold

        var postScriptName: String {
            switch self {
            case .regular: "Fraunces9pt-Regular"
            case .semibold: "Fraunces9pt-SemiBold"
            case .bold: "Fraunces9pt-Bold"
            }
        }
    }

    enum BodyWeight {
        case regular
        case medium
        case semibold
        case bold

        var postScriptName: String {
            switch self {
            case .regular: "Manrope-Regular"
            case .medium: "Manrope-Medium"
            case .semibold: "Manrope-SemiBold"
            case .bold: "Manrope-Bold"
            }
        }
    }

    enum MonoWeight {
        case regular
        case medium
        case semibold
        case bold

        var postScriptName: String {
            switch self {
            case .regular: "GeistMono-Regular"
            case .medium: "GeistMono-Medium"
            case .semibold: "GeistMono-SemiBold"
            case .bold: "GeistMono-Bold"
            }
        }
    }

    // MARK: Metric & Copy Helpers

    static func headline(forUsed percent: Double?) -> String {
        guard let percent else { return "Uncalibrated" }
        if percent >= 95 { return "Reserve depleted" }
        if percent >= 75 { return "Running close" }
        if percent >= 40 { return "Steady beat" }
        return "Full reserve"
    }

    static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let range = line.range(of: ": "),
              line.distance(from: line.startIndex, to: range.lowerBound) <= 28
        else { return nil }
        return (String(line[..<range.lowerBound]), String(line[range.upperBound...]))
    }

    static func usedShare(_ metric: UsageMenuCardView.Model.Metric) -> Double? {
        guard let percent = metric.percent else { return nil }
        switch metric.percentStyle {
        case .used: return percent
        case .left: return 100 - percent
        }
    }

    static func isExhausted(_ metric: UsageMenuCardView.Model.Metric) -> Bool {
        guard let used = usedShare(metric) else { return false }
        return used >= 99.5
    }

    static func paceMarker(for metric: UsageMenuCardView.Model.Metric) -> Double? {
        guard let percent = metric.percent, let detail = metric.detailText else { return nil }
        guard let open = detail.range(of: "("),
              let close = detail.range(of: "%)"),
              open.upperBound < close.lowerBound
        else { return nil }
        let raw = detail[open.upperBound..<close.lowerBound].replacingOccurrences(of: "+", with: "")
        let delta = Double(raw) ?? 0
        guard delta != 0 else { return nil }
        let target = switch metric.percentStyle {
        case .used: percent - delta
        case .left: percent + delta
        }
        return min(100, max(0, target))
    }

    static func dialTint(used: Double, theme: RunicThemePalette) -> Color {
        if used >= 99.5 { return theme.warm }
        if used >= 80 { return theme.highlight }
        return theme.accent
    }
}

// MARK: - Dial Plate & Casework

struct MeridianDialPlateBackground: View {
    var radius: CGFloat = RunicMeridian.plateRadius
    var tint: Color?
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: self.radius, style: .continuous)
        let dark = self.colorScheme == .dark
        ZStack {
            shape
                .fill(self.runicTheme.cardFill)
                .shadow(color: Color.black.opacity(dark ? 0.30 : 0.06), radius: 7, x: 0, y: 3)
            if let tint {
                shape.fill(tint.opacity(dark ? 0.09 : 0.06))
            }
            shape.strokeBorder(self.runicTheme.cardStroke, lineWidth: 0.75)
            shape
                .inset(by: 2)
                .strokeBorder(self.runicTheme.primaryText.opacity(dark ? 0.06 : 0.05), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}

struct MeridianDialPlate<Content: View>: View {
    var radius: CGFloat = RunicMeridian.plateRadius
    var padding: CGFloat = 12
    var tint: Color?
    @ViewBuilder let content: Content

    var body: some View {
        self.content
            .padding(self.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MeridianDialPlateBackground(radius: self.radius, tint: self.tint))
    }
}

// MARK: - Power Reserve Semicircular Arc

/// 200° chronometer power-reserve sub-dial (`170°` lower-left through `270°`
/// zenith to `370°` lower-right): 25 calibrated index batons, a ruby warning
/// sector on the depleted edge, a metallic reserve sweep, a tapered Dauphine
/// watch hand, and a faceted ruby pivot jewel at the arbor.
struct MeridianPowerReserveArc: View {
    let percent: Double
    let usedPercent: Double
    let isUsedMode: Bool
    let caption: String
    let accessibilityLabel: String
    var diameter: CGFloat = 112
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        let tone = RunicMeridian.dialTint(used: self.usedPercent, theme: self.runicTheme)
        let canvasHeight = self.diameter * 0.56

        VStack(spacing: 1) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.78)
                let outerRadius = min(size.width * 0.43, size.height * 0.68)
                let startDeg = 170.0
                let sweepDeg = 200.0
                let endDeg = startDeg + sweepDeg
                let fraction = clamped / 100.0
                let valueDeg = startDeg + sweepDeg * fraction
                let dark = self.colorScheme == .dark

                // Guilloche recessed dial ring.
                var track = Path()
                track.addArc(
                    center: center,
                    radius: outerRadius,
                    startAngle: .degrees(startDeg),
                    endAngle: .degrees(endDeg),
                    clockwise: false)
                context.stroke(
                    track,
                    with: .color(self.runicTheme.primaryText.opacity(dark ? 0.14 : 0.11)),
                    style: StrokeStyle(lineWidth: 5.5, lineCap: .round))

                // Danger reserve sector: upper 20% in used mode, lower 20% in reserve mode.
                var dangerSector = Path()
                let dangerStart = self.isUsedMode ? (startDeg + sweepDeg * 0.80) : startDeg
                let dangerEnd = self.isUsedMode ? endDeg : (startDeg + sweepDeg * 0.20)
                dangerSector.addArc(
                    center: center,
                    radius: outerRadius,
                    startAngle: .degrees(dangerStart),
                    endAngle: .degrees(dangerEnd),
                    clockwise: false)
                context.stroke(
                    dangerSector,
                    with: .color(self.runicTheme.warm.opacity(dark ? 0.42 : 0.34)),
                    style: StrokeStyle(lineWidth: 5.5, lineCap: .round))

                // Active sweep arc.
                if fraction > 0.005 {
                    var active = Path()
                    active.addArc(
                        center: center,
                        radius: outerRadius,
                        startAngle: .degrees(startDeg),
                        endAngle: .degrees(valueDeg),
                        clockwise: false)
                    context.stroke(
                        active,
                        with: .color(tone),
                        style: StrokeStyle(lineWidth: 4.0, lineCap: .round))
                }

                // 25 radial chapter-ring tick indices (major batons every 5th tick).
                let tickCount = 24
                for idx in 0...tickCount {
                    let isMajor = idx.isMultiple(of: 6)
                    let deg = startDeg + sweepDeg * Double(idx) / Double(tickCount)
                    let rad = deg * .pi / 180.0
                    let rIn = outerRadius - (isMajor ? 10.5 : 7.5)
                    let rOut = outerRadius - 4.5
                    var tick = Path()
                    tick.move(to: CGPoint(
                        x: center.x + cos(rad) * rIn,
                        y: center.y + sin(rad) * rIn))
                    tick.addLine(to: CGPoint(
                        x: center.x + cos(rad) * rOut,
                        y: center.y + sin(rad) * rOut))
                    let tickColor = self.runicTheme.primaryText.opacity(isMajor ? 0.62 : 0.26)
                    context.stroke(tick, with: .color(tickColor), lineWidth: isMajor ? 1.2 : 0.7)
                }

                // Tapered Dauphine watch hand pointing from arbor toward the active angle.
                let handRad = valueDeg * .pi / 180.0
                let perpRad = handRad + .pi / 2.0
                let tipRadius = outerRadius - 3.0
                let tailRadius: CGFloat = 6.0
                let halfBase: CGFloat = 2.4
                let tip = CGPoint(
                    x: center.x + cos(handRad) * tipRadius,
                    y: center.y + sin(handRad) * tipRadius)
                let tail = CGPoint(
                    x: center.x - cos(handRad) * tailRadius,
                    y: center.y - sin(handRad) * tailRadius)
                let shoulder = CGPoint(
                    x: center.x + cos(handRad) * 6.0,
                    y: center.y + sin(handRad) * 6.0)
                let leftWing = CGPoint(
                    x: shoulder.x + cos(perpRad) * halfBase,
                    y: shoulder.y + sin(perpRad) * halfBase)
                let rightWing = CGPoint(
                    x: shoulder.x - cos(perpRad) * halfBase,
                    y: shoulder.y - sin(perpRad) * halfBase)
                var hand = Path()
                hand.move(to: tip)
                hand.addLine(to: leftWing)
                hand.addLine(to: tail)
                hand.addLine(to: rightWing)
                hand.closeSubpath()
                context.fill(hand, with: .color(self.runicTheme.primaryText))

                // Arbor bezel + faceted ruby jewel cabochon.
                let arborOuter = CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9, height: 9)
                context.fill(Path(ellipseIn: arborOuter), with: .color(self.runicTheme.accent))
                let rubyCore = CGRect(x: center.x - 2.3, y: center.y - 2.3, width: 4.6, height: 4.6)
                context.fill(Path(ellipseIn: rubyCore), with: .color(self.runicTheme.warm))
            }
            .frame(width: self.diameter, height: canvasHeight)

            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int(clamped.rounded()))")
                        .font(RunicMeridian.display(self.diameter * 0.24, weight: .semibold))
                        .skinFace()
                        .foregroundStyle(self.usedPercent >= 99.5 ? self.runicTheme.warm : self.runicTheme.primaryText)
                    Text("%")
                        .font(RunicMeridian.mono(10.5, .medium))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
                Text(self.caption.uppercased())
                    .font(RunicMeridian.label(8.5))
                    .skinFace()
                    .tracking(1.1)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(width: self.diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped.rounded())) percent")
    }
}

// MARK: - Railway Track Linear Gauge

/// Calibrated chemin-de-fer linear gauge: double hairline rails, 20 fine graduations,
/// metallic fill band, optional pace diamond needle, and crisp end index.
struct MeridianRailwayGauge: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    var marker: Double?
    var height: CGFloat = 10
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        let dark = self.colorScheme == .dark
        GeometryReader { geo in
            let width = geo.size.width
            let fill = clamped <= 0 ? 0 : max(4, width * clamped / 100)
            Canvas { context, size in
                let midY = size.height / 2
                let topY = midY - self.height / 2
                let railRect = CGRect(x: 0.5, y: topY, width: max(0, size.width - 1), height: self.height)
                let trackPath = Path(roundedRect: railRect, cornerRadius: 2.5)
                context.fill(
                    trackPath,
                    with: .color(self.runicTheme.primaryText.opacity(dark ? 0.08 : 0.06)))
                context.stroke(
                    trackPath,
                    with: .color(self.runicTheme.primaryText.opacity(dark ? 0.24 : 0.22)),
                    lineWidth: 0.7)

                // Calibrated graduations inside the railway track.
                let ticks = 20
                for step in 1..<ticks {
                    let x = size.width * CGFloat(step) / CGFloat(ticks)
                    let major = step.isMultiple(of: 5)
                    let tickTop = major ? topY + 1 : midY - 1.5
                    let tickBottom = major ? topY + self.height - 1 : midY + 1.5
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: tickTop))
                    tick.addLine(to: CGPoint(x: x, y: tickBottom))
                    context.stroke(
                        tick,
                        with: .color(self.runicTheme.primaryText.opacity(major ? 0.28 : 0.14)),
                        lineWidth: 0.6)
                }

                // Active metallic reserve band.
                if fill > 0 {
                    let bandRect = CGRect(
                        x: 1,
                        y: topY + 1.5,
                        width: min(max(0, size.width - 2), fill),
                        height: max(2, self.height - 3))
                    context.fill(Path(roundedRect: bandRect, cornerRadius: 1.5), with: .color(self.tint))

                    // Specular pointer cap at the leading edge.
                    let capX = min(max(1.5, bandRect.maxX - 1.5), max(1.5, size.width - 2.5))
                    var cap = Path()
                    cap.move(to: CGPoint(x: capX, y: topY - 1))
                    cap.addLine(to: CGPoint(x: capX, y: topY + self.height + 1))
                    context.stroke(cap, with: .color(self.runicTheme.primaryText), lineWidth: 1.4)
                }

                // Optional pace diamond marker.
                if let marker = self.marker {
                    let mx = size.width * min(100, max(0, marker)) / 100
                    let r: CGFloat = 3.0
                    var diamond = Path()
                    diamond.move(to: CGPoint(x: mx, y: topY - 2))
                    diamond.addLine(to: CGPoint(x: mx + r, y: midY))
                    diamond.addLine(to: CGPoint(x: mx, y: topY + self.height + 2))
                    diamond.addLine(to: CGPoint(x: mx - r, y: midY))
                    diamond.closeSubpath()
                    context.fill(diamond, with: .color(self.runicTheme.secondary))
                    context.stroke(diamond, with: .color(self.runicTheme.surface), lineWidth: 0.7)
                }
            }
        }
        .frame(height: max(self.height + 4, 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped.rounded())) percent")
    }
}

// MARK: - Type, Pills, Rules & Buttons

struct MeridianLabel: View {
    let text: String
    var color: Color?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicMeridian.label())
            .skinFace()
            .tracking(1.0)
            .foregroundStyle(self.color ?? self.runicTheme.secondaryText)
            .lineLimit(1)
    }
}

struct MeridianSectionTitle: View {
    let title: String
    var systemImage: String?
    var trailing: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(self.runicTheme.accent)
                    .accessibilityHidden(true)
            }
            MeridianLabel(text: self.title)
            Spacer(minLength: 6)
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(RunicMeridian.mono(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Hairline divider centered with an engraved diamond lozenge (`◆`).
struct MeridianCasebackRule: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(self.runicTheme.cardStroke)
                .frame(height: 0.6)
            Rectangle()
                .fill(self.runicTheme.accent.opacity(0.65))
                .frame(width: 4, height: 4)
                .rotationEffect(.degrees(45))
            Rectangle()
                .fill(self.runicTheme.cardStroke)
                .frame(height: 0.6)
        }
        .accessibilityHidden(true)
    }
}

/// Chamfered horological plaque with optional jewel pip (plan tiers, banked resets, status).
struct MeridianJewelPill: View {
    enum Tone { case neutral, accent, good, caution, critical }

    let text: String
    var jewel = false
    var tone: Tone = .neutral
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RunicMeridian.jewelPillRadius, style: .continuous)
        HStack(spacing: 4) {
            if self.jewel {
                Circle()
                    .fill(self.foreground)
                    .frame(width: 4.5, height: 4.5)
                    .accessibilityHidden(true)
            }
            Text(self.text)
                .font(RunicMeridian.mono(9.5, .semibold))
                .skinFace()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(self.foreground)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(shape.fill(self.fill))
        .overlay(shape.strokeBorder(self.stroke, lineWidth: 0.6))
    }

    private var tint: Color? {
        switch self.tone {
        case .neutral: nil
        case .accent: self.runicTheme.accent
        case .good: self.runicTheme.tertiary
        case .caution: self.runicTheme.highlight
        case .critical: self.runicTheme.warm
        }
    }

    private var foreground: Color {
        self.tint ?? self.runicTheme.secondaryText
    }

    private var fill: Color {
        self.tint.map { $0.opacity(0.12) } ?? self.runicTheme.primaryText.opacity(0.05)
    }

    private var stroke: Color {
        self.tint.map { $0.opacity(0.38) } ?? self.runicTheme.cardStroke
    }
}

/// Circular watch-bezel medallion holding the brand emblem.
struct MeridianBrandMedallion: View {
    let image: NSImage?
    let name: String
    let tint: Color
    var size: CGFloat = 30
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        ZStack {
            Circle()
                .fill(self.runicTheme.surfaceAlt)
            Circle()
                .fill(self.tint.opacity(0.11))
            Circle()
                .strokeBorder(self.runicTheme.cardStroke, lineWidth: 0.75)
            Circle()
                .inset(by: 2)
                .strokeBorder(self.tint.opacity(0.32), lineWidth: 0.5)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: self.size * 0.54, height: self.size * 0.54)
            } else {
                Text(self.initial)
                    .font(RunicMeridian.display(self.size * 0.42, weight: .semibold))
                    .skinFace()
                    .foregroundStyle(self.tint)
            }
        }
        .frame(width: self.size, height: self.size)
        .accessibilityHidden(true)
    }

    private var initial: String {
        self.name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }
}

struct MeridianButton: View {
    let title: String
    var systemImage: String?
    var prominent = false
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RunicMeridian.jewelPillRadius, style: .continuous)
        Button(action: self.action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(self.title)
                    .font(RunicMeridian.body(11.5, .semibold))
                    .skinFace()
                    .lineLimit(1)
            }
            .foregroundStyle(self.prominent ? self.runicTheme.surface : self.runicTheme.accent)
            .padding(.horizontal, 11)
            .frame(height: 26)
            .background {
                if self.prominent {
                    shape.fill(self.runicTheme.accent.opacity(self.isHovered ? 0.88 : 1))
                } else {
                    shape.fill(self.runicTheme.accent.opacity(self.isHovered ? 0.16 : 0.08))
                }
            }
            .overlay(shape.strokeBorder(self.runicTheme.accent.opacity(0.38), lineWidth: 0.7))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

struct MeridianCopyButton: View {
    let copyText: String
    var label = "Copy error"
    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(self.copyText, forType: .string)
            withAnimation(self.runicTheme.motion.curve) { self.didCopy = true }
            self.resetTask?.cancel()
            self.resetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.9))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { self.didCopy = false }
            }
        } label: {
            Image(systemName: self.didCopy ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(self.runicTheme.secondaryText)
                .frame(width: 22, height: 22)
                .background(Circle().fill(self.runicTheme.primaryText.opacity(0.06)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(self.label)
        .accessibilityLabel(self.didCopy ? "Copied" : self.label)
    }
}

/// Key-value horology specification row inside a dial plate.
struct MeridianSpecRow: View {
    let label: String
    let value: String
    var detail: String?
    var valueColor: Color?
    var numeric = false
    var copyText: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(self.label)
                    .font(RunicMeridian.body(11.5, .medium))
                    .skinFace()
                    .foregroundStyle(self.value.isEmpty ? self.runicTheme.secondaryText : self.runicTheme.primaryText)
                    .lineLimit(self.value.isEmpty ? 3 : 1)
                    .fixedSize(horizontal: false, vertical: self.value.isEmpty)
                    .layoutPriority(self.value.isEmpty ? 2 : 1)
                if !self.value.isEmpty {
                    Spacer(minLength: 8)
                    Text(self.value)
                        .font(self.numeric ? RunicMeridian.mono(12.5, .semibold) : RunicMeridian.body(11.5, .medium))
                        .skinFace()
                        .foregroundStyle(self.valueColor ?? self.runicTheme.primaryText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(RunicMeridian.body(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay {
                        if let copyText = self.copyText {
                            ClickToCopyOverlay(copyText: copyText)
                        }
                    }
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MeridianHairline: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Rectangle()
            .fill(self.runicTheme.cardStroke.opacity(0.65))
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}
