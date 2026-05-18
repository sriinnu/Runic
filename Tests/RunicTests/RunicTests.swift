import AppKit
import Foundation
import RunicCore
import Testing
@testable import Runic

struct RunicTests {
    @Test
    func `icon renderer produces template image`() {
        let image = IconRenderer.makeIcon(
            primaryRemaining: 50,
            weeklyRemaining: 75,
            creditsRemaining: 500,
            stale: false,
            style: .codex)
        #expect(image.isTemplate)
        #expect(image.size.width > 0)
    }

    @Test
    func `timeline ranges expose matching scan horizons`() {
        #expect(UsageTimelineChartMenuView.TimeRange.threeDays.days == 3)
        #expect(UsageTimelineChartMenuView.TimeRange.sevenDays.days == 7)
        #expect(UsageTimelineChartMenuView.TimeRange.thirtyDays.days == 30)
        #expect(UsageTimelineChartMenuView.TimeRange.quarter.days == 90)
        #expect(UsageTimelineChartMenuView.TimeRange.year.days == 365)
    }

    @Test
    func `icon renderer renders at pixel aligned size`() {
        let image = IconRenderer.makeIcon(
            primaryRemaining: 50,
            weeklyRemaining: 75,
            creditsRemaining: 500,
            stale: false,
            style: .claude)
        let bitmapReps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        #expect(!bitmapReps.isEmpty)
        #expect(bitmapReps.contains { rep in rep.pixelsWide > 0 && rep.pixelsHigh > 0 })
    }

    @Test
    func `icon renderer caches static icons`() {
        let first = IconRenderer.makeIcon(
            primaryRemaining: 42,
            weeklyRemaining: 17,
            creditsRemaining: 250,
            stale: false,
            style: .codex)
        let second = IconRenderer.makeIcon(
            primaryRemaining: 42,
            weeklyRemaining: 17,
            creditsRemaining: 250,
            stale: false,
            style: .codex)
        #expect(first === second)
    }

    @Test
    func `icon renderer codex eyes punch through when unknown`() {
        // Regression guard: icon should preserve transparent + opaque pixels.
        let image = IconRenderer.makeIcon(
            primaryRemaining: nil,
            weeklyRemaining: 1,
            creditsRemaining: nil,
            stale: false,
            style: .codex)

        let bitmapReps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        let rep = bitmapReps.max { lhs, rhs in lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh }
        #expect(rep != nil)
        guard let rep else { return }

        func alphaAt(px x: Int, _ y: Int) -> CGFloat {
            (rep.colorAt(x: x, y: y) ?? .clear).alphaComponent
        }

        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        var transparentPixels = 0
        for y in 0..<h {
            for x in 0..<w {
                if alphaAt(px: x, y) < 0.05 {
                    transparentPixels += 1
                }
            }
        }

        #expect(w > 0 && h > 0)
        #expect(transparentPixels > 0)
    }

    @MainActor
    @Test
    func `provider brand icons render as colorful plain marks`() {
        for provider in UsageProvider.allCases {
            let image = ProviderBrandIcon.image(for: provider, size: 20)

            #expect(image != nil, "Missing brand icon for \(provider.rawValue)")
            #expect(image?.isTemplate == false, "Brand icon must not be template-rendered for \(provider.rawValue)")
            #expect(image?.size == NSSize(width: 20, height: 20))
        }
    }

    @MainActor
    @Test
    func `bundled font families resolve to real font names`() {
        RunicTypography.registerFonts()

        let resolved = RunicTypography.fontName(for: "Fira Code")

        #expect(resolved == "FiraCode-Regular")
        #expect(NSFont(name: resolved, size: 13) != nil)
    }

    @MainActor
    @Test
    func `model breakdown collapses duplicate display rows`() {
        let summaries = [
            UsageLedgerModelSummary(
                provider: .codex,
                projectID: "alpha",
                model: "gpt-5.5",
                entryCount: 2,
                totals: UsageLedgerTotals(
                    inputTokens: 90,
                    outputTokens: 30,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 20,
                    costUSD: 0.20)),
            UsageLedgerModelSummary(
                provider: .codex,
                projectID: "beta",
                model: "gpt-5.5",
                entryCount: 1,
                totals: UsageLedgerTotals(
                    inputTokens: 70,
                    outputTokens: 10,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 10,
                    costUSD: 0.10)),
        ]

        let model = ModelBreakdownMenuView.makeModel(from: summaries)

        #expect(model.items.count == 1)
        #expect(model.items.first?.displayName == "gpt-5.5")
        #expect(model.items.first?.totalTokens == 230)
        #expect(model.items.first?.requestCount == 3)
        #expect(model.grandTotalCostText?.contains("0.30") == true)
    }

    @Test
    func `account info parses auth token`() throws {
        let tmp = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: URL(fileURLWithPath: NSTemporaryDirectory()),
            create: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let token = Self.fakeJWT(email: "user@example.com", plan: "pro")
        let auth = ["tokens": ["idToken": token]]
        let data = try JSONSerialization.data(withJSONObject: auth)
        let authURL = tmp.appendingPathComponent("auth.json")
        try data.write(to: authURL)

        let fetcher = UsageFetcher(environment: ["CODEX_HOME": tmp.path])
        let account = fetcher.loadAccountInfo()
        #expect(account.email == "user@example.com")
        #expect(account.plan == "pro")
    }

    private static func fakeJWT(email: String, plan: String) -> String {
        let header = (try? JSONSerialization.data(withJSONObject: ["alg": "none"])) ?? Data()
        let payload = (try? JSONSerialization.data(withJSONObject: [
            "email": email,
            "chatgpt_plan_type": plan,
        ])) ?? Data()
        func b64(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "=", with: "")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
        }
        return "\(b64(header)).\(b64(payload))."
    }
}
