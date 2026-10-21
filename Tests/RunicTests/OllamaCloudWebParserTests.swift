import Foundation
import Testing
@testable import RunicCore

struct OllamaCloudWebParserTests {
    /// Synthetic markup: the real settings page has not been captured, so the
    /// parser is deliberately label-driven rather than tied to a DOM shape.
    private static let signedIn = """
    <nav><a href="/signout">Sign out</a></nav>
    <h2>Cloud Usage</h2>
    <div><span>Session usage</span><span>12.5% used</span>
      <div>Resets in <span data-time="2026-10-21T15:00:00Z">3 hours</span></div></div>
    <div><span>Weekly usage</span><span>41% used</span>
      <div>Resets in <span data-time="2026-10-26T00:00:00Z">5 days</span></div></div>
    """

    @Test
    func `reads session and weekly percent with reset times`() throws {
        let usage = try #require(OllamaCloudWebParser.parse(html: Self.signedIn))
        #expect(usage.sessionUsage == 0.125)
        #expect(usage.weeklyUsage == 0.41)
        #expect(usage.sessionResetsAt == ISO8601DateFormatter().date(from: "2026-10-21T15:00:00Z"))
        #expect(usage.weeklyResetsAt == ISO8601DateFormatter().date(from: "2026-10-26T00:00:00Z"))
        let snapshot = usage.toUsageSnapshot()
        #expect(snapshot.primary.usedPercent == 12.5)
        #expect(snapshot.secondary?.usedPercent == 41)
        #expect(snapshot.secondary?.resetsAt != nil)
    }

    @Test
    func `a weekly only page has no session numbers bleeding in`() throws {
        let html = #"<a href="/signout">x</a><div>Weekly usage 7% used</div>"#
        let usage = try #require(OllamaCloudWebParser.parse(html: html))
        #expect(usage.sessionUsage == nil)
        #expect(usage.weeklyUsage == 0.07)
    }

    @Test
    func `a signed out page is rejected`() {
        let html = #"<a href="/signin">Sign in</a><p>Welcome to Ollama</p>"#
        #expect(OllamaCloudWebParser.parse(html: html) == nil)
    }

    @Test
    func `a signed in page without usage blocks reports no limits`() throws {
        let usage = try #require(OllamaCloudWebParser.parse(html: #"<a href="/signout">Sign out</a>"#))
        #expect(usage.sessionUsage == nil && usage.weeklyUsage == nil)
    }
}
