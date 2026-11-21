import AppKit
import RunicCore
import SwiftUI

// MARK: - Ceramic kit

/// Relief's kit: a matte ceramic instrument in the Braun manner. The page
/// is a warm alabaster chassis; sections are raised plinths lit from the
/// top left (a 1pt specular bevel and a soft bottom-right umbra); gauges are
/// machined troughs cut into the plinth with calibration ticks, a pace
/// detent and a signal-orange slider nib; provider tabs and chips are
/// keycaps with LED pips. One face — SF Pro with tabular figures — so the
/// numerals line up like a printed scale.
enum RunicRelief {
    // MARK: Faces

    /// SF Pro at a fixed size. `design: .default` is explicit so a
    /// monospaced body pick never re-resolves the instrument face.
    static func face(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Tabular figures: every readout lines up on its scale.
    static func numeral(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        self.face(size, weight).monospacedDigit()
    }

    /// Tracked small caps for engraved labels.
    static func label(_ size: CGFloat = 9.5) -> Font {
        self.face(size, .semibold)
    }

    static let labelTracking: CGFloat = 1.2

    // MARK: Geometry

    /// Plinth corner: soft, machined, never pill-shaped.
    static let plinthRadius: CGFloat = 12
    /// Keycap corner.
    static let keyRadius: CGFloat = 7
    /// Trough height for a full gauge.
    static let troughHeight: CGFloat = 12

    // MARK: Fixed light

    /// The lamp catching the top-left rim of a raised surface.
    static let specular = Color.white
    /// The slider nib: Braun's signal orange. Decorative (non-text), always
    /// drawn with a dark keyline so it holds against any trough.
    static let signal = Color(red: 0.910, green: 0.365, blue: 0.165)
    /// LED colours: lit green, amber, red. Pips sit on a dark bezel ring.
    static let ledGreen = Color(red: 0.180, green: 0.659, blue: 0.400)
    static let ledAmber = Color(red: 0.949, green: 0.627, blue: 0.137)
    static let ledRed = Color(red: 0.878, green: 0.243, blue: 0.267)

    // MARK: Text helpers

    /// Splits "Context health: max ctx ~272K" into a label and its value.
    static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let range = line.range(of: ": "),
              line.distance(from: line.startIndex, to: range.lowerBound) <= 28
        else { return nil }
        return (String(line[..<range.lowerBound]), String(line[range.upperBound...]))
    }

    /// "in 2h 14m" from "resets in 2h 14m · 18:46" or "↻ 2h 14m": the first
    /// clause only, so it fits a reset capsule.
    static func capsuleText(_ text: String?) -> String? {
        guard var value = text?.split(separator: "\u{00B7}").first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        if value.hasPrefix("\u{21BB}") {
            value = "in " + value.dropFirst().trimmingCharacters(in: .whitespaces)
        }
        for prefix in ["Resets ", "resets "] where value.hasPrefix(prefix) {
            value = String(value.dropFirst(prefix.count))
        }
        value = value.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// Where the window "should" be, from "Pace: Behind (-34%)": the shown
    /// percent pushed back by the delta. Nil when there is no pace line.
    static func paceMarker(percent: Double?, style: UsageMenuCardView.Model.PercentStyle, detail: String?) -> Double? {
        guard let percent, let detail, detail.lowercased().hasPrefix("pace") else { return nil }
        guard let open = detail.range(of: "("), let close = detail.range(of: "%)"),
              open.upperBound < close.lowerBound
        else { return nil }
        let raw = detail[open.upperBound..<close.lowerBound]
            .replacingOccurrences(of: "+", with: "")
            .replacingOccurrences(of: "\u{2212}", with: "-")
        guard let delta = Double(raw), delta != 0 else { return nil }
        let target = switch style {
        case .used: percent - delta
        case .left: percent + delta
        }
        return min(100, max(0, target))
    }

    /// Whether a window is spent, read the way it is displayed.
    static func isExhausted(percent: Double?, style: UsageMenuCardView.Model.PercentStyle) -> Bool {
        guard let percent else { return false }
        switch style {
        case .used: return percent >= 99.5
        case .left: return percent <= 0.5
        }
    }
}

// MARK: - Labels and rules

/// Engraved caption: tracked caps in the secondary tone.
struct ReliefLabel: View {
    let text: String
    var size: CGFloat = 9.5
    var color: Color?
    var tracking: CGFloat = RunicRelief.labelTracking
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicRelief.label(self.size))
            .skinFace()
            .tracking(self.tracking)
            .foregroundStyle(self.color ?? self.runicTheme.secondaryText)
            .lineLimit(1)
    }
}

/// An engraved groove: a shadow line with a lit line under it, the way a
/// machined cut reads under a top-left lamp.
struct ReliefGroove: View {
    var vertical = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shade = self.runicTheme.primaryText.opacity(0.13)
        let lit = RunicRelief.specular.opacity(0.9 * self.runicTheme.style.effects.elevation)
        Group {
            if self.vertical {
                HStack(spacing: 0) {
                    Rectangle().fill(shade).frame(width: 1)
                    Rectangle().fill(lit).frame(width: 1)
                }
            } else {
                VStack(spacing: 0) {
                    Rectangle().fill(shade).frame(height: 1)
                    Rectangle().fill(lit).frame(height: 1)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Surfaces

/// A raised ceramic plinth: matte fill, 1pt top-left specular bevel, a
/// hairline keyline, and two shadows — a tight contact shadow and a soft
/// bottom-right umbra.
struct ReliefPlinthBackground: View {
    var radius: CGFloat = RunicRelief.plinthRadius
    var lift: Double = 1
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        let strength = max(0.35, self.runicTheme.style.effects.elevation) * self.lift
        let shape = RoundedRectangle(cornerRadius: self.radius, style: .continuous)
        shape
            .fill(LinearGradient(
                colors: [self.runicTheme.cardFill, self.runicTheme.surfaceAlt],
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: RunicRelief.specular.opacity(0.95), location: 0),
                            .init(color: RunicRelief.specular.opacity(0.0), location: 0.45),
                            .init(color: ink.opacity(0.0), location: 0.6),
                            .init(color: ink.opacity(0.10), location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    lineWidth: 1)
            }
            .overlay { shape.stroke(self.runicTheme.cardStroke.opacity(0.55), lineWidth: 0.5) }
            .shadow(color: ink.opacity(0.10 * strength), radius: 0.8, x: 0.4, y: 0.8)
            .shadow(color: ink.opacity(0.11 * strength), radius: 7, x: 2, y: 4)
    }
}

/// A recessed well: a shallow pocket cut into the plinth with a soft inner
/// shadow along its top edge and a crisp lit lip along its bottom.
struct ReliefWellBackground<S: InsettableShape>: View {
    let shape: S
    var depth: Double = 1
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        self.shape
            .fill(ink.opacity(0.06 * self.depth))
            .overlay {
                // Inner top shadow: a blurred stroke pushed down, masked to
                // the well so it reads as depth, not a glow.
                self.shape
                    .stroke(ink.opacity(0.30 * self.depth), lineWidth: 2.5)
                    .blur(radius: 1.6)
                    .offset(x: 0.6, y: 1.4)
                    .mask(self.shape)
            }
            .overlay {
                self.shape.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: ink.opacity(0.20 * self.depth), location: 0),
                            .init(color: ink.opacity(0.0), location: 0.45),
                            .init(color: RunicRelief.specular.opacity(0.0), location: 0.6),
                            .init(color: RunicRelief.specular.opacity(0.95), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom),
                    lineWidth: 1)
            }
    }
}

extension View {
    /// Sets the view on a raised plinth.
    func reliefPlinth(radius: CGFloat = RunicRelief.plinthRadius, lift: Double = 1) -> some View {
        self.background(ReliefPlinthBackground(radius: radius, lift: lift))
    }

    /// Sets the view in a recessed well.
    func reliefWell(radius: CGFloat = 8, depth: Double = 1) -> some View {
        self.background(ReliefWellBackground(
            shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
            depth: depth))
    }
}

// MARK: - LED, capsule

/// A tiny LED pip in a dark bezel: lit with a hot core, or dark glass.
struct ReliefLED: View {
    var color: Color = RunicRelief.ledGreen
    var isLit = true
    var size: CGFloat = 6
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        ZStack {
            Circle().fill(ink.opacity(0.55))
            Circle()
                .fill(self.isLit
                    ? AnyShapeStyle(RadialGradient(
                        colors: [Color.white.opacity(0.9), self.color, self.color.opacity(0.85)],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: self.size * 0.55))
                    : AnyShapeStyle(ink.opacity(0.22)))
                .padding(self.size * 0.14)
        }
        .frame(width: self.size, height: self.size)
        .accessibilityHidden(true)
    }
}

/// The reset capsule: dark slate with alabaster tabular figures.
struct ReliefCapsule: View {
    let text: String
    var tone: Color?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text)
            .font(RunicRelief.numeral(10.5, .semibold))
            .skinFace()
            .foregroundStyle(self.runicTheme.surface)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(self.tone ?? self.runicTheme.primaryText.opacity(0.86)))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom),
                        lineWidth: 0.75)
            }
    }
}

// MARK: - Gauge

/// The gauge: a machined trough with a raised ceramic fill up to a
/// signal-orange slider nib, and a calibration scale under it — a tick
/// every 5, a long tick every 25 — with the pace detent as a dark notch.
struct ReliefGauge: View {
    let percent: Double
    let accessibilityLabel: String
    /// The nib colour. Signal orange unless the window is spent.
    var nib: Color = RunicRelief.signal
    /// A tint laid thinly over the ceramic fill (brand colour on the front
    /// page), or nil for plain ceramic.
    var fillTint: Color?
    /// Where the pace says the window should be, as a percent.
    var marker: Double?
    var troughHeight: CGFloat = RunicRelief.troughHeight
    var showsScale = true
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        VStack(spacing: 4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let h = self.troughHeight
                let inset: CGFloat = 2
                let travel = max(0, width - inset * 2)
                let x = inset + travel * clamped / 100
                ZStack(alignment: .leading) {
                    ReliefWellBackground(shape: Capsule(style: .continuous))
                    if clamped > 0.5 {
                        self.fill(width: max(h - inset * 2, x - inset), height: h - inset * 2)
                            .padding(.leading, inset)
                    }
                    self.nibView(height: h + 6)
                        .position(x: min(max(x, 4), width - 4), y: h / 2)
                }
            }
            .frame(height: self.troughHeight)
            if self.showsScale {
                ReliefScale(marker: self.marker)
                    .frame(height: 7)
                    .padding(.horizontal, 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped.rounded())) percent")
    }

    private func fill(width: CGFloat, height: CGFloat) -> some View {
        let shape = Capsule(style: .continuous)
        return shape
            .fill(LinearGradient(
                colors: [self.runicTheme.cardFill, self.runicTheme.surfaceAlt],
                startPoint: .top,
                endPoint: .bottom))
            .overlay { shape.fill((self.fillTint ?? .clear).opacity(0.28)) }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [RunicRelief.specular, self.runicTheme.primaryText.opacity(0.14)],
                        startPoint: .top,
                        endPoint: .bottom),
                    lineWidth: 0.75)
            }
            .shadow(color: self.runicTheme.primaryText.opacity(0.14), radius: 0.8, x: 0.5, y: 0.6)
            .frame(width: width, height: height)
    }

    private func nibView(height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 2.5, style: .continuous)
        return shape
            .fill(LinearGradient(
                colors: [self.nib.opacity(0.92), self.nib],
                startPoint: .top,
                endPoint: .bottom))
            .overlay { shape.stroke(self.runicTheme.primaryText.opacity(0.55), lineWidth: 0.75) }
            .overlay(alignment: .top) {
                Capsule().fill(Color.white.opacity(0.55)).frame(width: 2, height: height * 0.45).padding(.top, 3)
            }
            .shadow(color: self.runicTheme.primaryText.opacity(0.28), radius: 1.2, x: 0.6, y: 1)
            .frame(width: 6, height: height)
    }
}

/// The calibration scale under a trough: engraved ticks with a dark notch
/// at the pace detent.
struct ReliefScale: View {
    var marker: Double?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Canvas { context, size in
            let ink = self.runicTheme.primaryText
            for step in stride(from: 0, through: 100, by: 5) {
                let x = size.width * CGFloat(step) / 100
                let major = step % 25 == 0
                let tall: CGFloat = major ? size.height - 1 : size.height * 0.45
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: 0))
                tick.addLine(to: CGPoint(x: x, y: tall))
                context.stroke(tick, with: .color(ink.opacity(major ? 0.42 : 0.24)), lineWidth: 0.75)
            }
            if let marker = self.marker {
                let x = size.width * CGFloat(min(100, max(0, marker))) / 100
                var notch = Path()
                notch.move(to: CGPoint(x: x - 3, y: size.height))
                notch.addLine(to: CGPoint(x: x + 3, y: size.height))
                notch.addLine(to: CGPoint(x: x, y: 0))
                notch.closeSubpath()
                context.fill(notch, with: .color(ink.opacity(0.78)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Rows

/// Label left, tabular value right, an engraved groove beneath.
struct ReliefKeyValue: View {
    let label: String
    let value: String
    var strong = false
    var valueColor: Color?
    var detail: String?
    var isLast = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(self.label)
                    .font(RunicRelief.face(12, .regular))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text(self.value)
                    .font(RunicRelief.numeral(12.5, self.strong ? .semibold : .regular))
                    .skinFace()
                    .foregroundStyle(self.valueColor ?? self.runicTheme.primaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 7)
            if let detail = self.detail, !detail.isEmpty {
                Text(detail)
                    .font(RunicRelief.face(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 7)
            }
            if !self.isLast {
                ReliefGroove()
            }
        }
    }
}

/// A readout tile set in a recessed well: engraved caption over a large
/// tabular value. Used for API credits, banked resets, today.
struct ReliefReadoutTile: View {
    let label: String
    let value: String
    var unit: String?
    var led: Color?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let led { ReliefLED(color: led, size: 6) }
                ReliefLabel(text: self.label, size: 9)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(self.value)
                    .font(RunicRelief.numeral(17, .semibold))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit = self.unit {
                    Text(unit)
                        .font(RunicRelief.face(11))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .reliefWell(radius: 8, depth: 0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.label): \(self.value) \(self.unit ?? "")")
    }
}

// MARK: - Keycaps

/// A keycap: raised and lit at rest, pressed into the plinth when chosen
/// (the outer shadow drops away and an inner shadow takes over).
struct ReliefKeycapBackground: View {
    let isPressed: Bool
    var isHovered = false
    var radius: CGFloat = RunicRelief.keyRadius
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        if self.isPressed {
            ReliefWellBackground(
                shape: RoundedRectangle(cornerRadius: self.radius, style: .continuous),
                depth: 1.1)
        } else {
            ReliefPlinthBackground(radius: self.radius, lift: self.isHovered ? 1.15 : 0.7)
        }
    }
}

/// A keycap button. `primary` is the signal key: accent-filled with light
/// lettering.
struct ReliefButton: View {
    let title: String
    var primary = false
    var systemImage: String?
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(self.title)
                    .font(RunicRelief.face(11.5, .semibold))
                    .skinFace()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(self.primary ? self.runicTheme.cardFill : self.runicTheme.primaryText)
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background {
                if self.primary {
                    let shape = RoundedRectangle(cornerRadius: RunicRelief.keyRadius, style: .continuous)
                    shape
                        .fill(LinearGradient(
                            colors: [self.runicTheme.accent.opacity(0.9), self.runicTheme.accent],
                            startPoint: .top,
                            endPoint: .bottom))
                        .overlay {
                            shape.strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.black.opacity(0.18)],
                                    startPoint: .top,
                                    endPoint: .bottom),
                                lineWidth: 1)
                        }
                        .shadow(
                            color: self.runicTheme.primaryText.opacity(self.isHovered ? 0.26 : 0.18),
                            radius: self.isHovered ? 4 : 2.5,
                            x: 1,
                            y: 2)
                } else {
                    ReliefKeycapBackground(isPressed: false, isHovered: self.isHovered)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: RunicRelief.keyRadius, style: .continuous))
        }
        .buttonStyle(ReliefPressStyle())
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

/// Presses a keycap a half point into the chassis while held.
struct ReliefPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 0.75 : 0)
            .brightness(configuration.isPressed ? -0.03 : 0)
    }
}

/// A small keycap that copies text to the pasteboard and flips to a check.
struct ReliefCopyButton: View {
    let copyText: String
    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        ReliefButton(
            title: self.didCopy ? "Copied" : "Copy",
            systemImage: self.didCopy ? "checkmark" : "doc.on.doc")
        {
            let board = NSPasteboard.general
            board.clearContents()
            board.setString(self.copyText, forType: .string)
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

// MARK: - Fault panel

/// A provider fault, set in a recessed well with a red LED: the whole
/// message (up to six lines, wrapped, never clipped) and the keys to deal
/// with it — copy, reload, and sign in when the fault is about credentials.
struct ReliefFaultPanel: View {
    let message: String
    let provider: UsageProvider
    var showsSignIn = false
    var isCLIFallback = false
    var title = "Fault"
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ReliefLED(color: self.isCLIFallback && self.message.isEmpty ? RunicRelief.ledAmber : RunicRelief.ledRed)
                ReliefLabel(text: self.title, color: self.runicTheme.warm)
            }
            if !self.message.isEmpty {
                Text(self.message)
                    .font(RunicRelief.face(11.5, .medium))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.warm)
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            ReliefWrap(spacing: 6) {
                if !self.message.isEmpty {
                    ReliefCopyButton(copyText: self.message)
                }
                ReliefButton(title: "Reload", systemImage: "arrow.clockwise") {
                    NotificationCenter.default.post(
                        name: .runicReloadProvider,
                        object: nil,
                        userInfo: ["provider": self.provider.rawValue])
                }
                .accessibilityLabel("Reload provider")
                if self.showsSignIn || self.isCLIFallback {
                    self.signInButton
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .reliefWell(radius: 9, depth: 0.9)
    }

    @ViewBuilder
    private var signInButton: some View {
        if self.provider == .claude {
            ReliefButton(title: "Reconnect Claude\u{2026}", primary: true, systemImage: "key.horizontal") {
                NotificationCenter.default.post(
                    name: .runicReloadProvider,
                    object: nil,
                    userInfo: ["provider": UsageProvider.claude.rawValue])
            }
            .help(self.isCLIFallback
                ? "Runic's copy of the Claude login has expired, so usage is read through the Claude CLI "
                + "(no cost or reset credits). Reconnect re-reads the login from Keychain; macOS may ask once."
                : "Re-reads the Claude CLI's login from Keychain. macOS may ask once.")
            .accessibilityLabel("Reconnect Claude from the CLI's Keychain login")
        } else {
            ReliefButton(title: "Sign in\u{2026}", primary: true, systemImage: "person.badge.key") {
                SettingsWindowBridge.open(tab: .providers, selection: nil)
            }
            .accessibilityLabel("Add account in provider settings")
        }
    }
}

/// A wrapping row of keycaps: wraps to a new line instead of clipping.
struct ReliefWrap: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + self.spacing
                rowHeight = 0
            }
            x += size.width + self.spacing
            widest = max(widest, x - self.spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? widest : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + self.spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + self.spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
