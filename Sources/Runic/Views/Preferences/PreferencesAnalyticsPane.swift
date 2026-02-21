import AppKit
import RunicCore
import SwiftUI

@MainActor
struct AnalyticsPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    // MARK: - Disclosure state

    @State private var displayExpanded = true
    @State private var insightsExpanded = false
    @State private var alertsExpanded = false
    @State private var budgetsExpanded = false

    // MARK: - Alerts state

    @State private var alertsData: AlertRuleStore.AlertsData = AlertRuleStore.load()
    @State private var showingAddRule = false
    @State private var editingRule: AlertRuleStore.AlertRule?

    // MARK: - Budgets state

    @State private var budgets: [ProjectBudgetStore.ProjectBudget] = []
    @State private var editingProjectID: String?
    @State private var showingAddBudget = false
    @State private var newProjectID = ""
    @State private var newProjectName = ""
    @State private var newMonthlyLimit = ""
    @State private var newAlertThreshold = "80"
    @State private var budgetErrorMessage: String?

    var body: some View {
        PreferencesPane {
            // MARK: - Display section

            DisclosureGroup("Display", isExpanded: self.$displayExpanded) {
                VStack(alignment: .leading, spacing: PreferencesLayoutMetrics.sectionSpacing) {
                    PreferenceToggleRow(
                        title: "Show usage as used",
                        subtitle: "Progress bars fill as you consume quota (instead of showing remaining).",
                        binding: self.$settings.usageBarsShowUsed)
                    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                        Text("Usage metrics")
                            .font(.body)
                        Picker("", selection: self.$settings.usageMetricDisplayMode) {
                            ForEach(UsageMetricDisplayMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("Pick bars, percent, or both in the menu card.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    PreferenceToggleRow(
                        title: "Show credits + extra usage",
                        subtitle: "Show Codex Credits and Claude Extra usage sections in the menu.",
                        binding: self.$settings.showOptionalCreditsAndExtraUsage)
                    PreferenceToggleRow(
                        title: "Merge Icons",
                        subtitle: "Use a single menu bar icon with a provider switcher.",
                        binding: self.$settings.mergeIcons)
                    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                        Text("Provider switcher layout")
                            .font(.body)
                        Picker("", selection: self.$settings.providerSwitcherLayout) {
                            ForEach(ProviderSwitcherLayout.allCases) { layout in
                                Text(layout.label).tag(layout)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(!self.settings.mergeIcons)
                        .opacity(self.settings.mergeIcons ? 1 : 0.5)
                        Text("Choose whether providers appear on top or in a left sidebar.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                        Text("Switcher icon size")
                            .font(.body)
                        Picker("", selection: self.$settings.providerSwitcherIconSize) {
                            ForEach(ProviderSwitcherIconSize.allCases) { size in
                                Text(size.label).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(!self.settings.mergeIcons)
                        .opacity(self.settings.mergeIcons ? 1 : 0.5)
                        Text("Small or medium icons for the provider switcher.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    PreferenceToggleRow(
                        title: "Switcher shows icons",
                        subtitle: "Show provider icons in the switcher (otherwise show a weekly progress line).",
                        binding: self.$settings.switcherShowsIcons)
                        .disabled(!self.settings.mergeIcons || self.settings.providerSwitcherLayout == .sidebar)
                        .opacity(self.settings.mergeIcons && self.settings.providerSwitcherLayout != .sidebar ? 1 : 0.5)
                    PreferenceToggleRow(
                        title: "Menu bar shows percent",
                        subtitle: "Replace critter bars with provider branding icons and a percentage.",
                        binding: self.$settings.menuBarShowsBrandIconWithPercent)
                    PreferenceToggleRow(
                        title: "Surprise me",
                        subtitle: "Check if you like your agents having some fun up there.",
                        binding: self.$settings.randomBlinkEnabled)
                }
                .padding(.top, RunicSpacing.xs)
            }
            .disclosureGroupStyle(AnalyticsSectionDisclosureStyle())

            PreferencesDivider()

            // MARK: - Insights section

            DisclosureGroup("Insights", isExpanded: self.$insightsExpanded) {
                VStack(alignment: .leading, spacing: PreferencesLayoutMetrics.sectionSpacing) {
                    PreferenceStepperRow(
                        title: "Menu list size",
                        subtitle: "Limits insight rows shown in the menu before \u{201C}More\u{2026}\u{201D}.",
                        step: 1,
                        range: 2...8,
                        valueLabel: { "\($0) items" },
                        value: self.$settings.insightsMenuMaxItems)
                    PreferenceStepperRow(
                        title: "Report window",
                        subtitle: "Used when opening the Insights report.",
                        step: 1,
                        range: 1...30,
                        valueLabel: { "Last \($0) days" },
                        value: self.$settings.insightsReportDays)
                }
                .padding(.top, RunicSpacing.xs)
            }
            .disclosureGroupStyle(AnalyticsSectionDisclosureStyle())

            PreferencesDivider()

            // MARK: - Alerts section

            DisclosureGroup("Alerts", isExpanded: self.$alertsExpanded) {
                VStack(alignment: .leading, spacing: PreferencesLayoutMetrics.sectionSpacing) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                        HStack {
                            Text("\(self.alertsData.rules.count) rules configured")
                                .font(.footnote)
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
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, RunicSpacing.md)
                                .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: RunicSpacing.xxs) {
                                ForEach(self.alertsData.rules) { rule in
                                    self.alertRuleRow(rule)
                                }
                            }
                            .padding(.vertical, RunicSpacing.xs)
                        }
                    }
                }
                .padding(.top, RunicSpacing.xs)
            }
            .disclosureGroupStyle(AnalyticsSectionDisclosureStyle())

            PreferencesDivider()

            // MARK: - Budgets section

            DisclosureGroup("Budgets", isExpanded: self.$budgetsExpanded) {
                VStack(alignment: .leading, spacing: PreferencesLayoutMetrics.sectionSpacing) {
                    VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                        HStack {
                            Text("\(self.budgets.count) budgets configured")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                self.showingAddBudget = true
                            } label: {
                                Label("Add Budget", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if self.budgets.isEmpty {
                            Text("No budgets configured. Add a budget to track project spending.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                                .padding(.vertical, RunicSpacing.md)
                                .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: RunicSpacing.xxs) {
                                ForEach(self.budgets) { budget in
                                    self.budgetRow(budget)
                                }
                            }
                            .padding(.vertical, RunicSpacing.xs)
                        }

                        if let error = self.budgetErrorMessage {
                            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .padding(RunicSpacing.xs)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(RunicCornerRadius.sm)
                        }
                    }
                }
                .padding(.top, RunicSpacing.xs)
            }
            .disclosureGroupStyle(AnalyticsSectionDisclosureStyle())
        }
        .onAppear {
            self.alertsData = AlertRuleStore.load()
            self.budgets = ProjectBudgetStore.getAllBudgets()
        }
        .sheet(isPresented: self.$showingAddRule) {
            AnalyticsRuleEditorSheet(
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
            AnalyticsRuleEditorSheet(
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
        .sheet(isPresented: self.$showingAddBudget) {
            AnalyticsAddBudgetSheet(
                projectID: self.$newProjectID,
                projectName: self.$newProjectName,
                monthlyLimit: self.$newMonthlyLimit,
                alertThreshold: self.$newAlertThreshold,
                onAdd: { self.addBudget() },
                onCancel: {
                    self.showingAddBudget = false
                    self.resetNewBudgetFields()
                })
        }
    }

    // MARK: - Alert rule row

    private func alertRuleRow(_ rule: AlertRuleStore.AlertRule) -> some View {
        HStack(spacing: RunicSpacing.sm) {
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { enabled in
                    var updatedRule = rule
                    updatedRule.enabled = enabled
                    try? AlertRuleStore.updateRule(updatedRule)
                    self.alertsData = AlertRuleStore.load()
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                HStack(spacing: RunicSpacing.xs) {
                    Text(self.alertTypeLabel(rule.type))
                        .font(.body)

                    self.severityBadge(rule.severity)
                }

                Text("Threshold: \(Int(rule.threshold))%")
                    .font(.footnote)
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

    // MARK: - Budget row

    private func budgetRow(_ budget: ProjectBudgetStore.ProjectBudget) -> some View {
        HStack(spacing: RunicSpacing.sm) {
            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                Text(budget.projectName ?? budget.projectID)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: RunicSpacing.xs) {
                    Text(UsageFormatter.usdString(budget.monthlyLimit))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Alert at \(String(format: "%.0f%%", budget.alertThreshold * 100))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(budget.enabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundStyle(budget.enabled ? .green : .secondary)

            Button {
                self.deleteBudget(budget)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(RunicSpacing.xs)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(RunicCornerRadius.sm)
    }

    // MARK: - Helpers

    private func severityBadge(_ severity: AlertRuleStore.AlertSeverity) -> some View {
        let color: Color = {
            switch severity {
            case .info: return .blue
            case .warning: return .orange
            case .critical: return .red
            }
        }()

        return Text(severity.rawValue.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxs)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(RunicCornerRadius.xs)
    }

    private func alertTypeLabel(_ type: AlertRuleStore.AlertType) -> String {
        switch type {
        case .projectBudget: return "Project Budget"
        case .usageVelocity: return "Usage Velocity"
        case .costAnomaly: return "Cost Anomaly"
        case .quotaThreshold: return "Quota Threshold"
        }
    }

    private func deleteRule(_ rule: AlertRuleStore.AlertRule) {
        try? AlertRuleStore.removeRule(id: rule.id)
        self.alertsData = AlertRuleStore.load()
    }

    private func addBudget() {
        guard !self.newProjectID.isEmpty else {
            self.budgetErrorMessage = "Project ID is required"
            return
        }

        guard let limit = Double(self.newMonthlyLimit), limit > 0 else {
            self.budgetErrorMessage = "Monthly limit must be a positive number"
            return
        }

        guard let threshold = Double(self.newAlertThreshold), threshold > 0, threshold <= 100 else {
            self.budgetErrorMessage = "Alert threshold must be between 1 and 100"
            return
        }

        let budget = ProjectBudgetStore.ProjectBudget(
            projectID: self.newProjectID,
            projectName: self.newProjectName.isEmpty ? nil : self.newProjectName,
            monthlyLimit: limit,
            alertThreshold: threshold / 100.0,
            enabled: true)

        do {
            try ProjectBudgetStore.setBudget(budget)
            self.budgets = ProjectBudgetStore.getAllBudgets()
            self.showingAddBudget = false
            self.resetNewBudgetFields()
            self.budgetErrorMessage = nil
        } catch {
            self.budgetErrorMessage = "Failed to add budget: \(error.localizedDescription)"
        }
    }

    private func deleteBudget(_ budget: ProjectBudgetStore.ProjectBudget) {
        do {
            try ProjectBudgetStore.removeBudget(projectID: budget.projectID)
            self.budgets = ProjectBudgetStore.getAllBudgets()
            self.budgetErrorMessage = nil
        } catch {
            self.budgetErrorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    private func resetNewBudgetFields() {
        self.newProjectID = ""
        self.newProjectName = ""
        self.newMonthlyLimit = ""
        self.newAlertThreshold = "80"
    }
}

// MARK: - Disclosure Group Style

private struct AnalyticsSectionDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: RunicSpacing.xs) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    configuration.label
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}

// MARK: - Rule Editor Sheet

@MainActor
private struct AnalyticsRuleEditorSheet: View {
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
                .font(.headline)

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
                        createdAt: self.rule?.createdAt ?? Date()
                    )
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

// MARK: - Add Budget Sheet

@MainActor
private struct AnalyticsAddBudgetSheet: View {
    @Binding var projectID: String
    @Binding var projectName: String
    @Binding var monthlyLimit: String
    @Binding var alertThreshold: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.md) {
            Text("Add Budget")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Project ID", text: self.$projectID)
                    .textFieldStyle(.roundedBorder)
                TextField("Project Name (optional)", text: self.$projectName)
                    .textFieldStyle(.roundedBorder)
                TextField("Monthly Limit (USD)", text: self.$monthlyLimit)
                    .textFieldStyle(.roundedBorder)
                TextField("Alert Threshold (%)", text: self.$alertThreshold)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel", action: self.onCancel)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Add", action: self.onAdd)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(RunicSpacing.lg)
        .frame(width: 400)
    }
}
