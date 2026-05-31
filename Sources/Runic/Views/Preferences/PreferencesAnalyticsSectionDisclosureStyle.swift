import SwiftUI

struct AnalyticsSectionDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.runicFonts) private var fonts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: RunicSpacing.xs) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .frame(width: 12)
                    configuration.label
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .textCase(.uppercase)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
