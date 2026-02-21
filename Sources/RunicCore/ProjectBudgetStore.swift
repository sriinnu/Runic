import Foundation
import RunicCore

/// Storage for project budget limits and alert thresholds
public struct ProjectBudgetStore {
    // MARK: - Types

    public struct ProjectBudget: Codable, Sendable, Identifiable {
        public var id: String { projectID }
        public let projectID: String
        public var projectName: String?
        public var monthlyLimit: Double
        public var alertThreshold: Double // 0.0-1.0, default 0.8 (80%)
        public var enabled: Bool
        public let createdAt: Date

        public init(
            projectID: String,
            projectName: String? = nil,
            monthlyLimit: Double,
            alertThreshold: Double = 0.8,
            enabled: Bool = true,
            createdAt: Date = Date()
        ) {
            self.projectID = projectID
            self.projectName = projectName
            self.monthlyLimit = monthlyLimit
            self.alertThreshold = alertThreshold
            self.enabled = enabled
            self.createdAt = createdAt
        }
    }

    public struct BudgetsData: Codable {
        public let version: Int
        public var budgets: [String: ProjectBudget] // projectID -> budget

        public init(version: Int = 1, budgets: [String: ProjectBudget] = [:]) {
            self.version = version
            self.budgets = budgets
        }
    }

    // MARK: - Storage Location

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let runicDir = appSupport.appendingPathComponent("Runic", isDirectory: true)
        try? FileManager.default.createDirectory(at: runicDir, withIntermediateDirectories: true)
        return runicDir.appendingPathComponent("project-budgets.json")
    }

    // MARK: - Public Methods

    public static func load() -> BudgetsData {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return BudgetsData()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(BudgetsData.self, from: data)
        } catch {
            print("[ProjectBudgetStore] Failed to load budgets: \(error)")
            return BudgetsData()
        }
    }

    public static func save(_ budgetsData: BudgetsData) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(budgetsData)
        try data.write(to: storageURL, options: .atomic)
    }

    public static func getBudget(projectID: String) -> ProjectBudget? {
        load().budgets[projectID]
    }

    public static func setBudget(_ budget: ProjectBudget) throws {
        var data = load()
        data.budgets[budget.projectID] = budget
        try save(data)
    }

    public static func removeBudget(projectID: String) throws {
        var data = load()
        data.budgets.removeValue(forKey: projectID)
        try save(data)
    }

    public static func getAllBudgets() -> [ProjectBudget] {
        Array(load().budgets.values).sorted { $0.createdAt < $1.createdAt }
    }
}
