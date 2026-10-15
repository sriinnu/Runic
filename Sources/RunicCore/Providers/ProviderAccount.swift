import Foundation

/// One login of a provider kind.
///
/// `UsageProvider` is the *kind* (what Runic knows how to fetch); an account is
/// one credential of that kind. The default account's raw value is exactly the
/// kind's raw value, so every file name, notification id, relay id and toggle
/// key that exists today stays byte-identical and one-login users migrate
/// nothing. Added accounts use `kind~slug`; `~` because `/` and `:` are
/// already load-bearing in paths and relay ids. See docs/design/accounts-and-windows.md.
public struct AccountID: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public static let defaultSlug = "default"

    public let kind: UsageProvider
    public let slug: String

    public init(kind: UsageProvider, slug: String = AccountID.defaultSlug) {
        self.kind = kind
        self.slug = slug.isEmpty ? Self.defaultSlug : slug
    }

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "~", maxSplits: 1, omittingEmptySubsequences: false)
        guard let kind = UsageProvider(rawValue: String(parts[0])) else { return nil }
        let slug = parts.count > 1 ? String(parts[1]) : Self.defaultSlug
        guard !slug.isEmpty, slug != Self.defaultSlug || parts.count == 1 else { return nil }
        self.init(kind: kind, slug: slug)
    }

    public var rawValue: String {
        self.isDefault ? self.kind.rawValue : "\(self.kind.rawValue)~\(self.slug)"
    }

    public var isDefault: Bool {
        self.slug == Self.defaultSlug
    }

    public var description: String {
        self.rawValue
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let id = AccountID(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown account id \(raw)"))
        }
        self = id
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    /// Keychain account name for a stored secret of this account: the kind's
    /// historical item for the default account, a suffixed item otherwise.
    public func keychainAccount(base: String) -> String {
        self.isDefault ? base : "\(base).\(self.slug)"
    }
}

extension UsageProvider {
    /// The one account every kind has, and the only one until "Add account" exists.
    public var defaultAccount: AccountID {
        AccountID(kind: self)
    }
}

/// Where an account's credential lives.
///
/// Encoded as `{"type": "oauthDir", "value": "/path"}` so accounts.json can be
/// written by hand while the Add-account sheet does not exist yet.
public enum CredentialRef: Hashable, Codable, Sendable {
    /// A secret in Runic's provider-credentials keychain service under this account name.
    case keychainItem(String)
    /// A vendor CLI home directory (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `KIMI_CODE_HOME`).
    case oauthDir(String)
    /// An environment variable, for the default account only.
    case env(String)
    /// A browser-cookie store key.
    case cookies(String)

    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)
        switch type {
        case "keychainItem": self = .keychainItem(value)
        case "oauthDir": self = .oauthDir(value)
        case "env": self = .env(value)
        case "cookies": self = .cookies(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown credential type \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let (type, value): (String, String) = switch self {
        case let .keychainItem(name): ("keychainItem", name)
        case let .oauthDir(path): ("oauthDir", path)
        case let .env(name): ("env", name)
        case let .cookies(key): ("cookies", key)
        }
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
    }

    /// The environment a fetch for `kind` runs with so the vendor's own
    /// credential and log locations follow this account: the CLIs and Runic's
    /// readers both key on these variables.
    public func environmentOverrides(for kind: UsageProvider) -> [String: String] {
        guard case let .oauthDir(path) = self else { return [:] }
        switch kind {
        case .claude: return ["CLAUDE_CONFIG_DIR": path]
        case .codex: return ["CODEX_HOME": path]
        case .kimi, .kimiCN: return ["KIMI_CODE_HOME": path]
        default: return [:]
        }
    }
}

/// One login of a kind, as the user configured it. Default accounts are not
/// stored: an absent registry means "one default account per enabled kind".
public struct ProviderAccount: Codable, Sendable, Identifiable, Hashable {
    public let id: AccountID
    /// Short, user-renamable: the login email's local part by default.
    public var displayName: String
    public var region: ProviderRegion?
    public var credential: CredentialRef?
    public var isEnabled: Bool

    public init(
        id: AccountID,
        displayName: String,
        region: ProviderRegion? = nil,
        credential: CredentialRef? = nil,
        isEnabled: Bool = true)
    {
        self.id = id
        self.displayName = displayName
        self.region = region
        self.credential = credential
        self.isEnabled = isEnabled
    }

    public static func `default`(for kind: UsageProvider) -> ProviderAccount {
        ProviderAccount(id: kind.defaultAccount, displayName: AccountID.defaultSlug)
    }
}

/// `accounts.json` in Runic's support directory: only added accounts are
/// written, so a downgrade sees nothing new and a missing file is the
/// one-login world every install starts in.
public enum AccountRegistry {
    private static let log = RunicLog.logger("account-registry")

    struct File: Codable {
        var version: Int = 1
        var accounts: [ProviderAccount] = []
    }

    public static var defaultURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Runic", isDirectory: true).appendingPathComponent("accounts.json")
    }

    /// Added accounts on disk; never the defaults.
    public static func load(url: URL = AccountRegistry.defaultURL) -> [ProviderAccount] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode(File.self, from: data).accounts.filter { !$0.id.isDefault }
        } catch {
            self.log.error("accounts.json unreadable, ignoring it: \(error.localizedDescription)")
            return []
        }
    }

    public static func save(_ accounts: [ProviderAccount], url: URL = AccountRegistry.defaultURL) throws {
        let file = File(accounts: accounts.filter { !$0.id.isDefault })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(file).write(to: url, options: .atomic)
    }

    /// Every account of `kind` a refresh should visit: the default first, then
    /// the enabled added ones in registry order.
    public static func accounts(for kind: UsageProvider, added: [ProviderAccount]) -> [ProviderAccount] {
        [.default(for: kind)] + added.filter { $0.id.kind == kind && $0.isEnabled && !$0.id.isDefault }
    }
}

/// Account-keyed state stays addressable by kind: `snapshots[.codex]` is the
/// kind's default account. Added accounts are addressed by their `AccountID`.
extension Dictionary where Key == AccountID {
    public subscript(_ kind: UsageProvider) -> Value? {
        get { self[kind.defaultAccount] }
        set { self[kind.defaultAccount] = newValue }
    }

    @discardableResult
    public mutating func removeValue(forKey kind: UsageProvider) -> Value? {
        self.removeValue(forKey: kind.defaultAccount)
    }

    /// The default account's entry for each kind, for consumers that still
    /// think per kind.
    public var byKind: [UsageProvider: Value] {
        var result: [UsageProvider: Value] = [:]
        for (account, value) in self where account.isDefault {
            result[account.kind] = value
        }
        return result
    }
}

extension Set<AccountID> {
    public func contains(_ kind: UsageProvider) -> Bool {
        self.contains(kind.defaultAccount)
    }

    @discardableResult
    public mutating func insert(_ kind: UsageProvider) -> (inserted: Bool, memberAfterInsert: AccountID) {
        self.insert(kind.defaultAccount)
    }

    @discardableResult
    public mutating func remove(_ kind: UsageProvider) -> AccountID? {
        self.remove(kind.defaultAccount)
    }
}
