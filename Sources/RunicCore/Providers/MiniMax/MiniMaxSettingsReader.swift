import Foundation

public struct MiniMaxSettingsReader: Sendable {
    private static let log = RunicLog.logger("minimax-settings")

    public static let cookieKey = "MINIMAX_COOKIE"
    public static let cookieHeaderKey = "MINIMAX_COOKIE_HEADER"
    public static let groupIDKey = "MINIMAX_GROUP_ID"

    public static func cookieHeader(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        if let header = self.cleaned(environment[cookieHeaderKey]) { return header }
        if let header = self.cleaned(environment[cookieKey]) { return header }
        return nil
    }

    public static func groupID(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        if let groupID = self.cleaned(environment[groupIDKey]) { return groupID }
        return nil
    }

    static func cleaned(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'"))
        {
            value.removeFirst()
            value.removeLast()
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

public enum MiniMaxSettingsError: LocalizedError, Sendable {
    case missingCookieHeader
    case missingGroupID

    public var errorDescription: String? {
        switch self {
        case .missingCookieHeader:
            "MiniMax session cookie not found. Set it in Settings → Providers → MiniMax or via MINIMAX_COOKIE."
        case .missingGroupID:
            "MiniMax Group ID not found. Set it in Settings → Providers → MiniMax or via MINIMAX_GROUP_ID."
        }
    }
}
