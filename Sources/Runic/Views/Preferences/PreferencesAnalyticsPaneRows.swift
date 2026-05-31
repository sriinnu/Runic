import RunicCore
import SwiftUI

extension AnalyticsPane {
    func alertRuleRow(_ rule: AlertRuleStore.AlertRule) -> some View {
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
                        .font(self.fonts.body)

                    self.severityBadge(rule.severity)
                }

                Text("Threshold: \(Int(rule.threshold))%")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
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
        .background(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .fill(self.runicTheme.menuSubtleFill))
        .overlay(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .stroke(self.runicTheme.menuSeparatorColor.opacity(0.42), lineWidth: 0.7))
    }

    func budgetRow(_ budget: ProjectBudgetStore.ProjectBudget) -> some View {
        HStack(spacing: RunicSpacing.sm) {
            VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                Text(budget.projectName ?? budget.projectID)
                    .font(self.fonts.body)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: RunicSpacing.xs) {
                    Text(UsageFormatter.usdString(budget.monthlyLimit))
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Text("Alert at \(String(format: "%.0f%%", budget.alertThreshold * 100))")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
            }

            Spacer()

            Text(budget.enabled ? "Enabled" : "Disabled")
                .font(self.fonts.caption)
                .foregroundStyle(budget.enabled ? .green : .secondary)

            Button {
                self.deleteBudget(budget)
            } label: {
                Image(systemName: "trash")
                    .font(self.fonts.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(RunicSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .fill(self.runicTheme.menuSubtleFill))
        .overlay(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .stroke(self.runicTheme.menuSeparatorColor.opacity(0.42), lineWidth: 0.7))
    }

    func severityBadge(_ severity: AlertRuleStore.AlertSeverity) -> some View {
        let color: Color = switch severity {
        case .info: .blue
        case .warning: .orange
        case .critical: .red
        }

        return Text(severity.rawValue.uppercased())
            .font(self.fonts.caption2.weight(.semibold))
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxs)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(self.runicTheme.shape.cornerRadius(RunicCornerRadius.xs))
    }

    func alertTypeLabel(_ type: AlertRuleStore.AlertType) -> String {
        switch type {
        case .projectBudget: "Project Budget"
        case .usageVelocity: "Usage Velocity"
        case .costAnomaly: "Cost Anomaly"
        case .quotaThreshold: "Quota Threshold"
        }
    }

    func deleteRule(_ rule: AlertRuleStore.AlertRule) {
        try? AlertRuleStore.removeRule(id: rule.id)
        self.alertsData = AlertRuleStore.load()
    }

    func installDefaultGuardrails() {
        do {
            let count = try RunicDiagnosticsReport.installDefaultGuardrails()
            self.alertsData = AlertRuleStore.load()
            self.guardrailStatus = count == 0
                ? "Default guardrails already installed."
                : "Installed \(count) guardrails."
        } catch {
            self.guardrailStatus = "Failed to install guardrails: \(error.localizedDescription)"
        }
    }

    func addBudget() {
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

    func deleteBudget(_ budget: ProjectBudgetStore.ProjectBudget) {
        do {
            try ProjectBudgetStore.removeBudget(projectID: budget.projectID)
            self.budgets = ProjectBudgetStore.getAllBudgets()
            self.budgetErrorMessage = nil
        } catch {
            self.budgetErrorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    func resetNewBudgetFields() {
        self.newProjectID = ""
        self.newProjectName = ""
        self.newMonthlyLimit = ""
        self.newAlertThreshold = "80"
    }
}
