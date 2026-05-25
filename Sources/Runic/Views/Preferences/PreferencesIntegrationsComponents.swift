import AppKit
import SwiftUI

struct MCPServer: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var port: Int
}

struct WebhookTestResult: Equatable {
    var message: String
    var isSuccess: Bool
}

enum IntegrationWebhookPayload {
    static func data(format: String) -> Data {
        let text = "Runic webhook test"
        switch format {
        case "discord":
            return Data("{\"content\":\"\(text)\"}".utf8)
        case "generic":
            return Data("{\"event\":\"runic.test\",\"message\":\"\(text)\"}".utf8)
        default:
            return Data("{\"text\":\"\(text)\"}".utf8)
        }
    }
}

@MainActor
struct AdditionalUsageLogPathsEditor: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Binding var paths: String

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Additional usage log paths")
                .font(self.fonts.callout.weight(.semibold))
            TextField("~/Library/Logs/ai-usage.jsonl, /path/to/otel-logs", text: self.$paths)
                .textFieldStyle(.roundedBorder)
            Text("Comma, semicolon, or newline separated JSON/JSONL files and folders.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
struct GitRepositoryStatus: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let repositoryPath: String
    let isValid: Bool

    var body: some View {
        HStack(spacing: RunicSpacing.xs) {
            Image(systemName: self.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(self.isValid ? .green : .red)
            Text(self.statusText)
                .font(self.fonts.footnote)
                .foregroundStyle(self.isValid ? .green : self.runicTheme.subduedSecondaryText)
        }
    }

    private var statusText: String {
        if self.repositoryPath.isEmpty { return "Choose a local repository." }
        return self.isValid ? "Valid Git repository" : "Not a valid Git repository"
    }
}

@MainActor
struct IntegrationRow<Actions: View>: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let icon: String
    var iconIntent: RunicIconIntent = .info
    let title: String
    let status: String
    let detail: String
    var path: String?
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: RunicSpacing.sm) {
            RunicThemedSystemIcon(
                systemName: self.icon,
                intent: self.iconIntent,
                font: self.fonts.callout,
                width: 24)

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                HStack(spacing: RunicSpacing.xs) {
                    Text(self.title)
                        .font(self.fonts.callout.weight(.semibold))
                    IntegrationStatusPill(text: self.status)
                }
                Text(self.detail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let path {
                    Text(path)
                        .font(self.fonts.caption.monospaced())
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: RunicSpacing.xs) {
                    self.actions
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor
struct IntegrationMCPServerRow: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let server: MCPServer
    @Binding var copiedValue: String?
    let onCopy: (String) -> Void
    let onRemove: (MCPServer) -> Void

    var body: some View {
        HStack(spacing: RunicSpacing.sm) {
            RunicThemedSystemIcon(
                systemName: "bolt.horizontal.circle",
                intent: .data,
                font: self.fonts.callout,
                width: 24)

            VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                Text(self.server.name)
                    .font(self.fonts.callout.weight(.semibold))
                Text("localhost:\(self.server.port)")
                    .font(self.fonts.caption.monospaced())
                    .foregroundStyle(self.runicTheme.secondaryText)
            }

            Spacer()

            IntegrationCopyButton(
                title: "Copy",
                value: "mcp connect localhost:\(self.server.port)",
                copiedValue: self.$copiedValue,
                onCopy: self.onCopy)
            Button {
                self.onRemove(self.server)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.red)
        }
        .padding(RunicSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .fill(self.runicTheme.menuSubtleFill))
        .overlay(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .stroke(self.runicTheme.menuSeparatorColor.opacity(0.42), lineWidth: 0.7))
    }
}

@MainActor
struct IntegrationEmptyState: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: RunicSpacing.xs) {
            RunicThemedSystemIcon(
                systemName: self.icon,
                intent: .info,
                font: .system(size: 28))
            Text(self.title)
                .font(self.fonts.callout.weight(.semibold))
            Text(self.detail)
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RunicSpacing.lg)
    }
}

@MainActor
private struct IntegrationStatusPill: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let text: String

    var body: some View {
        Text(self.text)
            .font(self.fonts.caption.weight(.semibold))
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxxs)
            .background(Capsule(style: .continuous).fill(self.runicTheme.menuSubtleFill))
    }
}

@MainActor
struct IntegrationCopyButton: View {
    let title: String
    let value: String
    @Binding var copiedValue: String?
    let onCopy: (String) -> Void

    var body: some View {
        Button {
            self.onCopy(self.value)
        } label: {
            Label(
                self.copiedValue == self.value ? "Copied" : self.title,
                systemImage: self.copiedValue == self.value ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

@MainActor
struct IntegrationRevealButton: View {
    let path: String

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: self.path)])
        } label: {
            Label("Reveal", systemImage: "folder")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

@MainActor
struct IntegrationLinkButton: View {
    let title: String
    let systemImage: String
    let url: URL?

    var body: some View {
        Button {
            if let url {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Label(self.title, systemImage: self.systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(self.url == nil)
    }
}

@MainActor
struct AddMCPServerSheet: View {
    @Environment(\.runicFonts) private var fonts
    @Binding var name: String
    @Binding var port: Int
    let onAdd: () -> Void
    let onCancel: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.lg) {
            Text("Add MCP Profile")
                .font(self.fonts.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Name")
                    .font(self.fonts.subheadline.weight(.medium))
                TextField("Local MCP Bridge", text: self.$name)
                    .textFieldStyle(.roundedBorder)
                    .focused(self.$isNameFocused)
            }

            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Port")
                    .font(self.fonts.subheadline.weight(.medium))
                TextField("", value: self.$port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { self.onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { self.onAdd() }
                    .buttonStyle(.borderedProminent)
                    .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RunicSpacing.lg)
        .frame(width: 420)
        .onAppear { self.isNameFocused = true }
    }
}
