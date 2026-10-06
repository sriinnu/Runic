import Foundation

public enum ClaudeUsageDataSource: String, CaseIterable, Identifiable, Sendable {
    case oauth
    case web
    case cli

    public var id: String {
        self.rawValue
    }

    public var displayName: String {
        switch self {
        case .oauth: "OAuth API"
        case .web: "Web API (cookies)"
        case .cli: "CLI (PTY)"
        }
    }

    /// Source label when the OAuth path had no usable token and the numbers
    /// came through the CLI instead. Shown in Settings → Providers; the menu
    /// card badges it and offers Reconnect.
    public static let cliFallbackSourceLabel = "cli fallback"

    public var sourceLabel: String {
        switch self {
        case .oauth:
            "oauth"
        case .web:
            "web"
        case .cli:
            "cli"
        }
    }
}
