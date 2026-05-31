import AppKit
import RunicCore
import SwiftUI

enum PopoverInsightPanel: String, CaseIterable, Identifiable {
    case timeline
    case hourly
    case weekly
    case utilization
    case windows
    case projects
    case models

    var id: String {
        self.rawValue
    }

    var title: String {
        switch self {
        case .timeline: "Timeline"
        case .hourly: "Today"
        case .weekly: "7 days"
        case .utilization: "Utilization"
        case .windows: "Windows"
        case .projects: "Projects"
        case .models: "Models"
        }
    }

    var systemImage: String {
        switch self {
        case .timeline: "chart.xyaxis.line"
        case .hourly: "clock"
        case .weekly: "calendar"
        case .utilization: "gauge.with.dots.needle.67percent"
        case .windows: "rectangle.split.2x1"
        case .projects: "folder"
        case .models: "cpu"
        }
    }

    var iconIntent: RunicIconIntent {
        .navigation
    }
}

extension UsageExporter.Scope {
    init(panel: PopoverInsightPanel, timelineRange: UsageTimelineChartMenuView.TimeRange) {
        switch panel {
        case .timeline:
            self = timelineRange.exportScope
        case .hourly:
            self = .hourly
        case .weekly:
            self = .weekly
        case .utilization:
            self = .utilization
        case .windows:
            self = .windows
        case .projects:
            self = .projects
        case .models:
            self = .models
        }
    }
}

extension UsageTimelineChartMenuView.TimeRange {
    fileprivate var exportScope: UsageExporter.Scope {
        switch self {
        case .threeDays: .timeline3d
        case .sevenDays: .timeline7d
        case .thirtyDays: .timeline30d
        case .quarter: .timeline90d
        case .year: .timeline1y
        }
    }
}

struct MenuPopoverBackground: View {
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        ZStack {
            self.runicTheme.menuSurfaceGradient
            if self.runicTheme.id == "glass" {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.52)
            }
            if self.runicTheme.isTerminalHUD {
                RunicTerminalScanlineOverlay(opacity: self.runicTheme.style.effects.scanlineOpacity)
                RunicTerminalCornerOverlay(
                    inset: 10,
                    length: 16,
                    lineWidth: self.runicTheme.style.chrome.borderWeight,
                    opacity: 0.24)
            }
        }
        .ignoresSafeArea()
    }
}

struct MenuPopoverSurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let radius = self.runicTheme.shape.cornerRadius(RunicCornerRadius.lg)
        let strokeIsGlow = self.runicTheme.shape.separator == .glow
        let isGlass = self.runicTheme.id == "glass"
        self.content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isGlass ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(self.runicTheme.menuSubtleFill))
                    .background {
                        if isGlass {
                            // Soft accent bloom behind the frost — what makes
                            // Glass read as "club showroom" instead of "just
                            // another translucent panel".
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            self.runicTheme.accent.opacity(0.32),
                                            self.runicTheme.highlight.opacity(0.18),
                                            .clear,
                                        ],
                                        center: .topLeading,
                                        startRadius: 12,
                                        endRadius: 220))
                                .blur(radius: 18)
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity),
                        lineWidth: strokeIsGlow
                            ? max(0.8, self.runicTheme.style.chrome.borderWeight)
                            : self.runicTheme.style.chrome.borderWeight)
                    .shadow(
                        color: strokeIsGlow
                            ? self.runicTheme.accent.opacity(self.runicTheme.style.effects.glowStrength)
                            : .clear,
                        radius: 4 + self.runicTheme.style.effects.glowStrength * 5)
            }
            .retroBevel(baseRadius: RunicCornerRadius.lg)
    }
}

// MenuPopoverSeparator removed — superseded by `RunicDivider` (Sources/Runic/Core/RunicTheme.swift).

struct MenuPopoverChip: View {
    @Environment(\.runicFonts) private var fonts
    let title: String
    let systemImage: String
    let iconIntent: RunicIconIntent
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: RunicSpacing.menuControlSpacing) {
                RunicThemedSystemIcon(
                    systemName: self.systemImage,
                    intent: self.iconIntent,
                    selected: self.isSelected,
                    hovered: self.isHovered,
                    font: self.fonts.caption.weight(.semibold),
                    width: RunicSpacing.menuIconColumnWidth)
                Text(self.title)
                    .font(self.fonts.caption.weight(self.isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RunicSpacing.menuControlHorizontalPadding)
            .padding(.vertical, RunicSpacing.menuControlVerticalPadding)
            .foregroundStyle(self.foreground)
            .background {
                RoundedRectangle(
                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                    style: .continuous)
                    .fill(self.background)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                    style: .continuous)
                    .stroke(self.border, lineWidth: self.runicTheme.shape.separator == .glow ? 1.2 : 0.7)
                    .shadow(
                        color: self.glowColor,
                        radius: self.glowRadius)
            }
            .scaleEffect(self.isHovered ? 1.015 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) {
                self.isHovered = hovering
            }
        }
    }

    private var foreground: Color {
        // Terminal hover uses a low-opacity phosphor wash; selection still
        // carries the bright accent foreground.
        if self.runicTheme.isTerminalHUD, self.isHovered, !self.isSelected {
            return self.runicTheme.primaryText
        }
        return self.isSelected ? self.runicTheme.accent : self.runicTheme.primaryText
    }

    private var background: Color {
        if self.isSelected {
            switch self.runicTheme.style.controls.selectedFillStyle {
            case .accentSolid, .terminalSolid:
                return self.runicTheme.accent.opacity(self.runicTheme.isTerminalHUD ? 0.28 : 0.22)
            case .neutralSoft:
                return self.runicTheme.menuSubtleFill
            case .accentSoft:
                return self.runicTheme.accent.opacity(0.18)
            }
        }
        if self.isHovered {
            if self.runicTheme.isTerminalHUD {
                return self.runicTheme.accent.opacity(0.16)
            }
            if self.runicTheme.shape.separator == .glow {
                // Glass / Dark — denser accent wash plus glow underlay.
                return self.runicTheme.accent.opacity(0.24)
            }
            // Daybreak / Light — warm tint, kept soft.
            return self.runicTheme.accent.opacity(0.14)
        }
        return self.runicTheme.cardFill.opacity(0.34)
    }

    private var border: Color {
        self.isSelected
            ? self.runicTheme.accent.opacity(0.64)
            : self.runicTheme.cardStroke.opacity(self.isHovered ? 0.72 : 0.42)
    }

    /// Neon halo color for glow-style themes (Glass, Dark). Only shows on
    /// hover/selection — keeps idle state clean.
    private var glowColor: Color {
        guard self.runicTheme.shape.separator == .glow else { return .clear }
        if self.isSelected { return self.runicTheme.accent.opacity(0.55) }
        if self.isHovered { return self.runicTheme.accent.opacity(0.55) }
        return .clear
    }

    private var glowRadius: CGFloat {
        guard self.runicTheme.shape.separator == .glow else { return 0 }
        return self.isSelected ? 6 : (self.isHovered ? 8 : 0)
    }
}

struct MenuPopoverActionButton: View {
    @Environment(\.runicFonts) private var fonts
    enum Style {
        case normal
        case compact
    }

    let title: String
    let systemImage: String?
    var iconIntent: RunicIconIntent = .action
    var style: Style = .normal
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: self.iconTextSpacing) {
                if let systemImage {
                    RunicThemedSystemIcon(
                        systemName: systemImage,
                        intent: self.iconIntent,
                        hovered: self.isHovered,
                        font: self.iconFont,
                        width: self.iconColumnWidth)
                } else {
                    Color.clear.frame(width: self.iconColumnWidth, height: 1)
                }
                Text(self.title)
                    .font(self.titleFont)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: RunicSpacing.menuControlSpacing)
            }
            .padding(.horizontal, self.horizontalPadding)
            .padding(.vertical, self.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(self.themedForeground)
            .background {
                RoundedRectangle(
                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                    style: .continuous)
                    .fill(self.themedHoverFill)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                    style: .continuous)
                    .stroke(self.themedHoverBorder, lineWidth: self.runicTheme.shape.separator == .glow ? 1.0 : 0.6)
                    .shadow(color: self.themedGlow, radius: self.isHovered ? 6 : 0)
            }
            .contentShape(RoundedRectangle(
                cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(self.runicTheme.motion.curve) {
                self.isHovered = hovering
            }
        }
    }

    /// Foreground colour stays readable across selected and hover states.
    private var themedForeground: Color {
        self.runicTheme.primaryText
    }

    /// Per-theme hover background. Terminal uses a calm phosphor wash; glow
    /// themes get a stronger accent tint, and standard themes stay light.
    private var themedHoverFill: Color {
        guard self.isHovered else { return .clear }
        if self.runicTheme.isTerminalHUD { return self.runicTheme.accent.opacity(0.16) }
        if self.runicTheme.shape.separator == .glow { return self.runicTheme.accent.opacity(0.22) }
        return self.runicTheme.menuHoverFill
    }

    private var themedHoverBorder: Color {
        guard self.isHovered, self.runicTheme.shape.separator == .glow else { return .clear }
        return self.runicTheme.accent.opacity(0.55)
    }

    private var themedGlow: Color {
        guard self.isHovered, self.runicTheme.shape.separator == .glow else { return .clear }
        return self.runicTheme.accent.opacity(0.45)
    }

    private var titleFont: Font {
        // Match the surrounding section text — every other label in the
        // popover sits at footnote / caption. The previous `.body` choice
        // made `Settings...` and `Switch Account…` look oversized.
        self.style == .compact ? self.fonts.caption.weight(.medium) : self.fonts.footnote.weight(.medium)
    }

    private var iconFont: Font {
        self.style == .compact ? self.fonts.caption.weight(.semibold) : self.fonts.footnote.weight(.medium)
    }

    private var iconColumnWidth: CGFloat {
        self.style == .compact ? RunicSpacing.menuIconColumnWidth : RunicSpacing.menuActionIconColumnWidth
    }

    private var iconTextSpacing: CGFloat {
        self.style == .compact ? RunicSpacing.menuControlSpacing : RunicSpacing.menuActionIconTextSpacing
    }

    private var horizontalPadding: CGFloat {
        self.style == .compact ? RunicSpacing.menuControlHorizontalPadding : 0
    }

    private var verticalPadding: CGFloat {
        self.style == .compact ? RunicSpacing.xxs + 1 : RunicSpacing.menuControlVerticalPadding
    }
}

struct ModelQuotaWindowsPopoverView: View {
    @Environment(\.runicFonts) private var fonts
    let windows: [RateWindow]
    let width: CGFloat
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Models")
                .font(self.fonts.caption.weight(.semibold))
            if self.windows.isEmpty {
                Text("No model windows available.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            } else {
                ForEach(Array(self.windows.enumerated()), id: \.offset) { _, window in
                    VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                        HStack {
                            Text(UsageFormatter.modelDisplayName(window.label ?? "Model"))
                                .font(self.fonts.caption.weight(.medium))
                            Spacer()
                            Text("\(Int(window.usedPercent.rounded()))% used")
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText)
                        }
                        UsageProgressBar(
                            percent: window.usedPercent,
                            tint: self.runicTheme.accent,
                            accessibilityLabel: "Model quota")
                        if let reset = self.resetText(for: window) {
                            Text(reset)
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.chartAxisLabelColor)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private func resetText(for window: RateWindow) -> String? {
        if let resetsAt = window.resetsAt {
            return "Resets \(UsageFormatter.resetCountdownDescription(from: resetsAt))"
        }
        if let reset = window.resetDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !reset.isEmpty {
            return reset.lowercased().hasPrefix("resets") ? reset : "Resets \(reset)"
        }
        return nil
    }
}
