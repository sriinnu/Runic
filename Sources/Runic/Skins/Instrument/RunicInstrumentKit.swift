import AppKit
import RunicCore
import SwiftUI

// MARK: - Instrument kit

/// Instrument's kit: a 1970s bench instrument in cream enamel. Two faces
/// addressed by PostScript name — Archivo Narrow for engraved labels,
/// keycaps and copy, Space Mono for the LCD readouts — and the marks the
/// panel is built from: the recessed plate, the LCD strip, the keycap, the
/// LED, the groove, the corner screw and the VU meter.
enum RunicInstrument {
    enum NarrowWeight { case regular, medium, semibold, bold }
    enum MonoWeight { case regular, bold }

    /// Archivo Narrow, static instances cut from the variable master.
    static func narrow(_ size: CGFloat, _ weight: NarrowWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "ArchivoNarrow-Regular"
        case .medium: "ArchivoNarrow-Medium"
        case .semibold: "ArchivoNarrow-SemiBold"
        case .bold: "ArchivoNarrow-Bold"
        }
        return Font.custom(name, fixedSize: size)
    }

    /// Space Mono, the LCD face.
    static func mono(_ size: CGFloat, _ weight: MonoWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "SpaceMono-Regular"
        case .bold: "SpaceMono-Bold"
        }
        return Font.custom(name, fixedSize: size)
    }

    // MARK: Roles

    /// Engraved caps run at 0.22em.
    static let engraveTracking: CGFloat = 2.2
    /// Keycap caps run at 0.18em.
    static let keyTracking: CGFloat = 1.9

    static func engrave(_ size: CGFloat = 10) -> Font {
        self.narrow(size, .medium)
    }

    static func copy(_ size: CGFloat = 12.5) -> Font {
        self.narrow(size, .regular)
    }

    static func strong(_ size: CGFloat = 12.5) -> Font {
        self.narrow(size, .semibold)
    }

    static func key(_ size: CGFloat = 11) -> Font {
        self.narrow(size, .bold)
    }

    static func name(_ size: CGFloat = 30) -> Font {
        self.narrow(size, .bold)
    }

    static func lcd(_ size: CGFloat = 11, bold: Bool = false) -> Font {
        self.mono(size, bold ? .bold : .regular)
    }

    // MARK: Paint

    /// The enamel, the bezel and the lamps. These are the instrument's own
    /// materials; ink, cream and the red of the needle come from the theme.
    enum Paint {
        static let engrave = Color(red: 0.290, green: 0.251, blue: 0.204) // #4A4034
        static let bezel = Color(red: 0.420, green: 0.353, blue: 0.243) // #6B5A3E
        static let bevelInner = Color(red: 0.804, green: 0.749, blue: 0.620) // #CDBF9E
        static let plateTop = Color(red: 0.929, green: 0.890, blue: 0.784) // #EDE3C8
        static let plateBottom = Color(red: 0.902, green: 0.859, blue: 0.745) // #E6DBBE
        static let dialFace = Color(red: 0.984, green: 0.965, blue: 0.918) // #FBF6EA
        static let keyTop = Color(red: 0.976, green: 0.953, blue: 0.906) // #F9F3E7
        static let keyBottom = Color(red: 0.914, green: 0.875, blue: 0.776) // #E9DFC6
        static let keyHoverTop = Color(red: 1.0, green: 0.984, blue: 0.949) // #FFFBF2
        static let keyHoverBottom = Color(red: 0.941, green: 0.902, blue: 0.808) // #F0E6CE
        static let orangeTop = Color(red: 0.816, green: 0.345, blue: 0.227) // #D0583A
        static let orangeBottom = Color(red: 0.698, green: 0.227, blue: 0.141) // #B23A24
        static let orangeHoverTop = Color(red: 0.863, green: 0.392, blue: 0.275) // #DC6446
        static let orangeHoverBottom = Color(red: 0.741, green: 0.259, blue: 0.188) // #BD4230
        static let orangeEdge = Color(red: 0.478, green: 0.157, blue: 0.098) // #7A2819
        static let lcd = Color(red: 0.624, green: 0.647, blue: 0.549) // #9FA58C
        static let lcdText = Color(red: 0.122, green: 0.141, blue: 0.094) // #1F2418
        static let lcdAlert = Color(red: 0.478, green: 0.157, blue: 0.098) // #7A2819
        static let ledGreen = Color(red: 0.247, green: 0.702, blue: 0.310) // #3FB34F
        static let ledAmber = Color(red: 0.851, green: 0.647, blue: 0.125) // #D9A520
        static let ledUnlit = Color(red: 0.851, green: 0.812, blue: 0.698) // #D9CFB2
        static let lampOff = Color(red: 0.725, green: 0.682, blue: 0.576) // #B9AE93
        static let screwLight = Color(red: 0.890, green: 0.847, blue: 0.737) // #E3D8BC
        static let screwDark = Color(red: 0.541, green: 0.478, blue: 0.353) // #8A7A5A
        static let screwRing = Color(red: 0.353, green: 0.294, blue: 0.200) // #5A4B33
    }

    /// A lamp's state. `red` is the theme accent so the needle, the clip
    /// lamp and the pressed PING key share one red.
    enum Lamp {
        case green, amber, red, unlit, off

        func color(accent: Color) -> Color {
            switch self {
            case .green: Paint.ledGreen
            case .amber: Paint.ledAmber
            case .red: accent
            case .unlit: Paint.ledUnlit
            case .off: Paint.lampOff
            }
        }

        var isLit: Bool {
            switch self {
            case .green, .amber, .red: true
            case .unlit, .off: false
            }
        }
    }

    /// Colour of segment `index` of `count` on a level bar that runs
    /// green → amber → red: green to 60 %, amber to 80 %, red above.
    static func levelLamp(index: Int, count: Int) -> Lamp {
        let share = (Double(index) + 0.5) / Double(count)
        if share >= 0.8 { return .red }
        if share >= 0.6 { return .amber }
        return .green
    }

    // MARK: Readout text

    /// "Updated 4m ago" → "UPD 4M"; "Refreshing..." → "REFRESH"; "Not
    /// fetched yet" → "NO DATA". The LCD has eleven cells.
    static func lcdUpdated(_ subtitle: String) -> String {
        let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("refreshing") { return "REFRESH" }
        if trimmed.lowercased().hasPrefix("not fetched") { return "NO DATA" }
        var text = trimmed
        for prefix in ["Updated ", "updated "] where text.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
        }
        text = text.replacingOccurrences(of: " ago", with: "")
        text = text.replacingOccurrences(of: "just now", with: "NOW")
        text = self.compactDurations(text)
        return "UPD " + text.uppercased()
    }

    /// "Resets in 2h 14m · 17:35" → "RST 2H14M · 17:35";
    /// "Resets tomorrow 09:00" → "RST TMRW 09:00". A phrase with no
    /// "Resets" prefix is only uppercased.
    static func lcdReset(_ reset: String) -> String {
        var text = reset.trimmingCharacters(in: .whitespacesAndNewlines)
        var prefixed = false
        for prefix in ["Resets in ", "Resets ", "resets in ", "resets "] where text.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
            prefixed = true
            break
        }
        text = text.replacingOccurrences(of: "tomorrow,", with: "TMRW")
        text = text.replacingOccurrences(of: "tomorrow", with: "TMRW")
        text = self.compactDurations(text)
        let body = text.uppercased()
        return prefixed ? "RST " + body : body
    }

    /// "2h 14m" → "2H14M", "3d 5h" → "3D05H"; other text passes through.
    static func compactDurations(_ text: String) -> String {
        let pattern = #"(\d+)\s*([dhm])\s+(\d+)\s*([dhm])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1$2$3$4")
    }

    /// The signed percent in "Pace: Behind (-34%) · Runs out in 2h", or
    /// nil when the line carries no delta.
    static func paceDelta(_ detail: String?) -> Int? {
        guard let detail, let open = detail.range(of: "("), let close = detail.range(of: "%)"),
              open.upperBound < close.lowerBound
        else { return nil }
        let raw = detail[open.upperBound..<close.lowerBound]
        return Int(raw.replacingOccurrences(of: "+", with: ""))
    }

    /// "Pace: Behind (-34%) · Runs out in 2h" → "RUNS OUT 2H"; nil without
    /// an ETA.
    static func paceETA(_ detail: String?) -> String? {
        guard let detail, let dot = detail.range(of: " \u{00B7} ") else { return nil }
        let tail = String(detail[dot.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !tail.isEmpty else { return nil }
        return self.compactDurations(tail.replacingOccurrences(of: " in ", with: " ")).uppercased()
    }

    /// Whether a detail line is a pace line at all.
    static func isPaceLine(_ detail: String?) -> Bool {
        detail?.hasPrefix("Pace:") == true
    }

    /// A countdown as the LCD shows it: "02:14" under a day, "3D 05H" past.
    static func lcdCountdown(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "00:00" }
        let minutes = Int(ceil(seconds / 60))
        let days = minutes / 1440
        if days > 0 {
            return String(format: "%dD %02dH", days, (minutes / 60) % 24)
        }
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// The wall-clock moment: "17:35" today, "WED" inside the week, "NOV 5"
    /// beyond.
    static func lcdClock(_ date: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        }
        if let week = calendar.date(byAdding: .day, value: 6, to: now), date < week {
            return date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        }
        return date.formatted(.dateTime.month(.abbreviated).day()).uppercased()
    }

    /// Splits "Context health: max ctx ~272K" into a label and its value.
    static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let range = line.range(of: ": "),
              line.distance(from: line.startIndex, to: range.lowerBound) <= 28
        else { return nil }
        return (String(line[..<range.lowerBound]), String(line[range.upperBound...]))
    }

    /// Build number zero-padded to six, or nil when the binary carries none.
    static let serial: String? = {
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              !build.isEmpty
        else { return nil }
        let digits = build.filter(\.isNumber)
        guard !digits.isEmpty else { return build }
        return String(repeating: "0", count: max(0, 6 - digits.count)) + digits
    }()
}

// MARK: - Engraved label

/// Tracked caps cut into the enamel: Archivo Narrow Medium with a 1pt
/// white shadow beneath each stroke.
struct InstrumentEngraved: View {
    let text: String
    var size: CGFloat = 10
    var color: Color?
    var tracking: CGFloat = RunicInstrument.engraveTracking
    var weight: RunicInstrument.NarrowWeight = .medium

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicInstrument.narrow(self.size, self.weight))
            .skinFace()
            .tracking(self.tracking)
            .foregroundStyle(self.color ?? RunicInstrument.Paint.engrave)
            .shadow(color: Color.white.opacity(0.6), radius: 0, y: 1)
            .lineLimit(1)
    }
}

// MARK: - Plate

/// A recessed plate: warm gradient, 1pt bezel stroke, a white highlight
/// along the inside top edge and a shadow line along the inside bottom.
struct InstrumentPlate<Content: View>: View {
    var padding: EdgeInsets = .init(top: 10, leading: 12, bottom: 10, trailing: 12)
    @ViewBuilder let content: Content

    var body: some View {
        self.content
            .padding(self.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstrumentPlateSurface())
    }
}

/// The plate's surface on its own, for views that size themselves.
struct InstrumentPlateSurface: View {
    var cornerRadius: CGFloat = 4

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(
                colors: [RunicInstrument.Paint.plateTop, RunicInstrument.Paint.plateBottom],
                startPoint: .top,
                endPoint: .bottom))
            shape
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                .padding(1)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center))
            shape
                .strokeBorder(RunicInstrument.Paint.bezel.opacity(0.35), lineWidth: 1)
                .padding(1)
                .mask(LinearGradient(colors: [.clear, .black], startPoint: .center, endPoint: .bottom))
            shape.strokeBorder(RunicInstrument.Paint.bezel, lineWidth: 1)
        }
        .shadow(color: Color.white.opacity(0.5), radius: 0, y: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - LCD

/// An olive liquid-crystal strip with a dark bezel and an inset shadow.
/// Content is set in Space Mono by the caller.
struct InstrumentLCD<Content: View>: View {
    var padding: EdgeInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        self.content
            .foregroundStyle(RunicInstrument.Paint.lcdText)
            .padding(self.padding)
            .background {
                ZStack {
                    shape.fill(RunicInstrument.Paint.lcd)
                    // Inset shadow: a thick dark stroke blurred and pushed down,
                    // kept inside the glass.
                    shape
                        .stroke(Color.black.opacity(0.42), lineWidth: 5)
                        .blur(radius: 3)
                        .offset(y: 2)
                        .mask(shape)
                    shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 2)
                    shape.strokeBorder(RunicInstrument.Paint.engrave, lineWidth: 1)
                }
                .accessibilityHidden(true)
            }
    }
}

/// One line of LCD text.
struct InstrumentLCDText: View {
    let text: String
    var size: CGFloat = 11
    var bold = false
    var alert = false
    var dim = false
    var minWidth: CGFloat?
    var alignment: Alignment = .trailing

    var body: some View {
        InstrumentLCD {
            Text(self.text)
                .font(RunicInstrument.lcd(self.size, bold: self.bold))
                .skinFace()
                .foregroundStyle(self.alert ? RunicInstrument.Paint.lcdAlert : RunicInstrument.Paint.lcdText)
                .opacity(self.dim ? 0.6 : 1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: self.minWidth, alignment: self.alignment)
        }
    }
}

// MARK: - Keycap

/// A raised key: cream gradient, 1pt bezel, a 2pt hard shadow underneath.
/// Pressed (selected) keys are ink with cream text and sit 2pt lower; the
/// orange variant is the primary control.
/// Cream is the ordinary key; orange is the primary control.
enum InstrumentKeyVariant { case cream, orange }

struct InstrumentKeycap<Label: View>: View {
    var variant: InstrumentKeyVariant = .cream
    var pressed = false
    var height: CGFloat = 30
    var horizontalPadding: CGFloat = 12
    let action: () -> Void
    @ViewBuilder let label: Label

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            self.label
                .padding(.horizontal, self.horizontalPadding)
                .frame(height: self.height)
                .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(InstrumentKeyStyle(
            variant: self.variant,
            pressed: self.pressed,
            hovered: self.isHovered,
            ink: self.runicTheme.primary,
            cream: self.runicTheme.surface))
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
        .accessibilityAddTraits(self.pressed ? [.isSelected] : [])
    }
}

private struct InstrumentKeyStyle: ButtonStyle {
    let variant: InstrumentKeyVariant
    let pressed: Bool
    let hovered: Bool
    let ink: Color
    let cream: Color

    func makeBody(configuration: Configuration) -> some View {
        let down = self.pressed || configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        let edge = self.variant == .orange ? RunicInstrument.Paint.orangeEdge : RunicInstrument.Paint.bezel
        configuration.label
            .foregroundStyle(self.textColor(down: down))
            .background {
                ZStack {
                    if down, self.variant == .cream {
                        shape.fill(self.ink)
                        shape
                            .stroke(Color.black.opacity(0.6), lineWidth: 4)
                            .blur(radius: 2)
                            .offset(y: 2)
                            .mask(shape)
                    } else {
                        shape.fill(LinearGradient(colors: self.gradient, startPoint: .top, endPoint: .bottom))
                        shape
                            .strokeBorder(Color.white.opacity(self.variant == .orange ? 0.35 : 0.8), lineWidth: 1)
                            .padding(1)
                            .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center))
                    }
                    shape.strokeBorder(edge, lineWidth: 1)
                }
                .accessibilityHidden(true)
            }
            .background {
                // The hard 2pt shadow the key stands on; gone when pressed.
                if !down {
                    shape.fill(edge).offset(y: 2)
                }
            }
            .offset(y: down ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: down)
    }

    private var gradient: [Color] {
        switch (self.variant, self.hovered) {
        case (.cream, false): [RunicInstrument.Paint.keyTop, RunicInstrument.Paint.keyBottom]
        case (.cream, true): [RunicInstrument.Paint.keyHoverTop, RunicInstrument.Paint.keyHoverBottom]
        case (.orange, false): [RunicInstrument.Paint.orangeTop, RunicInstrument.Paint.orangeBottom]
        case (.orange, true): [RunicInstrument.Paint.orangeHoverTop, RunicInstrument.Paint.orangeHoverBottom]
        }
    }

    private func textColor(down: Bool) -> Color {
        if self.variant == .orange { return RunicInstrument.Paint.keyTop }
        return down ? self.cream : self.ink
    }
}

/// A keycap with a tracked-caps title and an optional glyph.
struct InstrumentKey: View {
    let title: String
    var systemImage: String?
    var variant: InstrumentKeyVariant = .cream
    var pressed = false
    var height: CGFloat = 30
    var size: CGFloat = 11
    var horizontalPadding: CGFloat = 12
    let action: () -> Void

    var body: some View {
        InstrumentKeycap(
            variant: self.variant,
            pressed: self.pressed,
            height: self.height,
            horizontalPadding: self.horizontalPadding,
            action: self.action)
        {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: self.size, weight: .bold))
                }
                Text(self.title.uppercased())
                    .font(RunicInstrument.key(self.size))
                    .skinFace()
                    .tracking(RunicInstrument.keyTracking)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Lamps, grooves, screws

/// A 9pt LED with a dark rim, a highlight on its crown and a glow when lit.
struct InstrumentLED: View {
    let lamp: RunicInstrument.Lamp
    var size: CGFloat = 9
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let color = self.lamp.color(accent: self.runicTheme.accent)
        Circle()
            .fill(color)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                    .padding(1)
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center)))
            .frame(width: self.size, height: self.size)
            .shadow(color: self.lamp.isLit ? color.opacity(0.85) : .clear, radius: 3)
            .accessibilityHidden(true)
    }
}

/// An LED with its engraved caption beside it.
struct InstrumentLampLabel: View {
    let lamp: RunicInstrument.Lamp
    let text: String
    var size: CGFloat = 10
    var ledSize: CGFloat = 9

    var body: some View {
        HStack(spacing: 7) {
            InstrumentLED(lamp: self.lamp, size: self.ledSize)
            InstrumentEngraved(text: self.text, size: self.size)
                .minimumScaleFactor(0.75)
        }
    }
}

/// An engraved groove: a shadow line over a highlight line.
struct InstrumentGroove: View {
    var body: some View {
        VStack(spacing: 1) {
            Rectangle().fill(RunicInstrument.Paint.bezel.opacity(0.55)).frame(height: 1)
            Rectangle().fill(Color.white.opacity(0.75)).frame(height: 1)
        }
        .frame(height: 3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A slotted screw head: a radial-gradient dome with a dark rim and a slot
/// turned a few degrees off level.
struct InstrumentScrew: View {
    var size: CGFloat = 11
    var slotAngle: Double = 28

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(
                colors: [RunicInstrument.Paint.screwLight, RunicInstrument.Paint.screwDark],
                center: UnitPoint(x: 0.4, y: 0.35),
                startRadius: 0,
                endRadius: self.size * 0.6))
            Circle().strokeBorder(RunicInstrument.Paint.screwRing, lineWidth: 1)
            RoundedRectangle(cornerRadius: 0.75)
                .fill(RunicInstrument.Paint.engrave)
                .frame(width: self.size - 4, height: 1.5)
                .rotationEffect(.degrees(self.slotAngle))
        }
        .frame(width: self.size, height: self.size)
        .shadow(color: Color.white.opacity(0.6), radius: 0, y: 1)
        .accessibilityHidden(true)
    }
}

// MARK: - VU meter

/// A VU meter: a cream dial with a 180° arc, five ticks, a red zone past
/// 80 %, a red needle and an ink hub, the window's name engraved under the
/// arc. 150×92 like the artboard; scale it with `scale`.
struct InstrumentVUMeter: View {
    let title: String
    /// The needle's reading, 0…100, or nil to rest it at zero.
    let percent: Double?
    /// The red zone sits at the low end when the meter reads what is left.
    var redZoneLow = false
    let accessibilityLabel: String
    var scale: CGFloat = 1
    @Environment(\.runicTheme) private var runicTheme

    private static let dial = CGSize(width: 150, height: 92)
    private static let hub = CGPoint(x: 75, y: 78)
    private static let radius: CGFloat = 56

    var body: some View {
        let reading = min(100, max(0, self.percent ?? 0))
        let ink = self.runicTheme.primary
        let red = self.runicTheme.accent
        ZStack {
            Canvas { context, _ in
                let hub = Self.hub
                let r = Self.radius
                let face = Path(roundedRect: CGRect(x: 1, y: 1, width: 148, height: 90), cornerRadius: 4)
                context.fill(face, with: .color(RunicInstrument.Paint.dialFace))
                context.stroke(face, with: .color(RunicInstrument.Paint.bezel), lineWidth: 1)

                var arc = Path()
                arc.addArc(center: hub, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(arc, with: .color(ink), lineWidth: 1.5)

                var zone = Path()
                if self.redZoneLow {
                    zone.addArc(
                        center: hub,
                        radius: r,
                        startAngle: .degrees(180),
                        endAngle: .degrees(216),
                        clockwise: false)
                } else {
                    zone.addArc(
                        center: hub,
                        radius: r,
                        startAngle: .degrees(324),
                        endAngle: .degrees(360),
                        clockwise: false)
                }
                context.stroke(zone, with: .color(red), lineWidth: 5)

                for step in 0...4 {
                    let angle = Angle.degrees(180 + Double(step) * 45).radians
                    let outer = CGPoint(x: hub.x + cos(angle) * r, y: hub.y + sin(angle) * r)
                    let inner = CGPoint(x: hub.x + cos(angle) * (r - 6), y: hub.y + sin(angle) * (r - 6))
                    var tick = Path()
                    tick.move(to: outer)
                    tick.addLine(to: inner)
                    context.stroke(tick, with: .color(ink), lineWidth: 1.5)
                }

                var needle = Path()
                needle.move(to: hub)
                needle.addLine(to: CGPoint(x: hub.x, y: hub.y - 52))
                let rotation = Angle.degrees((reading - 50) * 1.8)
                context.drawLayer { layer in
                    layer.translateBy(x: hub.x, y: hub.y)
                    layer.rotate(by: rotation)
                    layer.translateBy(x: -hub.x, y: -hub.y)
                    layer.stroke(needle, with: .color(red), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
                context.fill(
                    Path(ellipseIn: CGRect(x: hub.x - 4, y: hub.y - 4, width: 8, height: 8)),
                    with: .color(ink))
            }
            .skinFace()

            self.scaleLabel("0", color: self.redZoneLow ? red : RunicInstrument.Paint.engrave)
                .position(x: 24, y: 86)
            self.scaleLabel("50", color: RunicInstrument.Paint.engrave)
                .position(x: 75, y: 15)
            self.scaleLabel("100", color: self.redZoneLow ? RunicInstrument.Paint.engrave : red)
                .position(x: 126, y: 86)
            InstrumentEngraved(text: self.title, size: 7, tracking: 1.5)
                .minimumScaleFactor(0.7)
                .frame(width: 96)
                .position(x: 75, y: 61)
        }
        .frame(width: Self.dial.width, height: Self.dial.height)
        .scaleEffect(self.scale, anchor: .topLeading)
        .frame(width: Self.dial.width * self.scale, height: Self.dial.height * self.scale, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue(self.percent.map { "\(Int($0.rounded())) percent" } ?? "no reading")
    }

    private func scaleLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(RunicInstrument.narrow(8, .medium))
            .skinFace()
            .foregroundStyle(color)
    }
}

// MARK: - Segment bars

/// A row of LED segments lit from the left. `lamp(index)` colours each
/// segment; segments past `lit` are unlit.
struct InstrumentSegmentBar: View {
    let count: Int
    let lit: Int
    var segmentWidth: CGFloat?
    var height: CGFloat = 7
    var spacing: CGFloat = 2
    let lamp: (Int) -> RunicInstrument.Lamp
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: self.spacing) {
            ForEach(0..<self.count, id: \.self) { index in
                let state: RunicInstrument.Lamp = index < self.lit ? self.lamp(index) : .unlit
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(state.color(accent: self.runicTheme.accent))
                    .frame(width: self.segmentWidth, height: self.height)
                    .frame(maxWidth: self.segmentWidth == nil ? .infinity : nil)
                    .shadow(
                        color: index == self.lit - 1 && state == .red ? self.runicTheme.accent.opacity(0.8) : .clear,
                        radius: 3)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A column of LED segments lit from the bottom, for the activity bars.
struct InstrumentSegmentColumn: View {
    let count: Int
    let lit: Int
    var segmentHeight: CGFloat = 6
    var spacing: CGFloat = 2
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: self.spacing) {
            ForEach((0..<self.count).reversed(), id: \.self) { index in
                let state: RunicInstrument.Lamp = index < self.lit
                    ? RunicInstrument.levelLamp(index: index, count: self.count)
                    : .unlit
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(state.color(accent: self.runicTheme.accent))
                    .frame(maxWidth: .infinity)
                    .frame(height: self.segmentHeight)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Readout row

/// Engraved label on the left, an LCD value on the right.
struct InstrumentReadoutRow: View {
    let label: String
    let value: String
    var dim = false
    var alert = false
    var size: CGFloat = 11

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            InstrumentEngraved(text: self.label)
                .fixedSize()
                .layoutPriority(1)
            Spacer(minLength: 8)
            InstrumentLCD {
                Text(self.value)
                    .font(RunicInstrument.lcd(self.size))
                    .skinFace()
                    .foregroundStyle(self.alert ? RunicInstrument.Paint.lcdAlert : RunicInstrument.Paint.lcdText)
                    .opacity(self.dim ? 0.6 : 1)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 84, maxWidth: 200, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.label), \(self.value)")
    }
}
