import AppKit
import SwiftUI

// MARK: - Floating orb accent (About-specific)

@MainActor
private struct FloatingOrb: View {
    let color: Color
    let size: CGFloat
    let speed: Double
    let offset: Double
    @State private var phase: Double = 0
    private let timer = Timer.publish(every: 1 / 24.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [self.color.opacity(0.5), self.color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: self.size / 2))
            .frame(width: self.size, height: self.size)
            .offset(
                x: sin(self.phase * self.speed + self.offset) * 20,
                y: cos(self.phase * self.speed * 0.7 + self.offset) * 14)
            .onReceive(self.timer) { _ in self.phase += 1 / 24.0 }
    }
}

// MARK: - Liquid link button (About-specific)

@MainActor
private struct LiquidLinkButton: View {
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
                    .frame(width: 18)
                Text(self.title)
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(self.hovering ? .primary : .secondary)
            .padding(.horizontal, RunicSpacing.sm)
            .padding(.vertical, RunicSpacing.compact)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(self.hovering ? 1 : 0))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(self.hovering ? 0.18 : 0),
                        lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .onHover { over in
            withAnimation(.easeOut(duration: 0.18)) { self.hovering = over }
        }
        .scaleEffect(self.hovering ? 1.04 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: self.hovering)
    }
}

// MARK: - About pane

@MainActor
struct AboutPane: View {
    let updater: UpdaterProviding
    @State private var iconHover = false
    @State private var appeared = false
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
        ZStack {
            LiquidMeshBackground()
                .ignoresSafeArea()
                .opacity(0.6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: RunicSpacing.lg) {
                    self.heroSection
                    self.linksSection
                    self.updaterSection
                    self.footerSection
                }
                .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
                .padding(.vertical, PreferencesLayoutMetrics.paneVertical)
            }
        }
        .onAppear {
            guard !self.didLoadUpdaterState else { return }
            self.updater.automaticallyChecksForUpdates = self.autoUpdateEnabled
            self.updater.automaticallyDownloadsUpdates = self.autoUpdateEnabled
            self.didLoadUpdaterState = true
            withAnimation(.easeOut(duration: 0.8)) { self.appeared = true }
        }
        .onChange(of: self.autoUpdateEnabled) { _, newValue in
            self.updater.automaticallyChecksForUpdates = newValue
            self.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: RunicSpacing.md) {
            ZStack {
                FloatingOrb(color: .blue, size: 120, speed: 0.4, offset: 0)
                    .offset(x: -30, y: -10)
                FloatingOrb(color: .purple, size: 90, speed: 0.5, offset: 2.1)
                    .offset(x: 25, y: 15)

                if let image = NSApplication.shared.applicationIconImage {
                    Button(action: self.openProjectHome) {
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: RunicCornerRadius.xl, style: .continuous))
                            .shadow(
                                color: .black.opacity(0.18),
                                radius: self.iconHover ? 16 : 8,
                                y: self.iconHover ? 6 : 3)
                            .scaleEffect(self.iconHover ? 1.06 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Runic project on GitHub")
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            self.iconHover = hovering
                        }
                    }
                }
            }
            .frame(height: 120)

            VStack(spacing: RunicSpacing.xxs) {
                Text("Runic")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                Text("Version \(self.versionString)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if let buildTimestamp {
                    Text("Built \(buildTimestamp)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(spacing: RunicSpacing.xs) {
                Text("पूर्णमदः पूर्णमिदं पूर्णात् पूर्णमुदच्यते")
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("From fullness comes fullness.\nWhen fullness is taken from fullness,\nfullness alone remains.")
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                Text("— Isha Upanishad")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(self.appeared ? 1 : 0)
        .offset(y: self.appeared ? 0 : 12)
    }

    // MARK: - Links

    private var linksSection: some View {
        GlassCard {
            HStack(spacing: RunicSpacing.xs) {
                LiquidLinkButton(
                    icon: "chevron.left.slash.chevron.right",
                    title: "GitHub",
                    url: "https://github.com/sriinnu/Runic")
                LiquidLinkButton(
                    icon: "globe",
                    title: "Web",
                    url: "https://www.srinivas.dev")
                LiquidLinkButton(
                    icon: "bird",
                    title: "Twitter",
                    url: "https://x.com/sriinnu")
                LiquidLinkButton(
                    icon: "envelope",
                    title: "Email",
                    url: "mailto:sriinnu@users.noreply.github.com")
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(self.appeared ? 1 : 0)
        .offset(y: self.appeared ? 0 : 16)
        .animation(.easeOut(duration: 0.7).delay(0.15), value: self.appeared)
    }

    // MARK: - Updater

    private var updaterSection: some View {
        GlassCard {
            if self.updater.isAvailable {
                VStack(spacing: RunicSpacing.sm) {
                    Toggle("Check for updates automatically", isOn: self.$autoUpdateEnabled)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 12.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Button("Check for Updates…") { self.updater.checkForUpdates(nil) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else {
                Text(self.updater.unavailableReason ?? "Updates unavailable in this build.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .opacity(self.appeared ? 1 : 0)
        .offset(y: self.appeared ? 0 : 20)
        .animation(.easeOut(duration: 0.7).delay(0.25), value: self.appeared)
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("© 2025–2026 Srinivas Pendela. MIT License.")
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .opacity(self.appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.35), value: self.appeared)
    }

    private func openProjectHome() {
        guard let url = URL(string: "https://github.com/sriinnu/Runic") else { return }
        NSWorkspace.shared.open(url)
    }
}
