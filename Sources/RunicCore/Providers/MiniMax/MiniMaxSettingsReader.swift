import Foundation

public struct MiniMaxSettingsReader: Sendable {
    private static let log = RunicLog.logger("minimax-settings")

    public static let apiTokenKey = "MINIMAX_API_KEY"
    public static let groupIDKey = "MINIMAX_GROUP_ID"

    public static func apiToken(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        if let token = self.cleaned(environment[apiTokenKey]) { return token }
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
    case missingToken
    case missingGroupID

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            "MiniMax API token not found. Set it in Settings → Providers → MiniMax or via MINIMAX_API_KEY."
        case .missingGroupID:
            "MiniMax Group ID not found. Set it in Settings → Providers → MiniMax or via MINIMAX_GROUP_ID."
        }
    }
}
