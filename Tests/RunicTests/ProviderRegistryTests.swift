import RunicCore
import XCTest

final class ProviderRegistryTests: XCTestCase {
    func test_descriptorRegistryIsCompleteAndDeterministic() {
        let descriptors = ProviderDescriptorRegistry.all
        let ids = descriptors.map(\.id)

        XCTAssertFalse(descriptors.isEmpty, "ProviderDescriptorRegistry must not be empty.")
        XCTAssertEqual(Set(ids).count, ids.count, "ProviderDescriptorRegistry contains duplicate IDs.")

        let missing = Set(UsageProvider.allCases).subtracting(ids)
        XCTAssertTrue(missing.isEmpty, "Missing descriptors for providers: \(missing).")

        let secondPass = ProviderDescriptorRegistry.all.map(\.id)
        XCTAssertEqual(ids, secondPass, "ProviderDescriptorRegistry order changed between reads.")
    }

    func test_providerUsageCoverageFlagsForQuotaModelProviders() {
        let metadata = ProviderDefaults.metadata

        XCTAssertTrue(
            metadata[.gemini]?.usageCoverage.supportsModelBreakdown == true,
            "Gemini should advertise model breakdown coverage from quota windows.")
        XCTAssertTrue(
            metadata[.antigravity]?.usageCoverage.supportsModelBreakdown == true,
            "Antigravity should advertise model breakdown coverage from quota windows.")
    }
}
