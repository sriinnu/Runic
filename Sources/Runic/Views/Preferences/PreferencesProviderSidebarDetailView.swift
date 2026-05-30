import AppKit
import RunicCore
import SwiftUI

@MainActor
struct ProviderSidebarDetailView: View {
    @Environment(\.runicFonts) var fonts
    let provider: UsageProvider
    @Bindable var store: UsageStore
    @Binding var isEnabled: Bool
    let subtitle: String
    let usageStatus: ProviderUsageStatus
    let sourceLabel: String
    let statusLabel: String
    let settingsToggles: [ProviderSettingsToggleDescriptor]
    let settingsFields: [ProviderSettingsFieldDescriptor]
    let errorDisplay: ProviderErrorDisplay?
    @Binding var isErrorExpanded: Bool
    let onCopyError: (String) -> Void
    @State var diagnosticsCopyStatus: String?
    @State var selectedSubview: ProviderDetailSubview = .overview
    @State var historyMetricMode: ProviderHistoryMetricMode = .tokens
    @State var historyMonthStart: Date = Self.monthStart(for: Date())
    @State var historySnapshot: ProviderHistoryMonthSnapshot?
    @State var historySelectedDay: Date?
    @State var historyDayDetailMode: ProviderHistoryDayDetailMode = .summary
    @State var historyIsLoading = false
    @State var historyError: String?
    @Environment(\.runicTheme) var runicTheme

    var body: some View {
        let insightLines = ProviderInsightsComposer.lines(for: self.provider, store: self.store)
        let topModelLines = self.topModelLines
        let topProjectLines = self.topProjectLines

        ScrollView {
            VStack(alignment: .leading, spacing: ProviderListMetrics.sidebarSectionSpacing) {
                ProviderSidebarSectionCard {
                    VStack(alignment: .leading, spacing: RunicSpacing.md) {
                        HStack(alignment: .top, spacing: RunicSpacing.sm) {
                            ProviderListBrandIcon(provider: self.provider)
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                Text(self.store.metadata(for: self.provider).displayName)
                                    .font(self.fonts.title2.weight(.semibold))
                                Text(self.subtitle)
                                    .font(self.fonts.caption)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                            }
                            Spacer()
                            Toggle("Enabled", isOn: self.$isEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        Divider()

                        Picker("View", selection: self.$selectedSubview) {
                            ForEach(ProviderDetailSubview.allCases) { view in
                                Text(view.rawValue).tag(view)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if self.selectedSubview == .overview {
                    ProviderSidebarSectionCard {
                        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                ProviderSidebarSectionHeader(title: "Overview")
                                ProviderSidebarKeyValueRow(label: "Source", value: self.sourceLabel, helpText: nil)
                                ProviderSidebarKeyValueRow(label: "Updated", value: self.statusLabel, helpText: nil)
                                if let runtimeMetrics = self.runtimeMetrics {
                                    ProviderSidebarKeyValueRow(
                                        label: "Runtime",
                                        value: runtimeMetrics.lineText,
                                        helpText: runtimeMetrics.hoverText)
                                }
                                self.statusBadge
                            }

                            if !self.quickMetrics.isEmpty {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(minimum: 120), spacing: RunicSpacing.xs),
                                        GridItem(.flexible(minimum: 120), spacing: RunicSpacing.xs),
                                    ],
                                    alignment: .leading,
                                    spacing: RunicSpacing.xs)
                                {
                                    ForEach(self.quickMetrics) { metric in
                                        ProviderSidebarMetricChip(
                                            title: metric.title,
                                            value: metric.value,
                                            helpText: metric.helpText)
                                    }
                                }
                            }

                            HStack(spacing: RunicSpacing.xs) {
                                Button("Copy diagnostics") {
                                    self.copyDiagnostics()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("Copy fetch path, reliability, anomaly, and budget/forecast details.")

                                if let diagnosticsCopyStatus {
                                    Text(diagnosticsCopyStatus)
                                        .font(self.fonts.caption2)
                                        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                                }
                            }
                        }
                    }

                    if !insightLines.isEmpty {
                        ProviderSidebarSectionCard {
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                ProviderSidebarSectionHeader(title: "Insights")
                                ProviderInsightsView(lines: insightLines)
                            }
                        }
                    }

                    if !topModelLines.isEmpty || !topProjectLines.isEmpty {
                        ProviderSidebarSectionCard {
                            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                ProviderSidebarSectionHeader(title: "Activity leaders")
                                HStack(alignment: .top, spacing: RunicSpacing.md) {
                                    if !topModelLines.isEmpty {
                                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                            Text(self.modelSectionTitle)
                                                .font(self.fonts.caption2.weight(.semibold))
                                                .foregroundStyle(self.runicTheme.secondaryText)
                                            ForEach(Array(topModelLines.enumerated()), id: \.offset) { index, line in
                                                Text("\(index + 1). \(line)")
                                                    .font(self.fonts.caption)
                                                    .foregroundStyle(self.runicTheme.secondaryText)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    if !topProjectLines.isEmpty {
                                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                            Text("Projects")
                                                .font(self.fonts.caption2.weight(.semibold))
                                                .foregroundStyle(self.runicTheme.secondaryText)
                                            ForEach(Array(topProjectLines.enumerated()), id: \.offset) { index, line in
                                                Text("\(index + 1). \(line)")
                                                    .font(self.fonts.caption)
                                                    .foregroundStyle(self.runicTheme.secondaryText)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    self.historyContent
                }

                if let errorDisplay, self.isEnabled {
                    ProviderErrorView(
                        title: "Last fetch failed:",
                        display: errorDisplay,
                        isExpanded: self.$isErrorExpanded,
                        onCopy: { self.onCopyError(errorDisplay.full) })
                }

                if self.isEnabled, !self.settingsFields.isEmpty {
                    ProviderSidebarSectionCard {
                        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                            ProviderSidebarSectionHeader(title: "Settings fields")
                            ForEach(self.settingsFields) { field in
                                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                    Text(field.title)
                                        .font(self.fonts.body.weight(.medium))
                                    Text(field.subtitle)
                                        .font(self.fonts.caption)
                                        .foregroundStyle(self.runicTheme.secondaryText)
                                    switch field.kind {
                                    case .plain:
                                        TextField(field.placeholder ?? "", text: field.binding)
                                            .textFieldStyle(.roundedBorder)
                                            .font(self.fonts.callout)
                                    case .secure:
                                        SecureField(field.placeholder ?? "", text: field.binding)
                                            .textFieldStyle(.roundedBorder)
                                            .font(self.fonts.callout)
                                    }
                                    self.fieldActions(field.actions)
                                }
                            }
                        }
                    }
                }

                if self.isEnabled, !self.settingsToggles.isEmpty {
                    ProviderSidebarSectionCard {
                        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                            ProviderSidebarSectionHeader(title: "Settings toggles")
                            ForEach(self.settingsToggles) { toggle in
                                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                    Toggle(isOn: toggle.binding) {
                                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                                            Text(toggle.title)
                                                .font(self.fonts.body.weight(.medium))
                                            Text(toggle.subtitle)
                                                .font(self.fonts.caption)
                                                .foregroundStyle(self.runicTheme.secondaryText)
                                        }
                                    }
                                    .toggleStyle(.checkbox)

                                    if toggle.binding.wrappedValue {
                                        if let status = toggle.statusText?(), !status.isEmpty {
                                            Text(status)
                                                .font(self.fonts.caption)
                                                .foregroundStyle(self.runicTheme.secondaryText)
                                                .padding(RunicSpacing.xs)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(
                                                    RoundedRectangle(
                                                        cornerRadius: ProviderListMetrics.sidebarMicroCardCornerRadius,
                                                        style: .continuous)
                                                        .fill(Color(
                                                            nsColor: .controlBackgroundColor).opacity(
                                                            ProviderListMetrics.sidebarMicroCardBackgroundOpacity)))
                                        }
                                        self.toggleActions(toggle.actions)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(RunicSpacing.lg)
        }
        .frame(maxWidth: .infinity, minHeight: 0, alignment: .topLeading)
        .clipped()
        .task(id: self.historyTaskID) {
            guard self.selectedSubview == .history else { return }
            await self.loadHistoryMonth()
        }
        .onChange(of: self.provider) { _, _ in
            self.selectedSubview = .overview
            self.historyMetricMode = .tokens
            self.historyMonthStart = Self.monthStart(for: Date())
            self.historySnapshot = nil
            self.historySelectedDay = nil
            self.historyDayDetailMode = .summary
            self.historyError = nil
            self.historyIsLoading = false
        }
    }
}
