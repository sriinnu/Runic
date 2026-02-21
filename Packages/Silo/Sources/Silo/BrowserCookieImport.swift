import Foundation

public struct BrowserCookieImportOptions: Sendable {
    /// Default host-only behavior when the JSON payload does not specify it.
    public var defaultHostOnly: Bool

    public init(defaultHostOnly: Bool = true) {
        self.defaultHostOnly = defaultHostOnly
    }
}

public struct BrowserCookieImport: Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let stores: [BrowserCookieStoreRecords]

    public init(schemaVersion: Int = 1, generatedAt: Date = Date(), stores: [BrowserCookieStoreRecords]) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.stores = stores
    }

    public var records: [BrowserCookieRecord] {
        self.stores.flatMap(\.records)
    }

    public var browsers: [Browser] {
        var seen: Set<Browser> = []
        var ordered: [Browser] = []
        for store in self.stores {
            if seen.insert(store.store.browser).inserted {
                ordered.append(store.store.browser)
            }
        }
        return ordered
    }

    public init(
        export: BrowserCookieExport,
        options: BrowserCookieImportOptions = BrowserCookieImportOptions())
    {
        self.schemaVersion = export.schemaVersion
        self.generatedAt = export.generatedAt
        self.stores = export.stores.map { storeExport in
            let store = BrowserCookieStore(
                browser: storeExport.browser,
                profile: BrowserProfile(id: storeExport.profileId, name: storeExport.profileName),
                kind: storeExport.kind,
                label: storeExport.label,
                databaseURL: nil)
            let records = storeExport.records.map { exportRecord in
                Self.makeRecord(from: exportRecord, options: options)
            }
            return BrowserCookieStoreRecords(store: store, records: records)
        }
    }

    public init(
        data: Data,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601,
        options: BrowserCookieImportOptions = BrowserCookieImportOptions()) throws
    {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        let export = try decoder.decode(BrowserCookieExport.self, from: data)
        self.init(export: export, options: options)
    }

    private static func makeRecord(
        from exportRecord: BrowserCookieExportRecord,
        options: BrowserCookieImportOptions) -> BrowserCookieRecord
    {
        let hostOnlyOverride = hostOnlyOverride(
            domain: exportRecord.domain,
            isHostOnly: exportRecord.isHostOnly,
            defaultHostOnly: options.defaultHostOnly)

        return BrowserCookieRecord(
            domain: exportRecord.domain,
            name: exportRecord.name,
            path: exportRecord.path,
            value: exportRecord.value,
            expires: exportRecord.expires,
            createdAt: exportRecord.createdAt,
            lastAccessedAt: exportRecord.lastAccessedAt,
            isSecure: exportRecord.isSecure,
            isHTTPOnly: exportRecord.isHTTPOnly,
            isHostOnly: hostOnlyOverride,
            sameSite: exportRecord.sameSite,
            priority: exportRecord.priority,
            partitionKey: exportRecord.partitionKey,
            isSameParty: exportRecord.isSameParty)
    }

    private static func hostOnlyOverride(
        domain: String,
        isHostOnly: Bool?,
        defaultHostOnly: Bool) -> Bool?
    {
        if let isHostOnly {
            return isHostOnly
        }
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(".") {
            return nil
        }
        return defaultHostOnly
    }
}

public extension BrowserCookieClient {
    func importJSON(
        _ data: Data,
        dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601,
        options: BrowserCookieImportOptions = BrowserCookieImportOptions()) throws -> BrowserCookieImport
    {
        try BrowserCookieImport(data: data, dateDecodingStrategy: dateDecodingStrategy, options: options)
    }
}
