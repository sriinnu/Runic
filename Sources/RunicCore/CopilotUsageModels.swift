import Foundation

public struct CopilotUsageResponse: Sendable, Decodable {
    public struct Organization: Sendable, Decodable {
        public let name: String?
        public let login: String?
    }

    public struct QuotaSnapshot: Sendable, Decodable {
        public let entitlement: Double?
        public let remaining: Double?
        public let quotaRemaining: Double?
        public let percentRemaining: Double?
        public let quotaId: String?
        public let unlimited: Bool?
        public let overageCount: Double?
        public let overagePermitted: Bool?
        public let timestampUTC: String?

        private enum CodingKeys: String, CodingKey {
            case entitlement
            case remaining
            case quotaRemaining = "quota_remaining"
            case percentRemaining = "percent_remaining"
            case quotaId = "quota_id"
            case unlimited
            case overageCount = "overage_count"
            case overagePermitted = "overage_permitted"
            case timestampUTC = "timestamp_utc"
        }

        public var normalizedRemaining: Double? {
            self.remaining ?? self.quotaRemaining
        }

        public var normalizedPercentRemaining: Double? {
            if let percent = self.percentRemaining {
                return percent
            }

            guard let entitlement = self.entitlement,
                  entitlement > 0,
                  let remaining = self.normalizedRemaining
            else {
                return nil
            }

            let ratio = (remaining / entitlement) * 100
            return max(0, min(100, ratio))
        }
    }

    public struct QuotaSnapshots: Sendable, Decodable {
        public let premiumInteractions: QuotaSnapshot?
        public let chat: QuotaSnapshot?
        public let completions: QuotaSnapshot?

        private enum CodingKeys: String, CodingKey {
            case premiumInteractions = "premium_interactions"
            case chat
            case completions
        }
    }

    public let quotaSnapshots: QuotaSnapshots?
    public let copilotPlan: String?
    public let assignedDate: String?
    public let quotaResetDate: String?
    public let accessTypeSKU: String?
    public let chatEnabled: Bool?
    public let organizationLoginList: [String]?
    public let organizationList: [Organization]?

    private enum CodingKeys: String, CodingKey {
        case quotaSnapshots = "quota_snapshots"
        case copilotPlan = "copilot_plan"
        case assignedDate = "assigned_date"
        case quotaResetDate = "quota_reset_date"
        case accessTypeSKU = "access_type_sku"
        case chatEnabled = "chat_enabled"
        case organizationLoginList = "organization_login_list"
        case organizationList = "organization_list"
    }
}
