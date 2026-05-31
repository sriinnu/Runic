import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum GeminiStatusProbeError: LocalizedError, Sendable, Equatable {
    case geminiNotInstalled
    case notLoggedIn
    case unsupportedAuthType(String)
    case parseFailed(String)
    case timedOut
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .geminiNotInstalled:
            "Gemini CLI is not installed or not on PATH."
        case .notLoggedIn:
            "Not logged in to Gemini. Run 'gemini' in Terminal to authenticate."
        case let .unsupportedAuthType(authType):
            "Gemini \(authType) auth not supported. Use Google account (OAuth) instead."
        case let .parseFailed(msg):
            "Could not parse Gemini usage: \(msg)"
        case .timedOut:
            "Gemini quota API request timed out."
        case let .apiError(msg):
            "Gemini API error: \(msg)"
        }
    }
}

public enum GeminiAuthType: String, Sendable {
    case oauthPersonal = "oauth-personal"
    case apiKey = "api-key"
    case vertexAI = "vertex-ai"
    case unknown
}

/// User tier IDs returned from the Cloud Code Private API (loadCodeAssist).
/// Maps to: google3/cloud/developer_experience/cloudcode/pa/service/usertier.go
public enum GeminiUserTierId: String, Sendable {
    case free = "free-tier"
    case legacy = "legacy-tier"
    case standard = "standard-tier"
}

public struct GeminiStatusProbe: Sendable {
    public var timeout: TimeInterval = 10.0
    public var homeDirectory: String
    public var dataLoader: @Sendable (URLRequest) async throws -> (Data, URLResponse)
    static let log = RunicLog.logger("gemini-probe")
    static let quotaEndpoint = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
    static let loadCodeAssistEndpoint = "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist"
    static let projectsEndpoint = "https://cloudresourcemanager.googleapis.com/v1/projects"
    private static let settingsPath = "/.gemini/settings.json"

    public init(
        timeout: TimeInterval = 10.0,
        homeDirectory: String = NSHomeDirectory(),
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        })
    {
        self.timeout = timeout
        self.homeDirectory = homeDirectory
        self.dataLoader = dataLoader
    }

    /// Reads the current Gemini auth type from settings.json
    public static func currentAuthType(homeDirectory: String = NSHomeDirectory()) -> GeminiAuthType {
        let settingsURL = URL(fileURLWithPath: homeDirectory + Self.settingsPath)

        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let security = json["security"] as? [String: Any],
              let auth = security["auth"] as? [String: Any],
              let selectedType = auth["selectedType"] as? String
        else {
            return .unknown
        }

        return GeminiAuthType(rawValue: selectedType) ?? .unknown
    }

    public func fetch() async throws -> GeminiStatusSnapshot {
        // Block explicitly unsupported auth types; allow unknown to try OAuth creds
        let authType = Self.currentAuthType(homeDirectory: self.homeDirectory)
        switch authType {
        case .apiKey:
            throw GeminiStatusProbeError.unsupportedAuthType("API key")
        case .vertexAI:
            throw GeminiStatusProbeError.unsupportedAuthType("Vertex AI")
        case .oauthPersonal, .unknown:
            break
        }

        let snap = try await Self.fetchViaAPI(
            timeout: self.timeout,
            homeDirectory: self.homeDirectory,
            dataLoader: self.dataLoader)

        Self.log.info("Gemini API fetch ok", metadata: [
            "dailyPercentLeft": "\(snap.dailyPercentLeft ?? -1)",
        ])
        return snap
    }
}
