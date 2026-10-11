import AppKit
import RunicCore
import SwiftUI

// MARK: - Board kit

/// Departures' kit: a Solari split-flap board. Two faces addressed by
/// PostScript name — Barlow Condensed for every cap and numeral, Barlow for
/// running copy — plus the marks the board is built from: the flap tile,
/// the ten-segment gauge, the yellow rule, the ticker, the gate card.
enum RunicDepartures {
    enum CondensedWeight { case regular, medium, semibold, bold }
    enum BodyWeight { case regular, medium, semibold }

    /// Barlow Condensed, static instances. Tabular digits on.
    static func condensed(_ size: CGFloat, _ weight: CondensedWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "BarlowCondensed-Regular"
        case .medium: "BarlowCondensed-Medium"
        case .semibold: "BarlowCondensed-SemiBold"
        case .bold: "BarlowCondensed-Bold"
        }
        return Font.custom(name, fixedSize: size).monospacedDigit()
    }

    /// Barlow, static instances. Tabular digits on.
    static func body(_ size: CGFloat, _ weight: BodyWeight = .regular) -> Font {
        let name = switch weight {
        case .regular: "Barlow-Regular"
        case .medium: "Barlow-Medium"
        case .semibold: "Barlow-SemiBold"
        }
        return Font.custom(name, fixedSize: size).monospacedDigit()
    }

    // MARK: Roles

    /// Column headers and kickers run in wide-tracked caps.
    static let headerTracking: CGFloat = 2

    static func header(_ size: CGFloat = 10) -> Font {
        self.condensed(size, .regular)
    }

    static func copy(_ size: CGFloat = 12) -> Font {
        self.body(size)
    }

    static func strong(_ size: CGFloat = 12) -> Font {
        self.body(size, .semibold)
    }

    /// Tabs, buttons, status words.
    static func caps(_ size: CGFloat = 13) -> Font {
        self.condensed(size, .semibold)
    }

    /// Window and provider names on a row.
    static func name(_ size: CGFloat = 16) -> Font {
        self.condensed(size, .semibold)
    }

    static func numeral(_ size: CGFloat) -> Font {
        self.condensed(size, .bold)
    }

    // MARK: Gates

    /// Gate letters follow provider order: Codex is A, OpenCode B, Claude
    /// C… so a provider keeps its gate on every page. Past Z the letter
    /// takes a number, the way a terminal's annex does.
    static func gate(for provider: UsageProvider) -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        guard let index = UsageProvider.allCases.firstIndex(of: provider) else { return "?" }
        let letter = String(letters[index % letters.count])
        let annex = index / letters.count
        return annex == 0 ? letter : "\(letter)\(annex)"
    }

    // MARK: Time

    /// The board clock: 24-hour, zero-padded, whatever the locale.
    @MainActor static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    @MainActor static func clock(_ date: Date) -> String {
        self.clockFormatter.string(from: date)
    }

    /// The TIME column: "15 39" today, "WED" within the week, "NOV 5" after.
    @MainActor static func boardTime(_ date: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return self.clock(date).replacingOccurrences(of: ":", with: " ")
        }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)).day ?? 0
        if days >= 0, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        }
        return date.formatted(.dateTime.month(.abbreviated).day()).uppercased()
    }

    /// The REMAINING column: "02 14" (hours, minutes) under a day, "3D 5H"
    /// from a day up, "NOW" once it has passed.
    static func boardRemaining(_ seconds: TimeInterval) -> String {
        guard seconds > 30 else { return "NOW" }
        let minutes = max(1, Int(ceil(seconds / 60)))
        let days = minutes / 1440
        let hours = (minutes / 60) % 24
        let mins = minutes % 60
        if days > 0 { return hours > 0 ? "\(days)D \(hours)H" : "\(days)D" }
        return String(format: "%02d %02d", hours, mins)
    }

    /// The masthead's countdown: "18M", "2H 14M", "3D 5H".
    static func flapCountdown(_ seconds: TimeInterval) -> String {
        guard seconds > 30 else { return "NOW" }
        let minutes = max(1, Int(ceil(seconds / 60)))
        let days = minutes / 1440
        let hours = (minutes / 60) % 24
        let mins = minutes % 60
        if days > 0 { return hours > 0 ? "\(days)D \(hours)H" : "\(days)D" }
        if hours > 0 { return mins > 0 ? "\(hours)H \(mins)M" : "\(hours)H" }
        return "\(mins)M"
    }

    /// Reads a countdown out of the copy the cards already carry — "↻ in
    /// 2h 14m", "Resets in 3d 5h · Thu 9:00 AM", "in 45m" — as seconds.
    /// Nil when the text names no countdown ("Resets tomorrow 9:00 AM").
    static func countdownSeconds(in text: String?) -> TimeInterval? {
        guard let text = text?.lowercased(), let range = text.range(of: "in ") else { return nil }
        var rest = text[range.upperBound...]
        if let stop = rest.range(of: " \u{00B7} ") { rest = rest[..<stop.lowerBound] }
        var total: TimeInterval = 0
        var found = false
        for token in rest.split(separator: " ") {
            guard let unit = token.last, let value = Double(token.dropLast()) else { break }
            switch unit {
            case "d": total += value * 86400
            case "h": total += value * 3600
            case "m": total += value * 60
            default: return found ? total : nil
            }
            found = true
        }
        return found ? total : nil
    }

    /// Splits "Context health: max ctx ~272K" into a label and its value.
    static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let range = line.range(of: ": "),
              line.distance(from: line.startIndex, to: range.lowerBound) <= 28
        else { return nil }
        return (String(line[..<range.lowerBound]), String(line[range.upperBound...]))
    }

    /// Board copy: caps, no colons or brackets, a real minus sign.
    static func boardCopy(_ text: String) -> String {
        text.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "(-", with: "\u{2212}")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "\u{21BB} ", with: "")
            .uppercased()
    }
}

// MARK: - Flap tiles

/// A tile size: the masthead runs large, the table standard, status words
/// small.
struct FlapScale {
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat

    static let masthead = FlapScale(width: 20, height: 28, fontSize: 20)
    static let table = FlapScale(width: 14, height: 24, fontSize: 16)
    static let status = FlapScale(width: 12, height: 21, fontSize: 13)
}

/// One character on a split flap: a dark rounded tile with a highlight
/// along its top edge and a seam across the middle where the two halves
/// meet, a hard 1pt drop beneath.
struct FlapTile: View {
    let character: Character
    var tint: Color?
    var scale: FlapScale = .table
    var widthScale: CGFloat = 1
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let width = self.scale.width * self.widthScale
        let fontSize = self.scale.fontSize * min(1, self.widthScale)
        Text(String(self.character))
            .font(RunicDepartures.condensed(fontSize, .semibold))
            .skinFace()
            .foregroundStyle(self.tint ?? self.runicTheme.primaryText)
            .frame(width: width, height: self.scale.height)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.black)
                        .offset(y: 1)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(self.runicTheme.cardFill)
                }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 1)
                    .padding(.top, 1)
            }
            .overlay {
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 1)
            }
            .accessibilityHidden(true)
    }
}

/// A string on flaps: one tile per character, a 10pt gap for a space, and
/// as many tints as the line has segments ("NEXT" white, "18M" yellow,
/// "CLAUDE" red). Pass `fit` to let the tiles narrow for a long name.
struct FlapRow: View {
    struct Segment {
        let text: String
        var tint: Color?
    }

    let segments: [Segment]
    var scale: FlapScale = .table
    var fit: CGFloat?

    private static let gap: CGFloat = 10
    private static let seam: CGFloat = 2

    init(segments: [Segment], scale: FlapScale = .table, fit: CGFloat? = nil) {
        self.segments = segments
        self.scale = scale
        self.fit = fit
    }

    init(text: String, tint: Color? = nil, scale: FlapScale = .table, fit: CGFloat? = nil) {
        self.init(segments: [Segment(text: text, tint: tint)], scale: scale, fit: fit)
    }

    private struct Cell: Identifiable {
        let id: Int
        let character: Character
        let tint: Color?
    }

    private var cells: [Cell] {
        var cells: [Cell] = []
        for (index, segment) in self.segments.enumerated() {
            if index > 0 { cells.append(Cell(id: cells.count, character: " ", tint: nil)) }
            for character in segment.text.uppercased() {
                cells.append(Cell(id: cells.count, character: character, tint: segment.tint))
            }
        }
        return cells
    }

    var body: some View {
        let cells = self.cells
        let tiles = cells.count(where: { $0.character != " " })
        let spaces = cells.count - tiles
        let natural = CGFloat(tiles) * self.scale.width + CGFloat(spaces) * Self.gap
            + CGFloat(max(0, cells.count - 1)) * Self.seam
        let widthScale: CGFloat = {
            guard let fit, natural > fit, tiles > 0 else { return 1 }
            let room = fit - CGFloat(spaces) * Self.gap - CGFloat(max(0, cells.count - 1)) * Self.seam
            return max(0.55, room / (CGFloat(tiles) * self.scale.width))
        }()
        HStack(spacing: Self.seam) {
            ForEach(cells) { cell in
                if cell.character == " " {
                    Color.clear.frame(width: Self.gap, height: self.scale.height)
                } else {
                    FlapTile(character: cell.character, tint: cell.tint, scale: self.scale, widthScale: widthScale)
                }
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.segments.map(\.text).joined(separator: " "))
    }
}

// MARK: - Labels, rules, ticker

/// Tracked caps in Barlow Condensed: column headers, kickers, metadata.
struct DeparturesHeader: View {
    let text: String
    var size: CGFloat = 10
    var color: Color?
    var tracking: CGFloat = RunicDepartures.headerTracking
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicDepartures.header(self.size))
            .skinFace()
            .tracking(self.tracking)
            .foregroundStyle(self.color ?? self.runicTheme.secondary)
            .lineLimit(1)
    }
}

/// The 2pt board-yellow rule under a masthead.
struct DeparturesRule: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Rectangle()
            .fill(self.runicTheme.accent)
            .frame(height: 2)
            .accessibilityHidden(true)
    }
}

/// A 1pt hairline between rows.
struct DeparturesHairline: View {
    var opacity: Double = 0.08
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Rectangle()
            .fill(self.runicTheme.primaryText.opacity(self.opacity))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// The ticker: one tracked yellow line on the frame tone, ruled above and
/// below, dotted at both ends.
struct DeparturesTicker: View {
    let text: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text("\u{00B7} \u{00B7} \u{00B7}  \(self.text.uppercased())  \u{00B7} \u{00B7} \u{00B7}")
            .font(RunicDepartures.condensed(11))
            .skinFace()
            .tracking(1.5)
            .foregroundStyle(self.runicTheme.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(self.runicTheme.surfaceAlt)
            .overlay(alignment: .top) { DeparturesHairline(opacity: 0.12) }
            .overlay(alignment: .bottom) { DeparturesHairline(opacity: 0.12) }
    }
}

/// The board clock: HH:mm, refreshed every half minute.
struct DeparturesClock: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(RunicDepartures.clock(context.date))
                .font(RunicDepartures.condensed(12))
                .skinFace()
                .tracking(1.7)
                .foregroundStyle(self.runicTheme.secondary)
                .lineLimit(1)
                .accessibilityLabel("Board clock \(RunicDepartures.clock(context.date))")
        }
    }
}

// MARK: - Gauges

/// Ten segments, 4pt tall: the used share lit in the tint, the rest in
/// the tile tone.
struct DeparturesSegmentBar: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    var height: CGFloat = 4
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        let lit = Int((clamped / 10).rounded())
        HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { index in
                Rectangle()
                    .fill(index < lit ? self.tint : self.runicTheme.cardStroke.opacity(0.7))
                    .frame(height: self.height)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped)) percent")
    }
}

/// One gate on the front: "B · CODEX" with the percent in the tint, the
/// ten-segment gauge, and a line of context under it.
struct DeparturesGateCard: View {
    let letter: String
    let name: String
    let percentText: String
    let percent: Double?
    let tint: Color
    let detail: String?
    let accessibilityLabel: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(self.letter) \u{00B7} \(self.name.uppercased())")
                    .font(RunicDepartures.name(15))
                    .skinFace()
                    .tracking(0.9)
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(self.percentText)
                    .font(RunicDepartures.numeral(18))
                    .skinFace()
                    .foregroundStyle(self.tint)
                    .lineLimit(1)
            }
            if let percent {
                DeparturesSegmentBar(percent: percent, tint: self.tint, accessibilityLabel: self.accessibilityLabel)
            } else {
                DeparturesSegmentBar(percent: 0, tint: self.tint, accessibilityLabel: self.accessibilityLabel)
                    .opacity(0.5)
            }
            if let detail, !detail.isEmpty {
                Text(detail.uppercased())
                    .font(RunicDepartures.condensed(11))
                    .skinFace()
                    .tracking(1.1)
                    .foregroundStyle(self.runicTheme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(self.runicTheme.surfaceAlt))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(self.runicTheme.cardStroke.opacity(0.7), lineWidth: 1))
    }
}

// MARK: - Rows and controls

/// A plain table row: the label in tracked caps, the value in Barlow on
/// the right, a hairline beneath.
struct DeparturesKeyValue: View {
    let label: String
    let value: String
    var valueColor: Color?
    var detail: String?
    var isLast = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                DeparturesHeader(text: self.label, size: 11, tracking: 1.4)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text(self.value)
                    .font(RunicDepartures.strong(12.5))
                    .skinFace()
                    .foregroundStyle(self.valueColor ?? self.runicTheme.primaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.bottom, self.detail == nil ? 8 : 3)
            if let detail = self.detail, !detail.isEmpty {
                Text(detail)
                    .font(RunicDepartures.copy(11))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)
            }
            if !self.isLast {
                DeparturesHairline()
            }
        }
    }
}

/// A board button: a dark rectangle with a 1pt stroke and tracked caps.
/// `filled` makes it the yellow primary.
struct DeparturesButton: View {
    let title: String
    var filled = false
    var systemImage: String?
    var expands = false
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = Color(red: 0.067, green: 0.067, blue: 0.071)
        let yellow = self.runicTheme.accent
        Button(action: self.action) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(self.title.uppercased())
                    .font(RunicDepartures.caps(12))
                    .skinFace()
                    .tracking(1.9)
                    .lineLimit(1)
            }
            .foregroundStyle(self.filled ? ink : self.runicTheme.primaryText)
            .padding(.horizontal, 14)
            .frame(maxWidth: self.expands ? .infinity : nil)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(self.filled
                        ? (self.isHovered ? yellow.opacity(0.88) : yellow)
                        : (self.isHovered ? self.runicTheme.cardStroke.opacity(0.6) : self.runicTheme.cardFill)))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(self.filled ? yellow : self.runicTheme.cardStroke, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}

// MARK: - Departure rows

/// Column widths for the departures table: TIME, REMAINING and STATUS are
/// fixed so every row's flaps line up; WINDOW takes the rest.
enum DeparturesColumns {
    static let time: CGFloat = 80
    static let remaining: CGFloat = 72
    static let status: CGFloat = 54
    static let gap: CGFloat = 8

    static func window(in width: CGFloat) -> CGFloat {
        max(60, width - self.time - self.remaining - self.status - self.gap * 3)
    }
}

/// The header row: TIME / WINDOW / REMAINING / STATUS.
struct DeparturesTableHeader: View {
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DeparturesColumns.gap) {
                DeparturesHeader(text: "Time")
                    .frame(width: DeparturesColumns.time, alignment: .leading)
                DeparturesHeader(text: "Window")
                    .frame(width: DeparturesColumns.window(in: self.width), alignment: .leading)
                DeparturesHeader(text: "Remaining")
                    .frame(width: DeparturesColumns.remaining, alignment: .leading)
                DeparturesHeader(text: "Status")
                    .frame(width: DeparturesColumns.status, alignment: .trailing)
            }
            .padding(.top, 6)
            .padding(.bottom, 6)
            DeparturesHairline(opacity: 0.22)
        }
        .accessibilityHidden(true)
    }
}

/// A status word on small flaps: OPEN, OUT, HELD, DUE.
struct DeparturesStatus {
    let word: String
    let tint: Color

    static func forWindow(exhausted: Bool, secondsUntilReset: TimeInterval?, palette: RunicThemePalette) -> Self {
        if exhausted { return Self(word: "OUT", tint: palette.warm) }
        if let seconds = secondsUntilReset, seconds <= 30 * 60 { return Self(word: "DUE", tint: palette.accent) }
        return Self(word: "OPEN", tint: palette.highlight)
    }

    static func held(_ palette: RunicThemePalette) -> Self {
        Self(word: "HELD", tint: palette.accent)
    }
}

/// One departure: time flaps, the window with a line under it (and an
/// optional gauge), the remaining flaps, the status word. Any column may be
/// a dash when the provider gave no date.
struct DeparturesRow: View {
    let width: CGFloat
    let time: String?
    let title: String
    let subtitle: String?
    var gauge: (percent: Double, tint: Color, label: String)?
    let remaining: String?
    /// Plain copy in the remaining column when there are no flaps to show
    /// (a balance, a provider's own phrase).
    var remainingText: String?
    let status: DeparturesStatus?
    let accessibilityLabel: String
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .center, spacing: DeparturesColumns.gap) {
            Group {
                if let time {
                    FlapRow(text: time, tint: self.runicTheme.accent, fit: DeparturesColumns.time)
                } else {
                    self.dash
                }
            }
            .frame(width: DeparturesColumns.time, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(self.title.uppercased())
                    .font(RunicDepartures.name(16))
                    .skinFace()
                    .tracking(0.6)
                    .foregroundStyle(self.runicTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let gauge {
                    DeparturesSegmentBar(percent: gauge.percent, tint: gauge.tint, accessibilityLabel: gauge.label)
                        .frame(maxWidth: 110)
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle.uppercased())
                        .font(RunicDepartures.condensed(11))
                        .skinFace()
                        .tracking(1.3)
                        .foregroundStyle(self.runicTheme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(width: DeparturesColumns.window(in: self.width), alignment: .leading)

            Group {
                if let remaining {
                    FlapRow(text: remaining, fit: DeparturesColumns.remaining)
                } else if let remainingText, !remainingText.isEmpty {
                    Text(remainingText)
                        .font(RunicDepartures.condensed(13, .medium))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.leading)
                } else {
                    self.dash
                }
            }
            .frame(width: DeparturesColumns.remaining, alignment: .leading)

            Group {
                if let status {
                    FlapRow(text: status.word, tint: status.tint, scale: .status)
                } else {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
            .frame(width: DeparturesColumns.status, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
    }

    private var dash: some View {
        Text("\u{2014}")
            .font(RunicDepartures.condensed(16, .medium))
            .skinFace()
            .foregroundStyle(self.runicTheme.secondary)
    }
}
