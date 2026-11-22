import AppKit
import RunicCore
import SwiftUI

// MARK: - Atelier Kit

/// Architectural studio drafting grammar inspired by Swiss-Nordic architectural
/// monographs: matte `18px` dot-grid paper in daylight and `#121212` studio
/// charcoal at night, sharp `0px` spec sheets with `1px` rules contrasted against
/// `9999px` pill tabs, `8px` primary action buttons, `400`-weight tight-tracked
/// Geist headings, `Geist Mono` parenthesized kickers `( SECTION )`, and surgical
/// electric blueprint cobalt (`#3848F0` / `#7C8AFF`) reserved for active states,
/// skyline elevations, and blueprint corner crop-marks.
enum RunicAtelier {
    static let popoverRadius: CGFloat = 10
    static let panelInset: CGFloat = 12
    static let buttonRadius: CGFloat = 8
    static let dotSpacing: CGFloat = 18

    // MARK: Typography (Static Bundled Geist & Geist Mono)

    enum SansWeight {
        case regular
        case medium
        case semibold

        var postScriptName: String {
            switch self {
            case .regular: "Geist-Regular"
            case .medium: "Geist-Medium"
            case .semibold: "Geist-SemiBold"
            }
        }
    }

    enum MonoWeight {
        case regular
        case medium
        case semibold

        var postScriptName: String {
            switch self {
            case .regular: "GeistMono-Regular"
            case .medium: "GeistMono-Medium"
            case .semibold: "GeistMono-SemiBold"
            }
        }
    }

    static func display(_ size: CGFloat = 24, _ weight: SansWeight = .regular) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    static func sans(_ size: CGFloat = 12, _ weight: SansWeight = .regular) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    static func mono(_ size: CGFloat = 11, _ weight: MonoWeight = .regular) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    static func kicker(_ size: CGFloat = 9.5) -> Font {
        .custom(MonoWeight.medium.postScriptName, fixedSize: size)
    }

    // MARK: Helpers

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

    static func gaugeTint(used: Double, theme: RunicThemePalette) -> Color {
        if used >= 99.5 { return theme.warm }
        if used >= 80 { return theme.highlight }
        return theme.primary
    }

    static func pillColors(
        tone: AtelierPillBadge.Tone,
        theme: RunicThemePalette,
        dark: Bool) -> (fill: Color, text: Color, border: Color?)
    {
        switch tone {
        case .cobalt:
            let fill = dark
                ? Color(red: 31 / 255, green: 37 / 255, blue: 68 / 255)
                : Color(red: 236 / 255, green: 238 / 255, blue: 255 / 255)
            let text = dark
                ? Color(red: 164 / 255, green: 176 / 255, blue: 255 / 255)
                : Color(red: 42 / 255, green: 54 / 255, blue: 214 / 255)
            return (fill, text, nil)
        case .cobaltSolid:
            return (theme.accent, Color.white, nil)
        case .neutral:
            return (
                theme.surfaceAlt,
                theme.secondaryText,
                theme.cardStroke)
        case .critical:
            return (
                theme.warm.opacity(dark ? 0.18 : 0.10),
                theme.warm,
                theme.warm.opacity(0.35))
        case .good:
            return (
                theme.tertiary.opacity(dark ? 0.18 : 0.10),
                theme.tertiary,
                theme.tertiary.opacity(0.35))
        }
    }
}

// MARK: - Paper & Spec Sheet Chrome

/// Matte `18px` architectural dot-grid drafting paper (`#D3D3CB` Light / `#262624` Dark).
struct AtelierDotGridPaper: View {
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        let dotColor = dark
            ? Color(red: 42 / 255, green: 42 / 255, blue: 39 / 255)
            : Color(red: 211 / 255, green: 211 / 255, blue: 203 / 255)
        ZStack {
            self.runicTheme.surface
            Canvas { context, size in
                let step = RunicAtelier.dotSpacing
                guard size.width > 0, size.height > 0 else { return }
                let cols = Int(ceil(size.width / step))
                let rows = Int(ceil(size.height / step))
                let offsetX = (size.width - CGFloat(cols) * step) / 2 + step / 2
                let offsetY = step / 2
                for row in 0...rows {
                    let y = offsetY + CGFloat(row) * step
                    if y > size.height { break }
                    for col in 0...cols {
                        let x = offsetX + CGFloat(col) * step
                        if x > size.width || x < 0 { continue }
                        let rect = CGRect(x: x - 0.65, y: y - 0.65, width: 1.3, height: 1.3)
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Blueprint corner crop-marks (`┌ ┐ └ ┘`) in electric cobalt around architectural drawing sheets.
struct AtelierCornerReticles: View {
    var armLength: CGFloat = 7
    var lineWidth: CGFloat = 1.25
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Canvas { context, size in
            guard size.width > 16, size.height > 16 else { return }
            let a = self.armLength
            let w = size.width
            let h = size.height
            let inset: CGFloat = 0.5
            var path = Path()
            // Top-left
            path.move(to: CGPoint(x: inset, y: inset + a))
            path.addLine(to: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: inset + a, y: inset))
            // Top-right
            path.move(to: CGPoint(x: w - inset - a, y: inset))
            path.addLine(to: CGPoint(x: w - inset, y: inset))
            path.addLine(to: CGPoint(x: w - inset, y: inset + a))
            // Bottom-left
            path.move(to: CGPoint(x: inset, y: h - inset - a))
            path.addLine(to: CGPoint(x: inset, y: h - inset))
            path.addLine(to: CGPoint(x: inset + a, y: h - inset))
            // Bottom-right
            path.move(to: CGPoint(x: w - inset - a, y: h - inset))
            path.addLine(to: CGPoint(x: w - inset, y: h - inset))
            path.addLine(to: CGPoint(x: w - inset, y: h - inset - a))
            context.stroke(
                path,
                with: .color(self.runicTheme.accent.opacity(0.85)),
                style: StrokeStyle(lineWidth: self.lineWidth, lineCap: .square))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Sharp `0px` architectural specification sheet with `1px` rule and optional blueprint crop-marks.
struct AtelierSheet<Content: View>: View {
    var padding: CGFloat = 12
    var cropMarks: Bool = false
    var tint: Color?
    @ViewBuilder let content: Content
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = self.colorScheme == .dark
        self.content
            .padding(self.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    self.runicTheme.cardFill
                    if let tint {
                        tint.opacity(dark ? 0.08 : 0.04)
                    }
                }
            }
            .overlay(Rectangle().strokeBorder(self.runicTheme.cardStroke, lineWidth: 1))
            .overlay {
                if self.cropMarks {
                    AtelierCornerReticles()
                }
            }
    }
}

struct AtelierHairline: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Rectangle()
            .fill(self.runicTheme.cardStroke)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - Typography, Kickers & Pills

/// Parenthesized uppercase technical kicker `( SECTION )`.
struct AtelierKicker: View {
    let text: String
    var parenthesized: Bool = true
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let formatted = self.parenthesized ? "( \(self.text.uppercased()) )" : self.text.uppercased()
        Text(formatted)
            .font(RunicAtelier.kicker(9.5))
            .skinFace()
            .tracking(1.1)
            .foregroundStyle(self.runicTheme.secondaryText)
            .lineLimit(1)
    }
}

struct AtelierPillBadge: View {
    enum Tone {
        case cobalt
        case cobaltSolid
        case neutral
        case critical
        case good
    }

    let text: String
    var tone: Tone = .cobalt
    var arrow: String?
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let style = RunicAtelier.pillColors(
            tone: self.tone,
            theme: self.runicTheme,
            dark: self.colorScheme == .dark)
        HStack(spacing: 3) {
            Text(self.text)
                .font(RunicAtelier.mono(9, .semibold))
                .skinFace()
                .tracking(0.5)
                .lineLimit(1)
            if let arrow {
                Text(arrow)
                    .font(RunicAtelier.mono(9, .semibold))
                    .skinFace()
            }
        }
        .foregroundStyle(style.text)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(Capsule(style: .continuous).fill(style.fill))
        .overlay {
            if let border = style.border {
                Capsule(style: .continuous).strokeBorder(border, lineWidth: 0.75)
            }
        }
    }
}

// MARK: - Controls

/// Architectural `8px` button (`#121212` / `#F8F8F5` -> `#3848F0` cobalt on hover).
struct AtelierButton: View {
    let title: String
    var arrow: String? = "\u{2197}"
    var systemImage: String?
    var prominent: Bool = false
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RunicAtelier.buttonRadius, style: .continuous)
        let dark = self.colorScheme == .dark
        Button(action: self.action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .medium))
                        .accessibilityHidden(true)
                }
                Text(self.title)
                    .font(RunicAtelier.sans(11.5, .medium))
                    .skinFace()
                    .lineLimit(1)
                if let arrow {
                    Text(arrow)
                        .font(RunicAtelier.mono(10.5, .medium))
                        .skinFace()
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(self.foreground(dark: dark))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(shape.fill(self.background(dark: dark)))
            .overlay {
                if !self.prominent {
                    shape.strokeBorder(self.runicTheme.cardStroke, lineWidth: 1)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) { self.isHovered = hovering }
        }
    }

    private func foreground(dark: Bool) -> Color {
        if self.prominent {
            if self.isHovered { return Color.white }
            return dark ? Color(red: 18 / 255, green: 18 / 255, blue: 18 / 255) : Color.white
        }
        return self.isHovered ? self.runicTheme.accent : self.runicTheme.primaryText
    }

    private func background(dark: Bool) -> Color {
        if self.prominent {
            return self.isHovered ? self.runicTheme.accent : self.runicTheme.primary
        }
        return self.isHovered ? self.runicTheme.surfaceAlt : self.runicTheme.cardFill
    }
}

struct AtelierCopyButton: View {
    let copyText: String
    @State private var copied = false
    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(self.copyText, forType: .string)
            self.copied = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                self.copied = false
            }
        } label: {
            Text(self.copied ? "COPIED" : "COPY")
                .font(RunicAtelier.mono(8.5, .medium))
                .skinFace()
                .tracking(0.6)
                .foregroundStyle(self.copied
                    ? self.runicTheme.tertiary
                    : (self.isHovered ? self.runicTheme.accent : self.runicTheme.secondaryText))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(self.runicTheme.surfaceAlt)
                .overlay(Rectangle().strokeBorder(self.runicTheme.cardStroke, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .accessibilityLabel("Copy text")
    }
}

// MARK: - Quota Skyline Elevation (Overview Hero)

/// Architectural silhouette skyline of active quota towers (`01`..`07`) standing
/// on a `1px` hairline datum: the focused tower illuminates in electric blueprint
/// cobalt hatching with its active callout pill aligned in the top header row,
/// and clicking any tower jumps to that provider's tab.
struct AtelierQuotaSkyline: View {
    let summaries: [OverviewMenuView.ProviderSummary]
    let showsUsed: Bool
    let average: Double?
    let averageUsed: Double?
    var onSelect: ((UsageProvider) -> Void)?

    @State private var hoveredID: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let towers = Array(self.summaries.filter(\.hasQuota).prefix(7))
        let activeID = towers.isEmpty ? nil : self.resolvedActiveID(in: towers)
        let activeIndex = activeID.flatMap { id in towers.firstIndex { $0.id == id } }
        let activeSummary = activeIndex.map { towers[$0] }

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                AtelierKicker(text: "Quota skyline")
                Spacer(minLength: 6)
                if let activeIndex, let activeSummary {
                    Button {
                        self.onSelect?(activeSummary.provider)
                    } label: {
                        let code = String(format: "%02d", activeIndex + 1)
                        let pct = Int(activeSummary.usedPercent.rounded())
                        let label = "\(code) \(UsageProvider.compactDisplayName(activeSummary.name)) \u{00B7} \(pct)%"
                        AtelierPillBadge(text: label, tone: .cobaltSolid, arrow: "\u{2197}")
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let average = self.average {
                    let rounded = Int(average.rounded())
                    Text("\(rounded)%")
                        .font(RunicAtelier.display(24, .regular))
                        .skinFace()
                        .foregroundStyle(
                            (self.averageUsed ?? 0) >= 95 ? self.runicTheme.warm : self.runicTheme.primaryText)
                    Text(self.showsUsed ? "average used" : "average reserve")
                        .font(RunicAtelier.display(20, .regular))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text("Unmeasured")
                        .font(RunicAtelier.display(20, .regular))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
                Spacer(minLength: 0)
            }

            if !towers.isEmpty {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(towers.enumerated()), id: \.element.id) { index, summary in
                        let isActive = summary.id == activeID
                        AtelierSkylineTower(
                            index: index,
                            summary: summary,
                            isActive: isActive,
                            showsUsed: self.showsUsed)
                            .onHover { hovering in
                                if hovering {
                                    self.hoveredID = summary.id
                                } else if self.hoveredID == summary.id {
                                    self.hoveredID = nil
                                }
                            }
                            .onTapGesture {
                                self.onSelect?(summary.provider)
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(alignment: .bottom) {
                    AtelierHairline()
                        .padding(.bottom, 16)
                }
            }
        }
    }

    private func resolvedActiveID(in towers: [OverviewMenuView.ProviderSummary]) -> String {
        if let hovered = self.hoveredID, towers.contains(where: { $0.id == hovered }) {
            return hovered
        }
        if let peak = towers.max(by: { lhs, rhs in
            let lShare = self.showsUsed ? lhs.usedPercent : 100 - lhs.usedPercent
            let rShare = self.showsUsed ? rhs.usedPercent : 100 - rhs.usedPercent
            return lShare < rShare
        }) {
            return peak.id
        }
        return towers[0].id
    }
}

private struct AtelierSkylineTower: View {
    let index: Int
    let summary: OverviewMenuView.ProviderSummary
    let isActive: Bool
    let showsUsed: Bool
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let clamped = min(100, max(0, self.summary.usedPercent))
        let maxHeight: CGFloat = 44
        let towerHeight = max(6, maxHeight * CGFloat(clamped) / 100.0)
        let dark = self.colorScheme == .dark
        let code = String(format: "%02d", self.index + 1)

        VStack(spacing: 4) {
            Text("\(Int(clamped.rounded()))%")
                .font(RunicAtelier.mono(9, self.isActive ? .semibold : .regular))
                .skinFace()
                .foregroundStyle(self.isActive ? self.runicTheme.accent : self.runicTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ZStack(alignment: .bottom) {
                Rectangle()
                    .strokeBorder(
                        self.runicTheme.cardStroke.opacity(dark ? 0.55 : 0.75),
                        style: StrokeStyle(lineWidth: 0.75, dash: [2, 2]))
                    .frame(height: maxHeight)

                Canvas { context, size in
                    let rect = CGRect(origin: .zero, size: size)
                    if self.isActive {
                        context.fill(Path(rect), with: .color(self.runicTheme.accent.opacity(dark ? 0.22 : 0.14)))
                        // 45° blueprint architectural hatch lines.
                        let spacing: CGFloat = 4.5
                        var hatch = Path()
                        var x = -size.height
                        while x < size.width + size.height {
                            hatch.move(to: CGPoint(x: x, y: size.height))
                            hatch.addLine(to: CGPoint(x: x + size.height, y: 0))
                            x += spacing
                        }
                        context.stroke(
                            hatch,
                            with: .color(self.runicTheme.accent.opacity(dark ? 0.75 : 0.65)),
                            lineWidth: 0.85)
                    } else {
                        let fill = self.runicTheme.primary.opacity(dark ? 0.16 : 0.08)
                        context.fill(Path(rect), with: .color(fill))
                        // Fine subtle horizontal elevation coursing.
                        var coursing = Path()
                        var y: CGFloat = 5
                        while y < size.height {
                            coursing.move(to: CGPoint(x: 0, y: y))
                            coursing.addLine(to: CGPoint(x: size.width, y: y))
                            y += 5
                        }
                        context.stroke(
                            coursing,
                            with: .color(self.runicTheme.primaryText.opacity(dark ? 0.10 : 0.08)),
                            lineWidth: 0.5)
                    }
                    let strokeColor = self.isActive
                        ? self.runicTheme.accent
                        : self.runicTheme.primaryText.opacity(dark ? 0.36 : 0.45)
                    context.stroke(
                        Path(rect.insetBy(dx: 0.5, dy: 0.5)),
                        with: .color(strokeColor),
                        lineWidth: self.isActive ? 1.25 : 0.85)
                }
                .frame(height: towerHeight)
            }
            .frame(maxWidth: .infinity)

            Text(code)
                .font(RunicAtelier.mono(9, self.isActive ? .semibold : .regular))
                .skinFace()
                .foregroundStyle(self.isActive ? self.runicTheme.accent : self.runicTheme.secondaryText)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(self.summary.name), \(Int(clamped.rounded())) percent")
    }
}

// MARK: - Studio 3-Cell Stat Strip

struct AtelierStatStrip: View {
    struct Cell {
        let label: String
        let value: String
        var accentColor: Color?
    }

    let cells: [Cell]
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(self.cells.enumerated()), id: \.offset) { index, cell in
                if index > 0 {
                    Rectangle()
                        .fill(self.runicTheme.cardStroke)
                        .frame(width: 1)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(cell.label.uppercased())
                        .font(RunicAtelier.mono(8.5, .medium))
                        .skinFace()
                        .tracking(0.8)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                    Text(cell.value)
                        .font(RunicAtelier.display(16, .regular))
                        .skinFace()
                        .foregroundStyle(cell.accentColor ?? self.runicTheme.primaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(self.runicTheme.cardFill)
    }
}

// MARK: - Architectural Hairline Gauge

/// Crisp `5pt` square-corner architectural progress track with solid fill,
/// subtle end datum tick, and optional vertical pace index line.
struct AtelierGauge: View {
    let percent: Double
    let tint: Color
    let accessibilityLabel: String
    var marker: Double?
    var height: CGFloat = 5
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        let dark = self.colorScheme == .dark
        GeometryReader { geo in
            let width = geo.size.width
            let fillWidth = clamped <= 0 ? 0 : max(2, width * clamped / 100)
            Canvas { context, size in
                let barY = (size.height - self.height) / 2
                let trackRect = CGRect(x: 0, y: barY, width: size.width, height: self.height)
                context.fill(
                    Path(trackRect),
                    with: .color(self.runicTheme.primaryText.opacity(dark ? 0.12 : 0.08)))

                if fillWidth > 0 {
                    let fillRect = CGRect(x: 0, y: barY, width: fillWidth, height: self.height)
                    context.fill(Path(fillRect), with: .color(self.tint))

                    // End index datum tick
                    let capX = min(size.width - 0.75, fillWidth)
                    let tickRect = CGRect(x: capX - 0.75, y: barY - 1.5, width: 1.5, height: self.height + 3)
                    context.fill(Path(tickRect), with: .color(self.tint))
                }

                if let marker {
                    let mFrac = min(1, max(0, marker / 100))
                    let mx = min(size.width - 1, max(1, size.width * mFrac))
                    let paceRect = CGRect(x: mx - 0.75, y: 0, width: 1.5, height: size.height)
                    context.fill(Path(paceRect), with: .color(self.runicTheme.accent))
                }
            }
        }
        .frame(height: self.height + 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.accessibilityLabel)
        .accessibilityValue("\(Int(clamped.rounded())) percent")
    }
}

// MARK: - Specification Row

struct AtelierSpecRow: View {
    let label: String
    let value: String
    var detail: String?
    var copyText: String?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(self.label.uppercased())
                    .font(RunicAtelier.mono(9, .medium))
                    .skinFace()
                    .tracking(0.6)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if !self.value.isEmpty {
                    Text(self.value)
                        .font(RunicAtelier.mono(11, .medium))
                        .skinFace()
                        .foregroundStyle(self.runicTheme.primaryText)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let copyText, !copyText.isEmpty {
                    AtelierCopyButton(copyText: copyText)
                }
            }
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(RunicAtelier.sans(10.5))
                    .skinFace()
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }
}
