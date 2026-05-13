import RunicCore
import SwiftUI

struct MenuActionRowView: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let isEnabled: Bool

    @Environment(\.runicTheme) private var theme

    init(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        isEnabled: Bool = true)
    {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isEnabled = isEnabled
    }

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(self.theme.secondaryText)
                    .frame(width: 20, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(self.title)
                    .font(RunicFont.body)
                    .foregroundStyle(self.theme.primaryText)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(RunicFont.caption)
                        .foregroundStyle(self.theme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, RunicSpacing.sm)
        .padding(.trailing, RunicSpacing.lg)
        .padding(.vertical, RunicSpacing.xxs)
        .opacity(self.isEnabled ? 1 : 0.55)
    }
}

struct MenuSeparatorRowView: View {
    @Environment(\.runicTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(self.theme.menuSeparatorColor.opacity(0.70))
            .frame(height: 1)
            .padding(.horizontal, RunicSpacing.sm)
    }
}
