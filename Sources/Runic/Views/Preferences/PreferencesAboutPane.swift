import AppKit
import SwiftUI

@MainActor
private struct AboutLinkPillButton: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let icon: String
    let title: String
    let url: String
    @State private var hovering = false

    var body: some View {
        Button {
            if let url = URL(string: self.url) { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: RunicSpacing.xs) {
                Image(systemName: self.icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(self.title)
                    .font(self.fonts.footnote.weight(.medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(self.hovering ? self.runicTheme.primaryText : self.runicTheme.secondaryText)
            .padding(.horizontal, RunicSpacing.compact)
            .padding(.vertical, RunicSpacing.compact)
            .background(
                Capsule(style: .continuous)
                    .fill(self.hovering ? self.runicTheme.menuSubtleFill : Color.clear))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        self.runicTheme.menuSeparatorColor.opacity(self.hovering ? 0.72 : 0.32),
                        lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .onHover { over in
            self.hovering = over
        }
    }
}

@MainActor
struct AboutPane: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Bindable var settings: SettingsStore
    let updater: UpdaterProviding
    @State private var iconHover = false
    @AppStorage("autoUpdateEnabled") private var autoUpdateEnabled: Bool = true
    @State private var didLoadUpdaterState = false

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private var buildTimestamp: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CodexBuildTimestamp") as? String else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        guard let date = parser.date(from: raw) else { return raw }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter.string(from: date)
    }

    var body: some View {
        LiquidPreferencesPane {
            self.heroSection
            self.linksSection
            self.updaterSection
            self.helpSection
            self.troubleshootingSection
            self.footerSection
        }
        .onAppear {
            guard !self.didLoadUpdaterState else { return }
            self.updater.automaticallyChecksForUpdates = self.autoUpdateEnabled
            self.updater.automaticallyDownloadsUpdates = self.autoUpdateEnabled
            self.didLoadUpdaterState = true
        }
        .onChange(of: self.autoUpdateEnabled) { _, newValue in
            self.updater.automaticallyChecksForUpdates = newValue
            self.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    private var heroSection: some View {
        VStack(spacing: RunicSpacing.md) {
            if let image = NSApplication.shared.applicationIconImage {
                Button(action: self.openProjectHome) {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(
                            cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.xl),
                            style: .continuous))
                        .shadow(
                            color: .black.opacity(0.16),
                            radius: self.iconHover ? 14 : 6,
                            y: self.iconHover ? 5 : 2)
                        .scaleEffect(self.iconHover ? 1.04 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Runic project on GitHub")
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.iconHover = hovering
                    }
                }
            }

            VStack(spacing: RunicSpacing.xxs) {
                Text("Runic")
                    .font(self.fonts.title2.weight(.bold))

                Text("Version \(self.versionString)")
                    .font(self.fonts.footnote.weight(.medium))
                    .foregroundStyle(self.runicTheme.secondaryText)

                if let buildTimestamp {
                    Text("Built \(buildTimestamp)")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }

            VStack(spacing: RunicSpacing.xxs) {
                Text("पूर्णमदः पूर्णमिदं पूर्णात् पूर्णमुदच्यते")
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .multilineTextAlignment(.center)
                Text("From fullness comes fullness.\nWhen fullness is taken from fullness,\nfullness alone remains.")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("— Isha Upanishad")
                    .font(self.fonts.caption2.weight(.medium))
                    .foregroundStyle(self.runicTheme.subduedSecondaryText.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RunicSpacing.xs)
    }

    private var linksSection: some View {
        SettingsGroupCard {
            HStack(spacing: RunicSpacing.xs) {
                Spacer(minLength: 0)
                AboutLinkPillButton(
                    icon: "chevron.left.slash.chevron.right",
                    title: "GitHub",
                    url: "https://github.com/sriinnu/Runic")
                AboutLinkPillButton(
                    icon: "book",
                    title: "Docs",
                    url: "https://runic.srinivas.dev")
                AboutLinkPillButton(
                    icon: "globe",
                    title: "Web",
                    url: "https://www.srinivas.dev")
                AboutLinkPillButton(
                    icon: "bird",
                    title: "Twitter",
                    url: "https://x.com/_sriinnu_")
                AboutLinkPillButton(
                    icon: "envelope",
                    title: "Email",
                    url: "mailto:5410488+sriinnu@users.noreply.github.com")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var updaterSection: some View {
        SettingsGroupCard(title: "Updates") {
            if self.updater.isAvailable {
                PreferenceToggleRow(
                    title: "Check and download updates automatically",
                    subtitle: nil,
                    binding: self.$autoUpdateEnabled)
                Button("Check for Updates…") { self.updater.checkForUpdates(nil) }
                    .buttonStyle(.runicBordered)
                    .controlSize(.small)
            } else {
                Text(self.updater.unavailableReason ?? "Updates unavailable in this build.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var helpSection: some View {
        SettingsGroupCard(title: "Quick Reference") {
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Menu refresh")
                    .font(self.fonts.callout.weight(.medium))
                Text(
                    "Use Ping now in the menu to refresh usage immediately. "
                        + "Manual cadence disables background refreshes.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Data sources")
                    .font(self.fonts.callout.weight(.medium))
                Text(
                    "Runic reads local logs, CLIs, API keys in macOS Keychain, "
                        + "or saved browser sessions configured under Providers.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var troubleshootingSection: some View {
        SettingsGroupCard(title: "Developer & Debug") {
            PreferenceToggleRow(
                title: "Show Debug Settings",
                subtitle: "Expose probe logs, fetch pipeline diagnostics, and animation tools in the sidebar.",
                binding: self.$settings.debugMenuEnabled)
        }
    }

    private var footerSection: some View {
        Text("© 2025–2026 Srinivas Pendela. MPL-2.0.")
            .font(self.fonts.caption)
            .foregroundStyle(self.runicTheme.subduedSecondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, RunicSpacing.xs)
    }

    private func openProjectHome() {
        guard let url = URL(string: "https://github.com/sriinnu/Runic") else { return }
        NSWorkspace.shared.open(url)
    }
}
