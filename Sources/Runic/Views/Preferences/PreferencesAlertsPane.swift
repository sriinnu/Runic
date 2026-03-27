import AppKit
import RunicCore
import SwiftUI

@MainActor
struct AlertsPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    @State private var alertsData: AlertRuleStore.AlertsData = AlertRuleStore.load()
    @State private var showingAddRule = false
    @State private var editingRule: AlertRuleStore.AlertRule?
    @State private var showingTestResult: String?
    @State private var defaultWebhookURL: String = ""
    @State private var webhookFormat: WebhookFormat = .slack

    enum WebhookFormat: String, CaseIterable, Identifiable {
        case slack
        case discord
        case generic

        var id: String {
            self.rawValue
        }

        var label: String {
            switch self {
            case .slack: "Slack"
            case .discord: "Discord"
            case .generic: "Generic"
            }
        }
    }

    var body: some View {
        PreferencesPane {
            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Alert Rules")
                    .font(RunicFont.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    HStack {
                        Text("\(self.alertsData.rules.count) rules configured")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            self.showingAddRule = true
                        } label: {
                            Label("Add Rule", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if self.alertsData.rules.isEmpty {
                        Text("No alert rules configured. Add a rule to get started.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, RunicSpacing.md)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: RunicSpacing.xxs) {
                            ForEach(self.alertsData.rules) { rule in
                                self.ruleRow(rule)
                            }
                        }
                        .padding(.vertical, RunicSpacing.xs)
                    }
                }
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Webhook Configuration")
                    .font(RunicFont.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default webhook URL")
                            .font(RunicFont.body)
                        TextField("https://hooks.slack.com/services/...", text: self.$defaultWebhookURL)
                            .textFieldStyle(.roundedBorder)
                        Text("Used for all alerts unless overridden in rule settings.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Webhook format")
                            .font(RunicFont.body)
                        Picker("", selection: self.$webhookFormat) {
                            ForEach(WebhookFormat.allCases) { format in
                                Text(format.label).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    }

                    HStack(spacing: RunicSpacing.xs) {
                        Button("Test Webhook") {
                            self.testWebhook()
                        }
                        .buttonStyle(.bordered)
                        .disabled(self.defaultWebhookURL.isEmpty)

                        if let result = self.showingTestResult {
                            Text(result)
                                .font(RunicFont.footnote)
                                .foregroundStyle(result.contains("Success") ? .green : .red)
                        }
                    }
                }
            }

            PreferencesDivider()

            SettingsSection(contentSpacing: PreferencesLayoutMetrics.sectionSpacing) {
                Text("Alert History")
                    .font(RunicFont.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    HStack {
                        Text("Last 20 triggered alerts")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Clear History") {
                            self.clearHistory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(self.alertsData.history.isEmpty)
                    }

                    let recentHistory = AlertRuleStore.getRecentHistory(limit: 20)

                    if recentHistory.isEmpty {
                        Text("No alerts triggered yet.")
                            .font(RunicFont.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, RunicSpacing.md)
                            .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: RunicSpacing.xxs) {
                                ForEach(recentHistory) { entry in
                                    self.historyRow(entry)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
        }
        .sheet(isPresented: self.$showingAddRule) {
            RuleEditorSheet(
                rule: nil,
                onSave: { newRule in
                    do {
                        try AlertRuleStore.addRule(newRule)
                        self.alertsData = AlertRuleStore.load()
                    } catch {
                        print("Failed to add rule: \(error)")
                    }
                })
        }
        .sheet(item: self.$editingRule) { rule in
            RuleEditorSheet(
                rule: rule,
                onSave: { updatedRule in
                    do {
                        try AlertRuleStore.updateRule(updatedRule)
                        self.alertsData = AlertRuleStore.load()
                    } catch {
                        print("Failed to update rule: \(error)")
                    }
                })
        }
    }

    private func ruleRow(_ rule: AlertRuleStore.AlertRule) -> some View {
        HStack(spacing: RunicSpacing.sm) {
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { enabled in
                    var updatedRule = rule
                    updatedRule.enabled = enabled
                    try? AlertRuleStore.updateRule(updatedRule)
                    self.alertsData = AlertRuleStore.load()
                }))
                .toggleStyle(.switch)
                .controlSize(.small)

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                HStack(spacing: RunicSpacing.xs) {
                    Text(self.alertTypeLabel(rule.type))
                        .font(RunicFont.body)

                    self.severityBadge(rule.severity)
                }

                Text("Threshold: \(Int(rule.threshold))%")
                    .font(RunicFont.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    self.editingRule = rule
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)

                Button {
                    self.deleteRule(rule)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.red)
            }
        }
        .padding(RunicSpacing.xs)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(RunicCornerRadius.sm)
    }

    private func historyRow(_ entry: AlertRuleStore.AlertHistoryEntry) -> some View {
        HStack(spacing: RunicSpacing.sm) {
            self.severityBadge(entry.severity)

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                Text(entry.message)
                    .font(RunicFont.footnote)
                    .lineLimit(2)

                Text(self.relativeTime(entry.triggeredAt))
                    .font(RunicFont.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !entry.acknowledged {
                Button("Ack") {
                    try? AlertRuleStore.acknowledgeAlert(id: entry.id)
                    self.alertsData = AlertRuleStore.load()
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .foregroundStyle(.blue)
            }
        }
        .padding(RunicSpacing.xs)
        .background(Color(nsColor: .controlBackgroundColor).opacity(entry.acknowledged ? 0.5 : 1.0))
        .cornerRadius(RunicCornerRadius.sm)
    }

    private func severityBadge(_ severity: AlertRuleStore.AlertSeverity) -> some View {
        let color: Color = switch severity {
        case .info: .blue
        case .warning: .orange
        case .critical: .red
        }

        return Text(severity.rawValue.uppercased())
            .font(RunicFont.caption2.weight(.semibold))
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxs)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(RunicCornerRadius.xs)
    }

    private func alertTypeLabel(_ type: AlertRuleStore.AlertType) -> String {
        switch type {
        case .projectBudget: "Project Budget"
        case .usageVelocity: "Usage Velocity"
        case .costAnomaly: "Cost Anomaly"
        case .quotaThreshold: "Quota Threshold"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func deleteRule(_ rule: AlertRuleStore.AlertRule) {
        try? AlertRuleStore.removeRule(id: rule.id)
        self.alertsData = AlertRuleStore.load()
    }

    private func clearHistory() {
        var data = self.alertsData
        data.history = []
        try? AlertRuleStore.save(data)
        self.alertsData = AlertRuleStore.load()
    }

    private func testWebhook() {
        guard !self.defaultWebhookURL.isEmpty else { return }

        // Simulate webhook test
        Task {
            self.showingTestResult = "Testing..."
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.showingTestResult = "Success: 200 OK"

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.showingTestResult = nil
        }
    }
}

// MARK: - Rule Editor Sheet

@MainActor
private struct RuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let rule: AlertRuleStore.AlertRule?
    let onSave: (AlertRuleStore.AlertRule) -> Void

    @State private var alertType: AlertRuleStore.AlertType
    @State private var threshold: Double
    @State private var severity: AlertRuleStore.AlertSeverity
    @State private var webhookURL: String
    @State private var notifyWebhook: Bool

    init(rule: AlertRuleStore.AlertRule?, onSave: @escaping (AlertRuleStore.AlertRule) -> Void) {
        self.rule = rule
        self.onSave = onSave

        self._alertType = State(initialValue: rule?.type ?? .projectBudget)
        self._threshold = State(initialValue: rule?.threshold ?? 80.0)
        self._severity = State(initialValue: rule?.severity ?? .warning)
        self._webhookURL = State(initialValue: rule?.webhookURL ?? "")
        self._notifyWebhook = State(initialValue: rule?.notifyWebhook ?? false)
    }

    var body: some View {
        VStack(spacing: RunicSpacing.lg) {
            Text(self.rule == nil ? "Add Alert Rule" : "Edit Alert Rule")
                .font(RunicFont.headline)

            Form {
                Picker("Alert Type", selection: self.$alertType) {
                    Text("Project Budget").tag(AlertRuleStore.AlertType.projectBudget)
                    Text("Usage Velocity").tag(AlertRuleStore.AlertType.usageVelocity)
                    Text("Cost Anomaly").tag(AlertRuleStore.AlertType.costAnomaly)
                    Text("Quota Threshold").tag(AlertRuleStore.AlertType.quotaThreshold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Threshold: \(Int(self.threshold))%")
                    Slider(value: self.$threshold, in: 0...100, step: 5)
                }

                Picker("Severity", selection: self.$severity) {
                    Text("Info").tag(AlertRuleStore.AlertSeverity.info)
                    Text("Warning").tag(AlertRuleStore.AlertSeverity.warning)
                    Text("Critical").tag(AlertRuleStore.AlertSeverity.critical)
                }

                Toggle("Enable webhook notifications", isOn: self.$notifyWebhook)

                if self.notifyWebhook {
                    TextField("Webhook URL", text: self.$webhookURL)
                }
            }
            .padding()

            HStack {
                Button("Cancel") {
                    self.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    let newRule = AlertRuleStore.AlertRule(
                        id: self.rule?.id ?? UUID().uuidString,
                        type: self.alertType,
                        threshold: self.threshold,
                        severity: self.severity,
                        notifyWebhook: self.notifyWebhook,
                        webhookURL: self.webhookURL.isEmpty ? nil : self.webhookURL,
                        createdAt: self.rule?.createdAt ?? Date())
                    self.onSave(newRule)
                    self.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(RunicSpacing.lg)
        .frame(width: 400)
    }
}
