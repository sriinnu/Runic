import AppKit
import RunicCore
import SwiftUI

// MARK: - Optical kit

/// Liquid Glass MK II's kit: concentric geometry, native SF Pro roles, and
/// the optical marks the pages are built from — the 3-pass Fresnel rim, the
/// glass card, the matte recessed data well and the borosilicate capillary
/// bar. Numbers never sit on blur: every readout lives in a matte well.
enum RunicLiquidGlass {
    // MARK: Geometry (26 outer − 12 inset = 14 inner)

    static let popoverRadius: CGFloat = 26
    static let panelInset: CGFloat = 12
    static let cardRadius: CGFloat = 14
    static let tileRadius: CGFloat = 6
    static let capillaryHeight: CGFloat = 10

    // MARK: Type (native SF Pro)

    /// 30pt semibold tabular hero percent.
    static func hero(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .semibold).monospacedDigit()
    }

    /// 15pt section / provider header.
    static func header(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// 10.5pt metadata label.
    static func label(_ size: CGFloat = 10.5) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func body(_ size: CGFloat = 12, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func numeric(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    // MARK: Optical tones

    /// The matte well under every readout: ink at 4.5 % on daylight, white at
    /// 5.5 % at night — never blurred, so digits stay crisp.
    static func wellFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.055)
            : Color(red: 11 / 255, green: 17 / 255, blue: 26 / 255).opacity(0.045)
    }

    /// The capillary's empty tube: a touch deeper than a well.
    static func tubeFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.085)
            : Color(red: 11 / 255, green: 17 / 255, blue: 26 / 255).opacity(0.075)
    }

    /// Prism caustic pair for the innermost rim pass (#A8E0FF / #FFE0C2).
    static let causticCool = Color(red: 168 / 255, green: 224 / 255, blue: 1)
    static let causticWarm = Color(red: 1, green: 224 / 255, blue: 194 / 255)

    /// Offscreen screenshot renders cache the hosting view, where a
    /// behind-window material samples nothing; the stage paints an opaque
    /// optical gradient instead so every capture stays readable.
    static let isOffscreenRender: Bool =
        ProcessInfo.processInfo.environment["RUNIC_SCREENSHOT_RENDER"] != nil

    // MARK: Copy helpers

    /// "Running hot" for 81 % — the front page's one-line read of the day.
    static func headline(forUsed percent: Double?) -> String {
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

    static func isExhausted(_ metric: UsageMenuCardView.Model.Metric) -> Bool {
        guard let percent = metric.percent else { return false }
        switch metric.percentStyle {
        case .used: return percent >= 99.5
        case .left: return percent <= 0.5
        }
    }

    /// Used share of a metric whatever direction it is displayed in.
    static func usedShare(_ metric: UsageMenuCardView.Model.Metric) -> Double? {
        guard let percent = metric.percent else { return nil }
        switch metric.percentStyle {
        case .used: return percent
        case .left: return 100 - percent
        }
    }

    /// The pace needle: where the window "should" be. The detail carries a
    /// delta ("Pace: Behind (-34%)"), so the needle is the shown share pushed
    /// back by it. Nil when there is no pace.
    static func paceMarker(for metric: UsageMenuCardView.Model.Metric) -> Double? {
        guard let percent = metric.percent, let detail = metric.detailText else { return nil }
        guard let open = detail.range(of: "("), let close = detail.range(of: "%)"),
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
}

// MARK: - Fresnel rim

/// The 3-pass Fresnel perimeter every glass surface carries: a 0.5pt outer
/// dark hairline, a 1pt directional specular lit from the top-left (added
/// with `.plusLighter`), and a 0.5pt inner prism caustic. Reduce
/// Transparency swaps it for one solid high-contrast hairline.
struct LiquidGlassFresnelRim<S: InsettableShape>: View {
    let shape: S
    var intensity: Double = 1
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let dark = self.colorScheme == .dark
        Group {
            if self.reduceTransparency {
                self.shape
                    .strokeBorder(self.runicTheme.primaryText.opacity(0.32), lineWidth: 1)
            } else {
                ZStack {
                    self.shape
                        .strokeBorder(Color.black.opacity(dark ? 0.6 : 0.16), lineWidth: 0.5)
                    self.shape
                        .inset(by: 0.5)
                        .strokeBorder(self.specular(dark: dark), lineWidth: 1)
                        .blendMode(.plusLighter)
                    self.shape
                        .inset(by: 1.5)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    RunicLiquidGlass.causticCool.opacity(0.14),
                                    RunicLiquidGlass.causticWarm.opacity(0.14),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing),
                            lineWidth: 0.5)
                }
                .opacity(self.intensity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Clockwise from 3 o'clock: brightest at the top-left (225°), faint at
    /// the bottom-right (45°).
    private func specular(dark: Bool) -> AngularGradient {
        let peak = dark ? 0.46 : 0.95
        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .white.opacity(peak * 0.22), location: 0),
                .init(color: .white.opacity(peak * 0.06), location: 0.125),
                .init(color: .white.opacity(peak * 0.24), location: 0.375),
                .init(color: .white.opacity(peak), location: 0.625),
                .init(color: .white.opacity(peak * 0.4), location: 0.875),
                .init(color: .white.opacity(peak * 0.22), location: 1),
            ]),
            center: .center)
    }
}

// MARK: - Glass card and matte well

/// A floating glass card: the translucent card fill under a top sheen, a
/// soft lift and the Fresnel rim. Opaque `surfaceAlt` under Reduce
/// Transparency.
struct LiquidGlassCardBackground: View {
    var radius: CGFloat = RunicLiquidGlass.cardRadius
    var isActive = false
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: self.radius, style: .continuous)
        let dark = self.colorScheme == .dark
        ZStack {
            if self.reduceTransparency {
                shape.fill(self.runicTheme.surfaceAlt)
            } else {
                shape
                    .fill(self.runicTheme.cardFill)
                    .shadow(color: .black.opacity(dark ? 0.32 : 0.07), radius: 10, x: 0, y: 4)
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(dark ? 0.07 : 0.28), .clear],
                        startPoint: .top,
                        endPoint: .center))
            }
            if self.isActive {
                shape.fill(self.runicTheme.accent.opacity(0.10))
            }
            LiquidGlassFresnelRim(shape: shape)
        }
        .accessibilityHidden(true)
    }
}

/// The non-glass recessed well: a matte fill with an inner top shadow and a
/// lit bottom lip, so a readout looks set into the glass.
struct LiquidGlassWellBackground: View {
    var radius: CGFloat = RunicLiquidGlass.tileRadius
    var tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: self.radius, style: .continuous)
        let dark = self.colorScheme == .dark
        ZStack {
            shape.fill(RunicLiquidGlass.wellFill(self.colorScheme))
            if let tint {
                shape.fill(tint.opacity(0.08))
            }
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.black.opacity(dark ? 0.38 : 0.10),
                        Color.clear,
                        Color.white.opacity(dark ? 0.07 : 0.55),
                    ],
                    startPoint: .top,
                    endPoint: .bottom),
                lineWidth: 0.75)
        }
        .accessibilityHidden(true)
    }
}

/// Content set inside a matte well.
struct LiquidGlassWell<Content: View>: View {
    var radius: CGFloat = RunicLiquidGlass.tileRadius
    var padding: CGFloat = 10
    var tint: Color?
    @ViewBuilder let content: Content

    var body: some View {
        self.content
            .padding(self.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiquidGlassWellBackground(radius: self.radius, tint: self.tint))
    }
}

// MARK: - Capillary bar

/// The signature gauge: a recessed 10pt capsule tube, a solid optical liquid
/// fill with a 1.5pt white meniscus along its top, and a 1.5 × 14pt pace
/// needle. No glow, no blur.
struct BorosilicateCapillaryBar: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    /// Where the pace needle sits, as a percent, or nil.
    var marker: Double?
    var height: CGFloat = RunicLiquidGlass.capillaryHeight
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        let dark = self.colorScheme == .dark
        GeometryReader { geo in
            let width = geo.size.width
            let fill = clamped <= 0 ? 0 : max(self.height, width * clamped / 100)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(RunicLiquidGlass.tubeFill(self.colorScheme))
                    .frame(height: self.height)
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(dark ? 0.45 : 0.14),
                                Color.white.opacity(dark ? 0.08 : 0.6),
                            ],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 0.5)
                    .frame(height: self.height)
                if fill > 0 {
                    Capsule(style: .continuous)
                        .fill(self.tint)
                        .frame(width: fill, height: self.height)
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(dark ? 0.55 : 0.75))
                        .frame(width: max(0, fill - self.height * 0.8), height: 1.5)
                        .offset(x: self.height * 0.4, y: -(self.height / 2 - 2.25))
                        .blendMode(.plusLighter)
                }
                if let marker = self.marker {
                    let x = width * min(100, max(0, marker)) / 100
                    Capsule(style: .continuous)
                        .fill(self.runicTheme.primaryText)
                        .frame(width: 1.5, height: 14)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(self.runicTheme.surface.opacity(0.7), lineWidth: 0.5))
                        .offset(x: min(max(0, x - 0.75), max(0, width - 1.5)))
                }
            }
            .frame(width: width, height: geo.size.height)
        }
        .frame(height: max(self.height, 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped.rounded())) percent")
    }
}

// MARK: - Type marks

/// Small uppercase metadata label (10.5pt, secondary tone).
struct LiquidGlassLabel: View {
    let text: String
    var color: Color?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicLiquidGlass.label())
            .skinFace()
            .tracking(0.6)
            .foregroundStyle(self.color ?? self.runicTheme.secondaryText)
            .lineLimit(1)
    }
}

/// A section opener inside a page: label on the left, optional trailing copy.
struct LiquidGlassSectionTitle: View {
    let title: String
    var systemImage: String?
    var trailing: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .accessibilityHidden(true)
            }
            LiquidGlassLabel(text: self.title)
            Spacer(minLength: 6)
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(RunicLiquidGlass.numeric(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Pills and buttons

/// A capsule pill: email, plan, status, banked resets.
struct LiquidGlassPill: View {
    enum Tone { case neutral, accent, good, caution, critical }

    let text: String
    var systemImage: String?
    var tone: Tone = .neutral
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
                    .accessibilityHidden(true)
            }
            Text(self.text)
                .font(RunicLiquidGlass.body(10.5, .medium))
                .skinFace()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(self.foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(self.fill))
        .overlay(Capsule(style: .continuous).strokeBorder(self.stroke, lineWidth: 0.5))
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
        self.tint.map { $0.opacity(0.35) } ?? self.runicTheme.cardStroke
    }
}

/// A capsule glass button. `prominent` fills it with the sapphire accent.
struct LiquidGlassButton: View {
    let title: String
    var systemImage: String?
    var prominent = false
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(self.title)
                    .font(RunicLiquidGlass.body(11.5, .semibold))
                    .skinFace()
                    .lineLimit(1)
            }
            .foregroundStyle(self.prominent ? self.runicTheme.surface : self.runicTheme.accent)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background {
                if self.prominent {
                    Capsule(style: .continuous)
                        .fill(self.runicTheme.accent.opacity(self.isHovered ? 0.88 : 1))
                } else {
                    Capsule(style: .continuous)
                        .fill(self.runicTheme.accent.opacity(self.isHovered ? 0.16 : 0.08))
                }
            }
            .overlay(LiquidGlassFresnelRim(shape: Capsule(style: .continuous), intensity: 0.8))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

/// Copies a string with a brief checkmark.
struct LiquidGlassCopyButton: View {
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

// MARK: - Rows

/// A provider's brand mark on a 6pt micro-tile.
struct LiquidGlassProviderMark: View {
    let image: NSImage?
    let name: String
    let tint: Color
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RunicLiquidGlass.tileRadius, style: .continuous)
                .fill(self.tint.opacity(0.12))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: self.size * 0.62, height: self.size * 0.62)
            } else {
                Text(self.initial)
                    .font(.system(size: self.size * 0.45, weight: .semibold))
                    .skinFace()
                    .foregroundStyle(self.tint)
            }
        }
        .frame(width: self.size, height: self.size)
        .overlay(LiquidGlassFresnelRim(
            shape: RoundedRectangle(cornerRadius: RunicLiquidGlass.tileRadius, style: .continuous),
            intensity: 0.7))
        .accessibilityHidden(true)
    }

    private var initial: String {
        self.name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }
}

/// Label on the left, value on the right, optional detail beneath.
struct LiquidGlassKeyValue: View {
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
                    .font(RunicLiquidGlass.body(12, .regular))
                    .skinFace()
                    .foregroundStyle(self.value.isEmpty ? self.runicTheme.secondaryText : self.runicTheme.primaryText)
                    .lineLimit(self.value.isEmpty ? 3 : 1)
                    .fixedSize(horizontal: false, vertical: self.value.isEmpty)
                    .layoutPriority(self.value.isEmpty ? 2 : 1)
                if !self.value.isEmpty {
                    Spacer(minLength: 8)
                    Text(self.value)
                        .font(self.numeric
                            ? RunicLiquidGlass.numeric(13, .semibold)
                            : RunicLiquidGlass.body(12, .medium))
                        .skinFace()
                        .foregroundStyle(self.valueColor ?? self.runicTheme.primaryText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(RunicLiquidGlass.body(11))
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

/// A hairline between rows inside a well.
struct LiquidGlassHairline: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Rectangle()
            .fill(self.runicTheme.primaryText.opacity(0.08))
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}
