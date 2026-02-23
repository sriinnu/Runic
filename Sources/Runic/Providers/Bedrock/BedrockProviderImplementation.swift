import AppKit
import RunicCore
import RunicMacroSupport
import Foundation

@ProviderImplementationRegistration
struct BedrockProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .bedrock

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "bedrock-region",
                title: "AWS region",
                subtitle: "Required. Example: us-east-1.",
                kind: .plain,
                placeholder: "us-east-1",
                binding: context.stringBinding(\.bedrockRegion),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "bedrock-aws-profile",
                title: "AWS profile (optional)",
                subtitle: "If set, Runic uses this profile when calling AWS CLI.",
                kind: .plain,
                placeholder: "default",
                binding: context.stringBinding(\.bedrockAWSProfile),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "bedrock-model-id",
                title: "Model filter (optional)",
                subtitle: "Filter model list to a specific model ID or prefix.",
                kind: .plain,
                placeholder: "anthropic.claude-3-5-sonnet",
                binding: context.stringBinding(\.bedrockModelID),
                actions: [],
                isVisible: nil),
        ]
    }
}
