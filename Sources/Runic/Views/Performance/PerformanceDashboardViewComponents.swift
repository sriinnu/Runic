import SwiftUI

struct MetricCard: View {
    @Environment(\.runicFonts) private var fonts
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            HStack {
                Image(systemName: self.icon)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.color)
                Text(self.title)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            Text(self.value)
                .font(self.fonts.title3)
                .fontWeight(.semibold)
                .foregroundStyle(self.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RunicSpacing.xs)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(8), style: .continuous)
                    .fill(self.runicTheme.cardBackgroundStyle)
                if self.runicTheme.isTerminalHUD {
                    RunicTerminalScanlineOverlay(opacity: 0.45)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(8), style: .continuous)
                .stroke(self.runicTheme.menuSeparatorColor.opacity(0.62), lineWidth: 0.7))
    }
}

struct ErrorTypeLabel: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let type: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(self.color)
                .frame(width: 8, height: 8)
            Text("\(self.type): \(self.count)")
                .font(self.fonts.caption2)
                .foregroundStyle(self.runicTheme.secondaryText)
        }
    }
}
