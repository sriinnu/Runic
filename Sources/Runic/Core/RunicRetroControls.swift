import SwiftUI

// MARK: - Retro Checkbox

/// Theme-owned checkbox chrome for Retro and Terminal. Retro gets the soft
/// System-7 bevel; Terminal gets phosphor HUD boxes instead of native blue.
/// Falls back to the standard toggle on any other theme.
@MainActor
struct RetroToggleStyle: ToggleStyle {
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        if self.runicTheme.prefersRetroToggleChrome {
            // `.center` aligns with PreferenceToggleRow's outer HStack so the
            // checkbox sits beside the label rather than baseline-shifting.
            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                self.box(isOn: configuration.isOn)
                configuration.label
                    .foregroundStyle(self.runicTheme.primaryText)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion)) {
                    configuration.isOn.toggle()
                }
            }
        } else {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.checkbox)
        }
    }

    private func box(isOn: Bool) -> some View {
        let size: CGFloat = 16
        let radius: CGFloat = self.runicTheme.isTerminalHUD ? 3 : 2
        let fill: Color = switch (self.runicTheme.isTerminalHUD, isOn) {
        case (true, true):
            self.runicTheme.accent.opacity(0.88)
        case (true, false):
            self.runicTheme.surfaceAlt.opacity(0.88)
        case (false, true):
            self.runicTheme.accent
        case (false, false):
            self.runicTheme.surfaceAlt
        }
        let stroke = self.runicTheme.isTerminalHUD
            ? self.runicTheme.accent.opacity(isOn ? 0.95 : 0.42)
            : self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity)
        return ZStack {
            // Card body — parchment for "off", System-7 blue for "on".
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .frame(width: size, height: size)
            // Two-layer bevel
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(stroke, lineWidth: self.runicTheme.style.chrome.borderWeight)
                .frame(width: size, height: size)
            RoundedRectangle(cornerRadius: max(radius - 1, 0.5), style: .continuous)
                .strokeBorder(
                    Color.white.opacity(self.runicTheme.isTerminalHUD ? 0.10 : (isOn ? 0.40 : 0.85)),
                    lineWidth: 0.7)
                .frame(width: size - 2, height: size - 2)
            // Check glyph
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(self.runicTheme.surface)
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(Text(isOn ? "on" : "off"))
    }
}

extension ToggleStyle where Self == RetroToggleStyle {
    /// Use theme-owned checkbox chrome for Retro/Terminal; system toggle elsewhere.
    @MainActor
    static var retro: RetroToggleStyle {
        RetroToggleStyle()
    }
}

@MainActor
private struct RunicPreferenceToggleStyleModifier: ViewModifier {
    @Environment(\.runicTheme) private var runicTheme

    func body(content: Content) -> some View {
        if self.runicTheme.prefersRetroToggleChrome {
            content.toggleStyle(.retro)
        } else {
            content.toggleStyle(.checkbox)
        }
    }
}

extension View {
    @MainActor
    func runicPreferenceToggleStyle() -> some View {
        self.modifier(RunicPreferenceToggleStyleModifier())
    }
}

// RetroButtonStyle removed — was defined during prototyping but never wired
// into any callsite. If beveled buttons are wanted later, reintroduce alongside
// a ButtonStyle.retro extension and the actual `.buttonStyle(.retro)` usages.
