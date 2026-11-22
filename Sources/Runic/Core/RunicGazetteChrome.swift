import AppKit
import RunicCore
import SwiftUI

// MARK: - Editorial Kit

/// The Gazette's WSJ / NY Times broadsheet kit: adaptive Morning (light) and
/// Evening (dark) inks derived from `runicTheme`, classic transitional serif
/// (`Baskerville` nameplate), crisp digital broadsheet (`Georgia` headlines,
/// numerals, body, and italic decks/status), and condensed grotesque
/// (`Archivo Narrow` datelines, kickers, hairline tags, and tabular metadata).
enum RunicGazette {
    static let pageHorizontalInset: CGFloat = RunicSpacing.xxs
    static let labelTracking: CGFloat = 0.8

    // MARK: Adaptive Inks

    static func bodyInk(_ theme: RunicThemePalette) -> Color {
        theme.primaryText.opacity(0.88)
    }

    static func trackFill(_ theme: RunicThemePalette, dark: Bool) -> Color {
        theme.primaryText.opacity(dark ? 0.18 : 0.12)
    }

    static func gaugeTint(used: Double?, exhausted: Bool, theme: RunicThemePalette) -> Color {
        if exhausted { return theme.warm }
        if let used, used >= 80 { return theme.highlight }
        return theme.primaryText
    }

    static func bulletColor(_ index: Int, theme: RunicThemePalette) -> Color {
        let cycle = [theme.primaryText, theme.warm, theme.tertiary, theme.highlight, theme.secondaryText]
        return cycle[((index % cycle.count) + cycle.count) % cycle.count]
    }

    // MARK: Metric Helpers

    static func usedShare(_ metric: UsageMenuCardView.Model.Metric) -> Double? {
        guard let percent = metric.percent else { return nil }
        switch metric.percentStyle {
        case .used: return percent
        case .left: return 100 - percent
        }
    }

    static func isExhausted(_ metric: UsageMenuCardView.Model.Metric) -> Bool {
        guard let used = self.usedShare(metric) else { return false }
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

    // MARK: Faces

    enum SerifWeight { case regular, semibold, bold, black, italic, boldItalic }
    enum SansWeight { case regular, medium, semibold, bold }

    /// Georgia + Baskerville editorial serifs. Crisp at every size.
    static func serif(_ size: CGFloat, _ weight: SerifWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "Georgia"
        case .semibold: "Baskerville-SemiBold"
        case .bold: "Georgia-Bold"
        case .black: "Baskerville-Bold"
        case .italic: "Georgia-Italic"
        case .boldItalic: "Georgia-BoldItalic"
        }
        return Font.custom(name, fixedSize: size)
    }

    /// Archivo Narrow condensed static instances. Datelines, kickers, tabs,
    /// badges, and tabular metadata.
    static func sans(_ size: CGFloat, _ weight: SansWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "ArchivoNarrow-Regular"
        case .medium: "ArchivoNarrow-Medium"
        case .semibold: "ArchivoNarrow-SemiBold"
        case .bold: "ArchivoNarrow-Bold"
        }
        return Font.custom(name, fixedSize: size)
    }

    // MARK: Roles

    /// Condensed tracked uppercase labels: folio dateline, metadata, tab labels.
    static func label(_ size: CGFloat = 9.5) -> Font {
        self.sans(size, .bold)
    }

    /// Flush-left section kickers (`QUOTA LEDGER`, `SESSION`, `WEEKLY`, `RESETS`).
    static func kicker(_ size: CGFloat = 10) -> Font {
        self.sans(size, .bold)
    }

    /// Story & provider row headline (`Georgia-Bold`).
    static func headline(_ size: CGFloat) -> Font {
        self.serif(size, .bold)
    }

    /// Upright broadsheet numerals (`100%`, `48%`). Pair with `.monospacedDigit()`.
    static func numeral(_ size: CGFloat) -> Font {
        self.serif(size, .bold)
    }

    /// Italic editorial status word (*exhausted*, *used*).
    static func statusItalic(_ size: CGFloat) -> Font {
        self.serif(size, .italic)
    }

    /// Classical broadsheet masthead (`Baskerville-Bold`).
    static func nameplate(_ size: CGFloat = 29) -> Font {
        .custom("Baskerville-Bold", fixedSize: size)
    }

    /// Editorial deck or pull-quote italic (`Georgia-Italic`).
    static func deckItalic(_ size: CGFloat = 11.5) -> Font {
        self.serif(size, .italic)
    }

    /// Lead-story prose (`Georgia`).
    static func body(_ size: CGFloat = 12) -> Font {
        self.serif(size, .regular)
    }

    /// Secondary condensed metadata copy (`ArchivoNarrow-Medium`).
    static func copy(_ size: CGFloat = 10) -> Font {
        self.sans(size, .medium)
    }

    /// Pull quote (`Georgia-Italic`).
    static func quote(_ size: CGFloat = 12.5) -> Font {
        self.serif(size, .italic)
    }

    // MARK: Folio

    /// "Vol. II · No. 221" — the marketing major in Roman numerals as the
    /// volume, the build as the issue number. Read once.
    static let edition: String = {
        let majorText = RunicVersion.marketing.split(separator: ".").first.map(String.init) ?? RunicVersion.marketing
        let volume = Self.romanNumeral(for: Int(majorText)) ?? majorText
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "Vol. \(volume) \u{00B7} No. \(build)"
        }
        return "Vol. \(volume)"
    }()

    private static func romanNumeral(for value: Int?) -> String? {
        guard let value else { return nil }
        switch value {
        case 1: return "I"
        case 2: return "II"
        case 3: return "III"
        case 4: return "IV"
        case 5: return "V"
        case 6: return "VI"
        case 7: return "VII"
        case 8: return "VIII"
        case 9: return "IX"
        case 10: return "X"
        default: return nil
        }
    }

    /// Fixed POSIX/US broadsheet dateline ("Sunday, Nov. 22, 2026").
    /// Condensed typography allows the full weekday + abbreviated month to fit cleanly.
    private static let folioFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM. d, yyyy"
        return formatter
    }()

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

// MARK: - Typography Protection

extension View {
    /// Clears any inherited `.monospaced` font design so custom PostScript
    /// fonts (`Baskerville`, `Georgia`, `Archivo Narrow`) never fall back to
    /// the generic user body font.
    func gazetteFace() -> some View {
        self.fontDesign(nil)
    }
}

// MARK: - Labels, Kickers and Hairline Tags

/// Condensed tracked uppercase caption in Archivo Narrow Bold: folio, metadata.
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

/// Flush-left broadsheet section kicker (`QUOTA LEDGER`, `SESSION`, `WEEKLY`).
/// Monochrome uppercase typography — no solid category ribbons.
struct GazetteKicker: View {
    let text: String
    var size: CGFloat = 10
    var color: Color?
    var tracking: CGFloat = 1.0
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicGazette.kicker(self.size))
            .gazetteFace()
            .tracking(self.tracking)
            .foregroundStyle(self.color ?? self.runicTheme.primaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Legacy source-compatible section header alias rendered as a flat editorial
/// kicker so any external call site stays consistent with the print grid.
struct GazettePill: View {
    let text: String
    var color: Color?
    var size: CGFloat = 10

    var body: some View {
        GazetteKicker(text: self.text, size: self.size, color: self.color)
    }
}

/// Crisp 1px rectangular broadsheet tag (`PRO`, `ULTRA`, `EXHAUSTED`, `[2]`).
struct GazetteHairlineBadge: View {
    let text: String
    var textColor: Color?
    var borderColor: Color?
    var fillColor: Color = .clear
    var size: CGFloat = 8.5

    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        Text(self.text.uppercased())
            .font(RunicGazette.sans(self.size, .semibold))
            .gazetteFace()
            .tracking(0.6)
            .foregroundStyle(self.textColor ?? self.runicTheme.secondaryText)
            .lineLimit(1)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1)
            .background(shape.fill(self.fillColor))
            .overlay(shape.strokeBorder(self.borderColor ?? self.runicTheme.cardStroke, lineWidth: 0.9))
            .fixedSize()
    }
}

// MARK: - Rules and Leaders

/// Broadsheet horizontal ink rules:
/// - `hair`: 0.5pt row divider inside a ledger
/// - `single`: 1pt section / folio rule
/// - `heavy`: 2pt section topper rule
/// - `double`: classic WSJ / NYT masthead rule (2pt heavy over 0.5pt hair)
struct GazetteRule: View {
    enum Weight { case hair, single, double, heavy }

    var weight: Weight = .single
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        Group {
            switch self.weight {
            case .hair:
                Rectangle().fill(ink.opacity(0.22)).frame(height: 0.75)
            case .single:
                Rectangle().fill(ink.opacity(0.85)).frame(height: 1)
            case .heavy:
                Rectangle().fill(ink).frame(height: 2)
            case .double:
                VStack(spacing: 2) {
                    Rectangle().fill(ink).frame(height: 2)
                    Rectangle().fill(ink.opacity(0.75)).frame(height: 0.75)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Vertical hairline between two broadsheet columns.
struct GazetteColumnRule: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Rectangle()
            .fill(self.runicTheme.primaryText.opacity(0.26))
            .frame(width: 0.75)
            .accessibilityHidden(true)
    }
}

/// Crisp baseline dotted leader between a row headline and its tabular numeral.
struct GazetteLeader: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0.5))
            }
            .stroke(
                self.runicTheme.secondaryText.opacity(0.65),
                style: StrokeStyle(lineWidth: 1.0, lineCap: .round, dash: [0.2, 3.2]))
        }
        .frame(height: 1)
        .frame(minWidth: 10, maxWidth: .infinity)
        .padding(.bottom, 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Controls

/// Crisp 1px rectangular broadsheet button with clean paper/ink hover inversion.
struct GazetteButton: View {
    let title: String
    var filled = false
    var size: CGFloat = 9.5
    var height: CGFloat = 22
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primaryText
        let paper = self.runicTheme.surface
        let inverted = self.filled != self.isHovered
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        Button(action: self.action) {
            Text(self.title.uppercased())
                .font(RunicGazette.label(self.size))
                .gazetteFace()
                .tracking(0.8)
                .lineLimit(1)
                .foregroundStyle(inverted ? paper : ink)
                .padding(.horizontal, 10)
                .frame(height: self.height)
                .background(shape.fill(inverted ? ink : paper))
                .overlay(shape.strokeBorder(ink.opacity(inverted ? 1 : 0.45), lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
    }
}

/// Understated broadsheet inline link in ink with a crisp 1pt underline.
struct GazetteLink: View {
    let text: String
    var action: (() -> Void)?
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let label = Text(self.text.uppercased())
            .font(RunicGazette.sans(9.5, .semibold))
            .gazetteFace()
            .tracking(0.8)
            .foregroundStyle(self.isHovered ? self.runicTheme.secondaryText : self.runicTheme.primaryText)
            .lineLimit(1)
            .padding(.bottom, 1)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill((self.isHovered ? self.runicTheme.secondaryText : self.runicTheme.primaryText).opacity(0.65))
                    .frame(height: 1)
            }
        if let action {
            Button(action: action) { label.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .onHover { self.isHovered = $0 }
        } else {
            label
        }
    }
}

// MARK: - Editorial Copy

/// One In-brief item: a square marker, bold serif lead, and adaptive body ink.
struct GazetteBullet: View {
    let color: Color
    let lead: String?
    let text: String
    var detail: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\u{25AA}")
                .font(RunicGazette.sans(10, .bold))
                .foregroundStyle(self.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                self.line
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = self.detail, !detail.isEmpty {
                    Text(detail)
                        .font(RunicGazette.copy(9.5))
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .gazetteFace()
    }

    private var line: Text {
        let body = Text(self.text)
            .font(RunicGazette.body(11))
            .fontDesign(nil)
            .foregroundStyle(RunicGazette.bodyInk(self.runicTheme))
        guard let lead = self.lead, !lead.isEmpty else { return body }
        return Text("\(lead):")
            .font(RunicGazette.headline(11))
            .fontDesign(nil)
            .foregroundStyle(self.runicTheme.primaryText)
            + Text(" ")
            + body
    }
}

/// Pull quote: Georgia Italic framed by heavy top & bottom ink rules.
struct GazetteQuote: View {
    let text: String
    var attribution: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\u{201C}\(self.text)\u{201D}")
                .font(RunicGazette.quote(12))
                .foregroundStyle(self.runicTheme.primaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            if let attribution = self.attribution, !attribution.isEmpty {
                GazetteLabel(text: "\u{2014} \(attribution)", size: 8.5, color: self.runicTheme.secondaryText)
            }
        }
        .gazetteFace()
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { GazetteRule(weight: .heavy) }
        .overlay(alignment: .bottom) { GazetteRule(weight: .heavy) }
    }
}

/// Razor-thin flat newsprint gauge with optional vertical pace marker tick.
struct GazetteBar: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    var marker: Double?
    var height: CGFloat = 4
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        let dark = self.colorScheme == .dark
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(RunicGazette.trackFill(self.runicTheme, dark: dark))
                    .frame(height: self.height)
                if clamped > 0 {
                    Rectangle()
                        .fill(self.tint)
                        .frame(width: max(2, proxy.size.width * clamped / 100), height: self.height)
                }
                if let marker = self.marker {
                    let x = max(0, min(proxy.size.width - 1.5, proxy.size.width * marker / 100))
                    Rectangle()
                        .fill(self.runicTheme.primaryText.opacity(0.85))
                        .frame(width: 1.5, height: self.height + 4)
                        .offset(x: x)
                }
            }
            .frame(height: self.height)
        }
        .frame(height: self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped)) percent")
    }
}

/// Top dateline bar framed by 1pt rules: Edition | Date | Freshness or Active count.
struct GazetteFolio: View {
    var trailing: String?
    var trailingColor: Color?
    var showsTopRule = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 4) {
            if self.showsTopRule {
                GazetteRule(weight: .single)
            }
            HStack(alignment: .center, spacing: 6) {
                GazetteLabel(
                    text: RunicGazette.edition,
                    size: 8.5,
                    color: self.runicTheme.secondaryText,
                    tracking: 0.6)
                GazetteColumnRule().frame(height: 9)
                Spacer(minLength: 2)
                GazetteLabel(
                    text: RunicGazette.folioDate(),
                    size: 8.5,
                    color: self.runicTheme.secondaryText,
                    tracking: 0.6)
                    .minimumScaleFactor(0.78)
                if let trailing = self.trailing, !trailing.isEmpty {
                    Spacer(minLength: 2)
                    GazetteColumnRule().frame(height: 9)
                    GazetteLabel(
                        text: trailing,
                        size: 8.5,
                        color: self.trailingColor ?? self.runicTheme.secondaryText,
                        tracking: 0.6)
                        .minimumScaleFactor(0.78)
                }
            }
            GazetteRule(weight: .single)
        }
    }
}

/// Broadsheet colophon footer: 1pt rule, version + issue + author link, About button.
struct GazetteFooter: View {
    let byline: String
    let bylineURL: URL
    let imprint: String
    let buttonTitle: String
    let action: () -> Void

    @State private var isBylineHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: 6) {
            GazetteRule(weight: .single)
            HStack(alignment: .center, spacing: 6) {
                GazetteLabel(
                    text: self.imprint,
                    size: 8.5,
                    color: self.runicTheme.secondaryText,
                    tracking: 0.6)
                    .minimumScaleFactor(0.8)
                GazetteColumnRule().frame(height: 9)
                Button {
                    NSWorkspace.shared.open(self.bylineURL)
                } label: {
                    Text(self.byline.uppercased())
                        .font(RunicGazette.sans(8.5, .semibold))
                        .gazetteFace()
                        .tracking(0.6)
                        .foregroundStyle(
                            self.isBylineHovered ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
                        .lineLimit(1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { self.isBylineHovered = $0 }
                .accessibilityLabel("\(self.byline), opens \(self.bylineURL.host ?? "link")")
                Spacer(minLength: 8)
                GazetteButton(title: self.buttonTitle, size: 8.5, height: 20, action: self.action)
            }
            .padding(.horizontal, RunicGazette.pageHorizontalInset)
        }
        .gazetteFace()
    }
}
