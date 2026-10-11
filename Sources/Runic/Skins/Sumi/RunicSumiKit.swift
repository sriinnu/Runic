import AppKit
import RunicCore
import SwiftUI

// MARK: - Ink kit

/// Sumi's kit: ink on washi. Two faces addressed by PostScript name —
/// Shippori Mincho for names and numerals, Zen Kaku Gothic for labels and
/// copy — plus the marks the page is composed from: the hanko seal, the
/// brush-stroke gauge, the dry-brush rule, the vertical side label.
enum RunicSumi {
    enum MinchoWeight { case regular, semibold, bold, extraBold }
    enum GothicWeight { case regular, medium, bold }

    /// Shippori Mincho, static instances subset to Latin.
    static func mincho(_ size: CGFloat, _ weight: MinchoWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "ShipporiMincho-Regular"
        case .semibold: "ShipporiMincho-SemiBold"
        case .bold: "ShipporiMincho-Bold"
        case .extraBold: "ShipporiMincho-ExtraBold"
        }
        return Font.custom(name, fixedSize: size)
    }

    /// Zen Kaku Gothic New, static instances subset to Latin.
    static func gothic(_ size: CGFloat, _ weight: GothicWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "ZenKakuGothicNew-Regular"
        case .medium: "ZenKakuGothicNew-Medium"
        case .bold: "ZenKakuGothicNew-Bold"
        }
        return Font.custom(name, fixedSize: size)
    }

    // MARK: Roles

    /// Tracked caps run wide on washi.
    static let labelTracking: CGFloat = 3

    static func label(_ size: CGFloat = 10) -> Font {
        self.gothic(size, .medium)
    }

    static func copy(_ size: CGFloat = 12) -> Font {
        self.gothic(size, .regular)
    }

    static func strong(_ size: CGFloat = 12.5) -> Font {
        self.gothic(size, .bold)
    }

    static func headline(_ size: CGFloat) -> Font {
        self.mincho(size, .semibold)
    }

    static func numeral(_ size: CGFloat) -> Font {
        self.mincho(size, .regular)
    }

    static func name(_ size: CGFloat = 40) -> Font {
        self.mincho(size, .semibold)
    }

    /// The seal's glyph for a provider: its initial.
    static func initial(for name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "\u{5370}"
    }

    /// "Running hot" for 81 % — the front page's one-line read of the day.
    static func headline(forAverage percent: Double?) -> String {
        guard let percent else { return "No quota yet" }
        if percent >= 95 { return "Spent" }
        if percent >= 75 { return "Running hot" }
        if percent >= 40 { return "Steady" }
        return "Plenty left"
    }

    /// Splits "Context health: max ctx ~272K" into a label and its value.
    static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let range = line.range(of: ": "),
              line.distance(from: line.startIndex, to: range.lowerBound) <= 28
        else { return nil }
        return (String(line[..<range.lowerBound]), String(line[range.upperBound...]))
    }
}

// MARK: - Labels

/// Tracked uppercase caption in Zen Kaku Medium: section labels, bylines.
struct SumiLabel: View {
    let text: String
    var size: CGFloat = 10
    var color: Color?
    var tracking: CGFloat = RunicSumi.labelTracking
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicSumi.label(self.size))
            .skinFace()
            .tracking(self.tracking)
            .foregroundStyle(self.color ?? self.runicTheme.secondaryText)
            .lineLimit(1)
    }
}

/// A side label set vertically, the way a hanging scroll is titled, with a
/// hairline on its leading edge.
struct SumiVerticalLabel: View {
    let text: String
    var length: CGFloat = 112
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Rectangle()
                .fill(self.runicTheme.primaryText.opacity(0.3))
                .frame(width: 1, height: self.length)
            Text(self.text.uppercased())
                .font(RunicSumi.label(9.5))
                .skinFace()
                .tracking(RunicSumi.labelTracking)
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: self.length, height: 12, alignment: .leading)
                .rotationEffect(.degrees(90), anchor: .topLeading)
                .frame(width: 12, height: self.length, alignment: .topLeading)
                .offset(x: 12)
        }
        .frame(width: 18, height: self.length, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

// MARK: - Seal

/// A hanko: a coloured square with the paper knocked out as an inner ring
/// and a Mincho glyph, pressed slightly off-square.
struct SumiSeal: View {
    let text: String
    var color: Color?
    var size: CGFloat = 30
    var rotation: Double = -3
    /// A brand mark cut into the seal instead of the glyph, when there is one.
    var image: NSImage?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.color ?? self.runicTheme.accent
        let paper = self.runicTheme.surface
        Group {
            if let image {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: self.size * 0.52, height: self.size * 0.52)
            } else {
                Text(self.text)
                    .font(RunicSumi.mincho(self.size * 0.5, .extraBold))
                    .skinFace()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .foregroundStyle(paper)
        .frame(width: self.size, height: self.size)
        .background(RoundedRectangle(cornerRadius: self.size * 0.1, style: .continuous).fill(ink))
        .overlay {
            RoundedRectangle(cornerRadius: self.size * 0.07, style: .continuous)
                .strokeBorder(paper.opacity(0.55), lineWidth: max(1, self.size * 0.05))
                .padding(max(1.5, self.size * 0.08))
        }
        .rotationEffect(.degrees(self.rotation))
        .accessibilityHidden(true)
    }
}

// MARK: - Rules and gauges

/// A dry-brush rule: one wavering stroke that breaks where the brush ran
/// out of ink. Seeded by width so it never flickers.
struct SumiRule: View {
    var opacity: Double = 0.9
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Canvas { context, size in
            guard size.width > 8 else { return }
            var rng = RunicSeededRandom(seed: UInt64(size.width * 3 + 7))
            let midY = size.height / 2
            var path = Path()
            path.move(to: CGPoint(x: 1, y: midY + 1))
            let segments = 4
            for i in 1...segments {
                let x = size.width * CGFloat(i) / CGFloat(segments)
                let y = midY + CGFloat(rng.nextUnit() - 0.5) * 3
                let c1 = CGPoint(
                    x: x - size.width / CGFloat(segments) * 0.6,
                    y: midY + CGFloat(rng.nextUnit() - 0.5) * 4)
                let c2 = CGPoint(
                    x: x - size.width / CGFloat(segments) * 0.3,
                    y: midY + CGFloat(rng.nextUnit() - 0.5) * 4)
                path.addCurve(to: CGPoint(x: x, y: y), control1: c1, control2: c2)
            }
            let dash: [CGFloat] = [size.width * 0.3, 2, size.width * 0.12, 3, size.width * 0.35, 1, size.width * 0.2]
            context.stroke(
                path,
                with: .color(self.runicTheme.primaryText.opacity(self.opacity)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: dash))
        }
        .frame(height: 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The gauge: a brush stroke laid over a dry dotted line. The stroke is the
/// used share; the line is the whole window.
struct SumiBrushBar: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    var height: CGFloat = 14
    /// Where a plan line should sit, as a percent, or nil.
    var marker: Double?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        Canvas { context, size in
            let midY = size.height / 2
            var track = Path()
            track.move(to: CGPoint(x: 0, y: midY))
            track.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(
                track,
                with: .color(self.runicTheme.primaryText.opacity(0.32)),
                style: StrokeStyle(lineWidth: 1, dash: [3, 2, 7, 1, 2, 3]))

            let width = size.width * clamped / 100
            if width > 2 {
                let h = size.height
                let w = max(width, 10)
                var stroke = Path()
                // Lands thick, runs level, lifts with a hooked tail.
                stroke.move(to: CGPoint(x: 0, y: midY))
                stroke.addCurve(
                    to: CGPoint(x: min(w, 24) * 0.5, y: h * 0.14),
                    control1: CGPoint(x: 3, y: h * 0.08),
                    control2: CGPoint(x: 7, y: h * 0.04))
                stroke.addLine(to: CGPoint(x: w - min(w, 30) * 0.5, y: h * 0.18))
                stroke.addCurve(
                    to: CGPoint(x: w, y: midY),
                    control1: CGPoint(x: w - 8, y: h * 0.1),
                    control2: CGPoint(x: w - 2, y: h * 0.28))
                stroke.addCurve(
                    to: CGPoint(x: w - min(w, 30) * 0.45, y: h * 0.82),
                    control1: CGPoint(x: w - 2, y: h * 0.72),
                    control2: CGPoint(x: w - 7, y: h * 0.9))
                stroke.addLine(to: CGPoint(x: min(w, 24) * 0.55, y: h * 0.86))
                stroke.addCurve(
                    to: CGPoint(x: 0, y: midY),
                    control1: CGPoint(x: 7, y: h * 0.96),
                    control2: CGPoint(x: 2, y: h * 0.9))
                stroke.closeSubpath()
                context.fill(stroke, with: .color(self.tint))

                // Two paper streaks where the bristles parted.
                var streak = Path()
                streak.move(to: CGPoint(x: w * 0.05, y: h * 0.42))
                streak.addCurve(
                    to: CGPoint(x: w * 0.95, y: h * 0.4),
                    control1: CGPoint(x: w * 0.3, y: h * 0.36),
                    control2: CGPoint(x: w * 0.7, y: h * 0.44))
                context.stroke(streak, with: .color(self.runicTheme.surface.opacity(0.25)), lineWidth: 1.2)
                var streak2 = Path()
                streak2.move(to: CGPoint(x: w * 0.08, y: h * 0.64))
                streak2.addCurve(
                    to: CGPoint(x: w * 0.92, y: h * 0.62),
                    control1: CGPoint(x: w * 0.4, y: h * 0.7),
                    control2: CGPoint(x: w * 0.6, y: h * 0.6))
                context.stroke(streak2, with: .color(self.runicTheme.surface.opacity(0.18)), lineWidth: 1)
            }

            if let marker = self.marker {
                let x = size.width * min(100, max(0, marker)) / 100
                var line = Path()
                line.move(to: CGPoint(x: x, y: -2))
                line.addLine(to: CGPoint(x: x, y: size.height + 2))
                context.stroke(line, with: .color(self.runicTheme.accent), lineWidth: 1)
            }
        }
        .frame(height: self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped)) percent")
    }
}

/// An ensō: a brush circle drawn in one breath, open where the brush left
/// the paper. The ring fills with the share used.
struct SumiEnso: View {
    let percent: Double?
    var size: CGFloat = 132
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        let fraction = (self.percent ?? 0) / 100
        ZStack {
            Circle()
                .stroke(ink.opacity(0.12), style: StrokeStyle(lineWidth: 2, dash: [2, 4]))
            Circle()
                .trim(from: 0, to: min(0.97, max(0.02, fraction * 0.97)))
                .stroke(ink, style: StrokeStyle(lineWidth: self.size * 0.07, lineCap: .round))
                .rotationEffect(.degrees(-100))
            Circle()
                .trim(from: 0.52, to: min(0.97, max(0.52, fraction * 0.97)))
                .stroke(ink.opacity(0.5), style: StrokeStyle(lineWidth: self.size * 0.04, lineCap: .round))
                .rotationEffect(.degrees(-100))
            Circle()
                .trim(from: 0.05, to: min(0.95, max(0.05, fraction * 0.9)))
                .stroke(self.runicTheme.surface.opacity(0.45), style: StrokeStyle(lineWidth: 1))
                .rotationEffect(.degrees(-100))
                .padding(self.size * 0.035)
        }
        .padding(self.size * 0.06)
        .frame(width: self.size, height: self.size)
        .accessibilityHidden(true)
    }
}

// MARK: - Rows and controls

/// Label on the left, value on the right, a faint ink hairline beneath.
struct SumiKeyValue: View {
    let label: String
    let value: String
    var strong = false
    var valueFont: Font?
    var valueColor: Color?
    /// A second line under the pair, in the secondary tone.
    var detail: String?
    var isLast = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(self.label)
                    .font(RunicSumi.copy(13))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text(self.value)
                    .font(self.valueFont ?? (self.strong ? RunicSumi.strong() : RunicSumi.copy(12.5)))
                    .skinFace()
                    .foregroundStyle(self
                        .valueColor ?? (self.strong ? self.runicTheme.primaryText : self.runicTheme.secondaryText))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.bottom, self.detail == nil ? 8 : 3)
            if let detail = self.detail, !detail.isEmpty {
                Text(detail)
                    .font(RunicSumi.copy(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)
            }
            if !self.isLast {
                Rectangle()
                    .fill(self.runicTheme.primaryText.opacity(0.1))
                    .frame(height: 1)
            }
        }
    }
}

/// Ink-outlined button; `filled` sets it as an ink block. Hover turns the
/// outline vermilion.
struct SumiButton: View {
    let title: String
    var filled = false
    var systemImage: String?
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        let paper = self.runicTheme.surface
        let seal = self.runicTheme.accent
        Button(action: self.action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(self.title)
                    .font(RunicSumi.strong(12))
                    .skinFace()
                    .tracking(0.8)
                    .lineLimit(1)
            }
            .foregroundStyle(self.filled ? paper : (self.isHovered ? seal : ink))
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(self.filled ? (self.isHovered ? seal : ink) : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(self.filled ? Color.clear : (self.isHovered ? seal : ink), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}
