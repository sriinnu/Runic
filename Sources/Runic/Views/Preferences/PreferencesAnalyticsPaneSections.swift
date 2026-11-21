import RunicCore
import SwiftUI

extension AnalyticsPane {
    var insightsSection: some View {
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
        .liquidGlass()
        .liquidEntrance(appeared: self.appeared, index: 1)
    }

    var alertsSection: some View {
        DisclosureGroup("Guardrail Rules (Draft)", isExpanded: self.$alertsExpanded) {
            VStack(alignment: .leading, spacing: PreferencesLayoutMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    self.alertsHeader
                    self.alertsList

                    if let guardrailStatus {
                        Text(guardrailStatus)
                            .font(self.fonts.footnote)
                            .foregroundStyle(self.runicTheme.secondaryText)
                    }
                    Text(
                        "Rules are saved locally as drafts for upcoming guardrail automation. " +
                            "Today, production notifications come from Budgets below and " +
                            "session quota notifications in General.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }
            .padding(.top, RunicSpacing.xs)
        }
        .disclosureGroupStyle(AnalyticsSectionDisclosureStyle())
        .liquidGlass()
        .liquidEntrance(appeared: self.appeared, index: 2)
    }

    var budgetsSection: some View {
        DisclosureGroup("Budgets", isExpanded: self.$budgetsExpanded) {
            VStack(alignment: .leading, spacing: PreferencesLayoutMetrics.sectionSpacing) {
                PreferenceToggleRow(
                    title: "Budget breach notifications",
                    subtitle: "Notify when a project forecast is projected to exceed its monthly budget.",
                    binding: self.$settings.budgetNotificationsEnabled)

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    self.budgetsHeader
                    self.budgetsList

                    Text(
                        "Budgets are local JSON and feed project forecasts, menu budget cards, " +
                            "and breach notifications when enabled.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)

                    if let error = self.budgetErrorMessage {
                        HStack(alignment: .center, spacing: RunicSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(self.fonts.caption)
                                .foregroundStyle(.red)
                            Text(error)
                                .font(self.fonts.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(RunicSpacing.xs)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm))
                    }
                }
            }
            .padding(.top, RunicSpacing.xs)
        }
        .disclosureGroupStyle(AnalyticsSectionDisclosureStyle())
        .liquidGlass()
        .liquidEntrance(appeared: self.appeared, index: 3)
    }
}

extension AnalyticsPane {
    private var alertsHeader: some View {
        HStack {
            Text(self.alertStatusLine)
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.secondaryText)

            Spacer()

            if self.missingDefaultGuardrailCount > 0 {
                Button {
                    self.installDefaultGuardrails()
                } label: {
                    Label("Install Defaults", systemImage: "shield.lefthalf.filled")
                }
                .buttonStyle(.runicBordered)
                .controlSize(.small)
            }

            Button {
                self.activeSheet = .addRule
            } label: {
                Label("Add Rule", systemImage: "plus")
            }
            .buttonStyle(.runicBordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var alertsList: some View {
        if self.alertsData.rules.isEmpty {
            Text("No guardrail rules configured on this Mac.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
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

    private var budgetsHeader: some View {
        HStack {
            Text(self.budgetStatusLine)
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.secondaryText)

            Spacer()

            Button {
                self.budgetErrorMessage = nil
                self.activeSheet = .addBudget
            } label: {
                Label("Add Budget", systemImage: "plus")
            }
            .buttonStyle(.runicBordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var budgetsList: some View {
        if self.budgets.isEmpty {
            Text("No project budgets configured on this Mac.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
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
    }

    private var alertStatusLine: String {
        let enabled = self.alertsData.rules.count(where: \.enabled)
        let history = self.alertsData.history.count
        return "\(enabled) enabled · \(self.alertsData.rules.count) rules · \(history) history"
    }

    private var budgetStatusLine: String {
        let enabled = self.budgets.count(where: \.enabled)
        return "\(enabled) enabled · \(self.budgets.count) budgets"
    }

    private var missingDefaultGuardrailCount: Int {
        let currentIDs = Set(self.alertsData.rules.map(\.id))
        return Self.defaultGuardrailIDs.subtracting(currentIDs).count
    }

    fileprivate static var defaultGuardrailIDs: Set<String> {
        [
            "runic-default-quota-critical",
            "runic-default-usage-velocity",
            "runic-default-cost-anomaly",
        ]
    }
}
