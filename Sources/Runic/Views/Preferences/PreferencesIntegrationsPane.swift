import AppKit
import RunicCore
import SwiftUI

@MainActor
struct IntegrationsPane: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    @State private var copiedPath: String?

    private var collectorPath: String {
        OTelGenAICollectorConfiguration.defaultOutputFile().path
    }

    private var koshaPath: String {
        NSString(string: "~/.kosha/registry.json").expandingTildeInPath
    }

    var body: some View {
        PreferencesPane {
            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                self.sectionTitle("Local data sources")
                self.statusRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Provider JSONL logs",
                    status: "Read-only",
                    detail: "Runic never deletes Claude/Codex provider logs. It scans recent changes " +
                        "and keeps local daily summaries for older history.")
                self.statusRow(
                    icon: "waveform.path.ecg.rectangle",
                    title: "OpenTelemetry GenAI ledger",
                    status: FileManager.default.fileExists(atPath: self.collectorPath) ? "Found" : "Ready",
                    detail: "The local collector writes sanitized metric JSONL here. Prompts and " +
                        "responses are not persisted.",
                    path: self.collectorPath)
                self.pathEditor
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                self.sectionTitle("Detected integrations")
                self.statusRow(
                    icon: "sparkles",
                    title: "Kosha model registry",
                    status: FileManager.default.fileExists(atPath: self.koshaPath) ? "Found" : "Optional",
                    detail: "Runic reads Kosha locally for model context metadata when the registry exists.",
                    path: self.koshaPath)
                self.statusRow(
                    icon: "bell.badge",
                    title: "Alert webhooks",
                    status: "Analytics",
                    detail: "Per-rule webhook URLs live in Analytics > Alerts inside Add/Edit Rule.")
                self.statusRow(
                    icon: "terminal",
                    title: "Runic CLI",
                    status: "Performance",
                    detail: "Install or refresh the command-line helper from Performance > Refresh & Safety.")
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(self.fonts.caption.weight(.semibold))
            .foregroundStyle(self.runicTheme.secondaryText)
            .textCase(.uppercase)
    }

    private var pathEditor: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Additional usage log paths")
                .font(self.fonts.body)
            TextField("~/Library/Logs/ai-usage.jsonl, /path/to/otel-logs", text: self.$settings.otelGenAILogPaths)
                .textFieldStyle(.roundedBorder)
            Text("Comma, semicolon, or newline separated JSON/JSONL files and folders.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.72))
        }
    }

    private func statusRow(
        icon: String,
        title: String,
        status: String,
        detail: String,
        path: String? = nil) -> some View
    {
        HStack(alignment: .top, spacing: RunicSpacing.sm) {
            Image(systemName: icon)
                .font(self.fonts.callout)
                .frame(width: 22)
                .foregroundStyle(self.runicTheme.accent)
            VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                HStack(spacing: RunicSpacing.xs) {
                    Text(title)
                        .font(self.fonts.body.weight(.semibold))
                    Text(status)
                        .font(self.fonts.caption.weight(.semibold))
                        .padding(.horizontal, RunicSpacing.xs)
                        .padding(.vertical, RunicSpacing.xxxs)
                        .background(Capsule(style: .continuous).fill(self.runicTheme.menuSubtleFill))
                }
                Text(detail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
                if let path {
                    HStack(spacing: RunicSpacing.xs) {
                        Text(path)
                            .font(self.fonts.caption.monospaced())
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button(self.copiedPath == path ? "Copied" : "Copy") {
                            self.copy(path)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        self.copiedPath = text
    }
}
