import Foundation

/// Supported browsers for cookie extraction.
public enum Browser: String, Sendable, Hashable, CaseIterable, Codable {
    case safari
    case chrome
    case chromeBeta
    case chromeCanary
    case arc
    case arcBeta
    case arcCanary
    case chatgptAtlas
    case chromium
    case firefox
    case brave
    case braveBeta
    case braveNightly
    case edge
    case edgeBeta
    case edgeCanary
    case helium
    case vivaldi

    public var displayName: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Chrome"
        case .chromeBeta: "Chrome Beta"
        case .chromeCanary: "Chrome Canary"
        case .arc: "Arc"
        case .arcBeta: "Arc Beta"
        case .arcCanary: "Arc Canary"
        case .chatgptAtlas: "ChatGPT Atlas"
        case .chromium: "Chromium"
        case .firefox: "Firefox"
        case .brave: "Brave"
        case .braveBeta: "Brave Beta"
        case .braveNightly: "Brave Nightly"
        case .edge: "Microsoft Edge"
        case .edgeBeta: "Microsoft Edge Beta"
        case .edgeCanary: "Microsoft Edge Canary"
        case .helium: "Helium"
        case .vivaldi: "Vivaldi"
        }
    }

    public static let defaultImportOrder: [Browser] = [
        .safari, .chrome, .edge, .brave, .arc,
        .chatgptAtlas, .chromium, .helium, .vivaldi, .firefox,
        .chromeBeta, .chromeCanary, .arcBeta, .arcCanary,
        .braveBeta, .braveNightly, .edgeBeta, .edgeCanary,
    ]

    var engine: BrowserEngine {
        switch self {
        case .safari: .webkit
        case .firefox: .firefox
        default: .chromium
        }
    }
}

enum BrowserEngine: Sendable {
    case webkit
    case chromium
    case firefox
}

/// Domain matching strategy for cookie queries.
public enum BrowserCookieDomainMatch: Sendable {
    case contains
    case suffix
    case exact
}

/// Path matching strategy for cookie queries.
public enum BrowserCookiePathMatch: Sendable {
    case contains
    case prefix
    case exact
}

/// SameSite policy values for cookies.
public enum BrowserCookieSameSite: String, Sendable, Codable {
    case lax
    case strict
    case none

    public var propertyValue: String {
        switch self {
        case .lax:
            return "Lax"
        case .strict:
            return "Strict"
        case .none:
            return "None"
        }
    }
}

/// Cookie priority values (browser-specific scale).
public struct BrowserCookiePriority: RawRepresentable, Sendable, Hashable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let low = BrowserCookiePriority(rawValue: 0)
    public static let medium = BrowserCookiePriority(rawValue: 1)
    public static let high = BrowserCookiePriority(rawValue: 2)
}

/// Behavior when a cookie value fails to decrypt.
public enum BrowserCookieDecryptionFailurePolicy: Sendable {
    /// Skip undecryptable cookies unless nothing can be returned.
    case bestEffort
    /// Treat any decryption failure as a hard error.
    case strict
}

/// Redacts cookie values for safe logging.
public enum CookieValueRedactor {
    public static func redact(_ value: String, prefix: Int = 4, suffix: Int = 0) -> String {
        guard !value.isEmpty else { return "" }
        let safePrefix = max(0, prefix)
        let safeSuffix = max(0, suffix)
        let length = value.count
        if safePrefix + safeSuffix >= length {
            return String(repeating: "*", count: length)
        }

        let startIndex = value.startIndex
        let prefixEnd = value.index(startIndex, offsetBy: safePrefix)
        let suffixStart = value.index(value.endIndex, offsetBy: -safeSuffix)
        let prefixValue = String(value[startIndex..<prefixEnd])
        let suffixValue = safeSuffix > 0 ? String(value[suffixStart..<value.endIndex]) : ""
        return "\(prefixValue)...\(suffixValue)"
    }
}

/// Maps a cookie domain to an origin URL when building HTTPCookie values.
public enum BrowserCookieOriginStrategy: Sendable {
    case domainBased
    case fixed(URL)
    case custom(@Sendable (String) -> URL?)

    func resolve(domain: String) -> URL? {
        switch self {
        case .domainBased:
            URL(string: "https://\(domain)")
        case let .fixed(url):
            url
        case let .custom(resolver):
            resolver(domain)
        }
    }
}

/// Query definition for fetching browser cookies.
public struct BrowserCookieQuery: Sendable {
    public let domains: [String]
    public let domainMatch: BrowserCookieDomainMatch
    public let domainPattern: String?
    public let pathPattern: String?
    public let useRegex: Bool
    public let paths: [String]
    public let pathMatch: BrowserCookiePathMatch
    public let secureOnly: Bool?
    public let httpOnlyOnly: Bool?
    public let excludeSession: Bool
    public let minExpiryDate: Date?
    public let maxExpiryDate: Date?
    public let sameSite: BrowserCookieSameSite?
    public let origin: BrowserCookieOriginStrategy
    public let includeExpired: Bool
    public let referenceDate: Date

    public init(
        domains: [String] = [],
        domainMatch: BrowserCookieDomainMatch = .contains,
        domainPattern: String? = nil,
        pathPattern: String? = nil,
        useRegex: Bool = false,
        paths: [String] = [],
        pathMatch: BrowserCookiePathMatch = .contains,
        secureOnly: Bool? = nil,
        httpOnlyOnly: Bool? = nil,
        excludeSession: Bool = false,
        minExpiryDate: Date? = nil,
        maxExpiryDate: Date? = nil,
        sameSite: BrowserCookieSameSite? = nil,
        origin: BrowserCookieOriginStrategy = .domainBased,
        includeExpired: Bool = false,
        referenceDate: Date = Date())
    {
        self.domains = domains
        self.domainMatch = domainMatch
        self.domainPattern = domainPattern
        self.pathPattern = pathPattern
        self.useRegex = useRegex
        self.paths = paths
        self.pathMatch = pathMatch
        self.secureOnly = secureOnly
        self.httpOnlyOnly = httpOnlyOnly
        self.excludeSession = excludeSession
        self.minExpiryDate = minExpiryDate
        self.maxExpiryDate = maxExpiryDate
        self.sameSite = sameSite
        self.origin = origin
        self.includeExpired = includeExpired
        self.referenceDate = referenceDate
    }
}

/// A browser profile identifier.
public struct BrowserProfile: Sendable, Hashable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Which cookie store a browser profile represents.
public enum BrowserCookieStoreKind: String, Sendable, Codable {
    case primary
    case network
    case safari
}

/// A concrete cookie store for a browser profile.
public struct BrowserCookieStore: Sendable, Hashable {
    public let browser: Browser
    public let profile: BrowserProfile
    public let kind: BrowserCookieStoreKind
    public let label: String
    public let databaseURL: URL?

    public init(
        browser: Browser,
        profile: BrowserProfile,
        kind: BrowserCookieStoreKind,
        label: String,
        databaseURL: URL?)
    {
        self.browser = browser
        self.profile = profile
        self.kind = kind
        self.label = label
        self.databaseURL = databaseURL
    }
}

/// A browser cookie record normalized for cross-browser handling.
public struct BrowserCookieRecord: Sendable {
    public let domain: String
    public let isHostOnly: Bool
    public let name: String
    public let path: String
    public let value: String
    public let expires: Date?
    public let createdAt: Date?
    public let lastAccessedAt: Date?
    public let isSecure: Bool
    public let isHTTPOnly: Bool
    public let sameSite: BrowserCookieSameSite?
    public let priority: BrowserCookiePriority?
    public let partitionKey: String?
    public let isSameParty: Bool?

    public var isDomainCookie: Bool { !self.isHostOnly }
    public var isSession: Bool { self.expires == nil }
    public var redactedValue: String { CookieValueRedactor.redact(self.value) }

    public func redactedValue(prefix: Int = 4, suffix: Int = 0) -> String {
        CookieValueRedactor.redact(self.value, prefix: prefix, suffix: suffix)
    }

    public init(
        domain: String,
        name: String,
        path: String,
        value: String,
        expires: Date?,
        createdAt: Date? = nil,
        lastAccessedAt: Date? = nil,
        isSecure: Bool,
        isHTTPOnly: Bool,
        isHostOnly: Bool? = nil,
        sameSite: BrowserCookieSameSite? = nil,
        priority: BrowserCookiePriority? = nil,
        partitionKey: String? = nil,
        isSameParty: Bool? = nil)
    {
        let (normalizedDomain, hostOnly) = Self.parseDomain(domain, isHostOnly: isHostOnly)
        self.domain = normalizedDomain
        self.isHostOnly = hostOnly
        self.name = name
        self.path = path
        self.value = value
        self.expires = expires
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.sameSite = sameSite
        self.priority = priority
        self.partitionKey = partitionKey
        self.isSameParty = isSameParty
    }

    private static func parseDomain(_ raw: String, isHostOnly: Bool?) -> (String, Bool) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix(".") ? String(trimmed.dropFirst()) : trimmed
        if let isHostOnly {
            return (normalized, isHostOnly)
        }
        return (normalized, !trimmed.hasPrefix("."))
    }
}

/// Cookie records loaded from a specific browser store.
public struct BrowserCookieStoreRecords: Sendable {
    public let store: BrowserCookieStore
    public let records: [BrowserCookieRecord]

    public init(store: BrowserCookieStore, records: [BrowserCookieRecord]) {
        self.store = store
        self.records = records
    }

    public var label: String { self.store.label }
    public var browser: Browser { self.store.browser }

    public func cookies(origin: BrowserCookieOriginStrategy = .domainBased) -> [HTTPCookie] {
        BrowserCookieClient.makeHTTPCookies(self.records, origin: origin)
    }
}

/// Errors raised when reading browser cookies.
public enum BrowserCookieError: LocalizedError, Sendable {
    case notFound(browser: Browser, details: String)
    case accessDenied(browser: Browser, details: String)
    case loadFailed(browser: Browser, details: String)

    public var errorDescription: String? {
        switch self {
        case let .notFound(browser, details):
            "\(browser.displayName) cookies not found: \(details)"
        case let .accessDenied(browser, details):
            "\(browser.displayName) access denied: \(details)"
        case let .loadFailed(browser, details):
            "\(browser.displayName) load failed: \(details)"
        }
    }

    public var accessDeniedHint: String {
        switch self {
        case .accessDenied:
            #if os(macOS)
            return "Enable Full Disk Access in System Settings → Privacy & Security"
            #elseif os(Linux)
            return "Check file permissions for browser profile directories"
            #elseif os(Windows)
            return "Check DPAPI access and user profile permissions"
            #else
            return "Check permissions for cookie storage"
            #endif
        default:
            return ""
        }
    }
}

/// Errors raised when building or applying cookie queries.
public enum BrowserCookieQueryError: LocalizedError, Sendable {
    case invalidDomainPattern(String)
    case invalidPathPattern(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidDomainPattern(pattern):
            "Invalid domain regex pattern: \(pattern)"
        case let .invalidPathPattern(pattern):
            "Invalid path regex pattern: \(pattern)"
        }
    }
}
