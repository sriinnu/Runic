import Foundation
import RunicCore

// MARK: - Errors

enum CustomProviderStoreError: LocalizedError {
    case providerNotFound(id: String)
    case duplicateProvider(id: String)
    case invalidData
    case fileSystemError(String)

    var errorDescription: String? {
        switch self {
        case let .providerNotFound(id):
            "Provider with ID '\(id)' not found."
        case let .duplicateProvider(id):
            "Provider with ID '\(id)' already exists."
        case .invalidData:
            "Invalid provider data."
        case let .fileSystemError(message):
            "File system error: \(message)"
        }
    }
}

// MARK: - Store

public enum CustomProviderStore {
    private static let log = RunicLog.logger("custom-provider-store")

    // MARK: - Storage Location

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let runicDir = appSupport.appendingPathComponent("Runic", isDirectory: true)
        try? FileManager.default.createDirectory(at: runicDir, withIntermediateDirectories: true)
        return runicDir.appendingPathComponent("custom-providers.json")
    }

    // MARK: - Load/Save

    /// Load all custom providers from disk.
    public static func load() -> CustomProvidersData {
        guard FileManager.default.fileExists(atPath: self.storageURL.path) else {
            self.log.info("No custom providers file found, returning empty data.")
            return CustomProvidersData()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let providersData = try decoder.decode(CustomProvidersData.self, from: data)
            Self.log.info("Loaded \(providersData.providers.count) custom provider(s).")
            return providersData
        } catch {
            self.log.error("Failed to load custom providers: \(error)")
            return CustomProvidersData()
        }
    }

    /// Save all custom providers to disk.
    public static func save(_ providersData: CustomProvidersData) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(providersData)
            try data.write(to: self.storageURL, options: .atomic)
            Self.log.info("Saved \(providersData.providers.count) custom provider(s).")
        } catch {
            Self.log.error("Failed to save custom providers: \(error)")
            throw CustomProviderStoreError.fileSystemError(error.localizedDescription)
        }
    }

    // MARK: - CRUD Operations

    /// Add a new custom provider.
    ///
    /// - Parameter provider: The provider configuration to add.
    /// - Throws: `CustomProviderStoreError.duplicateProvider` if a provider with the same ID already exists.
    public static func addProvider(_ provider: CustomProviderConfig) throws {
        var data = Self.load()

        // Check for duplicates
        if data.providers.contains(where: { $0.id == provider.id }) {
            Self.log.error("Provider with ID '\(provider.id)' already exists.")
            throw CustomProviderStoreError.duplicateProvider(id: provider.id)
        }

        data.providers.append(provider)
        try Self.save(data)
        Self.log.info("Added custom provider: \(provider.name) (ID: \(provider.id))")
    }

    /// Update an existing custom provider.
    ///
    /// - Parameter provider: The updated provider configuration.
    /// - Throws: `CustomProviderStoreError.providerNotFound` if the provider doesn't exist.
    public static func updateProvider(_ provider: CustomProviderConfig) throws {
        var data = Self.load()

        guard let index = data.providers.firstIndex(where: { $0.id == provider.id }) else {
            Self.log.error("Provider with ID '\(provider.id)' not found for update.")
            throw CustomProviderStoreError.providerNotFound(id: provider.id)
        }

        var updatedProvider = provider
        updatedProvider.updatedAt = Date()
        data.providers[index] = updatedProvider
        try Self.save(data)
        Self.log.info("Updated custom provider: \(provider.name) (ID: \(provider.id))")
    }

    /// Remove a custom provider by ID.
    ///
    /// - Parameter id: The ID of the provider to remove.
    /// - Throws: `CustomProviderStoreError.providerNotFound` if the provider doesn't exist.
    public static func removeProvider(id: String) throws {
        var data = Self.load()

        guard let index = data.providers.firstIndex(where: { $0.id == id }) else {
            Self.log.error("Provider with ID '\(id)' not found for removal.")
            throw CustomProviderStoreError.providerNotFound(id: id)
        }

        let removedProvider = data.providers.remove(at: index)
        try Self.save(data)
        Self.log.info("Removed custom provider: \(removedProvider.name) (ID: \(id))")
    }

    /// Get a custom provider by ID.
    ///
    /// - Parameter id: The ID of the provider to retrieve.
    /// - Returns: The provider configuration, or `nil` if not found.
    public static func getProvider(id: String) -> CustomProviderConfig? {
        let data = Self.load()
        return data.providers.first(where: { $0.id == id })
    }

    /// Get all custom providers.
    ///
    /// - Returns: Array of all custom provider configurations.
    public static func getAllProviders() -> [CustomProviderConfig] {
        let data = Self.load()
        return data.providers
    }

    /// Get only enabled custom providers.
    ///
    /// - Returns: Array of enabled custom provider configurations.
    public static func getEnabledProviders() -> [CustomProviderConfig] {
        let data = Self.load()
        return data.providers.filter(\.enabled)
    }
}
