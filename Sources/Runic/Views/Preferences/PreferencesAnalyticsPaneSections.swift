import RunicCore
import SwiftUI

extension AnalyticsPane {
    var displaySection: some View {
        DisclosureGroup("Display", isExpanded: self.$displayExpanded) {
            VStack(alignment: .leading, spacing: PreferencesLayoutMetrics.sectionSpacing) {
                PreferenceToggleRow(
                    title: "Show usage as used",
                    subtitle: "Progress bars fill as you consume quota (instead of showing remaining).",
                    binding: self.$settings.usageBarsShowUsed)
                self.usageMetricsPicker
                self.menuModePicker
                PreferenceToggleRow(
                    title: "Show credits + extra usage",
                    subtitle: "Show Codex Credits and Claude Extra usage sections in the menu.",
                    binding: self.$settings.showOptionalCreditsAndExtraUsage)
                PreferenceToggleRow(
                    title: "Merge Icons",
                    subtitle: "Use a single menu bar icon with a provider switcher.",
                    binding: self.$settings.mergeIcons)
                self.providerSwitcherLayoutPicker
                self.providerSwitcherIconSizePicker
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
        .liquidGlass()
        .liquidEntrance(appeared: self.appeared, index: 0)
    }

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

private extension AnalyticsPane {
    var usageMetricsPicker: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Usage metrics")
                .font(self.fonts.body)
            Picker("", selection: self.$settings.usageMetricDisplayMode) {
                ForEach(UsageMetricDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text("Pick bars, percent, or both in the menu card.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var menuModePicker: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Menu mode")
                .font(self.fonts.body)
            Picker("", selection: self.$settings.menuMode) {
                ForEach(MenuMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text("Glance: usage only. Analyst: usage + credits/cost. Operator: full insights and actions.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var providerSwitcherLayoutPicker: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Provider switcher layout")
                .font(self.fonts.body)
            Picker("", selection: self.$settings.providerSwitcherLayout) {
                ForEach(ProviderSwitcherLayout.allCases) { layout in
                    Text(layout.label).tag(layout)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!self.settings.mergeIcons)
            .opacity(self.settings.mergeIcons ? 1 : 0.5)
            Text("Choose whether providers appear on top or in a left sidebar.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var providerSwitcherIconSizePicker: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Switcher icon size")
                .font(self.fonts.body)
            Picker("", selection: self.$settings.providerSwitcherIconSize) {
                ForEach(ProviderSwitcherIconSize.allCases) { size in
                    Text(size.label).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!self.settings.mergeIcons)
            .opacity(self.settings.mergeIcons ? 1 : 0.5)
            Text("Small or medium icons for the provider switcher.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var alertsHeader: some View {
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
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                self.showingAddRule = true
            } label: {
                Label("Add Rule", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    var alertsList: some View {
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

    var budgetsHeader: some View {
        HStack {
            Text(self.budgetStatusLine)
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.secondaryText)

            Spacer()

            Button {
                self.showingAddBudget = true
            } label: {
                Label("Add Budget", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    var budgetsList: some View {
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

    var alertStatusLine: String {
        let enabled = self.alertsData.rules.count(where: \.enabled)
        let history = self.alertsData.history.count
        return "\(enabled) enabled · \(self.alertsData.rules.count) rules · \(history) history"
    }

    var budgetStatusLine: String {
        let enabled = self.budgets.count(where: \.enabled)
        return "\(enabled) enabled · \(self.budgets.count) budgets"
    }

    var missingDefaultGuardrailCount: Int {
        let currentIDs = Set(self.alertsData.rules.map(\.id))
        return Self.defaultGuardrailIDs.subtracting(currentIDs).count
    }

    static var defaultGuardrailIDs: Set<String> {
        [
            "runic-default-quota-critical",
            "runic-default-usage-velocity",
            "runic-default-cost-anomaly",
        ]
    }
}
