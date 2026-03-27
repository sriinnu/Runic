import RunicCore
import SwiftUI

@MainActor
struct ProjectBudgetMenuView: View {
    fileprivate struct ProjectUsage: Identifiable {
        let id: String
        let projectName: String
        let budget: ProjectBudgetStore.ProjectBudget
        let spent: Double
        let percentUsed: Double
        let isOverBudget: Bool
        let isNearLimit: Bool

        var statusColor: Color {
            if self.isOverBudget {
                return Color(red: 0.94, green: 0.36, blue: 0.36) // Red
            } else if self.isNearLimit {
                return Color(red: 0.94, green: 0.74, blue: 0.26) // Yellow
            } else {
                return Color(red: 0.46, green: 0.75, blue: 0.36) // Green
            }
        }
    }

    private let projectSummaries: [UsageLedgerProjectSummary]
    private let width: CGFloat
    private let onOpenPreferences: () -> Void

    @State private var hoveredProjectID: String?

    init(
        projectSummaries: [UsageLedgerProjectSummary],
        width: CGFloat,
        onOpenPreferences: @escaping () -> Void)
    {
        self.projectSummaries = projectSummaries
        self.width = width
        self.onOpenPreferences = onOpenPreferences
    }

    var body: some View {
        let model = Self.makeModel(from: self.projectSummaries)
        VStack(alignment: .leading, spacing: RunicSpacing.sm) {
            HStack {
                Text("Project Budgets")
                    .font(RunicFont.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    self.onOpenPreferences()
                } label: {
                    HStack(spacing: RunicSpacing.xxs) {
                        Image(systemName: "gearshape")
                            .font(RunicFont.caption)
                        Text("Configure")
                            .font(RunicFont.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            if model.isEmpty {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("No budgets configured.")
                        .font(RunicFont.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        self.onOpenPreferences()
                    } label: {
                        Text("Set up budgets in Preferences")
                            .font(RunicFont.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            } else {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    ForEach(model) { project in
                        ProjectBudgetRow(
                            project: project,
                            isHovered: self.hoveredProjectID == project.id)
                            .onHover { hovering in
                                self.hoveredProjectID = hovering ? project.id : nil
                            }
                    }
                }

                // Summary
                let overBudget = model.filter { $0.isOverBudget }.count
                let nearLimit = model.filter { $0.isNearLimit && !$0.isOverBudget }.count
                if overBudget > 0 || nearLimit > 0 {
                    Divider()
                        .padding(.vertical, RunicSpacing.xxs)

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        if overBudget > 0 {
                            HStack(spacing: RunicSpacing.xxs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(RunicFont.caption2)
                                    .foregroundStyle(Color(red: 0.94, green: 0.36, blue: 0.36))
                                Text("\(overBudget) project\(overBudget == 1 ? "" : "s") over budget")
                                    .font(RunicFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if nearLimit > 0 {
                            HStack(spacing: RunicSpacing.xxs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(RunicFont.caption2)
                                    .foregroundStyle(Color(red: 0.94, green: 0.74, blue: 0.26))
                                Text("\(nearLimit) project\(nearLimit == 1 ? "" : "s") near limit")
                                    .font(RunicFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.vertical, RunicSpacing.xs)
        .frame(minWidth: self.width, maxWidth: .infinity, alignment: .leading)
    }

    private static func makeModel(from summaries: [UsageLedgerProjectSummary]) -> [ProjectUsage] {
        let budgets = ProjectBudgetStore.getAllBudgets()

        var result: [ProjectUsage] = []

        for budget in budgets where budget.enabled {
            let projectID = budget.projectID
            let summary = summaries.first { $0.projectID == projectID }
            let spent = summary?.totals.costUSD ?? 0.0
            let percentUsed = budget.monthlyLimit > 0 ? (spent / budget.monthlyLimit) * 100 : 0
            let isOverBudget = percentUsed > 100
            let isNearLimit = percentUsed >= (budget.alertThreshold * 100)

            result.append(ProjectUsage(
                id: projectID,
                projectName: budget.projectName ?? projectID,
                budget: budget,
                spent: spent,
                percentUsed: min(100, percentUsed),
                isOverBudget: isOverBudget,
                isNearLimit: isNearLimit))
        }

        return result.sorted { lhs, rhs in
            if lhs.isOverBudget != rhs.isOverBudget {
                return lhs.isOverBudget
            }
            if lhs.isNearLimit != rhs.isNearLimit {
                return lhs.isNearLimit
            }
            return lhs.percentUsed > rhs.percentUsed
        }
    }
}

private struct ProjectBudgetRow: View {
    let project: ProjectBudgetMenuView.ProjectUsage
    let isHovered: Bool
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(project.projectName)
                    .font(RunicFont.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Text(self.budgetText)
                    .font(RunicFont.caption)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }

            UsageProgressBar(
                percent: project.percentUsed,
                tint: project.statusColor,
                accessibilityLabel: "Budget usage")

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.0f%%", project.percentUsed))
                    .font(RunicFont.caption)
                    .foregroundStyle(self.statusTextColor)
                Spacer()
                if project.isOverBudget {
                    Text("Over budget")
                        .font(RunicFont.caption)
                        .foregroundStyle(Color(red: 0.94, green: 0.36, blue: 0.36))
                        .fontWeight(.medium)
                } else if project.isNearLimit {
                    Text("Near limit")
                        .font(RunicFont.caption)
                        .foregroundStyle(Color(red: 0.94, green: 0.74, blue: 0.26))
                        .fontWeight(.medium)
                }
            }
        }
        .padding(RunicSpacing.xs)
        .background {
            RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                .fill(self.isHovered ? Color(nsColor: .separatorColor).opacity(0.15) : Color.clear)
        }
    }

    private var budgetText: String {
        "\(UsageFormatter.usdString(project.spent)) / \(UsageFormatter.usdString(project.budget.monthlyLimit))"
    }

    private var statusTextColor: Color {
        if self.isHighlighted {
            return MenuHighlightStyle.selectionText
        }
        return project.statusColor
    }
}
