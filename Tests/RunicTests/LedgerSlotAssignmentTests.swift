import RunicCore
import Testing
@testable import Runic

/// Log-derived usage has no region (`kimi-k3` is attributed to `.kimi` whether
/// it went to api.moonshot.cn or .ai). A China-only user has `.kimi` off, so that
/// usage must surface on `.kimiCN` instead of being dropped.
@MainActor
struct LedgerSlotAssignmentTests {
    private func assign(
        data: Set<UsageProvider>,
        withData: Set<UsageProvider>,
        enabled: Set<UsageProvider>) -> [UsageProvider: UsageProvider]
    {
        UsageStore.ledgerSlotAssignments(
            dataProviders: data,
            hasData: { withData.contains($0) },
            isEnabled: { enabled.contains($0) })
    }

    @Test
    func `china-only user sees brand usage on the china slot`() {
        let result = self.assign(data: [.kimi, .kimiCN], withData: [.kimi], enabled: [.kimiCN])
        #expect(result == [.kimiCN: .kimi])
    }

    @Test
    func `china-only user without a queried china source still gets it`() {
        let result = self.assign(data: [.kimi, .claude], withData: [.kimi, .claude], enabled: [.kimiCN, .claude])
        #expect(result == [.kimiCN: .kimi, .claude: .claude])
    }

    @Test
    func `both regions enabled keep their own data`() {
        let result = self.assign(data: [.kimi, .kimiCN], withData: [.kimi], enabled: [.kimi, .kimiCN])
        #expect(result == [.kimi: .kimi, .kimiCN: .kimiCN])
    }

    @Test
    func `china slot with its own usage is not overwritten`() {
        let result = self.assign(data: [.kimi, .kimiCN], withData: [.kimi, .kimiCN], enabled: [.kimiCN])
        #expect(result == [.kimiCN: .kimiCN])
    }

    @Test
    func `international-only user sees china-attributed usage`() {
        let result = self.assign(data: [.zaiCN], withData: [.zaiCN], enabled: [.zai])
        #expect(result == [.zai: .zaiCN])
    }

    @Test
    func `disabled brand with no enabled sibling stays dropped`() {
        let result = self.assign(data: [.kimi, .deepseek], withData: [.kimi, .deepseek], enabled: [])
        #expect(result.isEmpty)
    }
}
