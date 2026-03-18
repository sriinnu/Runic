import Foundation

struct VertexAIModelsResponse: Decodable, Sendable {
    struct Model: Decodable, Sendable {
        let name: String?
        let displayName: String?
    }

    let models: [Model]

    init(models: [Model]) {
        self.models = models
    }

    init(from decoder: Decoder) throws {
        // gcloud ai models list --format=json returns a top-level array
        let container = try decoder.singleValueContainer()
        self.models = try container.decode([Model].self)
    }
}

struct VertexAIUsageFetcher {
    private static let commandTimeout: TimeInterval = 20

    static func fetchModels(
        project: String,
        location: String) async throws -> VertexAIModelsResponse
    {
        let output = try await self.runGCloudCLI(
            arguments: [
                "ai", "models", "list",
                "--project=\(project)",
                "--region=\(location)",
                "--format=json",
            ])

        let decoder = JSONDecoder()
        let decoded: VertexAIModelsResponse
        do {
            decoded = try decoder.decode(VertexAIModelsResponse.self, from: output)
        } catch {
            throw VertexAICLIError.decodeFailed(error.localizedDescription)
        }

        return decoded
    }

    private static func runGCloudCLI(arguments: [String]) async throws -> Data {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = self.effectivePATH(existing: environment["PATH"])

        do {
            let result = try await SubprocessRunner.run(
                binary: "/usr/bin/env",
                arguments: ["gcloud"] + arguments,
                environment: environment,
                timeout: Self.commandTimeout,
                label: "vertexai.cli")
            let output = Data(result.stdout.utf8)
            guard !output.isEmpty else {
                throw VertexAICLIError.emptyResponse
            }
            return output
        } catch let error as SubprocessRunnerError {
            switch error {
            case .binaryNotFound:
                throw VertexAICLIError.gcloudNotFound
            case let .launchFailed(details):
                throw VertexAICLIError.commandFailed(statusCode: -1, detail: details)
            case .timedOut:
                throw VertexAICLIError.commandTimedOut
            case let .nonZeroExit(code, stderr):
                throw VertexAICLIError.commandFailed(statusCode: Int(code), detail: stderr)
            }
        }
    }

    private static func effectivePATH(existing: String?) -> String {
        let defaults = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        var parts = (existing ?? "")
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }
        for path in defaults where !parts.contains(path) {
            parts.append(path)
        }
        return parts.joined(separator: ":")
    }
}

extension VertexAIModelsResponse {
    func toUsageSnapshot(project: String, location: String) -> UsageSnapshot {
        let count = self.models.count
        let preview = self.models
            .compactMap(\.displayName)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: ", ")

        var summaryParts: [String] = ["Models available: \(count)", "project \(project)", "region \(location)"]
        if !preview.isEmpty {
            summaryParts.append(preview)
        }

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: summaryParts.joined(separator: " \u{2022} "),
                label: "AI models"),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }
}

enum VertexAICLIError: LocalizedError, Sendable {
    case gcloudNotFound
    case commandFailed(statusCode: Int, detail: String?)
    case commandTimedOut
    case decodeFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .gcloudNotFound:
            return "gcloud CLI is not available. Install the Google Cloud SDK and ensure `gcloud` is on PATH."
        case let .commandFailed(statusCode, detail):
            if let detail, !detail.isEmpty {
                return "Vertex AI CLI request failed (\(statusCode)): \(detail)"
            }
            return "Vertex AI CLI request failed with exit code \(statusCode)."
        case .commandTimedOut:
            return "Vertex AI CLI request timed out."
        case let .decodeFailed(detail):
            return "Could not decode Vertex AI response: \(detail)"
        case .emptyResponse:
            return "Vertex AI returned an empty response."
        }
    }
}
