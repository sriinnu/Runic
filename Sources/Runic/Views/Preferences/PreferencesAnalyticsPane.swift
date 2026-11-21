import RunicCore
import SwiftUI

@MainActor
struct AnalyticsPane: View {
    @Environment(\.runicFonts) var fonts
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    enum ActiveSheet: Identifiable {
        case addRule
        case editRule(AlertRuleStore.AlertRule)
        case addBudget

        var id: String {
            switch self {
            case .addRule: "add-rule"
            case let .editRule(rule): "edit-rule-\(rule.id)"
            case .addBudget: "add-budget"
            }
        }
    }

    // MARK: - Disclosure state

    @State var insightsExpanded = true
    @State var budgetsExpanded = true
    @State var alertsExpanded = false

    // MARK: - Alerts state

    @State var alertsData: AlertRuleStore.AlertsData = AlertRuleStore.load()
    @State var guardrailStatus: String?

    // MARK: - Budgets state

    @State var budgets: [ProjectBudgetStore.ProjectBudget] = []
    @State var newProjectID = ""
    @State var newProjectName = ""
    @State var newMonthlyLimit = ""
    @State var newAlertThreshold = "80"
    @State var budgetErrorMessage: String?

    @State var activeSheet: ActiveSheet?
    @State var appeared = false
    @Environment(\.runicTheme) var runicTheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        LiquidPreferencesPane {
            self.insightsSection
            self.budgetsSection
            self.alertsSection
        }
        .onAppear {
            self.alertsData = AlertRuleStore.load()
            self.budgets = ProjectBudgetStore.getAllBudgets()
            if !self.appeared {
                withAnimation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion)) {
                    self.appeared = true
                }
            }
        }
        .sheet(item: self.$activeSheet) { sheet in
            switch sheet {
            case .addRule:
                AnalyticsRuleEditorSheet(
                    rule: nil,
                    onSave: { newRule in
                        do {
                            try AlertRuleStore.addRule(newRule)
                            self.alertsData = AlertRuleStore.load()
                        } catch {
                            self.guardrailStatus = "Failed to add rule: \(error.localizedDescription)"
                        }
                    })
            case let .editRule(rule):
                AnalyticsRuleEditorSheet(
                    rule: rule,
                    onSave: { updatedRule in
                        do {
                            try AlertRuleStore.updateRule(updatedRule)
                            self.alertsData = AlertRuleStore.load()
                        } catch {
                            self.guardrailStatus = "Failed to update rule: \(error.localizedDescription)"
                        }
                    })
            case .addBudget:
                AnalyticsAddBudgetSheet(
                    projectID: self.$newProjectID,
                    projectName: self.$newProjectName,
                    monthlyLimit: self.$newMonthlyLimit,
                    alertThreshold: self.$newAlertThreshold,
                    errorMessage: self.budgetErrorMessage,
                    onAdd: { self.addBudget() },
                    onCancel: {
                        self.activeSheet = nil
                        self.resetNewBudgetFields()
                    })
            }
        }
    }
}
