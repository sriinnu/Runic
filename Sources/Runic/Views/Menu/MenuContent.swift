import AppKit
import RunicCore
import SwiftUI

enum MenuContentMetrics {
    /// Horizontal padding for menu content
    static let horizontalPadding: CGFloat = RunicSpacing.sm  // 12

    /// Vertical padding for menu content
    static let verticalPadding: CGFloat = RunicSpacing.xs  // 8

    /// Spacing between menu sections
    static let sectionSpacing: CGFloat = RunicSpacing.xs  // 8

    /// Spacing between menu entries
    static let entrySpacing: CGFloat = RunicSpacing.xxs  // 4

    /// Minimum menu width
    static let minWidth: CGFloat = 290
}

@MainActor
struct MenuContent: View {
    @Bindable var store: UsageStore
    @Bindable var settings: SettingsStore
    let account: AccountInfo
    let updater: UpdaterProviding
    let provider: UsageProvider?
    let actions: MenuActions

    var body: some View {
        let descriptor = MenuDescriptor.build(
            provider: self.provider,
            store: self.store,
            settings: self.settings,
            account: self.account,
            updateReady: self.updater.updateStatus.isUpdateReady)

        VStack(alignment: .leading, spacing: MenuContentMetrics.sectionSpacing) {
            ForEach(Array(descriptor.sections.enumerated()), id: \.offset) { index, section in
                VStack(alignment: .leading, spacing: MenuContentMetrics.entrySpacing) {
                    ForEach(Array(section.entries.enumerated()), id: \.offset) { _, entry in
                        self.row(for: entry)
                    }
                }
                if index < descriptor.sections.count - 1 {
                    Divider()
                        .padding(.vertical, RunicSpacing.xxs)
                }
            }
        }
        .padding(.horizontal, MenuContentMetrics.horizontalPadding)
        .padding(.vertical, MenuContentMetrics.verticalPadding)
        .frame(minWidth: MenuContentMetrics.minWidth, alignment: .leading)
        .runicTypography()
    }

    @ViewBuilder
    private func row(for entry: MenuDescriptor.Entry) -> some View {
        switch entry {
        case let .text(text, style):
            switch style {
            case .headline:
                Text(text).font(RunicFont.headline)
            case .primary:
                Text(text)
            case .secondary:
                Text(text).foregroundStyle(.secondary).font(RunicFont.footnote)
            }
        case let .action(title, action):
            Button {
                self.perform(action)
            } label: {
                if let icon = self.iconName(for: action) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .imageScale(.medium)
                            .frame(width: 18, alignment: .center)
                        Text(title)
                    }
                    .foregroundStyle(.primary)
                } else {
                    Text(title)
                }
            }
            .buttonStyle(.plain)
        case .divider:
            Divider()
                .padding(.vertical, RunicSpacing.xxs)
        }
    }

    private func iconName(for action: MenuDescriptor.MenuAction) -> String? { action.systemImageName }

    private func perform(_ action: MenuDescriptor.MenuAction) {
        switch action {
        case .refresh:
            self.actions.refresh()
        case .installUpdate:
            self.actions.installUpdate()
        case .dashboard:
            self.actions.openDashboard()
        case .statusPage:
            self.actions.openStatusPage()
        case let .switchAccount(provider):
            self.actions.switchAccount(provider)
        case .settings:
            self.actions.openSettings()
        case .about:
            self.actions.openAbout()
        case .quit:
            self.actions.quit()
        case let .copyError(message):
            self.actions.copyError(message)
        }
    }
}

struct MenuActions {
    let installUpdate: () -> Void
    let refresh: () -> Void
    let openDashboard: () -> Void
    let openStatusPage: () -> Void
    let switchAccount: (UsageProvider) -> Void
    let openSettings: () -> Void
    let openAbout: () -> Void
    let quit: () -> Void
    let copyError: (String) -> Void
}

@MainActor
struct StatusIconView: View {
    @Bindable var store: UsageStore
    let provider: UsageProvider

    var body: some View {
        Image(nsImage: self.icon)
            .renderingMode(.template)
            .interpolation(.none)
    }

    private var icon: NSImage {
        IconRenderer.makeIcon(
            primaryRemaining: self.store.snapshot(for: self.provider)?.primary.remainingPercent,
            weeklyRemaining: self.store.snapshot(for: self.provider)?.secondary?.remainingPercent,
            creditsRemaining: self.provider == .codex ? self.store.credits?.remaining : nil,
            stale: self.store.isStale(provider: self.provider),
            style: self.store.style(for: self.provider),
            statusIndicator: self.store.statusIndicator(for: self.provider))
    }
}
