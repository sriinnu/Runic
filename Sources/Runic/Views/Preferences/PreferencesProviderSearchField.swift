import SwiftUI

/// Filter field for Settings → Providers. It sits where the list starts: at the
/// top of the sidebar in the sidebar layout (System Settings style), and in the
/// "Built-in providers" header in the list layout. ⌘F focuses it, Esc clears it.
@MainActor
struct ProviderSearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: RunicSpacing.xxs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(self.runicTheme.secondaryText)
            TextField("Search providers", text: self.$text)
                .textFieldStyle(.plain)
                .font(self.fonts.caption)
                .focused(self.isFocused)
                .onExitCommand { self.text = "" }
            if !self.text.isEmpty {
                Button {
                    self.text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.compact)
        .background(
            RoundedRectangle(cornerRadius: RunicCornerRadius.md, style: .continuous)
                .fill(self.runicTheme.menuSubtleFill.opacity(0.6)))
        .overlay(
            RoundedRectangle(cornerRadius: RunicCornerRadius.md, style: .continuous)
                .strokeBorder(
                    self.isFocused.wrappedValue
                        ? Color.accentColor.opacity(0.6)
                        : self.runicTheme.menuSeparatorColor.opacity(0.5),
                    lineWidth: 1))
        .background {
            // Invisible ⌘F target; the field itself has no menu command to hang it on.
            Button("") { self.isFocused.wrappedValue = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search providers")
    }
}
