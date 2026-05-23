#if os(macOS)
import Foundation
import LocalAuthentication
import Security
import Testing
@testable import Runic
@testable import RunicCore

struct KeychainQueryPolicyTests {
    @Test
    func `Runic token store queries fail instead of prompting`() throws {
        var query: [String: Any] = [:]

        RunicKeychainQuery.disallowAuthenticationUI(in: &query)

        #expect(query[kSecUseAuthenticationUI as String] as? String == "u_AuthUIS")
        let context = try #require(query[kSecUseAuthenticationContext as String] as? LAContext)
        #expect(context.interactionNotAllowed)
    }

    @Test
    func `RunicCore background keychain queries fail instead of prompting`() throws {
        var query: [String: Any] = [:]

        RunicCoreKeychainQueryPolicy.disallowAuthenticationUI(in: &query)

        #expect(query[kSecUseAuthenticationUI as String] as? String == "u_AuthUIS")
        let context = try #require(query[kSecUseAuthenticationContext as String] as? LAContext)
        #expect(context.interactionNotAllowed)
    }

    @Test
    func `RunicCore explicit imports are the only interactive keychain path`() throws {
        var query: [String: Any] = [:]

        RunicCoreKeychainQueryPolicy.setAuthenticationUI(true, in: &query)

        #expect(query[kSecUseAuthenticationUI as String] as? String == "u_AuthUIA")
        let context = try #require(query[kSecUseAuthenticationContext as String] as? LAContext)
        #expect(!context.interactionNotAllowed)
    }
}
#endif
