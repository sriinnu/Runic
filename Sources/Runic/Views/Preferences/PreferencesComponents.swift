import AppKit
import SwiftUI

enum PreferencesLayoutMetrics {
    static let outerHorizontal: CGFloat = 0
    static let outerVertical: CGFloat = 0
    static let paneHorizontal: CGFloat = 35
    static let paneVertical: CGFloat = 25
    static let paneSpacing: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let sectionHeaderSpacing: CGFloat = 18
}

@MainActor
struct PreferencesPane<Content: View>: View {
    let showsIndicators: Bool
    private let content: () -> Content

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
    }
}

@MainActor
struct PreferencesListPane<Content: View>: View {
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    private let content: () -> Content

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
    }
}

@MainActor
struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var binding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5.4) {
            Toggle(isOn: self.$binding) {
                Text(self.title)
                    .font(.body)
            }
            .toggleStyle(.checkbox)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
struct PreferenceStepperRow: View {
    let title: String
    let subtitle: String?
    let step: Int
    let range: ClosedRange<Int>
    let valueLabel: (Int) -> String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5.4) {
            HStack(spacing: 12) {
                Text(self.title)
                    .font(.body)
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
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
struct PreferencesDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 4)
    }
}

@MainActor
private struct PreferenceStepperControl: View {
    let valueLabel: String
    let canDecrement: Bool
    let canIncrement: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: self.onDecrement) {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!self.canDecrement)

            Text(self.valueLabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor)))

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
                    .font(.subheadline.weight(.semibold))
            }
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: self.contentSpacing) {
                self.content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
            HStack(spacing: 8) {
                Image(systemName: self.icon)
                Text(self.title)
                    .underline(self.hovering, color: .accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { self.hovering = $0 }
    }
}
