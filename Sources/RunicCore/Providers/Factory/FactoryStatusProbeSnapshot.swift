import Foundation

#if os(macOS)
extension FactoryStatusProbe {
    func extractUserIdFromAuth(_ auth: FactoryAuthResponse) -> String? {
        _ = auth
        // The user ID might be in the organization or we might need to parse JWT.
        // For now, return nil and let the API handle it.
        return nil
    }

    func buildSnapshot(
        authInfo: FactoryAuthResponse,
        usageData: FactoryUsageResponse,
        userId: String?) -> FactoryStatusSnapshot
    {
        let usage = usageData.usage

        let periodStart: Date? = usage?.startDate.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        let periodEnd: Date? = usage?.endDate.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }

        return FactoryStatusSnapshot(
            standardUserTokens: usage?.standard?.userTokens ?? 0,
            standardOrgTokens: usage?.standard?.orgTotalTokensUsed ?? 0,
            standardAllowance: usage?.standard?.totalAllowance ?? 0,
            premiumUserTokens: usage?.premium?.userTokens ?? 0,
            premiumOrgTokens: usage?.premium?.orgTotalTokensUsed ?? 0,
            premiumAllowance: usage?.premium?.totalAllowance ?? 0,
            standardUsedRatio: usage?.standard?.usedRatio,
            premiumUsedRatio: usage?.premium?.usedRatio,
            periodStart: periodStart,
            periodEnd: periodEnd,
            planName: authInfo.organization?.subscription?.orbSubscription?.plan?.name,
            tier: authInfo.organization?.subscription?.factoryTier,
            organizationName: authInfo.organization?.name,
            accountEmail: nil, // Email is in JWT, not in auth response body.
            userId: userId ?? usageData.userId,
            rawJSON: nil)
    }
}
#endif
