import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// High-level API for enumerating and reading browser cookies.
public struct BrowserCookieClient: Sendable {
    public enum MutationError: LocalizedError, Sendable {
        case duplicateCookie(details: String)
        case missingCookie(details: String)

        public var errorDescription: String? {
            switch self {
            case let .duplicateCookie(details):
                return "Cookie already exists: \(details)"
            case let .missingCookie(details):
                return "Cookie not found: \(details)"
            }
        }
    }

    public struct Configuration: Sendable {
        public var homeDirectories: [URL]
        public var decryptionFailurePolicy: BrowserCookieDecryptionFailurePolicy

        public init(
            homeDirectories: [URL] = Self.defaultHomeDirectories(),
            decryptionFailurePolicy: BrowserCookieDecryptionFailurePolicy = .bestEffort)
        {
            self.homeDirectories = homeDirectories
            self.decryptionFailurePolicy = decryptionFailurePolicy
        }

        public static func defaultHomeDirectories() -> [URL] {
            var dirs: [URL] = []
            #if os(macOS) || os(iOS)
            dirs.append(FileManager.default.homeDirectoryForCurrentUser)
            #elseif os(Linux) || os(Windows)
            if let home = ProcessInfo.processInfo.environment["HOME"] {
                dirs.append(URL(fileURLWithPath: home))
            }
            #endif
            return dirs
        }
    }

    public let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Returns cookie stores for a specific browser.
    public func stores(for browser: Browser) -> [BrowserCookieStore] {
        Self.backend(for: browser).stores(for: browser, configuration: self.configuration)
    }

    /// Returns cookie stores for multiple browsers.
    public func stores(in browsers: [Browser]) -> [BrowserCookieStore] {
        browsers.flatMap { self.stores(for: $0) }
    }

    /// Loads cookie records from multiple browsers.
    public func records(
        matching query: BrowserCookieQuery,
        in browsers: [Browser]) throws -> [BrowserCookieStoreRecords]
    {
        try browsers.flatMap { try self.records(matching: query, in: $0) }
    }

    /// Loads cookie records from a specific browser.
    public func records(
        matching query: BrowserCookieQuery,
        in browser: Browser) throws -> [BrowserCookieStoreRecords]
    {
        let stores = self.stores(for: browser)
        return try stores.compactMap { store in
            let records = try self.records(matching: query, in: store)
            guard !records.isEmpty else { return nil }
            return BrowserCookieStoreRecords(store: store, records: records)
        }
    }

    /// Loads cookie records from a specific cookie store.
    public func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore) throws -> [BrowserCookieRecord]
    {
        let records = try Self.backend(for: store.browser).records(
            matching: query,
            in: store,
            configuration: self.configuration)
        return try Self.apply(query: query, to: records)
    }

    /// Loads HTTPCookie values from a specific store.
    public func cookies(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieStore) throws -> [HTTPCookie]
    {
        let records = try self.records(matching: query, in: store)
        return Self.makeHTTPCookies(records, origin: query.origin)
    }

    /// Loads HTTPCookie values from multiple browser stores.
    public func cookies(
        matching query: BrowserCookieQuery,
        in browser: Browser) throws -> [HTTPCookie]
    {
        let sources = try self.records(matching: query, in: browser)
        return sources.flatMap { $0.cookies(origin: query.origin) }
    }

    /// Loads HTTPCookie values from multiple browsers.
    public func cookies(
        matching query: BrowserCookieQuery,
        in browsers: [Browser]) throws -> [HTTPCookie]
    {
        let sources = try self.records(matching: query, in: browsers)
        return sources.flatMap { $0.cookies(origin: query.origin) }
    }

    /// Convert cookie records into HTTPCookie values.
    public static func makeHTTPCookies(
        _ records: [BrowserCookieRecord],
        origin: BrowserCookieOriginStrategy = .domainBased) -> [HTTPCookie]
    {
        records.compactMap { record in
            let host = record.domain.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !host.isEmpty else { return nil }
            let domain = record.isHostOnly ? host : ".\(host)"
            var props: [HTTPCookiePropertyKey: Any] = [
                .domain: domain,
                .name: record.name,
                .path: record.path,
                .value: record.value,
            ]
            if record.isSecure {
                props[.secure] = "TRUE"
            }
            if record.isHTTPOnly {
                props[HTTPCookiePropertyKey("HttpOnly")] = "TRUE"
            }
            if let expires = record.expires {
                props[.expires] = expires
            }
            if let sameSite = record.sameSite {
                props[HTTPCookiePropertyKey("SameSite")] = sameSite.propertyValue
            }
            if let originURL = origin.resolve(domain: host) {
                props[.originURL] = originURL
            }
            return HTTPCookie(properties: props)
        }
    }

    private static func backend(for browser: Browser) -> BrowserCookieBackend {
        BrowserCookieBackendRegistry.backend(for: browser)
    }

    static func apply(
        query: BrowserCookieQuery,
        to records: [BrowserCookieRecord]) throws -> [BrowserCookieRecord]
    {
        var filtered = records

        if !query.includeExpired {
            filtered = filtered.filter { record in
                guard let expires = record.expires else { return true }
                return expires >= query.referenceDate
            }
        }

        if query.excludeSession {
            filtered = filtered.filter { !$0.isSession }
        }

        if let minExpiry = query.minExpiryDate {
            filtered = filtered.filter { record in
                guard let expires = record.expires else { return false }
                return expires >= minExpiry
            }
        }

        if let maxExpiry = query.maxExpiryDate {
            filtered = filtered.filter { record in
                guard let expires = record.expires else { return false }
                return expires <= maxExpiry
            }
        }

        if let secureOnly = query.secureOnly {
            filtered = filtered.filter { $0.isSecure == secureOnly }
        }

        if let httpOnlyOnly = query.httpOnlyOnly {
            filtered = filtered.filter { $0.isHTTPOnly == httpOnlyOnly }
        }

        if let sameSite = query.sameSite {
            filtered = filtered.filter { $0.sameSite == sameSite }
        }

        if !query.paths.isEmpty {
            filtered = filtered.filter { record in
                Self.matchesPath(record.path, patterns: query.paths, match: query.pathMatch)
            }
        }

        if query.useRegex, let pattern = query.pathPattern, !pattern.isEmpty {
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                throw BrowserCookieQueryError.invalidPathPattern(pattern)
            }
            filtered = filtered.filter { record in
                let range = NSRange(record.path.startIndex..<record.path.endIndex, in: record.path)
                return regex.firstMatch(in: record.path, options: [], range: range) != nil
            }
        }

        if !query.domains.isEmpty {
            filtered = filtered.filter { record in
                Self.matchesDomain(record.domain, patterns: query.domains, match: query.domainMatch)
            }
        }

        if query.useRegex, let pattern = query.domainPattern, !pattern.isEmpty {
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            } catch {
                throw BrowserCookieQueryError.invalidDomainPattern(pattern)
            }
            filtered = filtered.filter { record in
                let range = NSRange(record.domain.startIndex..<record.domain.endIndex, in: record.domain)
                return regex.firstMatch(in: record.domain, options: [], range: range) != nil
            }
        }

        return filtered
    }

    private static func matchesDomain(
        _ domain: String,
        patterns: [String],
        match: BrowserCookieDomainMatch) -> Bool
    {
        let host = domain.lowercased()
        for pattern in patterns {
            let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let normalized = trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
            let target = normalized.lowercased()
            switch match {
            case .contains:
                if host.contains(target) { return true }
            case .suffix:
                if host == target || host.hasSuffix(".\(target)") { return true }
            case .exact:
                if host == target { return true }
            }
        }
        return false
    }

    private static func matchesPath(
        _ path: String,
        patterns: [String],
        match: BrowserCookiePathMatch) -> Bool
    {
        for pattern in patterns {
            if pattern.isEmpty { continue }
            switch match {
            case .contains:
                if path.contains(pattern) { return true }
            case .prefix:
                if path.hasPrefix(pattern) { return true }
            case .exact:
                if path == pattern { return true }
            }
        }
        return false
    }
}

public extension BrowserCookieClient {
    func records(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieMockStore) throws -> [BrowserCookieRecord]
    {
        try store.records(matching: query)
    }

    func cookies(
        matching query: BrowserCookieQuery,
        in store: BrowserCookieMockStore) throws -> [HTTPCookie]
    {
        let records = try store.records(matching: query)
        return Self.makeHTTPCookies(records, origin: query.origin)
    }

    func create(_ record: BrowserCookieRecord, in store: BrowserCookieMockStore) throws {
        try store.create(record)
    }

    func update(_ record: BrowserCookieRecord, in store: BrowserCookieMockStore) throws {
        try store.update(record)
    }

    func upsert(_ record: BrowserCookieRecord, in store: BrowserCookieMockStore) {
        store.upsert(record)
    }

    @discardableResult
    func delete(_ record: BrowserCookieRecord, in store: BrowserCookieMockStore) -> Bool {
        store.delete(record)
    }

    @discardableResult
    func delete(matching query: BrowserCookieQuery, in store: BrowserCookieMockStore) throws -> Int {
        try store.delete(matching: query)
    }
}
