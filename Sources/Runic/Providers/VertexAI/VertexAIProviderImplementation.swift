import AppKit
import Foundation
import RunicCore
import RunicMacroSupport

@ProviderImplementationRegistration
struct VertexAIProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .vertexai

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        [
            ProviderSettingsFieldDescriptor(
                id: "vertexai-project",
                title: "Google Cloud project",
                subtitle: "Used by gcloud; alternatively export VERTEX_AI_PROJECT.",
                kind: .plain,
                placeholder: "my-gcp-project",
                binding: context.stringBinding(\.vertexaiProject),
                actions: [],
                isVisible: nil),
            ProviderSettingsFieldDescriptor(
                id: "vertexai-location",
                title: "Location",
                subtitle: "Defaults to us-central1 when omitted; alternatively export VERTEX_AI_LOCATION.",
                kind: .plain,
                placeholder: "us-central1",
                binding: context.stringBinding(\.vertexaiLocation),
                actions: [],
                isVisible: nil),
        ]
    }
}
