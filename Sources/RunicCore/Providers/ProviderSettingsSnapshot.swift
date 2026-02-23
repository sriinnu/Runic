import Foundation

public struct ProviderSettingsSnapshot: Sendable {
    public struct CodexProviderSettings: Sendable {
        public let usageDataSource: CodexUsageDataSource

        public init(usageDataSource: CodexUsageDataSource) {
            self.usageDataSource = usageDataSource
        }
    }

    public struct ClaudeProviderSettings: Sendable {
        public let usageDataSource: ClaudeUsageDataSource
        public let webExtrasEnabled: Bool

        public init(usageDataSource: ClaudeUsageDataSource, webExtrasEnabled: Bool) {
            self.usageDataSource = usageDataSource
            self.webExtrasEnabled = webExtrasEnabled
        }
    }

    public struct ZaiProviderSettings: Sendable {
        public init() {}
    }

    public struct CopilotProviderSettings: Sendable {
        public let apiToken: String?

        public init(apiToken: String?) {
            self.apiToken = apiToken
        }
    }

    public struct AzureProviderSettings: Sendable {
        public let apiToken: String?
        public let endpoint: String?
        public let deployment: String?
        public let apiVersion: String?

        public init(apiToken: String?, endpoint: String?, deployment: String?, apiVersion: String?) {
            self.apiToken = apiToken
            self.endpoint = endpoint
            self.deployment = deployment
            self.apiVersion = apiVersion
        }
    }

    public struct BedrockProviderSettings: Sendable {
        public let region: String?
        public let profile: String?
        public let modelID: String?

        public init(region: String?, profile: String?, modelID: String?) {
            self.region = region
            self.profile = profile
            self.modelID = modelID
        }
    }

    public let debugMenuEnabled: Bool
    public let codex: CodexProviderSettings?
    public let claude: ClaudeProviderSettings?
    public let zai: ZaiProviderSettings?
    public let copilot: CopilotProviderSettings?
    public let azure: AzureProviderSettings?
    public let bedrock: BedrockProviderSettings?

    public init(
        debugMenuEnabled: Bool,
        codex: CodexProviderSettings?,
        claude: ClaudeProviderSettings?,
        zai: ZaiProviderSettings?,
        copilot: CopilotProviderSettings?,
        azure: AzureProviderSettings?,
        bedrock: BedrockProviderSettings?)
    {
        self.debugMenuEnabled = debugMenuEnabled
        self.codex = codex
        self.claude = claude
        self.zai = zai
        self.copilot = copilot
        self.azure = azure
        self.bedrock = bedrock
    }
}
