import Foundation
import RunicCore

/// Storage for alert rules, alert history, and webhook configurations
public struct AlertRuleStore {
    // MARK: - Types

    public enum AlertType: String, Codable, Sendable {
        case projectBudget = "project_budget"
        case usageVelocity = "usage_velocity"
        case costAnomaly = "cost_anomaly"
        case quotaThreshold = "quota_threshold"
    }

    public enum AlertSeverity: String, Codable, Sendable {
        case info
        case warning
        case critical
    }

    public struct AlertRule: Codable, Sendable, Identifiable {
        public let id: String
        public var type: AlertType
        public var projectID: String?
        public var provider: String? // UsageProvider rawValue
        public var threshold: Double
        public var severity: AlertSeverity
        public var notifyWebhook: Bool
        public var webhookURL: String?
        public var enabled: Bool
        public let createdAt: Date

        public init(
            id: String = UUID().uuidString,
            type: AlertType,
            projectID: String? = nil,
            provider: String? = nil,
            threshold: Double,
            severity: AlertSeverity,
            notifyWebhook: Bool = false,
            webhookURL: String? = nil,
            enabled: Bool = true,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.type = type
            self.projectID = projectID
            self.provider = provider
            self.threshold = threshold
            self.severity = severity
            self.notifyWebhook = notifyWebhook
            self.webhookURL = webhookURL
            self.enabled = enabled
            self.createdAt = createdAt
        }
    }

    public struct AlertHistoryEntry: Codable, Sendable, Identifiable {
        public let id: String
        public let alertID: String
        public let triggeredAt: Date
        public var message: String
        public var severity: AlertSeverity
        public var acknowledged: Bool
        public var acknowledgedAt: Date?

        public init(
            id: String = UUID().uuidString,
            alertID: String,
            triggeredAt: Date = Date(),
            message: String,
            severity: AlertSeverity,
            acknowledged: Bool = false,
            acknowledgedAt: Date? = nil
        ) {
            self.id = id
            self.alertID = alertID
            self.triggeredAt = triggeredAt
            self.message = message
            self.severity = severity
            self.acknowledged = acknowledged
            self.acknowledgedAt = acknowledgedAt
        }
    }

    public struct AlertsData: Codable {
        public let version: Int
        public var rules: [AlertRule]
        public var history: [AlertHistoryEntry]

        public init(version: Int = 1, rules: [AlertRule] = [], history: [AlertHistoryEntry] = []) {
            self.version = version
            self.rules = rules
            self.history = history
        }
    }

    // MARK: - Storage Location

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let runicDir = appSupport.appendingPathComponent("Runic", isDirectory: true)
        try? FileManager.default.createDirectory(at: runicDir, withIntermediateDirectories: true)
        return runicDir.appendingPathComponent("alert-rules.json")
    }

    // MARK: - Public Methods

    public static func load() -> AlertsData {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return AlertsData()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(AlertsData.self, from: data)
        } catch {
            print("[AlertRuleStore] Failed to load alerts: \(error)")
            return AlertsData()
        }
    }

    public static func save(_ alertsData: AlertsData) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(alertsData)
        try data.write(to: storageURL, options: .atomic)
    }

    public static func addRule(_ rule: AlertRule) throws {
        var data = load()
        data.rules.append(rule)
        try save(data)
    }

    public static func removeRule(id: String) throws {
        var data = load()
        data.rules.removeAll { $0.id == id }
        try save(data)
    }

    public static func updateRule(_ rule: AlertRule) throws {
        var data = load()
        if let index = data.rules.firstIndex(where: { $0.id == rule.id }) {
            data.rules[index] = rule
            try save(data)
        }
    }

    public static func getEnabledRules() -> [AlertRule] {
        load().rules.filter { $0.enabled }
    }

    public static func addHistoryEntry(_ entry: AlertHistoryEntry) throws {
        var data = load()
        data.history.append(entry)

        // Keep last 100 history entries
        if data.history.count > 100 {
            data.history = Array(data.history.suffix(100))
        }

        try save(data)
    }

    public static func acknowledgeAlert(id: String) throws {
        var data = load()
        if let index = data.history.firstIndex(where: { $0.id == id }) {
            data.history[index].acknowledged = true
            data.history[index].acknowledgedAt = Date()
            try save(data)
        }
    }

    public static func getRecentHistory(limit: Int = 20) -> [AlertHistoryEntry] {
        let history = load().history.sorted { $0.triggeredAt > $1.triggeredAt }
        return Array(history.prefix(limit))
    }

    public static func getUnacknowledgedAlerts() -> [AlertHistoryEntry] {
        load().history.filter { !$0.acknowledged }
    }
}
