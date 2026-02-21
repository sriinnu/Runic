import Foundation

/// In-memory cookie store for tests or ephemeral usage.
public final class BrowserCookieMockStore {
    public let store: BrowserCookieStore

    private let lock = NSLock()
    private var records: [BrowserCookieRecord]

    public init(store: BrowserCookieStore, records: [BrowserCookieRecord] = []) {
        self.store = store
        self.records = records
    }

    public convenience init(
        browser: Browser = .chrome,
        profile: BrowserProfile = BrowserProfile(id: "Default", name: "Default"),
        kind: BrowserCookieStoreKind = .primary,
        label: String = "Mock",
        databaseURL: URL? = nil,
        records: [BrowserCookieRecord] = [])
    {
        self.init(
            store: BrowserCookieStore(
                browser: browser,
                profile: profile,
                kind: kind,
                label: label,
                databaseURL: databaseURL),
            records: records)
    }

    public func allRecords() -> [BrowserCookieRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records
    }

    public func records(matching query: BrowserCookieQuery) throws -> [BrowserCookieRecord] {
        let snapshot = allRecords()
        return try BrowserCookieClient.apply(query: query, to: snapshot)
    }

    public func create(_ record: BrowserCookieRecord) throws {
        lock.lock()
        defer { lock.unlock() }
        let key = CookieIdentity(record)
        if records.contains(where: { CookieIdentity($0) == key }) {
            throw BrowserCookieClient.MutationError.duplicateCookie(details: key.description)
        }
        records.append(record)
    }

    public func update(_ record: BrowserCookieRecord) throws {
        lock.lock()
        defer { lock.unlock() }
        let key = CookieIdentity(record)
        guard let index = records.firstIndex(where: { CookieIdentity($0) == key }) else {
            throw BrowserCookieClient.MutationError.missingCookie(details: key.description)
        }
        records[index] = record
    }

    public func upsert(_ record: BrowserCookieRecord) {
        lock.lock()
        defer { lock.unlock() }
        let key = CookieIdentity(record)
        if let index = records.firstIndex(where: { CookieIdentity($0) == key }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    @discardableResult
    public func delete(_ record: BrowserCookieRecord) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let key = CookieIdentity(record)
        guard let index = records.firstIndex(where: { CookieIdentity($0) == key }) else {
            return false
        }
        records.remove(at: index)
        return true
    }

    @discardableResult
    public func delete(matching query: BrowserCookieQuery) throws -> Int {
        let snapshot = allRecords()
        let matches = try BrowserCookieClient.apply(query: query, to: snapshot)
        guard !matches.isEmpty else { return 0 }

        let keys = Set(matches.map(CookieIdentity.init))
        lock.lock()
        defer { lock.unlock() }
        let before = records.count
        records.removeAll { keys.contains(CookieIdentity($0)) }
        return before - records.count
    }
}

private struct CookieIdentity: Hashable, CustomStringConvertible {
    let domain: String
    let name: String
    let path: String
    let isHostOnly: Bool
    let partitionKey: String?

    init(_ record: BrowserCookieRecord) {
        self.domain = record.domain
        self.name = record.name
        self.path = record.path
        self.isHostOnly = record.isHostOnly
        self.partitionKey = record.partitionKey
    }

    var description: String {
        let partition = partitionKey ?? "<none>"
        return "domain=\(domain) name=\(name) path=\(path) hostOnly=\(isHostOnly) partition=\(partition)"
    }
}
