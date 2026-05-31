import AppKit
import RunicCore
import SwiftUI

struct RunicOperationsCenterView: View {
    @Environment(\.runicFonts) private var fonts
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    let diagnosticsStatus: String?
    let guardrailStatus: String?
    let onCopyDiagnostics: () -> Void
    let onInstallGuardrails: () -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let health = RunicDiagnosticsReport.providerHealthRows(settings: self.settings, store: self.store)
        let recommendations = RunicDiagnosticsReport.recommendations(settings: self.settings, store: self.store)
        let connected = health.count {
            $0.credentialState == .connected ||
                $0.credentialState == .configured ||
                $0.credentialState == .local
        }
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            HStack(spacing: RunicSpacing.xs) {
                self.summaryPill(
                    title: "Credentials",
                    value: "\(connected)/\(max(health.count, 1))",
                    systemImage: "key.horizontal")
                self.summaryPill(
                    title: "Alerts",
                    value: "\(AlertRuleStore.load().rules.count)",
                    systemImage: "bell.badge")
                self.summaryPill(
                    title: "Budgets",
                    value: "\(ProjectBudgetStore.getAllBudgets().count)",
                    systemImage: "target")
            }

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                Text("Provider health")
                    .font(self.fonts.caption.weight(.semibold))
                    .foregroundStyle(self.runicTheme.secondaryText)
                ForEach(Array(health.prefix(6))) { row in
                    ProviderHealthCompactRow(row: row)
                }
                if health.count > 6 {
                    Text("+ \(health.count - 6) more providers")
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                Text("Recommended next actions")
                    .font(self.fonts.caption.weight(.semibold))
                    .foregroundStyle(self.runicTheme.secondaryText)
                ForEach(recommendations.prefix(4)) { recommendation in
                    HStack(alignment: .top, spacing: RunicSpacing.xs) {
                        RunicThemedSystemIcon(
                            systemName: recommendation.systemImage,
                            intent: .info,
                            font: self.fonts.caption,
                            width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(recommendation.title)
                                .font(self.fonts.caption.weight(.semibold))
                            Text(recommendation.detail)
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack(spacing: RunicSpacing.xs) {
                Button {
                    self.onInstallGuardrails()
                } label: {
                    Label("Install Guardrails", systemImage: "shield.checkered")
                }
                .buttonStyle(.bordered)

                Button {
                    self.onCopyDiagnostics()
                } label: {
                    Label("Copy Diagnostics", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                if let status = self.guardrailStatus ?? self.diagnosticsStatus {
                    Text(status)
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }
        }
    }

    private func summaryPill(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: RunicSpacing.xxs) {
            RunicThemedSystemIcon(
                systemName: systemImage,
                intent: .data,
                font: self.fonts.caption)
            Text(title)
                .font(self.fonts.caption2)
            Text(value)
                .font(self.fonts.caption2.weight(.semibold))
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.xxxs)
        .background(
            Capsule(style: .continuous)
                .fill(self.runicTheme.menuSubtleFill))
        .overlay(
            Capsule(style: .continuous)
                .stroke(self.runicTheme.menuSeparatorColor.opacity(0.55), lineWidth: 0.7))
    }
}

private struct ProviderHealthCompactRow: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let row: RunicProviderHealthRow

    var body: some View {
        HStack(alignment: .center, spacing: RunicSpacing.xs) {
            if let icon = ProviderBrandIcon.image(for: self.row.provider, size: 20) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: RunicSpacing.xxs) {
                    Text(self.row.name)
                        .font(self.fonts.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(self.row.source)
                        .font(self.fonts.caption2.weight(.medium))
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .lineLimit(1)
                }
                Text("\(self.row.credentialDetail) · \(self.row.dataDetail)")
                    .font(self.fonts.caption2)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: RunicSpacing.xs)

            Text(self.row.credentialState.label)
                .font(self.fonts.caption2.weight(.semibold))
                .foregroundStyle(self.stateColor)
                .padding(.horizontal, RunicSpacing.xs)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(self.stateColor.opacity(0.12)))
        }
        .padding(.vertical, 2)
    }

    private var stateColor: Color {
        switch self.row.credentialState {
        case .connected, .configured: .green
        case .local: .blue
        case .missing: .orange
        case .attention: .red
        }
    }
}
