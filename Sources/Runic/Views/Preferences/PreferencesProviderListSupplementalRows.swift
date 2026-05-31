import RunicCore
import SwiftUI

@MainActor
struct ProviderListToggleRowView: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider
    let toggle: ProviderSettingsToggleDescriptor
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Toggle("", isOn: self.toggle.binding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    Text(self.toggle.title)
                        .font(self.fonts.callout.weight(.semibold))
                    Text(self.toggle.subtitle)
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if self.toggle.binding.wrappedValue {
                    if let status = self.toggle.statusText?(), !status.isEmpty {
                        Text(status)
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(RunicSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                                    style: .continuous)
                                    .fill(self.runicTheme.menuSubtleFill))
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                                    style: .continuous)
                                    .strokeBorder(self.runicTheme.menuSeparatorColor.opacity(0.38), lineWidth: 1)
                            }
                    }

                    let actions = self.toggle.actions.filter { $0.isVisible?() ?? true }
                    if !actions.isEmpty {
                        HStack(spacing: RunicSpacing.xs) {
                            ForEach(actions) { action in
                                Button(action.title) {
                                    Task { @MainActor in
                                        await action.perform()
                                    }
                                }
                                .applyProviderSettingsButtonStyle(action.style)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .padding(.leading, ProviderListMetrics.iconSize + RunicSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProviderListMetrics.supplementalCardPadding)
        .background(self.supplementalCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
                .strokeBorder(self.supplementalCardBorderColor, lineWidth: 1)
        }
        .onChange(of: self.toggle.binding.wrappedValue) { _, enabled in
            guard let onChange = self.toggle.onChange else { return }
            Task { @MainActor in
                await onChange(enabled)
            }
        }
        .task(id: self.toggle.binding.wrappedValue) {
            guard self.toggle.binding.wrappedValue else { return }
            guard let onAppear = self.toggle.onAppearWhenEnabled else { return }
            await onAppear()
        }
    }

    private var supplementalCardBackground: some View {
        RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
            .fill(self.runicTheme.menuSubtleFill.opacity(ProviderListMetrics.supplementalCardBackgroundOpacity + 0.20))
    }

    private var supplementalCardBorderColor: Color {
        self.runicTheme.menuSeparatorColor.opacity(ProviderListMetrics.supplementalCardBorderOpacity + 0.10)
    }
}

@MainActor
struct ProviderListFieldRowView: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider
    let field: ProviderSettingsFieldDescriptor
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Color.clear
                .frame(width: ProviderListMetrics.checkboxSize, height: ProviderListMetrics.checkboxSize)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    Text(self.field.title)
                        .font(self.fonts.callout.weight(.semibold))
                    Text(self.field.subtitle)
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                switch self.field.kind {
                case .plain:
                    TextField(self.field.placeholder ?? "", text: self.field.binding)
                        .textFieldStyle(.roundedBorder)
                        .font(self.fonts.callout)
                        .frame(maxWidth: ProviderListMetrics.fieldMaxWidth, alignment: .leading)
                case .secure:
                    SecureField(self.field.placeholder ?? "", text: self.field.binding)
                        .textFieldStyle(.roundedBorder)
                        .font(self.fonts.callout)
                        .frame(maxWidth: ProviderListMetrics.fieldMaxWidth, alignment: .leading)
                }

                let actions = self.field.actions.filter { $0.isVisible?() ?? true }
                if !actions.isEmpty {
                    HStack(spacing: RunicSpacing.xs) {
                        ForEach(actions) { action in
                            Button(action.title) {
                                Task { @MainActor in
                                    await action.perform()
                                }
                            }
                            .applyProviderSettingsButtonStyle(action.style)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(.leading, ProviderListMetrics.iconSize + RunicSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProviderListMetrics.supplementalCardPadding)
        .background(self.supplementalCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
                .strokeBorder(self.supplementalCardBorderColor, lineWidth: 1)
        }
    }

    private var supplementalCardBackground: some View {
        RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
            .fill(self.runicTheme.menuSubtleFill.opacity(ProviderListMetrics.supplementalCardBackgroundOpacity + 0.20))
    }

    private var supplementalCardBorderColor: Color {
        self.runicTheme.menuSeparatorColor.opacity(0.26)
    }
}

extension View {
    @ViewBuilder
    func applyProviderSettingsButtonStyle(_ style: ProviderSettingsActionDescriptor.Style) -> some View {
        switch style {
        case .bordered:
            self.buttonStyle(.bordered)
        case .link:
            self.buttonStyle(.link)
        }
    }
}
