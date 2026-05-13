import Foundation
import RunicCore

struct RunicProviderHealthRow: Identifiable, Hashable {
    enum CredentialState: String, Hashable {
        case connected
        case configured
        case local
        case missing
        case attention

        var label: String {
            switch self {
            case .connected: "Connected"
            case .configured: "Configured"
            case .local: "Local"
            case .missing: "Missing"
            case .attention: "Attention"
            }
        }
    }

    let provider: UsageProvider
    let name: String
    let source: String
    let credentialState: CredentialState
    let credentialDetail: String
    let dataDetail: String
    let issue: String?

    var id: UsageProvider { self.provider }
}

struct RunicActionRecommendation: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}

@MainActor
enum RunicDiagnosticsReport {
    static func providerHealthRows(settings: SettingsStore, store: UsageStore) -> [RunicProviderHealthRow] {
        let enabled = store.enabledProviders()
        let providers = enabled.isEmpty ? Array(settings.orderedProviders().prefix(8)) : enabled

        return providers.map { provider in
            let metadata = ProviderDescriptorRegistry.descriptor(for: provider).metadata
            let snapshot = store.snapshot(for: provider)
            let source = store.sourceLabel(for: provider)
            let providerError = self.redacted(store.error(for: provider) ?? "")
            let ledgerError = self.redacted(store.ledgerError(for: provider) ?? "")
            let tokenError = self.redacted(store.tokenError(for: provider) ?? "")
            let issue = [providerError, ledgerError, tokenError]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty })

            let credential = self.credentialState(provider: provider, settings: settings, snapshot: snapshot)
            let dataDetail = self.dataDetail(provider: provider, snapshot: snapshot, store: store, issue: issue)
            let state: RunicProviderHealthRow.CredentialState = issue == nil ? credential.state : .attention

            return RunicProviderHealthRow(
                provider: provider,
                name: metadata.displayName,
                source: source,
                credentialState: state,
                credentialDetail: credential.detail,
                dataDetail: dataDetail,
                issue: issue)
        }
    }

    static func recommendations(settings: SettingsStore, store: UsageStore) -> [RunicActionRecommendation] {
        var recommendations: [RunicActionRecommendation] = []
        let health = self.providerHealthRows(settings: settings, store: store)

        if health.contains(where: { $0.credentialState == .missing || $0.credentialState == .attention }) {
            recommendations.append(RunicActionRecommendation(
                id: "credentials",
                title: "Credential health",
                detail: "At least one enabled provider needs auth/config attention.",
                systemImage: "key.viewfinder"))
        }

        let alertData = AlertRuleStore.load()
        if alertData.rules.isEmpty {
            recommendations.append(RunicActionRecommendation(
                id: "guardrails",
                title: "Install guardrails",
                detail: "Add default quota, velocity, and cost anomaly alert rules.",
                systemImage: "bell.badge"))
        }

        if ProjectBudgetStore.getAllBudgets().isEmpty {
            recommendations.append(RunicActionRecommendation(
                id: "budgets",
                title: "Project budgets",
                detail: "Add at least one project budget to make spend forecasts actionable.",
                systemImage: "target"))
        }

        for provider in store.enabledProviders() {
            if let routing = store.ledgerRoutingRecommendation(for: provider) {
                let metadata = ProviderDescriptorRegistry.descriptor(for: provider).metadata
                recommendations.append(RunicActionRecommendation(
                    id: "routing-\(provider.rawValue)",
                    title: "\(metadata.displayName) routing",
                    detail: "Move \(routing.shiftPercent)% from \(routing.fromModel) to \(routing.toModel); est. " +
                        "\(UsageFormatter.usdString(routing.estimatedSavingsUSD)) saved.",
                    systemImage: "arrow.triangle.branch"))
                break
            }
        }

        if recommendations.isEmpty {
            recommendations.append(RunicActionRecommendation(
                id: "steady",
                title: "Baseline looks steady",
                detail: "Credentials, guardrails, budgets, and routing checks have no obvious gaps.",
                systemImage: "checkmark.seal"))
        }

        return recommendations
    }

    static func installDefaultGuardrails() throws -> Int {
        var data = AlertRuleStore.load()
        let existingIDs = Set(data.rules.map(\.id))
        let defaults = [
            AlertRuleStore.AlertRule(
                id: "runic-default-quota-critical",
                type: .quotaThreshold,
                threshold: 10,
                severity: .critical),
            AlertRuleStore.AlertRule(
                id: "runic-default-usage-velocity",
                type: .usageVelocity,
                threshold: 85,
                severity: .warning),
            AlertRuleStore.AlertRule(
                id: "runic-default-cost-anomaly",
                type: .costAnomaly,
                threshold: 150,
                severity: .warning),
        ]
        let missing = defaults.filter { !existingIDs.contains($0.id) }
        guard !missing.isEmpty else { return 0 }
        data.rules.append(contentsOf: missing)
        try AlertRuleStore.save(data)
        return missing.count
    }

    static func makeText(settings: SettingsStore, store: UsageStore, now: Date = Date()) -> String {
        var lines: [String] = []
        lines.append("Runic Diagnostics")
        lines.append("generated: \(ISO8601DateFormatter().string(from: now))")
        lines.append("version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown") " +
            "(\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"))")
        lines.append("commit: \(Bundle.main.infoDictionary?["CodexGitCommit"] as? String ?? "unknown")")
        lines.append("theme: \(settings.theme.label)")
        lines.append("font: \(self.fontLabel(settings.selectedFontFamily))")
        lines.append("refresh: \(settings.refreshFrequency.label)")
        lines.append("menuMode: \(settings.menuMode.label)")
        lines.append("costUsage: \(settings.costUsageEnabled ? "enabled" : "disabled")")
        lines.append("otelPaths: \(settings.otelGenAILogPaths.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "none" : "configured")")
        lines.append("")
        lines.append("providers:")

        for row in self.providerHealthRows(settings: settings, store: store) {
            lines.append("- \(row.name) [\(row.provider.rawValue)]")
            lines.append("  source: \(row.source)")
            lines.append("  credential: \(row.credentialState.label) - \(row.credentialDetail)")
            lines.append("  data: \(row.dataDetail)")
            if let issue = row.issue {
                lines.append("  issue: \(self.redacted(issue))")
            }
            if let reliability = store.ledgerReliabilityScore(for: row.provider) {
                lines.append("  reliability: \(reliability.grade) (\(reliability.score)) - \(reliability.summary)")
            }
            if let routing = store.ledgerRoutingRecommendation(for: row.provider) {
                lines.append("  routing: shift \(routing.shiftPercent)% \(routing.fromModel) -> " +
                    "\(routing.toModel), est \(UsageFormatter.usdString(routing.estimatedSavingsUSD))")
            }
        }

        let alertData = AlertRuleStore.load()
        let budgets = ProjectBudgetStore.getAllBudgets()
        lines.append("")
        lines.append("guardrails:")
        lines.append("- alertRules: \(alertData.rules.count)")
        lines.append("- unacknowledgedAlerts: \(alertData.history.count(where: { !$0.acknowledged }))")
        lines.append("- projectBudgets: \(budgets.count)")
        lines.append("")
        lines.append("recommendations:")
        for rec in self.recommendations(settings: settings, store: store) {
            lines.append("- \(rec.title): \(rec.detail)")
        }

        return self.redacted(lines.joined(separator: "\n"))
    }

    private static func dataDetail(
        provider: UsageProvider,
        snapshot: UsageSnapshot?,
        store: UsageStore,
        issue: String?) -> String
    {
        if let issue, !issue.isEmpty {
            return "needs attention"
        }
        if let snapshot {
            return "usage \(UsageFormatter.updatedString(from: snapshot.updatedAt))"
        }
        if let ledgerUpdated = store.ledgerUpdatedAt(for: provider) {
            return "ledger \(UsageFormatter.updatedString(from: ledgerUpdated))"
        }
        if let token = store.tokenSnapshot(for: provider) {
            return "tokens \(UsageFormatter.updatedString(from: token.updatedAt))"
        }
        return "waiting for first sample"
    }

    private static func credentialState(
        provider: UsageProvider,
        settings: SettingsStore,
        snapshot: UsageSnapshot?) -> (state: RunicProviderHealthRow.CredentialState, detail: String)
    {
        if let identity = snapshot?.identity(for: provider) ?? snapshot?.identity {
            let account = identity.accountEmail ?? identity.accountOrganization ?? identity.loginMethod
            return (.connected, account.map { "account \(self.redacted($0))" } ?? "identity detected")
        }

        switch provider {
        case .codex:
            return (.local, "OAuth or local Codex session")
        case .claude:
            return (.local, "OAuth, web, or Claude CLI session")
        case .cursor, .factory, .gemini, .antigravity:
            return (.local, "local CLI/browser session")
        case .zai:
            return self.tokenState(settings.zaiAPIToken, label: "API key")
        case .minimax:
            if !settings.minimaxAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (.configured, "API token saved")
            }
            if !settings.minimaxCookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (.configured, "web cookie header saved")
            }
            return (.missing, "API token or web cookie missing")
        case .copilot:
            return self.tokenState(settings.copilotAPIToken, label: "API token")
        case .openrouter:
            return self.tokenState(settings.openRouterAPIToken, label: "API key")
        case .vercelai:
            return self.tokenState(settings.vercelAIAPIToken, label: "Gateway API key")
        case .groq:
            return self.tokenState(settings.groqAPIToken, label: "API key")
        case .deepseek:
            return self.tokenState(settings.deepSeekAPIToken, label: "API key")
        case .fireworks:
            return self.tokenState(settings.fireworksAPIToken, label: "API key")
        case .mistral:
            return self.tokenState(settings.mistralAPIToken, label: "API key")
        case .perplexity:
            return self.tokenState(settings.perplexityAPIToken, label: "API key")
        case .kimi:
            return self.tokenState(settings.kimiAPIToken, label: "API key")
        case .auggie:
            return self.tokenState(settings.auggieAPIToken, label: "API token")
        case .together:
            return self.tokenState(settings.togetherAPIToken, label: "API key")
        case .cohere:
            return self.tokenState(settings.cohereAPIToken, label: "API key")
        case .xai:
            return self.tokenState(settings.xaiAPIToken, label: "API key")
        case .cerebras:
            return self.tokenState(settings.cerebrasAPIToken, label: "API key")
        case .qwen:
            return self.tokenState(settings.qwenAPIToken, label: "API key")
        case .sambanova:
            return self.tokenState(settings.sambaNovaAPIToken, label: "API key")
        case .azure:
            let hasEndpoint = !settings.azureOpenAIEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasDeployment = !settings.azureOpenAIDeployment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasToken = !settings.azureOpenAIAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasEndpoint && hasDeployment && hasToken
                ? (.configured, "endpoint, deployment, and key saved")
                : (.missing, "endpoint, deployment, or key missing")
        case .bedrock:
            let hasRegion = !settings.bedrockRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasProfile = !settings.bedrockAWSProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasRegion || hasProfile
                ? (.configured, "AWS region/profile configured")
                : (.missing, "AWS region/profile missing")
        case .vertexai:
            let hasProject = !settings.vertexaiProject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasLocation = !settings.vertexaiLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasProject && hasLocation
                ? (.configured, "project and location configured")
                : (.missing, "project or location missing")
        }
    }

    private static func tokenState(
        _ token: String,
        label: String) -> (state: RunicProviderHealthRow.CredentialState, detail: String)
    {
        token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (.missing, "\(label) missing")
            : (.configured, "\(label) saved")
    }

    private static func fontLabel(_ id: String) -> String {
        switch id {
        case RunicFontChoice.sfPro.id: return RunicFontChoice.sfPro.displayName
        case RunicFontChoice.sfMono.id: return RunicFontChoice.sfMono.displayName
        default: return id
        }
    }

    private static func redacted(_ input: String) -> String {
        var text = input
        let replacements: [(String, String)] = [
            (#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, "<email>"),
            (#"sk-[A-Za-z0-9_\-]{12,}"#, "<api-key>"),
            (#"(Bearer|token|api[_-]?key)[=: ]+[A-Za-z0-9._\-]{8,}"#, "$1=<redacted>"),
            (#"eyJ[A-Za-z0-9._\-]{20,}"#, "<jwt>"),
        ]
        for (pattern, replacement) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
            }
        }
        return text
    }
}
