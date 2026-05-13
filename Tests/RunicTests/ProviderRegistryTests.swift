import RunicCore
import XCTest

final class ProviderRegistryTests: XCTestCase {
    private struct ContextWindowEntry: Decodable {
        let contextK: Int?
        let label: String?
    }

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

    func test_providerContextWindowFallbacksCoverEveryProvider() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let url = root.appendingPathComponent("Sources/Runic/Resources/provider-context-windows.json")
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([String: ContextWindowEntry].self, from: data)

        let missing = Set(UsageProvider.allCases.map(\.rawValue)).subtracting(entries.keys)
        XCTAssertTrue(missing.isEmpty, "Missing context fallback entries for providers: \(missing.sorted()).")

        let invalid = entries.filter { _, entry in
            let label = entry.label?.trimmingCharacters(in: .whitespacesAndNewlines)
            return entry.contextK == nil && (label?.isEmpty ?? true)
        }
        XCTAssertTrue(invalid.isEmpty, "Context fallback entries need either contextK or label: \(invalid.keys.sorted()).")
    }
}
