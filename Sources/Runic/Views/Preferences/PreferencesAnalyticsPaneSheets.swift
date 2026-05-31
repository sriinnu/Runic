import RunicCore
import SwiftUI

@MainActor
struct AnalyticsRuleEditorSheet: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultWebhookURL") private var defaultWebhookURL = ""

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
        let savedWebhookURL = UserDefaults.standard.string(forKey: "defaultWebhookURL") ?? ""
        self._webhookURL = State(initialValue: rule?.webhookURL ?? savedWebhookURL)
        self._notifyWebhook = State(initialValue: rule?.notifyWebhook ?? false)
    }

    var body: some View {
        VStack(spacing: RunicSpacing.lg) {
            Text(self.rule == nil ? "Add Guardrail Draft" : "Edit Guardrail Draft")
                .font(self.fonts.headline)

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

                Toggle("Save webhook URL for future automation", isOn: self.$notifyWebhook)
                    .disabled(true)

                if self.notifyWebhook {
                    TextField("Webhook URL", text: self.$webhookURL)
                        .disabled(true)
                    if !self.defaultWebhookURL.isEmpty, self.webhookURL != self.defaultWebhookURL {
                        Button("Use default webhook") {
                            self.webhookURL = self.defaultWebhookURL
                        }
                        .disabled(true)
                    }
                }

                Text("Webhook delivery is not active yet; this draft only stores rule intent.")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
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
                        notifyWebhook: false,
                        webhookURL: nil,
                        enabled: self.rule?.enabled ?? true,
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

@MainActor
struct AnalyticsAddBudgetSheet: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Binding var projectID: String
    @Binding var projectName: String
    @Binding var monthlyLimit: String
    @Binding var alertThreshold: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.md) {
            Text("Add Budget")
                .font(self.fonts.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Project ID or workspace path", text: self.$projectID)
                    .textFieldStyle(.roundedBorder)
                Text("Use the project identifier from a provider's Projects breakdown. This is not the provider name.")
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
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
