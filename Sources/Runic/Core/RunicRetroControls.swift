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
                if self.runicTheme.isPaperCutout {
                    self.paperPill(isOn: configuration.isOn)
                } else {
                    self.box(isOn: configuration.isOn)
                }
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

    /// Kirigami: a paper pill switch — outlined capsule, "On"/"Off" written
    /// inside, a round knob with its own outline that slides to the on side.
    private func paperPill(isOn: Bool) -> some View {
        let width: CGFloat = 44
        let height: CGFloat = 20
        let ink = self.runicTheme.cardStroke.opacity(self.runicTheme.style.chrome.borderOpacity)
        let inkWidth = max(1, self.runicTheme.style.chrome.borderWeight)
        let knob = height - 6
        return ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule(style: .continuous)
                .fill(isOn ? self.runicTheme.tertiary.opacity(0.30) : self.runicTheme.surfaceAlt)
                .overlay(Capsule(style: .continuous).strokeBorder(ink, lineWidth: inkWidth))
                .frame(width: width, height: height)
            Text(isOn ? "On" : "Off")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(self.runicTheme.primaryText)
                .frame(width: width - knob - 8, alignment: .center)
                .offset(x: isOn ? -(knob + 4) : (knob + 4))
                .frame(width: width, alignment: isOn ? .trailing : .leading)
            Circle()
                .fill(isOn ? self.runicTheme.tertiary : Color.white)
                .overlay(Circle().strokeBorder(ink, lineWidth: inkWidth))
                .frame(width: knob, height: knob)
                .padding(3)
        }
        .frame(width: width, height: height)
        .runicCutout(radius: height / 2, lift: 0.45)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(Text(isOn ? "on" : "off"))
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
            // Elevated themes: the well sits a step darker than the card so
            // an unchecked box still reads as a box.
            self.runicTheme.isElevated ? self.runicTheme.surface : self.runicTheme.surfaceAlt
        }
        // An unchecked box must still read as a box: themes with faint
        // chrome (Relief's 0.35 hairline) get a floor on the stroke.
        let stroke: Color = if self.runicTheme.isTerminalHUD {
            self.runicTheme.accent.opacity(isOn ? 0.95 : 0.42)
        } else if self.runicTheme.isElevated {
            self.runicTheme.primaryText.opacity(isOn ? 0.18 : 0.38)
        } else {
            self.runicTheme.cardStroke.opacity(max(self.runicTheme.style.chrome.borderOpacity, 0.55))
        }
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
        // Elevated themes: an unchecked box is a well, a checked one a raised chip.
        .runicRecessed(radius: isOn ? 0 : radius)
        .runicRaised(radius: radius, lift: isOn ? 0.6 : 0)
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
