import Foundation
import RunicCore
import Testing
@testable import RunicCLI

struct CLISnapshotTests {
    @Test
    func `renders codex text snapshot`() {
        let identity = ProviderIdentitySnapshot(
            providerID: .codex,
            accountEmail: "user@example.com",
            accountOrganization: nil,
            loginMethod: "pro")
        let snapshot = UsageSnapshot(
            primary: .init(usedPercent: 12, windowMinutes: 300, resetsAt: nil, resetDescription: "today at 3:00 PM"),
            secondary: .init(usedPercent: 25, windowMinutes: 10080, resetsAt: nil, resetDescription: "Fri at 9:00 AM"),
            tertiary: nil,
            updatedAt: Date(timeIntervalSince1970: 0),
            identity: identity)

        let output = CLIRenderer.renderText(
            provider: .codex,
            snapshot: snapshot,
            credits: CreditsSnapshot(remaining: 42, events: [], updatedAt: Date()),
            context: RenderContext(header: "Codex 1.2.3 (codex-cli)", useColor: false))

        #expect(output.contains("Codex 1.2.3 (codex-cli)"))
        #expect(output.contains("Session"))
        #expect(output.contains("Weekly"))
        #expect(output.contains("Credits: 42"))
        #expect(output.contains("Account: user@example.com"))
        #expect(output.contains("Plan: Pro"))
    }

    @Test
    func `renders claude snapshot without weekly when missing`() {
        let snapshot = UsageSnapshot(
            primary: .init(usedPercent: 2, windowMinutes: nil, resetsAt: nil, resetDescription: "3pm (Europe/Vienna)"),
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(timeIntervalSince1970: 0))

        let output = CLIRenderer.renderText(
            provider: .claude,
            snapshot: snapshot,
            credits: nil,
            context: RenderContext(header: "Claude Code 2.0.69 (claude)", useColor: false))

        #expect(output.contains("Session"))
        #expect(!output.contains("Weekly:"))
    }

    @Test
    func `applies ansi colors when enabled`() {
        let snapshot = UsageSnapshot(
            primary: .init(usedPercent: 95, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: .init(usedPercent: 80, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
            tertiary: nil,
            updatedAt: Date(timeIntervalSince1970: 0))

        let output = CLIRenderer.renderText(
            provider: .codex,
            snapshot: snapshot,
            credits: nil,
            context: RenderContext(header: "Codex 0.0.0 (codex-cli)", useColor: true))

        #expect(output.contains("\u{001B}[1;36mCodex 0.0.0 (codex-cli)\u{001B}[0m"))
        #expect(output.contains("\u{001B}[31m"))
        #expect(output.contains("\u{001B}[33m"))
    }
}
