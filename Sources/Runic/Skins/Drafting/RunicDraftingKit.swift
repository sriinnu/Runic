import AppKit
import RunicCore
import SwiftUI

// MARK: - Drafting kit

/// Drafting's kit: an engineering drawing sheet. Two faces addressed by
/// PostScript name — Geist for titles and copy, Geist Mono for every
/// dimension, label and table — plus the marks a sheet is composed from:
/// ruled cells, crop marks, numbered callouts, the dimensioned bar with its
/// hatched fill, the tilted check stamp, outlined mono-caps buttons.
enum RunicDrafting {
    enum Weight { case regular, medium, semibold, bold }

    /// Geist, static instances.
    static func sans(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        let name = switch weight {
        case .regular: "Geist-Regular"
        case .medium: "Geist-Medium"
        case .semibold: "Geist-SemiBold"
        case .bold: "Geist-Bold"
        }
        return Font.custom(name, fixedSize: size)
    }

    /// Geist Mono, static instances.
    static func mono(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        let name = switch weight {
        case .regular: "GeistMono-Regular"
        case .medium: "GeistMono-Medium"
        case .semibold: "GeistMono-SemiBold"
        case .bold: "GeistMono-Bold"
        }
        return Font.custom(name, fixedSize: size)
    }

    // MARK: Roles

    /// Tracked mono caps: `.16em` at 9.5pt.
    static let capTracking: CGFloat = 1.5

    static func cap(_ size: CGFloat = 9.5) -> Font {
        self.mono(size, .medium)
    }

    static func copy(_ size: CGFloat = 12) -> Font {
        self.sans(size)
    }

    static func strong(_ size: CGFloat = 12) -> Font {
        self.sans(size, .semibold)
    }

    static func title(_ size: CGFloat = 26) -> Font {
        self.sans(size, .semibold)
    }

    static func numeral(_ size: CGFloat, _ weight: Weight = .bold) -> Font {
        self.mono(size, weight)
    }

    // MARK: Sheet data

    /// The build number: the drawing's revision. `nil` outside an app bundle
    /// (a bare debug binary has no Info.plist). Read once.
    static let build: String? = {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty { return build }
        return nil
    }()

    /// The REV cell: the build, or the marketing version when there is none.
    static var revision: String {
        self.build ?? RunicVersion.marketing
    }

    /// "11 OCT" or "11 OCT 26" — the date cell of a title block.
    static func dateStamp(_ date: Date = .now, withYear: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = withYear ? "d MMM yy" : "d MMM"
        return formatter.string(from: date).uppercased()
    }

    /// "RN-CDX" for Codex, "RN-CLD" for Claude: the provider's name as a
    /// three-letter drawing code — initial plus consonants, padded.
    static func drawingNumber(for name: String) -> String {
        let letters = name.uppercased().filter(\.isLetter)
        guard let first = letters.first else { return "RN-\u{2014}" }
        let vowels: Set<Character> = ["A", "E", "I", "O", "U"]
        var code = String(first)
        for char in letters.dropFirst() where code.count < 3 && !vowels.contains(char) {
            code.append(char)
        }
        for char in letters.dropFirst() where code.count < 3 {
            code.append(char)
        }
        return "RN-\(code)"
    }

    /// "Sht 2 · Codex" — a sheet index tab; the overview is the general
    /// arrangement.
    static func sheetTitle(index: Int, label: String, isOverview: Bool) -> String {
        "Sht \(index + 1) \u{00B7} \(isOverview ? "GA" : label)"
    }

    /// "Resets in 2h 14m · 17:35" → "RESET 2h 14m → 17:35".
    static func resetCallout(_ text: String) -> String {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["Resets ", "resets ", "\u{21BB} ", "in "] where body.hasPrefix(prefix) {
            body = String(body.dropFirst(prefix.count))
        }
        body = body.replacingOccurrences(of: " \u{00B7} ", with: " \u{2192} ")
        return "RESET \(body)"
    }

    /// The signed delta inside a pace line: "Pace: Behind (-34%) · …" → −34.
    static func paceDelta(_ detail: String) -> Double? {
        guard detail.hasPrefix("Pace:"),
              let open = detail.range(of: "("), let close = detail.range(of: "%)"),
              open.upperBound < close.lowerBound
        else { return nil }
        let raw = detail[open.upperBound..<close.lowerBound].replacingOccurrences(of: "+", with: "")
        guard let delta = Double(raw), delta != 0 else { return nil }
        return delta
    }

    /// "Pace: Behind (-34%) · …" → "PACE −34% (BEHIND)".
    static func paceCallout(_ detail: String) -> String? {
        guard let delta = self.paceDelta(detail) else { return nil }
        let label = detail
            .dropFirst("Pace:".count)
            .split(separator: "(").first?
            .trimmingCharacters(in: .whitespaces) ?? "pace"
        let sign = delta < 0 ? "\u{2212}" : "+"
        return "PACE \(sign)\(Int(abs(delta).rounded()))% (\(label.uppercased()))"
    }

    /// Splits "Context health: max ctx ~272K" into a label and its value.
    static func keyValue(_ line: String) -> (key: String, value: String)? {
        guard let range = line.range(of: ": "),
              line.distance(from: line.startIndex, to: range.lowerBound) <= 28
        else { return nil }
        return (String(line[..<range.lowerBound]), String(line[range.upperBound...]))
    }

    /// Circled figure for a callout: ①, ②, … up to ⑳, then the digits.
    static func circled(_ number: Int) -> String {
        guard number >= 1, number <= 20, let scalar = UnicodeScalar(0x2460 + number - 1) else {
            return "\(number)"
        }
        return String(Character(scalar))
    }
}

// MARK: - Labels

/// Tracked uppercase mono caption: the cap of a cell, a section label.
struct DraftingCap: View {
    let text: String
    var size: CGFloat = 9.5
    var color: Color?
    var tracking: CGFloat = RunicDrafting.capTracking
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text(self.text.uppercased())
            .font(RunicDrafting.cap(self.size))
            .skinFace()
            .tracking(self.tracking)
            .foregroundStyle(self.color ?? self.runicTheme.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// A numbered callout: a figure inside an 18pt ruled circle.
struct DraftingCallout: View {
    let number: Int
    var size: CGFloat = 18
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Text("\(self.number)")
            .font(RunicDrafting.mono(self.size * 0.56, .bold))
            .skinFace()
            .foregroundStyle(self.runicTheme.primary)
            .frame(width: self.size, height: self.size)
            .overlay(Circle().stroke(self.runicTheme.primary, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// A small tilted stamp: "CHECKED ✓" in a thin ruled box.
struct DraftingStamp: View {
    let text: String
    var color: Color?
    var rotation: Double = -4
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.color ?? self.runicTheme.tertiary
        Text(self.text)
            .font(RunicDrafting.mono(9, .medium))
            .skinFace()
            .tracking(1.1)
            .foregroundStyle(ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(Rectangle().stroke(ink, lineWidth: 1))
            .rotationEffect(.degrees(self.rotation))
            .accessibilityHidden(true)
    }
}

// MARK: - Rules, edges, crop marks

/// A 1pt rule, solid or dashed, in the sheet's line ink.
struct DraftingRule: View {
    var dashed = false
    var opacity: Double = 1
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 1)
            .overlay {
                DraftingEdgeShape(edges: .top)
                    .stroke(
                        self.runicTheme.primary.opacity(self.opacity),
                        style: StrokeStyle(lineWidth: 1, dash: self.dashed ? [3, 3] : []))
            }
            .accessibilityHidden(true)
    }
}

/// Strokes only the chosen edges of a rect, so adjacent cells share one
/// rule instead of doubling it.
struct DraftingEdgeShape: Shape {
    let edges: Edge.Set

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = rect.insetBy(dx: 0.5, dy: 0.5)
        if self.edges.contains(.top) {
            path.move(to: CGPoint(x: inset.minX, y: inset.minY))
            path.addLine(to: CGPoint(x: inset.maxX, y: inset.minY))
        }
        if self.edges.contains(.bottom) {
            path.move(to: CGPoint(x: inset.minX, y: inset.maxY))
            path.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
        }
        if self.edges.contains(.leading) {
            path.move(to: CGPoint(x: inset.minX, y: inset.minY))
            path.addLine(to: CGPoint(x: inset.minX, y: inset.maxY))
        }
        if self.edges.contains(.trailing) {
            path.move(to: CGPoint(x: inset.maxX, y: inset.minY))
            path.addLine(to: CGPoint(x: inset.maxX, y: inset.maxY))
        }
        return path
    }
}

extension View {
    /// Rules the given edges of this view in the sheet's line ink.
    func draftingEdges(_ edges: Edge.Set, color: Color, lineWidth: CGFloat = 1) -> some View {
        self.overlay(DraftingEdgeShape(edges: edges).stroke(color, lineWidth: lineWidth))
    }
}

/// Registration marks in the four corners of a sheet.
struct DraftingCropMarks: View {
    var length: CGFloat = 12
    var inset: CGFloat = 0
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Canvas { context, size in
            let l = self.length
            let i = self.inset + 0.5
            var path = Path()
            // Top-left
            path.move(to: CGPoint(x: i, y: i + l))
            path.addLine(to: CGPoint(x: i, y: i))
            path.addLine(to: CGPoint(x: i + l, y: i))
            // Top-right
            path.move(to: CGPoint(x: size.width - i - l, y: i))
            path.addLine(to: CGPoint(x: size.width - i, y: i))
            path.addLine(to: CGPoint(x: size.width - i, y: i + l))
            // Bottom-left
            path.move(to: CGPoint(x: i, y: size.height - i - l))
            path.addLine(to: CGPoint(x: i, y: size.height - i))
            path.addLine(to: CGPoint(x: i + l, y: size.height - i))
            // Bottom-right
            path.move(to: CGPoint(x: size.width - i - l, y: size.height - i))
            path.addLine(to: CGPoint(x: size.width - i, y: size.height - i))
            path.addLine(to: CGPoint(x: size.width - i, y: size.height - i - l))
            context.stroke(path, with: .color(self.runicTheme.primary), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Cells

/// A ruled cell: a cap over a value. The parent chooses which edges rule.
struct DraftingCell: View {
    let label: String
    let value: String
    var valueFont: Font = RunicDrafting.strong(12)
    var valueColor: Color?
    var edges: Edge.Set = .all
    var edgeOpacity: Double = 0.6
    var alignment: HorizontalAlignment = .leading
    var lineLimit = 1
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: self.alignment, spacing: 2) {
            DraftingCap(text: self.label)
            Text(self.value)
                .font(self.valueFont)
                .skinFace()
                .foregroundStyle(self.valueColor ?? self.runicTheme.primaryText)
                .lineLimit(self.lineLimit)
                .minimumScaleFactor(0.75)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: self.alignment, vertical: .center))
        .draftingEdges(self.edges, color: self.runicTheme.primary.opacity(self.edgeOpacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.label), \(self.value)")
    }
}

// MARK: - Hatching and bars

/// Hatch at 45° in the accent, clipped to a rect: the "used" fill.
enum DraftingHatch {
    static func draw(in rect: CGRect, context: inout GraphicsContext, color: Color, spacing: CGFloat = 6) {
        guard rect.width > 0, rect.height > 0 else { return }
        var inner = context
        inner.clip(to: Path(rect))
        var lines = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            lines.move(to: CGPoint(x: x, y: rect.maxY))
            lines.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        inner.stroke(lines, with: .color(color), lineWidth: 1.2)
    }

    static func arrow(at tip: CGPoint, pointingLeft: Bool, length: CGFloat = 8, halfHeight: CGFloat = 4) -> Path {
        var path = Path()
        let base = pointingLeft ? tip.x + length : tip.x - length
        path.move(to: tip)
        path.addLine(to: CGPoint(x: base, y: tip.y - halfHeight))
        path.addLine(to: CGPoint(x: base, y: tip.y + halfHeight))
        path.closeSubpath()
        return path
    }
}

/// A 1pt outlined bar with a hatched fill for the used share and an
/// optional dashed plan line.
struct DraftingHatchBar: View {
    let percent: Double
    let accessibilityLabel: String
    var height: CGFloat = 14
    var isWarm = false
    var marker: Double?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        Canvas { context, size in
            let ink = self.isWarm ? self.runicTheme.warm : self.runicTheme.primary
            let hatch = self.isWarm ? self.runicTheme.warm : self.runicTheme.accent
            let used = CGRect(x: 0, y: 0, width: size.width * clamped / 100, height: size.height)
            DraftingHatch.draw(in: used, context: &context, color: hatch)
            if used.width > 1, used.width < size.width - 1 {
                var edge = Path()
                edge.move(to: CGPoint(x: used.maxX - 0.5, y: 0))
                edge.addLine(to: CGPoint(x: used.maxX - 0.5, y: size.height))
                context.stroke(edge, with: .color(hatch), lineWidth: 1)
            }
            context.stroke(
                Path(CGRect(x: 0.5, y: 0.5, width: size.width - 1, height: size.height - 1)),
                with: .color(ink),
                lineWidth: 1)
            if let marker = self.marker {
                let x = (size.width * min(100, max(0, marker)) / 100).rounded() + 0.5
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(
                    line,
                    with: .color(self.runicTheme.highlight),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            }
        }
        .frame(height: self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped)) percent")
    }
}

/// The dimensioned bar: extension lines over the span, a dimension line
/// with arrowheads across the used share broken by the percent, the hatched
/// bar, a dashed plan line with its pace note, and a lettered detail bubble
/// on a short leader.
struct DraftingDimensionedBar: View {
    let percent: Double
    let accessibilityLabel: String
    /// "38% REMAINING" when there is no pace note.
    let remainingText: String
    /// Where the plan line sits, as a percent.
    var marker: Double?
    /// "PACE −34% (BEHIND)", set beside the plan line.
    var paceText: String?
    /// The letter of the detail bubble ("A"), when the window has a note.
    var bubble: String?
    var isWarm = false
    @Environment(\.runicTheme) private var runicTheme

    static let height: CGFloat = 58

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        Canvas { context, size in
            let ink = self.runicTheme.primary
            let paper = self.runicTheme.surface
            let hatch = self.isWarm ? self.runicTheme.warm : self.runicTheme.accent
            let usedX = (size.width * clamped / 100).rounded()
            let barRect = CGRect(x: 0, y: 22, width: size.width, height: 16)
            let dimY: CGFloat = 7.5

            // Extension lines: start, used edge, full span (faint).
            var extensions = Path()
            extensions.move(to: CGPoint(x: 0.5, y: 0))
            extensions.addLine(to: CGPoint(x: 0.5, y: 36))
            if usedX > 2 {
                extensions.move(to: CGPoint(x: usedX - 0.5, y: 0))
                extensions.addLine(to: CGPoint(x: usedX - 0.5, y: 36))
            }
            context.stroke(extensions, with: .color(ink), lineWidth: 1)
            var span = Path()
            span.move(to: CGPoint(x: size.width - 0.5, y: 0))
            span.addLine(to: CGPoint(x: size.width - 0.5, y: 36))
            context.stroke(span, with: .color(ink.opacity(0.5)), lineWidth: 1)

            // Dimension line with arrowheads across the used share.
            if usedX > 16 {
                var dimension = Path()
                dimension.move(to: CGPoint(x: 0, y: dimY))
                dimension.addLine(to: CGPoint(x: usedX, y: dimY))
                context.stroke(dimension, with: .color(ink), lineWidth: 1)
                context.fill(DraftingHatch.arrow(at: CGPoint(x: 0, y: dimY), pointingLeft: true), with: .color(ink))
                context.fill(
                    DraftingHatch.arrow(at: CGPoint(x: usedX, y: dimY), pointingLeft: false),
                    with: .color(ink))
            }

            // The percent breaks the dimension line; a narrow span sets it
            // just past the arrowhead instead.
            let percentText = context.resolve(
                Text("\(Int(clamped.rounded()))%")
                    .font(RunicDrafting.numeral(16))
                    .foregroundColor(self.isWarm ? self.runicTheme.warm : self.runicTheme.primaryText))
            let toleranceText = context.resolve(
                Text("\u{00B1}0.5")
                    .font(RunicDrafting.mono(9))
                    .foregroundColor(self.runicTheme.secondary))
            let percentSize = percentText.measure(in: CGSize(width: 120, height: 30))
            let toleranceSize = toleranceText.measure(in: CGSize(width: 60, height: 20))
            let labelWidth = percentSize.width + 4 + toleranceSize.width
            let fits = usedX >= labelWidth + 28
            var labelX = fits ? (usedX - labelWidth) / 2 : usedX + 10
            if labelX + labelWidth > size.width { labelX = max(0, size.width - labelWidth) }
            if fits {
                context.fill(
                    Path(CGRect(x: labelX - 6, y: 0, width: labelWidth + 12, height: 16)),
                    with: .color(paper))
            }
            context.draw(percentText, at: CGPoint(x: labelX, y: dimY), anchor: .leading)
            context.draw(
                toleranceText,
                at: CGPoint(x: labelX + percentSize.width + 4, y: dimY + 2),
                anchor: .leading)

            // The bar: hatched used share inside a 1pt outline.
            let usedRect = CGRect(x: 0, y: barRect.minY, width: usedX, height: barRect.height)
            DraftingHatch.draw(in: usedRect, context: &context, color: hatch)
            if usedX > 1, usedX < size.width - 1 {
                var edge = Path()
                edge.move(to: CGPoint(x: usedX - 0.5, y: barRect.minY))
                edge.addLine(to: CGPoint(x: usedX - 0.5, y: barRect.maxY))
                context.stroke(edge, with: .color(hatch), lineWidth: 1)
            }
            context.stroke(
                Path(barRect.insetBy(dx: 0.5, dy: 0.5)),
                with: .color(self.isWarm ? self.runicTheme.warm : ink),
                lineWidth: 1)

            // Plan line and pace note, or the remaining share.
            let noteY: CGFloat = 50
            if let marker = self.marker {
                let x = (size.width * min(100, max(0, marker)) / 100).rounded() + 0.5
                var line = Path()
                line.move(to: CGPoint(x: x, y: barRect.minY - 4))
                line.addLine(to: CGPoint(x: x, y: barRect.maxY + 4))
                context.stroke(
                    line,
                    with: .color(self.runicTheme.highlight),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                if let paceText = self.paceText {
                    let pace = context.resolve(
                        Text(paceText)
                            .font(RunicDrafting.mono(9.5))
                            .tracking(1.1)
                            .foregroundColor(self.runicTheme.highlight))
                    let paceSize = pace.measure(in: CGSize(width: size.width, height: 20))
                    let paceX = min(x + 6, size.width - paceSize.width)
                    context.draw(pace, at: CGPoint(x: max(0, paceX), y: noteY), anchor: .leading)
                }
            } else {
                let remaining = context.resolve(
                    Text(self.remainingText)
                        .font(RunicDrafting.mono(9.5))
                        .tracking(1.1)
                        .foregroundColor(self.isWarm ? self.runicTheme.warm : self.runicTheme.secondary))
                context.draw(remaining, at: CGPoint(x: size.width, y: noteY), anchor: .trailing)
            }

            // Detail bubble on a leader from the used edge.
            if let bubble = self.bubble {
                let flip = usedX + 40 > size.width
                let dir: CGFloat = flip ? -1 : 1
                let startX = usedX + 6 * dir
                var leader = Path()
                leader.move(to: CGPoint(x: startX, y: 34))
                leader.addLine(to: CGPoint(x: startX + 18 * dir, y: 48))
                context.stroke(leader, with: .color(ink), lineWidth: 1)
                let center = CGPoint(x: startX + 25 * dir, y: 48)
                let circle = Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14))
                context.fill(circle, with: .color(paper))
                context.stroke(circle, with: .color(ink), lineWidth: 1)
                let letter = context.resolve(
                    Text(bubble)
                        .font(RunicDrafting.mono(8, .medium))
                        .foregroundColor(ink))
                context.draw(letter, at: center, anchor: .center)
            }
        }
        .skinFace()
        .frame(height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped)) percent")
    }
}

// MARK: - Buttons

/// Outlined rectangle in mono caps; `filled` sets it in the accent as the
/// primary action. Hover fills with paper.
struct DraftingButton: View {
    let title: String
    var filled = false
    var systemImage: String?
    var compact = false
    /// A row: the button spans its container with the label at the leading
    /// edge, the icon in a fixed column.
    var fullWidth = false
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let ink = self.runicTheme.primary
        let paper = self.runicTheme.surface
        let accent = self.runicTheme.accent
        let amber = self.runicTheme.highlight
        let fill: Color = self.filled ? (self.isHovered ? amber : accent) : (self.isHovered ? ink : .clear)
        let text: Color = self.filled || self.isHovered ? paper : ink
        Button(action: self.action) {
            HStack(spacing: self.fullWidth ? 10 : 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: self.fullWidth ? RunicSpacing.menuActionIconColumnWidth : nil)
                }
                Text(self.title.uppercased())
                    .font(RunicDrafting.mono(self.compact ? 10 : 11, self.filled ? .bold : .medium))
                    .skinFace()
                    .tracking(self.compact ? 1.2 : 1.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: self.fullWidth ? .infinity : nil, alignment: .leading)
            .foregroundStyle(text)
            .padding(.horizontal, self.compact ? 10 : 14)
            .frame(height: self.compact ? 26 : 30)
            .background(Rectangle().fill(fill))
            .overlay(Rectangle().stroke(self.filled ? fill : ink, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }
}
