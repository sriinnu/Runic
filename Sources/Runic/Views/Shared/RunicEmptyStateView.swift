import SwiftUI

/// Shared empty-state: a Runi doodle beside (or above) the message.
///
/// `compact` lays the mascot and copy out horizontally for menu-card chart
/// slots where vertical space is precious; `prominent` stacks them for
/// full-pane empty states in preferences. The doodle is decorative — the
/// title/hint carry the meaning for accessibility.
@MainActor
struct RunicEmptyStateView: View {
    enum Layout {
        case compact
        case prominent
    }

    let mood: RunicDoodle.Mood
    let title: String
    var hint: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var layout: Layout = .compact

    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        switch self.layout {
        case .compact:
            HStack(spacing: RunicSpacing.sm) {
                RunicDoodle(mood: self.mood, size: 48)
                self.textStack(alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(.vertical, RunicSpacing.xxs)
        case .prominent:
            VStack(spacing: RunicSpacing.sm) {
                RunicDoodle(mood: self.mood, size: 76)
                self.textStack(alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RunicSpacing.xl)
        }
    }

    private func textStack(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: RunicSpacing.xxs) {
            Text(self.title)
                .font(self.layout == .prominent ? self.fonts.headline : self.fonts.footnote.weight(.medium))
                .foregroundStyle(
                    self.layout == .prominent ? self.runicTheme.secondaryText : self.runicTheme.readableSecondaryText)
            if let hint = self.hint {
                let text = Text(hint)
                    .font(self.layout == .prominent ? self.fonts.caption : self.fonts.caption2)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.8))
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if self.layout == .prominent {
                    text.frame(maxWidth: 300)
                } else {
                    text
                }
            }
            if let actionTitle = self.actionTitle, let action = self.action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(self.layout == .prominent ? self.fonts.footnote.weight(.semibold) : self.fonts.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.runicTheme.accent)
            }
        }
    }
}
