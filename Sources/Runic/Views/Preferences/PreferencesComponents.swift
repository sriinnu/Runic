import AppKit
import SwiftUI

enum PreferencesLayoutMetrics {
    static let outerHorizontal: CGFloat = 0
    static let outerVertical: CGFloat = 0
    static let paneHorizontal: CGFloat = 36
    static let paneVertical: CGFloat = 24
    static let paneSpacing: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let sectionHeaderSpacing: CGFloat = 16
}

enum PreferencesTypographyMetrics {
    static let terminalBodyLineSpacing: CGFloat = 6
}

@MainActor
struct PreferencesPane<Content: View>: View {
    @Environment(\.runicFonts) private var fonts
    let showsIndicators: Bool
    private let content: () -> Content
    @Environment(\.runicTheme) private var runicTheme

    init(
        showsIndicators: Bool = true,
        @ViewBuilder content: @escaping () -> Content)
    {
        self.showsIndicators = showsIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: self.showsIndicators) {
            VStack(alignment: .leading, spacing: PreferencesLayoutMetrics.paneSpacing) {
                self.content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
            .padding(.vertical, PreferencesLayoutMetrics.paneVertical)
        }
        .foregroundStyle(self.runicTheme.primaryText)
        .background {
            ZStack {
                self.runicTheme.menuSurfaceGradient
                if self.runicTheme.isTerminalHUD {
                    RunicTerminalScanlineOverlay(opacity: self.runicTheme.style.effects.scanlineOpacity)
                }
            }
        }
    }
}

@MainActor
struct PreferencesListPane<Content: View>: View {
    @Environment(\.runicFonts) private var fonts
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    private let content: () -> Content
    @Environment(\.runicTheme) private var runicTheme

    init(
        horizontalPadding: CGFloat = PreferencesLayoutMetrics.paneHorizontal,
        verticalPadding: CGFloat = PreferencesLayoutMetrics.paneVertical,
        @ViewBuilder content: @escaping () -> Content)
    {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.content = content
    }

    var body: some View {
        self.content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, self.horizontalPadding)
            .padding(.vertical, self.verticalPadding)
            .foregroundStyle(self.runicTheme.primaryText)
            .background {
                ZStack {
                    self.runicTheme.menuSurfaceGradient
                    if self.runicTheme.isTerminalHUD {
                        RunicTerminalScanlineOverlay(opacity: self.runicTheme.style.effects.scanlineOpacity)
                    }
                }
            }
    }
}

@MainActor
struct PreferenceToggleRow: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let title: String
    let subtitle: String?
    @Binding var binding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                if self.runicTheme.prefersRetroToggleChrome {
                    Toggle(isOn: self.$binding) {
                        Text(self.title)
                            .font(self.titleFont)
                    }
                    .toggleStyle(.retro)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                } else {
                    Toggle(isOn: self.$binding) {
                        Text(self.title)
                            .font(self.titleFont)
                    }
                    .toggleStyle(.checkbox)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                }
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(self.subtitleFont)
                    .fontDesign(self.subtitleDesign)
                    .tracking(self.subtitleTracking)
                    .foregroundStyle(self.subtitleColor)
                    .lineSpacing(self.subtitleLineSpacing)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleFont: Font {
        self.runicTheme.isTerminalHUD
            ? .system(size: 14, weight: .semibold, design: .monospaced)
            : self.fonts.callout.weight(.medium)
    }

    private var subtitleFont: Font {
        self.runicTheme.isTerminalHUD ? .system(size: 12, weight: .regular) : self.fonts.footnote
    }

    private var subtitleDesign: Font.Design? {
        self.runicTheme.isTerminalHUD ? .default : nil
    }

    private var subtitleTracking: CGFloat {
        self.runicTheme.isTerminalHUD ? 0 : RunicFont.activeRules.letterSpacing
    }

    private var subtitleColor: Color {
        self.runicTheme.subduedSecondaryText
    }

    private var subtitleLineSpacing: CGFloat {
        self.runicTheme.isTerminalHUD ? PreferencesTypographyMetrics.terminalBodyLineSpacing : 0
    }
}

@MainActor
struct PreferenceStepperRow: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let title: String
    let subtitle: String?
    let step: Int
    let range: ClosedRange<Int>
    let valueLabel: (Int) -> String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(spacing: RunicSpacing.sm) {
                Text(self.title)
                    .font(self.titleFont)
                Spacer()
                PreferenceStepperControl(
                    valueLabel: self.valueLabel(self.value),
                    canDecrement: self.value - self.step >= self.range.lowerBound,
                    canIncrement: self.value + self.step <= self.range.upperBound,
                    onDecrement: { self.value = max(self.range.lowerBound, self.value - self.step) },
                    onIncrement: { self.value = min(self.range.upperBound, self.value + self.step) })
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(self.subtitleFont)
                    .foregroundStyle(self.subtitleColor)
                    .lineSpacing(self.subtitleLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var titleFont: Font {
        self.runicTheme.isTerminalHUD
            ? .system(size: 14, weight: .semibold, design: .monospaced)
            : self.fonts.callout.weight(.medium)
    }

    private var subtitleFont: Font {
        self.runicTheme.isTerminalHUD ? .system(size: 12, weight: .regular) : self.fonts.footnote
    }

    private var subtitleColor: Color {
        self.runicTheme.subduedSecondaryText
    }

    private var subtitleLineSpacing: CGFloat {
        self.runicTheme.isTerminalHUD ? PreferencesTypographyMetrics.terminalBodyLineSpacing : 0
    }
}

@MainActor
struct PreferencesDivider: View {
    @Environment(\.runicFonts) private var fonts
    var body: some View {
        Divider()
            .padding(.vertical, RunicSpacing.xxs)
    }
}

@MainActor
private struct PreferenceStepperControl: View {
    @Environment(\.runicFonts) private var fonts
    let valueLabel: String
    let canDecrement: Bool
    let canIncrement: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
            Button(action: self.onDecrement) {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!self.canDecrement)

            Text(self.valueLabel)
                .font(self.fonts.footnote.weight(.semibold))
                .foregroundStyle(self.runicTheme.secondaryText)
                .padding(.horizontal, RunicSpacing.sm)
                .padding(.vertical, RunicSpacing.xxs)
                .background(
                    RoundedRectangle(
                        cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                        style: .continuous)
                        .fill(self.runicTheme.menuSubtleFill))
                .overlay(
                    RoundedRectangle(
                        cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                        style: .continuous)
                        .stroke(self.runicTheme.menuSeparatorColor.opacity(0.62), lineWidth: 0.7))

            Button(action: self.onIncrement) {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!self.canIncrement)
        }
    }
}

@MainActor
struct SettingsSection<Content: View>: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let title: String?
    let caption: String?
    let contentSpacing: CGFloat
    private let content: () -> Content

    init(
        title: String? = nil,
        caption: String? = nil,
        contentSpacing: CGFloat = PreferencesLayoutMetrics.sectionSpacing,
        @ViewBuilder content: @escaping () -> Content)
    {
        self.title = title
        self.caption = caption
        self.contentSpacing = contentSpacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PreferencesLayoutMetrics.sectionHeaderSpacing) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(self.titleFont)
                    .tracking(self.runicTheme.isTerminalHUD ? 0.8 : 0)
                    .textCase(self.runicTheme.isTerminalHUD ? .uppercase : nil)
            }
            if let caption {
                Text(caption)
                    .font(self.captionFont)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(self.captionOpacity))
                    .lineSpacing(self.captionLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: self.contentSpacing) {
                self.content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var titleFont: Font {
        self.runicTheme.isTerminalHUD ? self.fonts.headline.weight(.bold) : self.fonts.subheadline.weight(.semibold)
    }

    private var captionFont: Font {
        self.runicTheme.isTerminalHUD ? self.fonts.caption : self.fonts.footnote
    }

    private var captionOpacity: Double {
        self.runicTheme.isTerminalHUD ? 0.78 : 0.70
    }

    private var captionLineSpacing: CGFloat {
        self.runicTheme.isTerminalHUD ? PreferencesTypographyMetrics.terminalBodyLineSpacing : 0
    }
}

@MainActor
struct AboutLinkRow: View {
    let icon: String
    let title: String
    let url: String
    @State private var hovering = false

    var body: some View {
        Button {
            if let url = URL(string: self.url) { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: RunicSpacing.xs) {
                Image(systemName: self.icon)
                Text(self.title)
                    .underline(self.hovering, color: .accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RunicSpacing.xxs)
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { self.hovering = $0 }
    }
}
