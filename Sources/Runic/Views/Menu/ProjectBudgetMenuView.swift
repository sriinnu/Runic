import RunicCore
import SwiftUI

@MainActor
struct ProjectBudgetMenuView: View {
    @Environment(\.runicFonts) private var fonts
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
                Color(red: 0.94, green: 0.36, blue: 0.36) // Red
            } else if self.isNearLimit {
                Color(red: 0.94, green: 0.74, blue: 0.26) // Yellow
            } else {
                Color(red: 0.46, green: 0.75, blue: 0.36) // Green
            }
        }
    }

    private let projectSummaries: [UsageLedgerProjectSummary]
    private let width: CGFloat
    private let onOpenPreferences: () -> Void

    @State private var hoveredProjectID: String?
    @Environment(\.runicTheme) private var runicTheme

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
                    .font(self.fonts.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    self.onOpenPreferences()
                } label: {
                    HStack(spacing: RunicSpacing.xxs) {
                        Image(systemName: "gearshape")
                            .font(self.fonts.caption)
                        Text("Configure")
                            .font(self.fonts.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.runicTheme.accent)
            }

            if model.isEmpty {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("No budgets configured.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                    Button {
                        self.onOpenPreferences()
                    } label: {
                        Text("Set up budgets in Preferences")
                            .font(self.fonts.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(self.runicTheme.accent)
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
                let overBudget = model.count(where: { $0.isOverBudget })
                let nearLimit = model.count(where: { $0.isNearLimit && !$0.isOverBudget })
                if overBudget > 0 || nearLimit > 0 {
                    Divider()
                        .overlay(self.runicTheme.menuSeparatorColor)
                        .padding(.vertical, RunicSpacing.xxs)

                    VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                        if overBudget > 0 {
                            HStack(spacing: RunicSpacing.xxs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(self.fonts.caption2)
                                    .foregroundStyle(Color(red: 0.94, green: 0.36, blue: 0.36))
                                Text("\(overBudget) project\(overBudget == 1 ? "" : "s") over budget")
                                    .font(self.fonts.caption)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                            }
                        }
                        if nearLimit > 0 {
                            HStack(spacing: RunicSpacing.xxs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(self.fonts.caption2)
                                    .foregroundStyle(Color(red: 0.94, green: 0.74, blue: 0.26))
                                Text("\(nearLimit) project\(nearLimit == 1 ? "" : "s") near limit")
                                    .font(self.fonts.caption)
                                    .foregroundStyle(self.runicTheme.secondaryText)
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
    @Environment(\.runicFonts) private var fonts
    let project: ProjectBudgetMenuView.ProjectUsage
    let isHovered: Bool
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.project.projectName)
                    .font(self.fonts.body)
                    .fontWeight(.medium)
                    .foregroundStyle(self.rowPrimaryColor)
                    .lineLimit(1)
                Spacer()
                Text(self.budgetText)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.rowSecondaryColor)
            }

            UsageProgressBar(
                percent: self.project.percentUsed,
                tint: self.project.statusColor,
                accessibilityLabel: "Budget usage")

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.0f%%", self.project.percentUsed))
                    .font(self.fonts.caption)
                    .foregroundStyle(self.statusTextColor)
                Spacer()
                if self.project.isOverBudget {
                    Text("Over budget")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.warm)
                        .fontWeight(.medium)
                } else if self.project.isNearLimit {
                    Text("Near limit")
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.highlight)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(self.runicTheme.density.padding(RunicSpacing.xs))
        .background {
            RoundedRectangle(
                cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                style: .continuous)
                .fill(self.isHovered ? self.runicTheme.menuHoverFill : Color.clear)
        }
    }

    private var budgetText: String {
        "\(UsageFormatter.usdString(self.project.spent)) / \(UsageFormatter.usdString(self.project.budget.monthlyLimit))"
    }

    private var statusTextColor: Color {
        if self.isHighlighted {
            return MenuHighlightStyle.selectionText
        }
        return self.project.statusColor
    }

    private var rowPrimaryColor: Color {
        self.isHighlighted ? MenuHighlightStyle.selectionText : self.runicTheme.primaryText
    }

    private var rowSecondaryColor: Color {
        self.isHighlighted ? MenuHighlightStyle.selectionText : self.runicTheme.secondaryText
    }
}
