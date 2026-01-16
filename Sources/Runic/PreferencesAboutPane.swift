import AppKit
import SwiftUI

@MainActor
struct AboutPane: View {
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
        VStack(spacing: 12) {
            if let image = NSApplication.shared.applicationIconImage {
                Button(action: self.openProjectHome) {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: 92, height: 92)
                        .cornerRadius(16)
                        .scaleEffect(self.iconHover ? 1.05 : 1.0)
                        .shadow(color: self.iconHover ? .accentColor.opacity(0.25) : .clear, radius: 6)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        self.iconHover = hovering
                    }
                }
            }

            VStack(spacing: 2) {
                Text("Runic")
                    .font(.title3).bold()
                Text("Version \(self.versionString)")
                    .foregroundStyle(.secondary)
                if let buildTimestamp {
                    Text("Built \(buildTimestamp)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("May your tokens never run out—keep agent limits in view.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .center, spacing: 10) {
                AboutLinkRow(
                    icon: "chevron.left.slash.chevron.right",
                    title: "GitHub",
                    url: "https://github.com/sriinnu/athena/Runic")
                AboutLinkRow(icon: "globe", title: "Website", url: "https://www.srinivas.dev")
                AboutLinkRow(icon: "bird", title: "Twitter", url: "https://x.com/sriinnu")
                AboutLinkRow(icon: "envelope", title: "Email", url: "mailto:hello@srinivas.dev")
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            Divider()

            if self.updater.isAvailable {
                VStack(spacing: 10) {
                    Toggle("Check for updates automatically", isOn: self.$autoUpdateEnabled)
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Button("Check for Updates…") { self.updater.checkForUpdates(nil) }
                }
            } else {
                Text(self.updater.unavailableReason ?? "Updates unavailable in this build.")
                    .foregroundStyle(.secondary)
            }

            Text("© 2025 Srinivas Pendela. MIT License.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
        .padding(.vertical, PreferencesLayoutMetrics.paneVertical)
        .onAppear {
            guard !self.didLoadUpdaterState else { return }
            // Align Sparkle's flag with the persisted preference on first load.
            self.updater.automaticallyChecksForUpdates = self.autoUpdateEnabled
            self.updater.automaticallyDownloadsUpdates = self.autoUpdateEnabled
            self.didLoadUpdaterState = true
        }
        .onChange(of: self.autoUpdateEnabled) { _, newValue in
            self.updater.automaticallyChecksForUpdates = newValue
            self.updater.automaticallyDownloadsUpdates = newValue
        }
    }

    private func openProjectHome() {
        guard let url = URL(string: "https://github.com/sriinnu/athena/Runic") else { return }
        NSWorkspace.shared.open(url)
    }
}
