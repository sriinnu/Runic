import AppKit
import RunicCore
import SwiftUI

// MARK: - Editorial kit

/// The Gazette's printed-edition kit: the fixed inks that are not palette
/// slots and the two faces of the page, addressed by PostScript name so a
/// weight never depends on family matching. The composition rules (folio,
/// nameplate, category pill, dotted leader, double rule) live here too, the
/// way `RunicPaperStage` keeps the paper theme's pastels.
enum RunicGazette {
    /// Body copy sits a shade off full ink, like printed text.
    static let inkSoft = Color(red: 0.165, green: 0.165, blue: 0.165)
    /// Money column green.
    static let green = Color(red: 0.122, green: 0.478, blue: 0.247)
    /// Brief-bullet violet and amber.
    static let violet = Color(red: 0.608, green: 0.365, blue: 0.898)
    static let amber = Color(red: 0.722, green: 0.416, blue: 0.0)

    /// Section tag colours, cycling the way a paper's category labels do:
    /// rose, blue, gold, green, violet.
    static func sectionColor(_ index: Int, theme: RunicThemePalette) -> Color {
        let cycle = [theme.warm, theme.tertiary, theme.highlight, self.green, self.violet]
        return cycle[((index % cycle.count) + cycle.count) % cycle.count]
    }

    /// Bullet squares for the In-brief column.
    static func bulletColor(_ index: Int, theme: RunicThemePalette) -> Color {
        let cycle = [theme.warm, self.violet, self.amber, self.green, theme.tertiary]
        return cycle[((index % cycle.count) + cycle.count) % cycle.count]
    }

    // MARK: Faces

    enum SerifWeight { case regular, semibold, bold, black, italic }
    enum SansWeight { case regular, medium, semibold, bold }

    /// Fraunces 9pt, static instances. Headlines, numerals, the nameplate.
    static func serif(_ size: CGFloat, _ weight: SerifWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "Fraunces9pt-Regular"
        case .semibold: "Fraunces9pt-SemiBold"
        case .bold: "Fraunces9pt-Bold"
        case .black: "Fraunces9pt-Black"
        case .italic: "Fraunces9pt-Italic"
        }
        return Font.custom(name, fixedSize: size)
    }

    /// Manrope, static instances. Labels, metadata, secondary copy.
    static func sans(_ size: CGFloat, _ weight: SansWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "Manrope-Regular"
        case .medium: "Manrope-Medium"
        case .semibold: "Manrope-SemiBold"
        case .bold: "Manrope-Bold"
        }
        return Font.custom(name, fixedSize: size)
    }

    // MARK: Roles

    static let labelTracking: CGFloat = 1.4

    /// Tiny tracked caps: folio line, bylines, section tags.
    static func label(_ size: CGFloat = 9) -> Font {
        self.sans(size, .bold)
    }

    /// Story headline.
    static func headline(_ size: CGFloat) -> Font {
        self.serif(size, .bold)
    }

    /// Amounts and the big percentage.
    static func numeral(_ size: CGFloat) -> Font {
        self.serif(size, .black)
    }

    /// The nameplate.
    static func nameplate(_ size: CGFloat = 30) -> Font {
        self.serif(size, .black)
    }

    /// Lead-story copy.
    static func body(_ size: CGFloat = 12.5) -> Font {
        self.serif(size, .regular)
    }

    /// Secondary copy.
    static func copy(_ size: CGFloat = 10.5) -> Font {
        self.sans(size, .regular)
    }

    /// Pull quote.
    static func quote(_ size: CGFloat = 13) -> Font {
        self.serif(size, .italic)
    }

    // MARK: Folio

    /// "Vol. 2 · No. 154" — the marketing major as the volume, the build as
    /// the issue number, so every build is its own edition. Read once.
    static let edition: String = {
        let major = RunicVersion.marketing.split(separator: ".").first.map(String.init) ?? RunicVersion.marketing
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "Vol. \(major) · No. \(build)"
        }
        return "Vol. \(major)"
    }()

    /// Fixed en_GB order so the folio reads the same in every locale; it is
    /// typography, not a localised date. One formatter for the process —
    /// `DateFormatter` formatting is thread-safe on current macOS.
    private nonisolated(unsafe) static let folioFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "EEEE, d MMM yyyy"
        return formatter
    }()

    /// "Friday, 10 Oct 2026".
    static func folioDate(_ date: Date = .init()) -> String {
        self.folioFormatter.string(from: date)
    }

    /// Splits "Connection: connected" into a bold lead and the rest, when
    /// the lead is short enough to read as a name.
    static func briefParts(_ line: String) -> (lead: String?, rest: String) {
        guard let range = line.range(of: ": "), line.distance(from: line.startIndex, to: range.lowerBound) <= 24 else {
            return (nil, line)
        }
        return (String(line[..<range.lowerBound]), String(line[range.upperBound...]))
    }
}

// MARK: - Labels and tags

/// Tracked uppercase caption in Manrope Bold: the folio, bylines, metadata.
struct GazetteLabel: View {
    let text: String
    var size: CGFloat = 9
    var color: Color?
    var tracking: CGFloat = RunicGazette.labelTracking
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicGazette.label(self.size))
            .gazetteFace()
            .tracking(self.tracking)
            .foregroundStyle(self.color ?? self.runicTheme.primaryText)
            .lineLimit(1)
    }
}

extension View {
    /// Pins the editorial faces against the environment's font design. A
    /// user whose body font is SF Mono carries `.fontDesign(.monospaced)`
    /// through the panel, and SwiftUI would re-resolve `Font.custom` through
    /// it — Fraunces and Manrope have no monospaced cut and fall back to the
    /// body font. Every Gazette text sits under one of these.
    func gazetteFace() -> some View {
        self.fontDesign(.default)
    }
}

/// Solid category tag: caps knocked out of a hard-cornered brand block.
struct GazettePill: View {
    let text: String
    let color: Color
    var size: CGFloat = 9
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicGazette.label(self.size))
            .gazetteFace()
            .tracking(RunicGazette.labelTracking)
            .foregroundStyle(self.runicTheme.surface)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Rectangle().fill(self.color))
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Rules

/// Ink rules. `single` divides stories, `double` closes the masthead,
/// `heavy` frames a pull quote, `hair` separates columns.
struct GazetteRule: View {
    enum Weight { case hair, single, double, heavy }

    var weight: Weight = .single
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        Group {
            switch self.weight {
            case .hair:
                Rectangle().fill(ink.opacity(0.28)).frame(height: 1)
            case .single:
                Rectangle().fill(ink).frame(height: 1)
            case .heavy:
                Rectangle().fill(ink).frame(height: 3)
            case .double:
                VStack(spacing: 1) {
                    Rectangle().fill(ink).frame(height: 1)
                    Rectangle().fill(ink).frame(height: 1)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Vertical hairline between two columns of a row.
struct GazetteColumnRule: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Rectangle()
            .fill(self.runicTheme.primaryText.opacity(0.28))
            .frame(width: 1)
            .accessibilityHidden(true)
    }
}

/// Dotted leader between a label and its amount, sitting just above the
/// baseline. Place it in an `HStack(alignment: .firstTextBaseline)`.
struct GazetteLeader: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0.5))
            }
            .stroke(
                self.runicTheme.secondaryText,
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 3]))
        }
        .frame(height: 1)
        .frame(minWidth: 10, maxWidth: .infinity)
        .padding(.bottom, 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Controls

/// 22pt editorial button: ink outline, or ink block with the paper knocked
/// out when `filled`. Hover inverts it.
struct GazetteButton: View {
    let title: String
    var filled = false
    var size: CGFloat = 9.5
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        let paper = self.runicTheme.surface
        let inverted = self.filled != self.isHovered
        Button(action: self.action) {
            Text(self.title.uppercased())
                .font(RunicGazette.label(self.size))
                .gazetteFace()
                .tracking(1)
                .lineLimit(1)
                .foregroundStyle(inverted ? paper : ink)
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(Rectangle().fill(inverted ? ink : Color.clear))
                .overlay(Rectangle().stroke(ink, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
    }
}

/// "↩ Reply wanted" — a tracked caps link in the accent with a 2pt
/// underline. Decorative when `action` is nil.
struct GazetteLink: View {
    let text: String
    var action: (() -> Void)?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let label = Text(self.text.uppercased())
            .font(RunicGazette.label(9.5))
            .gazetteFace()
            .tracking(1)
            .foregroundStyle(self.runicTheme.accent)
            .lineLimit(1)
            .padding(.bottom, 1)
            .overlay(alignment: .bottom) {
                Rectangle().fill(self.runicTheme.accent).frame(height: 2)
            }
        if let action {
            Button(action: action) { label.contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            label
        }
    }
}

// MARK: - Copy

/// One In-brief item: a coloured square, an optional bold lead, the line.
struct GazetteBullet: View {
    let color: Color
    let lead: String?
    let text: String
    var detail: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\u{25AA}")
                .font(RunicGazette.sans(10.5, .bold))
                .foregroundStyle(self.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                self.line
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = self.detail, !detail.isEmpty {
                    Text(detail)
                        .font(RunicGazette.copy(10))
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .gazetteFace()
    }

    /// Runs of a concatenated `Text` resolve their own design, so the pin
    /// goes on each run, not just the container.
    private var line: Text {
        let body = Text(self.text)
            .font(RunicGazette.copy())
            .fontDesign(.default)
            .foregroundStyle(RunicGazette.inkSoft)
        guard let lead = self.lead, !lead.isEmpty else { return body }
        return Text(lead)
            .font(RunicGazette.sans(10.5, .bold))
            .fontDesign(.default)
            .foregroundStyle(self.runicTheme.primaryText)
            + Text(" ")
            + body
    }
}

/// Pull quote: italic serif framed by heavy rules above and below.
struct GazetteQuote: View {
    let text: String
    var attribution: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\u{201C}\(self.text)\u{201D}")
                .font(RunicGazette.quote())
                .foregroundStyle(self.runicTheme.primaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let attribution = self.attribution, !attribution.isEmpty {
                GazetteLabel(text: "\u{2014} \(attribution)", color: self.runicTheme.secondaryText, tracking: 1)
            }
        }
        .gazetteFace()
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { GazetteRule(weight: .heavy) }
        .overlay(alignment: .bottom) { GazetteRule(weight: .heavy) }
    }
}

/// Flat printed gauge: a hairline track on the paper, a solid fill.
struct GazetteBar: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    var height: CGFloat = 6
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(self.runicTheme.surface)
                    .overlay(Rectangle().strokeBorder(self.runicTheme.primaryText.opacity(0.35), lineWidth: 1))
                if clamped > 0 {
                    // Inside the 1pt stroke on both ends.
                    Rectangle()
                        .fill(self.tint)
                        .frame(width: max(2, (proxy.size.width - 2) * clamped / 100))
                        .padding(1)
                }
            }
        }
        .frame(height: self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped)) percent")
    }
}

/// The folio line: edition on the left, the date centred, a note on the
/// right, a rule beneath.
struct GazetteFolio: View {
    var trailing: String?
    var trailingColor: Color?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                GazetteLabel(text: RunicGazette.edition)
                Spacer(minLength: 4)
                GazetteLabel(text: RunicGazette.folioDate())
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                if let trailing = self.trailing, !trailing.isEmpty {
                    GazetteLabel(text: trailing, color: self.trailingColor)
                        .minimumScaleFactor(0.85)
                }
            }
            GazetteRule()
        }
    }
}

/// Page footer: the byline as a link, the imprint beside it, an outlined
/// button on the right.
struct GazetteFooter: View {
    /// "By Sriinnu" — opens `bylineURL`.
    let byline: String
    let bylineURL: URL
    let imprint: String
    let buttonTitle: String
    let action: () -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 8) {
            GazetteRule()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                GazetteLink(text: self.byline) {
                    NSWorkspace.shared.open(self.bylineURL)
                }
                .accessibilityLabel("\(self.byline), opens \(self.bylineURL.host ?? "link")")
                GazetteLabel(text: "\u{00B7}", color: self.runicTheme.secondaryText)
                GazetteLabel(text: self.imprint, color: self.runicTheme.secondaryText, tracking: 1.2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                GazetteButton(title: self.buttonTitle, size: 9, action: self.action)
            }
        }
        .gazetteFace()
    }
}
