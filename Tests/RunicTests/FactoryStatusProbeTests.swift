import Foundation
import Testing
@testable import RunicCore

struct FactoryStatusSnapshotTests {
    @Test
    func `maps usage snapshot windows and login method`() {
        let periodEnd = Date(timeIntervalSince1970: 1_738_368_000) // Feb 1, 2025
        let snapshot = FactoryStatusSnapshot(
            standardUserTokens: 50,
            standardOrgTokens: 0,
            standardAllowance: 100,
            premiumUserTokens: 25,
            premiumOrgTokens: 0,
            premiumAllowance: 50,
            periodStart: nil,
            periodEnd: periodEnd,
            planName: "Pro",
            tier: "enterprise",
            organizationName: "Acme",
            accountEmail: "user@example.com",
            userId: "user-1",
            rawJSON: nil)

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.primary.usedPercent == 50)
        #expect(usage.primary.resetsAt == periodEnd)
        #expect(usage.primary.resetDescription?.hasPrefix("Resets ") == true)
        #expect(usage.secondary?.usedPercent == 50)
        #expect(usage.loginMethod(for: .factory) == "Factory Enterprise - Pro")
    }

    @Test
    func `treats large allowances as unlimited`() {
        let snapshot = FactoryStatusSnapshot(
            standardUserTokens: 50_000_000,
            standardOrgTokens: 0,
            standardAllowance: 2_000_000_000_000,
            premiumUserTokens: 0,
            premiumOrgTokens: 0,
            premiumAllowance: 0,
            periodStart: nil,
            periodEnd: nil,
            planName: nil,
            tier: nil,
            organizationName: nil,
            accountEmail: nil,
            userId: nil,
            rawJSON: nil)

        let usage = snapshot.toUsageSnapshot()

        #expect(usage.primary.usedPercent == 50)
    }
}

struct FactoryStatusProbeWorkOSTests {
    @Test
    func `detects missing refresh token payload`() {
        let payload = Data("""
        {"error":"invalid_request","error_description":"Missing refresh token."}
        """.utf8)

        #expect(FactoryStatusProbe.isMissingWorkOSRefreshToken(payload))
    }
}
