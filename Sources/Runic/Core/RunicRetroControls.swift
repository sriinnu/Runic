import SwiftUI

// MARK: - Retro Checkbox

/// System-7 style checkbox: a beveled box with a hand-drawn check glyph
/// when on. Replaces SwiftUI's `Toggle` in Retro-themed Preference rows.
/// Falls back to the standard toggle on any other theme.
@MainActor
struct RetroToggleStyle: ToggleStyle {
    @Environment(\.runicTheme) private var runicTheme

    func makeBody(configuration: Configuration) -> some View {
        if self.runicTheme.id == "retro" {
            // `.center` aligns with PreferenceToggleRow's outer HStack so the
            // checkbox sits beside the label rather than baseline-shifting.
            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                self.box(isOn: configuration.isOn)
                    .onTapGesture {
                        withAnimation(self.runicTheme.motion.curve) {
                            configuration.isOn.toggle()
                        }
                    }
                configuration.label
                    .foregroundStyle(self.runicTheme.primaryText)
            }
            .contentShape(Rectangle())
        } else {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }

    private func box(isOn: Bool) -> some View {
        let size: CGFloat = 16
        let radius: CGFloat = 2
        return ZStack {
            // Card body — parchment for "off", System-7 blue for "on".
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(isOn ? self.runicTheme.accent : self.runicTheme.surfaceAlt)
                .frame(width: size, height: size)
            // Two-layer bevel
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(self.runicTheme.cardStroke, lineWidth: 1)
                .frame(width: size, height: size)
            RoundedRectangle(cornerRadius: max(radius - 1, 0.5), style: .continuous)
                .strokeBorder(Color.white.opacity(isOn ? 0.40 : 0.85), lineWidth: 0.7)
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
    /// Use the Retro beveled checkbox when the Retro theme is active.
    /// Falls back to system toggle on every other theme.
    @MainActor
    static var retro: RetroToggleStyle { RetroToggleStyle() }
}

// RetroButtonStyle removed — was defined during prototyping but never wired
// into any callsite. If beveled buttons are wanted later, reintroduce alongside
// a ButtonStyle.retro extension and the actual `.buttonStyle(.retro)` usages.
