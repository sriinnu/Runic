import RunicCore
import SwiftUI

/// Collapsed entry point for a region-specific sibling provider (e.g. "Add
/// Kimi (China)") that hasn't been configured yet. Tapping it reveals the
/// sibling's own credential field inline without touching the sibling's
/// enabled state — saving a key auto-enables it, which is what makes the
/// nested usage row in `ProviderListView` appear on the next render.
@MainActor
struct ProviderListAddRegionalAccountView: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let provider: UsageProvider
    let displayName: String
    @Binding var isExpanded: Bool
    let fields: [ProviderSettingsFieldDescriptor]

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.isExpanded.toggle()
                }
            } label: {
                Label(
                    self.isExpanded ? "Cancel" : "Add \(self.displayName)",
                    systemImage: self.isExpanded ? "xmark.circle" : "plus.circle")
                    .font(self.fonts.footnote.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(self.isExpanded ? self.runicTheme.secondaryText : Color.accentColor)

            if self.isExpanded {
                ForEach(self.fields) { field in
                    ProviderListFieldRowView(provider: self.provider, field: field)
                }
            }
        }
        .padding(.horizontal, RunicSpacing.sm)
        .padding(.vertical, RunicSpacing.xs)
    }
}
