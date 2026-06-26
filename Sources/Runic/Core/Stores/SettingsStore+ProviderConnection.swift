import Foundation

struct SettingsStoreProviderConnectionValues {
    var azureOpenAIEndpoint: String
    var azureOpenAIDeployment: String
    var azureOpenAIAPIVersion: String
    var bedrockRegion: String
    var bedrockAWSProfile: String
    var bedrockModelID: String
    var vertexaiProject: String
    var vertexaiLocation: String
    var kimiBaseURL: String

    init(defaults: SettingsStoreDefaultsSnapshot) {
        self.azureOpenAIEndpoint = defaults.azureOpenAIEndpoint
        self.azureOpenAIDeployment = defaults.azureOpenAIDeployment
        self.azureOpenAIAPIVersion = defaults.azureOpenAIAPIVersion
        self.bedrockRegion = defaults.bedrockRegion
        self.bedrockAWSProfile = defaults.bedrockAWSProfile
        self.bedrockModelID = defaults.bedrockModelID
        self.vertexaiProject = defaults.vertexaiProject
        self.vertexaiLocation = defaults.vertexaiLocation
        self.kimiBaseURL = defaults.kimiBaseURL
    }
}

extension SettingsStore {
    /// Azure OpenAI endpoint URL (stored in UserDefaults).
    var azureOpenAIEndpoint: String {
        get { self.providerConnectionValues.azureOpenAIEndpoint }
        set {
            self.providerConnectionValues.azureOpenAIEndpoint = newValue
            self.userDefaults.set(newValue, forKey: "azureOpenAIEndpoint")
        }
    }

    /// Azure OpenAI deployment name (stored in UserDefaults).
    var azureOpenAIDeployment: String {
        get { self.providerConnectionValues.azureOpenAIDeployment }
        set {
            self.providerConnectionValues.azureOpenAIDeployment = newValue
            self.userDefaults.set(newValue, forKey: "azureOpenAIDeployment")
        }
    }

    /// Azure OpenAI API version (stored in UserDefaults).
    var azureOpenAIAPIVersion: String {
        get { self.providerConnectionValues.azureOpenAIAPIVersion }
        set {
            self.providerConnectionValues.azureOpenAIAPIVersion = newValue
            self.userDefaults.set(newValue, forKey: "azureOpenAIAPIVersion")
        }
    }

    /// Amazon Bedrock region (stored in UserDefaults).
    var bedrockRegion: String {
        get { self.providerConnectionValues.bedrockRegion }
        set {
            self.providerConnectionValues.bedrockRegion = newValue
            self.userDefaults.set(newValue, forKey: "bedrockRegion")
        }
    }

    /// Optional AWS profile for Amazon Bedrock (stored in UserDefaults).
    var bedrockAWSProfile: String {
        get { self.providerConnectionValues.bedrockAWSProfile }
        set {
            self.providerConnectionValues.bedrockAWSProfile = newValue
            self.userDefaults.set(newValue, forKey: "bedrockAWSProfile")
        }
    }

    /// Optional model filter for Amazon Bedrock (stored in UserDefaults).
    var bedrockModelID: String {
        get { self.providerConnectionValues.bedrockModelID }
        set {
            self.providerConnectionValues.bedrockModelID = newValue
            self.userDefaults.set(newValue, forKey: "bedrockModelID")
        }
    }

    /// Google Cloud project for Vertex AI (stored in UserDefaults).
    var vertexaiProject: String {
        get { self.providerConnectionValues.vertexaiProject }
        set {
            self.providerConnectionValues.vertexaiProject = newValue
            self.userDefaults.set(newValue, forKey: "vertexaiProject")
        }
    }

    /// Google Cloud location/region for Vertex AI (stored in UserDefaults).
    var vertexaiLocation: String {
        get { self.providerConnectionValues.vertexaiLocation }
        set {
            self.providerConnectionValues.vertexaiLocation = newValue
            self.userDefaults.set(newValue, forKey: "vertexaiLocation")
        }
    }

    /// Kimi / Moonshot API base URL override (stored in UserDefaults).
    ///
    /// Empty falls back to the international endpoint. Set to `https://api.moonshot.cn`
    /// for subscriptions bought on the China platform, or any reseller/proxy host.
    var kimiBaseURL: String {
        get { self.providerConnectionValues.kimiBaseURL }
        set {
            self.providerConnectionValues.kimiBaseURL = newValue
            self.userDefaults.set(newValue, forKey: "kimiBaseURL")
        }
    }
}
