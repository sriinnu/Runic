import Foundation

struct ZaiQuotaLimitResponse: Decodable {
    let code: Int?
    let msg: String?
    let data: ZaiQuotaLimitData?
    let success: Bool?

    var isSuccess: Bool {
        (self.success ?? (self.code == 200)) && (self.code ?? 200) == 200
    }

    var errorMessage: String {
        self.msg ?? self.message ?? "Unknown API error (code: \(self.code ?? -1))"
    }

    /// Some responses use "message" instead of "msg".
    private let message: String?

    private enum CodingKeys: String, CodingKey {
        case code, msg, data, success, message
    }
}

struct ZaiQuotaLimitData: Decodable {
    let limits: [ZaiLimitRaw]
    let planName: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.limits = try container.decode([ZaiLimitRaw].self, forKey: .limits)
        let rawPlan = try [
            container.decodeIfPresent(String.self, forKey: .planName),
            container.decodeIfPresent(String.self, forKey: .plan),
            container.decodeIfPresent(String.self, forKey: .planType),
            container.decodeIfPresent(String.self, forKey: .packageName),
            container.decodeIfPresent(String.self, forKey: .level),
        ].compactMap(\.self).first
        let trimmed = rawPlan?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.planName = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    private enum CodingKeys: String, CodingKey {
        case limits
        case planName
        case plan
        case planType = "plan_type"
        case packageName
        case level
    }
}

struct ZaiLimitRaw: Codable {
    let type: String
    let unit: Int?
    let number: Int?
    let usage: Int?
    let currentValue: Int?
    let remaining: Int?
    let percentage: Int?
    let usageDetails: [ZaiUsageDetail]?
    let nextResetTime: Int?

    func toLimitEntry() -> ZaiLimitEntry? {
        guard let limitType = ZaiLimitType(rawValue: type) else { return nil }
        let limitUnit = ZaiLimitUnit(rawValue: unit ?? 0) ?? .unknown
        let resolvedUsage = self.usage ?? 0
        let resolvedCurrent = self.currentValue ?? 0
        let resolvedRemaining = self.remaining ?? max(0, resolvedUsage - resolvedCurrent)
        let nextReset = self.nextResetTime.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        return ZaiLimitEntry(
            type: limitType,
            unit: limitUnit,
            number: self.number ?? 0,
            usage: resolvedUsage,
            currentValue: resolvedCurrent,
            remaining: resolvedRemaining,
            percentage: Double(self.percentage ?? 0),
            usageDetails: self.usageDetails ?? [],
            nextResetTime: nextReset)
    }
}

/// Flexible model-usage API response (best-effort decoding).
struct ZaiModelUsageResponse: Decodable {
    let code: Int?
    let success: Bool?
    let data: ZaiModelUsageData?

    struct ZaiModelUsageData: Decodable {
        let models: [ZaiModelUsageRaw]?
        let totalTokens: Int?
        let totalPrompts: Int?
        let total_tokens: Int?
        let total_prompts: Int?

        var resolvedTotalTokens: Int? {
            self.totalTokens ?? self.total_tokens
        }

        var resolvedTotalPrompts: Int? {
            self.totalPrompts ?? self.total_prompts
        }
    }

    struct ZaiModelUsageRaw: Decodable {
        let modelCode: String?
        let model_code: String?
        let model: String?
        let tokens: Int?
        let usage: Int?
        let prompts: Int?
        let calls: Int?

        var resolvedModelCode: String? {
            self.modelCode ?? self.model_code ?? self.model
        }

        var resolvedTokens: Int {
            self.tokens ?? self.usage ?? 0
        }

        var resolvedPrompts: Int {
            self.prompts ?? self.calls ?? 0
        }
    }
}

/// Flexible tool-usage API response (best-effort decoding).
struct ZaiToolUsageResponse: Decodable {
    let code: Int?
    let success: Bool?
    let data: ZaiToolUsageData?

    struct ZaiToolUsageData: Decodable {
        let tools: [ZaiToolUsageRaw]?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            var toolEntries: [ZaiToolUsageRaw] = []
            if let tools = try? container.decodeIfPresent(
                [ZaiToolUsageRaw].self,
                forKey: DynamicKey(stringValue: "tools")!)
            {
                toolEntries = tools
            } else {
                // Fallback: try top-level keys as tool names with int values.
                for key in container.allKeys {
                    if let count = try? container.decode(Int.self, forKey: key) {
                        toolEntries.append(ZaiToolUsageRaw(tool: key.stringValue, name: nil, count: count, usage: nil))
                    }
                }
            }
            self.tools = toolEntries.isEmpty ? nil : toolEntries
        }
    }

    struct ZaiToolUsageRaw: Decodable {
        let tool: String?
        let name: String?
        let count: Int?
        let usage: Int?

        var resolvedName: String? {
            self.tool ?? self.name
        }

        var resolvedCount: Int {
            self.count ?? self.usage ?? 0
        }
    }

    struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
}
