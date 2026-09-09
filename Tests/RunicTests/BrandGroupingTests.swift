import Foundation
import RunicCore
import SwiftUI
import Testing
@testable import Runic

@MainActor
struct BrandGroupingTests {
    private func summary(_ provider: UsageProvider, name: String) -> OverviewMenuView.ProviderSummary {
        OverviewMenuView.ProviderSummary(
            id: provider.rawValue,
            provider: provider,
            name: name,
            icon: nil,
            usedPercent: 10,
            todayTokens: 0,
            brandColor: .blue,
            resetDescription: nil,
            windowLabel: nil,
            topModelContext: nil)
    }

    @Test
    func `two region brands stack under one root and offer the missing side`() {
        let groups = OverviewMenuView.brandGroups([
            self.summary(.codex, name: "Codex"),
            self.summary(.zai, name: "z.ai"),
            self.summary(.zaiCN, name: "z.ai CN"),
            self.summary(.kimiCN, name: "Kimi CN"),
            self.summary(.deepseek, name: "DeepSeek"),
        ])
        #expect(groups.map(\.root) == [.codex, .zai, .kimi, .deepseek])

        let codex = groups[0]
        #expect(!codex.isStacked)
        #expect(codex.missingSlot == nil)

        let zai = groups[1]
        #expect(zai.isStacked)
        #expect(zai.rows.map(\.provider) == [.zai, .zaiCN])
        #expect(zai.missingSlot == nil)

        // Only the China side configured: stacks under the Kimi root and
        // offers the international slot.
        let kimi = groups[2]
        #expect(kimi.isStacked)
        #expect(kimi.rows.map(\.provider) == [.kimiCN])
        #expect(kimi.missingSlot == .kimi)

        // A brand with no China sibling never stacks.
        #expect(!groups[3].isStacked)
    }

    @Test
    func `an international only brand offers its china slot`() {
        let groups = OverviewMenuView.brandGroups([self.summary(.stepfun, name: "StepFun")])
        #expect(groups.count == 1)
        #expect(groups[0].isStacked)
        #expect(groups[0].missingSlot == .stepfunCN)
        #expect(groups[0].rows.first?.region == .international)
    }

    @Test
    func `region and brand root follow the slot`() {
        #expect(UsageProvider.zaiCN.brandRoot == .zai)
        #expect(UsageProvider.zaiCN.region == .china)
        #expect(UsageProvider.zai.region == .international)
        #expect(UsageProvider.codex.brandRoot == .codex)
    }
}
