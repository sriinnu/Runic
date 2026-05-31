import Foundation

struct SettingsStoreUsageFeatureValues {
    var sessionQuotaNotificationsEnabled: Bool
    var budgetNotificationsEnabled: Bool
    var costUsageEnabled: Bool
    var otelGenAILogPaths: String
    var insightsMenuMaxItems: Int
    var insightsReportDays: Int
    var ledgerMaxAgeDays: Int
    var claudeWebExtrasEnabled: Bool
    var showOptionalCreditsAndExtraUsage: Bool
    var openAIWebAccessEnabled: Bool
    var codexUsageDataSourceRaw: String?
    var claudeUsageDataSourceRaw: String?

    init(defaults: SettingsStoreDefaultsSnapshot) {
        self.sessionQuotaNotificationsEnabled = defaults.sessionQuotaNotificationsEnabled
        self.budgetNotificationsEnabled = defaults.budgetNotificationsEnabled
        self.costUsageEnabled = defaults.costUsageEnabled
        self.otelGenAILogPaths = defaults.otelGenAILogPaths
        self.insightsMenuMaxItems = defaults.insightsMenuMaxItems
        self.insightsReportDays = defaults.insightsReportDays
        self.ledgerMaxAgeDays = defaults.ledgerMaxAgeDays
        self.claudeWebExtrasEnabled = defaults.claudeWebExtrasEnabled
        self.showOptionalCreditsAndExtraUsage = defaults.showOptionalCreditsAndExtraUsage
        self.openAIWebAccessEnabled = defaults.openAIWebAccessEnabled
        self.codexUsageDataSourceRaw = defaults.codexUsageDataSourceRaw
        self.claudeUsageDataSourceRaw = defaults.claudeUsageDataSourceRaw
    }
}

extension SettingsStore {
    var sessionQuotaNotificationsEnabled: Bool {
        get { self.usageFeatureValues.sessionQuotaNotificationsEnabled }
        set {
            self.usageFeatureValues.sessionQuotaNotificationsEnabled = newValue
            self.userDefaults.set(newValue, forKey: "sessionQuotaNotificationsEnabled")
        }
    }

    /// When enabled, post macOS notifications when spend forecasts breach project budgets.
    var budgetNotificationsEnabled: Bool {
        get { self.usageFeatureValues.budgetNotificationsEnabled }
        set {
            self.usageFeatureValues.budgetNotificationsEnabled = newValue
            self.userDefaults.set(newValue, forKey: "budgetNotificationsEnabled")
        }
    }

    /// Optional: show provider token/cost summaries from local usage logs.
    var costUsageEnabled: Bool {
        get { self.usageFeatureValues.costUsageEnabled }
        set {
            self.usageFeatureValues.costUsageEnabled = newValue
            self.userDefaults.set(newValue, forKey: "tokenCostUsageEnabled")
        }
    }

    /// Comma/newline separated OpenTelemetry GenAI JSON/JSONL files or folders.
    var otelGenAILogPaths: String {
        get { self.usageFeatureValues.otelGenAILogPaths }
        set {
            self.usageFeatureValues.otelGenAILogPaths = newValue
            self.userDefaults.set(newValue, forKey: "otelGenAILogPaths")
        }
    }

    /// Optional: limit how many insight rows appear in the menu before "More...".
    var insightsMenuMaxItems: Int {
        get { self.usageFeatureValues.insightsMenuMaxItems }
        set {
            self.usageFeatureValues.insightsMenuMaxItems = newValue
            self.userDefaults.set(newValue, forKey: "insightsMenuMaxItems")
        }
    }

    /// Optional: how many days to include in the insights report.
    var insightsReportDays: Int {
        get { self.usageFeatureValues.insightsReportDays }
        set {
            self.usageFeatureValues.insightsReportDays = newValue
            self.userDefaults.set(newValue, forKey: "insightsReportDays")
        }
    }

    /// How many days of usage history to scan for ledger data (charts, breakdowns).
    var ledgerMaxAgeDays: Int {
        get { self.usageFeatureValues.ledgerMaxAgeDays }
        set {
            self.usageFeatureValues.ledgerMaxAgeDays = newValue
            self.userDefaults.set(newValue, forKey: "ledgerMaxAgeDays")
        }
    }

    /// Optional: augment Claude usage with claude.ai web API (via browser cookies),
    /// incl. "Extra usage" spend.
    var claudeWebExtrasEnabled: Bool {
        get { self.usageFeatureValues.claudeWebExtrasEnabled }
        set {
            self.usageFeatureValues.claudeWebExtrasEnabled = newValue
            self.userDefaults.set(newValue, forKey: "claudeWebExtrasEnabled")
        }
    }

    /// Optional: show Codex credits + Claude extra usage sections in the menu UI.
    var showOptionalCreditsAndExtraUsage: Bool {
        get { self.usageFeatureValues.showOptionalCreditsAndExtraUsage }
        set {
            self.usageFeatureValues.showOptionalCreditsAndExtraUsage = newValue
            self.userDefaults.set(newValue, forKey: "showOptionalCreditsAndExtraUsage")
        }
    }

    /// Optional: fetch OpenAI web dashboard extras for Codex (browser cookies).
    var openAIWebAccessEnabled: Bool {
        get { self.usageFeatureValues.openAIWebAccessEnabled }
        set {
            self.usageFeatureValues.openAIWebAccessEnabled = newValue
            self.userDefaults.set(newValue, forKey: "openAIWebAccessEnabled")
        }
    }

    var codexUsageDataSourceRaw: String? {
        get { self.usageFeatureValues.codexUsageDataSourceRaw }
        set {
            self.usageFeatureValues.codexUsageDataSourceRaw = newValue
            if let newValue {
                self.userDefaults.set(newValue, forKey: "codexUsageDataSource")
            } else {
                self.userDefaults.removeObject(forKey: "codexUsageDataSource")
            }
        }
    }

    var claudeUsageDataSourceRaw: String? {
        get { self.usageFeatureValues.claudeUsageDataSourceRaw }
        set {
            self.usageFeatureValues.claudeUsageDataSourceRaw = newValue
            if let newValue {
                self.userDefaults.set(newValue, forKey: "claudeUsageDataSource")
            } else {
                self.userDefaults.removeObject(forKey: "claudeUsageDataSource")
            }
        }
    }
}
