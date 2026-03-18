import Foundation

public struct VertexAISettingsReader: Sendable {
    private static let log = RunicLog.logger("vertexai-settings")

    public static let projectKey = "VERTEX_AI_PROJECT"
    public static let locationKey = "VERTEX_AI_LOCATION"
    public static let credentialsKey = "GOOGLE_APPLICATION_CREDENTIALS"

    public static func project(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        if let value = self.cleaned(environment[projectKey]) { return value }
        if let value = self.cleaned(environment["GOOGLE_CLOUD_PROJECT"]) { return value }
        if let value = self.cleaned(environment["GCLOUD_PROJECT"]) { return value }
        return nil
    }

    public static func location(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        if let value = self.cleaned(environment[locationKey]) { return value }
        if let value = self.cleaned(environment["GOOGLE_CLOUD_REGION"]) { return value }
        return nil
    }

    public static func credentials(
        environment: [String: String] = ProcessInfo.processInfo.environment) -> String?
    {
        self.cleaned(environment[credentialsKey])
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
