import RunicCore
import SwiftUI

@MainActor
struct PreferencesBudgetsPane: View {
    @State private var budgets: [ProjectBudgetStore.ProjectBudget] = []
    @State private var editingProjectID: String?
    @State private var showingAddDialog = false
    @State private var newProjectID = ""
    @State private var newProjectName = ""
    @State private var newMonthlyLimit = ""
    @State private var newAlertThreshold = "80"
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.md) {
            VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                Text("Project Budgets")
                    .font(RunicFont.title2)
                    .fontWeight(.semibold)
                Text("Set monthly spending limits and alerts for projects.")
                    .font(RunicFont.subheadline)
                    .foregroundStyle(.secondary)
            }

            if self.budgets.isEmpty {
                VStack(spacing: RunicSpacing.md) {
                    Text("No budgets configured")
                        .font(RunicFont.body)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, RunicSpacing.lg)

                    Button {
                        self.showingAddDialog = true
                    } label: {
                        Label("Add Budget", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RunicSpacing.xl)
            } else {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    // Header
                    HStack(alignment: .center, spacing: RunicSpacing.sm) {
                        Text("Project")
                            .font(RunicFont.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 150, alignment: .leading)
                        Text("Monthly Limit")
                            .font(RunicFont.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 120, alignment: .leading)
                        Text("Alert at")
                            .font(RunicFont.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text("Status")
                            .font(RunicFont.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                    }
                    .padding(.horizontal, RunicSpacing.xs)

                    Divider()

                    ScrollView {
                        VStack(spacing: RunicSpacing.xxs) {
                            ForEach(self.budgets) { budget in
                                BudgetRow(
                                    budget: budget,
                                    isEditing: self.editingProjectID == budget.projectID,
                                    onEdit: {
                                        self.editingProjectID = budget.projectID
                                    },
                                    onSave: { updated in
                                        do {
                                            try ProjectBudgetStore.setBudget(updated)
                                            self.loadBudgets()
                                            self.editingProjectID = nil
                                            self.errorMessage = nil
                                        } catch {
                                            self.errorMessage = "Failed to save: \(error.localizedDescription)"
                                        }
                                    },
                                    onCancel: {
                                        self.editingProjectID = nil
                                    },
                                    onDelete: {
                                        self.deleteBudget(budget)
                                    })
                            }
                        }
                    }
                    .frame(maxHeight: 400)

                    Button {
                        self.showingAddDialog = true
                    } label: {
                        Label("Add Budget", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = self.errorMessage {
                HStack(alignment: .center, spacing: RunicSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(RunicFont.caption)
                        .foregroundStyle(.red)
                        .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                    Text(error)
                        .font(RunicFont.caption)
                        .foregroundStyle(.red)
                }
                .padding(RunicSpacing.xs)
                .background(Color.red.opacity(0.1))
                .cornerRadius(RunicCornerRadius.sm)
            }

            Spacer()
        }
        .padding(RunicSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            self.loadBudgets()
        }
        .sheet(isPresented: self.$showingAddDialog) {
            AddBudgetSheet(
                projectID: self.$newProjectID,
                projectName: self.$newProjectName,
                monthlyLimit: self.$newMonthlyLimit,
                alertThreshold: self.$newAlertThreshold,
                onAdd: { self.addBudget() },
                onCancel: {
                    self.showingAddDialog = false
                    self.resetNewBudgetFields()
                })
        }
    }

    private func loadBudgets() {
        self.budgets = ProjectBudgetStore.getAllBudgets()
    }

    private func addBudget() {
        guard !self.newProjectID.isEmpty else {
            self.errorMessage = "Project ID is required"
            return
        }

        guard let limit = Double(self.newMonthlyLimit), limit > 0 else {
            self.errorMessage = "Monthly limit must be a positive number"
            return
        }

        guard let threshold = Double(self.newAlertThreshold), threshold > 0, threshold <= 100 else {
            self.errorMessage = "Alert threshold must be between 1 and 100"
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
            self.loadBudgets()
            self.showingAddDialog = false
            self.resetNewBudgetFields()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to add budget: \(error.localizedDescription)"
        }
    }

    private func deleteBudget(_ budget: ProjectBudgetStore.ProjectBudget) {
        do {
            try ProjectBudgetStore.removeBudget(projectID: budget.projectID)
            self.loadBudgets()
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to delete: \(error.localizedDescription)"
        }
    }

    private func resetNewBudgetFields() {
        self.newProjectID = ""
        self.newProjectName = ""
        self.newMonthlyLimit = ""
        self.newAlertThreshold = "80"
    }
}

private struct BudgetRow: View {
    let budget: ProjectBudgetStore.ProjectBudget
    let isEditing: Bool
    let onEdit: () -> Void
    let onSave: (ProjectBudgetStore.ProjectBudget) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var editName: String
    @State private var editLimit: String
    @State private var editThreshold: String

    init(
        budget: ProjectBudgetStore.ProjectBudget,
        isEditing: Bool,
        onEdit: @escaping () -> Void,
        onSave: @escaping (ProjectBudgetStore.ProjectBudget) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: @escaping () -> Void)
    {
        self.budget = budget
        self.isEditing = isEditing
        self.onEdit = onEdit
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        self._editName = State(initialValue: budget.projectName ?? "")
        self._editLimit = State(initialValue: String(format: "%.2f", budget.monthlyLimit))
        self._editThreshold = State(initialValue: String(format: "%.0f", budget.alertThreshold * 100))
    }

    var body: some View {
        HStack(alignment: .center, spacing: RunicSpacing.sm) {
            if self.isEditing {
                TextField("Name", text: self.$editName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150, alignment: .leading)
                TextField("Limit", text: self.$editLimit)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120, alignment: .leading)
                TextField("%", text: self.$editThreshold)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80, alignment: .leading)
                Spacer()
                HStack(spacing: RunicSpacing.xs) {
                    Button("Save") {
                        guard let limit = Double(self.editLimit), limit > 0,
                              let threshold = Double(self.editThreshold), threshold > 0, threshold <= 100
                        else { return }

                        let updated = ProjectBudgetStore.ProjectBudget(
                            projectID: self.budget.projectID,
                            projectName: self.editName.isEmpty ? nil : self.editName,
                            monthlyLimit: limit,
                            alertThreshold: threshold / 100.0,
                            enabled: self.budget.enabled,
                            createdAt: self.budget.createdAt)
                        self.onSave(updated)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Button("Cancel", action: self.onCancel)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else {
                Text(self.budget.projectName ?? self.budget.projectID)
                    .font(RunicFont.body)
                    .frame(width: 150, alignment: .leading)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(UsageFormatter.usdString(self.budget.monthlyLimit))
                    .font(RunicFont.body)
                    .frame(width: 120, alignment: .leading)
                Text(String(format: "%.0f%%", self.budget.alertThreshold * 100))
                    .font(RunicFont.body)
                    .frame(width: 80, alignment: .leading)
                Text(self.budget.enabled ? "Enabled" : "Disabled")
                    .font(RunicFont.caption)
                    .foregroundStyle(self.budget.enabled ? .green : .secondary)
                    .frame(width: 80, alignment: .leading)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                Spacer()
                HStack(spacing: RunicSpacing.xs) {
                    Button {
                        self.onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(RunicFont.caption)
                    }
                    .buttonStyle(.plain)
                    Button {
                        self.onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(RunicFont.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.xxs)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(RunicCornerRadius.xs)
    }
}

private struct AddBudgetSheet: View {
    @Binding var projectID: String
    @Binding var projectName: String
    @Binding var monthlyLimit: String
    @Binding var alertThreshold: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.md) {
            Text("Add Budget")
                .font(RunicFont.title2)
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
