import Foundation

extension AntigravityStatusProbe {
    public static func parseUserStatusResponse(_ data: Data) throws -> AntigravityStatusSnapshot {
        let decoder = JSONDecoder()
        let response = try decoder.decode(UserStatusResponse.self, from: data)
        if let invalid = Self.invalidCode(response.code) {
            throw AntigravityStatusProbeError.apiError(invalid)
        }
        guard let userStatus = response.userStatus else {
            throw AntigravityStatusProbeError.parseFailed("Missing userStatus")
        }

        let modelConfigs = userStatus.cascadeModelConfigData?.clientModelConfigs ?? []
        let models = modelConfigs.compactMap(Self.quotaFromConfig(_:))
        let email = userStatus.email
        let planName = userStatus.planStatus?.planInfo?.preferredName

        return AntigravityStatusSnapshot(
            modelQuotas: models,
            accountEmail: email,
            accountPlan: planName)
    }

    static func parsePlanInfoSummary(_ data: Data) throws -> AntigravityPlanInfoSummary? {
        let decoder = JSONDecoder()
        let response = try decoder.decode(UserStatusResponse.self, from: data)
        if let invalid = Self.invalidCode(response.code) {
            throw AntigravityStatusProbeError.apiError(invalid)
        }
        guard let userStatus = response.userStatus else {
            throw AntigravityStatusProbeError.parseFailed("Missing userStatus")
        }
        guard let planInfo = userStatus.planStatus?.planInfo else { return nil }
        return AntigravityPlanInfoSummary(
            planName: planInfo.planName,
            planDisplayName: planInfo.planDisplayName,
            displayName: planInfo.displayName,
            productName: planInfo.productName,
            planShortName: planInfo.planShortName)
    }

    static func parseCommandModelResponse(_ data: Data) throws -> AntigravityStatusSnapshot {
        let decoder = JSONDecoder()
        let response = try decoder.decode(CommandModelConfigResponse.self, from: data)
        if let invalid = Self.invalidCode(response.code) {
            throw AntigravityStatusProbeError.apiError(invalid)
        }
        let modelConfigs = response.clientModelConfigs ?? []
        let models = modelConfigs.compactMap(Self.quotaFromConfig(_:))
        return AntigravityStatusSnapshot(modelQuotas: models, accountEmail: nil, accountPlan: nil)
    }

    private static func quotaFromConfig(_ config: ModelConfig) -> AntigravityModelQuota? {
        guard let quota = config.quotaInfo else { return nil }
        let reset = quota.resetTime.flatMap { Self.parseDate($0) }
        return AntigravityModelQuota(
            label: config.label,
            modelId: config.modelOrAlias.model,
            remainingFraction: quota.remainingFraction,
            resetTime: reset,
            resetDescription: nil)
    }

    private static func invalidCode(_ code: CodeValue?) -> String? {
        guard let code else { return nil }
        if code.isOK { return nil }
        return "\(code.rawValue)"
    }

    private static func parseDate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }
        if let seconds = Double(value) {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}

private struct UserStatusResponse: Decodable {
    let code: CodeValue?
    let message: String?
    let userStatus: UserStatus?
}

private struct CommandModelConfigResponse: Decodable {
    let code: CodeValue?
    let message: String?
    let clientModelConfigs: [ModelConfig]?
}

private struct UserStatus: Decodable {
    let email: String?
    let planStatus: PlanStatus?
    let cascadeModelConfigData: ModelConfigData?
}

private struct PlanStatus: Decodable {
    let planInfo: PlanInfo?
}

private struct PlanInfo: Decodable {
    let planName: String?
    let planDisplayName: String?
    let displayName: String?
    let productName: String?
    let planShortName: String?

    var preferredName: String? {
        let candidates = [
            planDisplayName,
            displayName,
            productName,
            planName,
            planShortName,
        ]
        for candidate in candidates {
            guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) else { continue }
            if !value.isEmpty { return value }
        }
        return nil
    }
}

private struct ModelConfigData: Decodable {
    let clientModelConfigs: [ModelConfig]?
}

private struct ModelConfig: Decodable {
    let label: String
    let modelOrAlias: ModelAlias
    let quotaInfo: QuotaInfo?
}

private struct ModelAlias: Decodable {
    let model: String
}

private struct QuotaInfo: Decodable {
    let remainingFraction: Double?
    let resetTime: String?
}

private enum CodeValue: Decodable {
    case int(Int)
    case string(String)

    var isOK: Bool {
        switch self {
        case let .int(value):
            return value == 0
        case let .string(value):
            let lower = value.lowercased()
            return lower == "ok" || lower == "success" || value == "0"
        }
    }

    var rawValue: String {
        switch self {
        case let .int(value): "\(value)"
        case let .string(value): value
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported code type")
    }
}
