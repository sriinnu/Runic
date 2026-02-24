import Foundation

struct BedrockModelsResponse: Decodable, Sendable {
    struct ModelSummary: Decodable, Sendable {
        let modelID: String?
        let modelName: String?
        let providerName: String?

        enum CodingKeys: String, CodingKey {
            case modelID = "modelId"
            case modelName
            case providerName
        }
    }

    let modelSummaries: [ModelSummary]?

    init(modelSummaries: [ModelSummary]?) {
        self.modelSummaries = modelSummaries
    }
}

struct BedrockUsageFetcher {
    private static let commandTimeout: TimeInterval = 20

    static func fetchModels(
        region: String,
        profile: String?,
        modelFilter: String?) async throws -> BedrockModelsResponse
    {
        let output = try await self.runAWSCLI(
            arguments: ["bedrock", "list-foundation-models", "--region", region, "--output", "json"],
            profile: profile)

        let decoder = JSONDecoder()
        let decoded: BedrockModelsResponse
        do {
            decoded = try decoder.decode(BedrockModelsResponse.self, from: output)
        } catch {
            throw BedrockCLIError.decodeFailed(error.localizedDescription)
        }

        guard let modelFilter = self.cleaned(modelFilter) else {
            return decoded
        }
        let loweredFilter = modelFilter.lowercased()
        let filtered = (decoded.modelSummaries ?? []).filter { model in
            let id = model.modelID?.lowercased() ?? ""
            let name = model.modelName?.lowercased() ?? ""
            let provider = model.providerName?.lowercased() ?? ""
            return id.contains(loweredFilter) || name.contains(loweredFilter) || provider.contains(loweredFilter)
        }
        return BedrockModelsResponse(modelSummaries: filtered)
    }

    private static func runAWSCLI(arguments: [String], profile: String?) async throws -> Data {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = self.effectivePATH(existing: environment["PATH"])
        if let profile = self.cleaned(profile) {
            environment["AWS_PROFILE"] = profile
        }

        do {
            let result = try await SubprocessRunner.run(
                binary: "/usr/bin/env",
                arguments: ["aws"] + arguments,
                environment: environment,
                timeout: Self.commandTimeout,
                label: "bedrock.cli")
            let output = Data(result.stdout.utf8)
            guard !output.isEmpty else {
                throw BedrockCLIError.emptyResponse
            }
            return output
        } catch let error as SubprocessRunnerError {
            switch error {
            case .binaryNotFound:
                throw BedrockCLIError.awsCLINotFound
            case let .launchFailed(details):
                throw BedrockCLIError.commandFailed(statusCode: -1, detail: details)
            case .timedOut:
                throw BedrockCLIError.commandTimedOut
            case let .nonZeroExit(code, stderr):
                throw BedrockCLIError.commandFailed(statusCode: Int(code), detail: stderr)
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

    private static func cleaned(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

extension BedrockModelsResponse {
    func toUsageSnapshot(region: String, profile: String?, modelFilter: String?) -> UsageSnapshot {
        let models = self.modelSummaries ?? []
        let count = models.count
        let preview = models
            .compactMap(\.modelID)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: ", ")

        var summaryParts: [String] = ["Models available: \(count)", "region \(region)"]
        if let profile = profile?.trimmingCharacters(in: .whitespacesAndNewlines), !profile.isEmpty {
            summaryParts.append("profile \(profile)")
        }
        if let modelFilter = modelFilter?.trimmingCharacters(in: .whitespacesAndNewlines), !modelFilter.isEmpty {
            summaryParts.append("filter \(modelFilter)")
        }
        if !preview.isEmpty {
            summaryParts.append(preview)
        }

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: summaryParts.joined(separator: " • "),
                label: "Foundation models"),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }
}

enum BedrockCLIError: LocalizedError, Sendable {
    case awsCLINotFound
    case commandFailed(statusCode: Int, detail: String?)
    case commandTimedOut
    case decodeFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .awsCLINotFound:
            return "AWS CLI is not available. Install awscli and ensure `aws` is on PATH."
        case let .commandFailed(statusCode, detail):
            if let detail, !detail.isEmpty {
                return "AWS Bedrock CLI request failed (\(statusCode)): \(detail)"
            }
            return "AWS Bedrock CLI request failed with exit code \(statusCode)."
        case .commandTimedOut:
            return "AWS Bedrock CLI request timed out."
        case let .decodeFailed(detail):
            return "Could not decode Bedrock response: \(detail)"
        case .emptyResponse:
            return "AWS Bedrock returned an empty response."
        }
    }
}
