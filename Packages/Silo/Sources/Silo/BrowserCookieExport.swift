import Foundation

public struct BrowserCookieExportRecord: Codable, Sendable {
    public let domain: String
    public let name: String
    public let path: String
    public let value: String
    public let expires: Date?
    public let createdAt: Date?
    public let lastAccessedAt: Date?
    public let isSecure: Bool
    public let isHTTPOnly: Bool
    public let isHostOnly: Bool?
    public let sameSite: BrowserCookieSameSite?
    public let priority: BrowserCookiePriority?
    public let partitionKey: String?
    public let isSameParty: Bool?

    public init(record: BrowserCookieRecord) {
        self.domain = record.domain
        self.name = record.name
        self.path = record.path
        self.value = record.value
        self.expires = record.expires
        self.createdAt = record.createdAt
        self.lastAccessedAt = record.lastAccessedAt
        self.isSecure = record.isSecure
        self.isHTTPOnly = record.isHTTPOnly
        self.isHostOnly = record.isHostOnly
        self.sameSite = record.sameSite
        self.priority = record.priority
        self.partitionKey = record.partitionKey
        self.isSameParty = record.isSameParty
    }
}

public struct BrowserCookieStoreExport: Codable, Sendable {
    public let browser: Browser
    public let profileId: String
    public let profileName: String
    public let kind: BrowserCookieStoreKind
    public let label: String
    public let records: [BrowserCookieExportRecord]

    public init(store: BrowserCookieStore, records: [BrowserCookieRecord]) {
        self.browser = store.browser
        self.profileId = store.profile.id
        self.profileName = store.profile.name
        self.kind = store.kind
        self.label = store.label
        self.records = records.map(BrowserCookieExportRecord.init(record:))
    }
}

public struct BrowserCookieExport: Codable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let stores: [BrowserCookieStoreExport]

    public init(
        schemaVersion: Int = 1,
        generatedAt: Date = Date(),
        stores: [BrowserCookieStoreExport])
    {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.stores = stores
    }

    public func jsonData(
        prettyPrinted: Bool = true,
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601) throws -> Data
    {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = dateEncodingStrategy
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case generatedAt
        case stores
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = (try? container.decode(Int.self, forKey: .schemaVersion)) ?? 1
        self.generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        self.stores = try container.decode([BrowserCookieStoreExport].self, forKey: .stores)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(stores, forKey: .stores)
    }
}

public extension BrowserCookieClient {
    func export(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore) throws -> BrowserCookieExport
    {
        let records = try self.records(matching: query, in: store)
        let exportStore = BrowserCookieStoreExport(store: store, records: records)
        return BrowserCookieExport(stores: [exportStore])
    }

    func export(
        matching query: BrowserCookieQuery,
        in browser: Browser) throws -> BrowserCookieExport
    {
        let sources = try self.records(matching: query, in: browser)
        let stores = sources.map { BrowserCookieStoreExport(store: $0.store, records: $0.records) }
        return BrowserCookieExport(stores: stores)
    }

    func export(
        matching query: BrowserCookieQuery,
        in browsers: [Browser]) throws -> BrowserCookieExport
    {
        let sources = try self.records(matching: query, in: browsers)
        let stores = sources.map { BrowserCookieStoreExport(store: $0.store, records: $0.records) }
        return BrowserCookieExport(stores: stores)
    }

    func exportJSON(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore,
        prettyPrinted: Bool = true) throws -> Data
    {
        try self.export(matching: query, in: store).jsonData(prettyPrinted: prettyPrinted)
    }

    func exportJSON(
        matching query: BrowserCookieQuery,
        in browser: Browser,
        prettyPrinted: Bool = true) throws -> Data
    {
        try self.export(matching: query, in: browser).jsonData(prettyPrinted: prettyPrinted)
    }

    func exportJSON(
        matching query: BrowserCookieQuery,
        in browsers: [Browser],
        prettyPrinted: Bool = true) throws -> Data
    {
        try self.export(matching: query, in: browsers).jsonData(prettyPrinted: prettyPrinted)
    }
}
