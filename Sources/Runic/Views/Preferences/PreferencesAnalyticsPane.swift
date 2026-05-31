import RunicCore
import SwiftUI

@MainActor
struct AnalyticsPane: View {
    @Environment(\.runicFonts) var fonts
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    // MARK: - Disclosure state

    @State var displayExpanded = true
    @State var insightsExpanded = false
    @State var alertsExpanded = false
    @State var budgetsExpanded = false

    // MARK: - Alerts state

    @State var alertsData: AlertRuleStore.AlertsData = AlertRuleStore.load()
    @State var showingAddRule = false
    @State var editingRule: AlertRuleStore.AlertRule?
    @State var guardrailStatus: String?

    // MARK: - Budgets state

    @State var budgets: [ProjectBudgetStore.ProjectBudget] = []
    @State var showingAddBudget = false
    @State var newProjectID = ""
    @State var newProjectName = ""
    @State var newMonthlyLimit = ""
    @State var newAlertThreshold = "80"
    @State var budgetErrorMessage: String?

    @State var appeared = false
    @Environment(\.runicTheme) var runicTheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        LiquidPreferencesPane {
            self.displaySection
            self.insightsSection
            self.alertsSection
            self.budgetsSection
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
}
