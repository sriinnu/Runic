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
public enum CredentialRef: Hashable, Codable, Sendable {
    /// A secret in Runic's provider-credentials keychain service under this account name.
    case keychainItem(String)
    /// A vendor CLI home directory (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `KIMI_CODE_HOME`).
    case oauthDir(String)
    /// An environment variable, for the default account only.
    case env(String)
    /// A browser-cookie store key.
    case cookies(String)
}
