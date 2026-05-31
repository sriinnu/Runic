import RunicCore
import SwiftUI

extension MenuPopoverView {
    func actionSections(provider: UsageProvider?, isOverview: Bool) -> some View {
        let descriptor = MenuDescriptor.build(
            provider: provider,
            store: self.store,
            settings: self.settings,
            account: self.account,
            updateReady: self.updateReady)
        let sections = descriptor.sections.filter { section in
            section.entries.contains { entry in
                if case .action = entry { return true }
                return false
            }
        }

        return VStack(alignment: .leading, spacing: RunicSpacing.menuPanelSpacing) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                MenuPopoverSurfaceCard {
                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        ForEach(Array(section.entries.enumerated()), id: \.offset) { _, entry in
                            self.actionEntry(entry, provider: provider, isOverview: isOverview)
                        }
                    }
                    .padding(self.panelInset)
                }
            }
        }
        .frame(width: self.contentWidth, alignment: .leading)
    }

    @ViewBuilder
    func actionEntry(
        _ entry: MenuDescriptor.Entry,
        provider: UsageProvider?,
        isOverview: Bool) -> some View
    {
        switch entry {
        case let .action(title, action):
            if self.shouldRender(action: action, isOverview: isOverview) {
                MenuPopoverActionButton(
                    title: title,
                    systemImage: self.systemImage(for: action),
                    iconIntent: action.iconIntent,
                    action: {
                        self.perform(action, provider: provider)
                    })
            }
        case let .text(text, style):
            HStack(spacing: RunicSpacing.menuActionIconTextSpacing) {
                Color.clear.frame(width: RunicSpacing.menuActionIconColumnWidth, height: 1)
                Text(text)
                    .font(style == .headline
                        ? self.fonts.caption.weight(.semibold)
                        : self.fonts.caption)
                    .foregroundStyle(style == .secondary
                        ? self.settings.theme.palette.secondaryText
                        : self.settings.theme.palette.primaryText)
                    .lineLimit(2)
                    .lineSpacing(self.settings.theme.palette.isTerminalHUD ? RunicSpacing.xxxs : 0)
                    .truncationMode(.tail)
                Spacer(minLength: RunicSpacing.menuControlSpacing)
            }
            .padding(.horizontal, 0)
            .padding(.vertical, RunicSpacing.xxxs)
        case .divider:
            RunicDivider().padding(.vertical, RunicSpacing.xxxs)
        }
    }

    func shouldRender(action: MenuDescriptor.MenuAction, isOverview: Bool) -> Bool {
        guard isOverview else { return true }
        switch action {
        case .switchAccount, .dashboard, .statusPage:
            return false
        case .installUpdate, .refresh, .settings, .about, .quit, .copyError:
            return true
        }
    }

    func systemImage(for action: MenuDescriptor.MenuAction) -> String? {
        switch action {
        case .installUpdate: "arrow.down.circle"
        case .settings: "gearshape"
        case .about: "info.circle"
        case .quit: "power"
        default: action.systemImageName
        }
    }

    func perform(_ action: MenuDescriptor.MenuAction, provider: UsageProvider?) {
        switch action {
        case .installUpdate:
            self.actions.installUpdate()
        case .refresh:
            self.actions.refresh()
        case .dashboard:
            self.actions.openDashboard()
        case .statusPage:
            self.actions.openStatusPage()
        case let .switchAccount(target):
            self.actions.switchAccount(target)
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
