import Foundation
import Testing
@testable import RunicCore

/// A sign-in window sees cookies from every site it passed through, such as the
/// Google login. Only the provider's own may reach its Keychain item.
struct WebSignInCookieTests {
    private func cookie(_ name: String, _ domain: String) throws -> HTTPCookie {
        try #require(HTTPCookie(properties: [.name: name, .value: "v", .domain: domain, .path: "/"]))
    }

    @Test
    func `ollama keeps only its own cookies`() throws {
        let header = try OllamaCloudCookieImporter.signInCookieHeader(from: [
            self.cookie("session", ".ollama.com"),
            self.cookie("www", "www.ollama.com"),
            self.cookie("SID", ".google.com"),
            self.cookie("fake", "notollama.com"),
        ])
        #expect(header == "session=v; www=v")
        #expect(try OllamaCloudCookieImporter.signInCookieHeader(from: [self.cookie("SID", ".google.com")]) == nil)
    }

    @Test
    func `siliconflow waits for a login cookie on its own region`() throws {
        let token = try self.cookie("__SF_auth.session-token", ".siliconflow.com")
        let tracker = try self.cookie("analytics", "cloud.siliconflow.com")
        let google = try self.cookie("SID", ".google.com")

        #expect(SiliconFlowCookieImporter.signInCookieHeader(from: [tracker, google], china: false) == nil)
        #expect(SiliconFlowCookieImporter.signInCookieHeader(from: [token, tracker, google], china: false)
            == "__SF_auth.session-token=v; analytics=v")
        #expect(SiliconFlowCookieImporter.signInCookieHeader(from: [token], china: true) == nil)
    }

    @Test
    func `siliconflow signs in on the matching region`() {
        #expect(SiliconFlowConsoleFetcher.signInURL(china: false).host == "cloud.siliconflow.com")
        #expect(SiliconFlowConsoleFetcher.signInURL(china: true).host == "cloud.siliconflow.cn")
    }
}
