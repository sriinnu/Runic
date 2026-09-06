import Foundation
#if canImport(Security)
import Security
#endif

/// Decides whether this process may touch the login keychain at all.
///
/// Login-keychain items carry an ACL bound to the code signature that stored
/// them. Every `swift build` / `swift test` product is ad-hoc signed with a
/// fresh identity, so the first read from each rebuilt binary summons the
/// "enter your password" dialog per item — and `kSecUseAuthenticationUI` does
/// not suppress that classic prompt. The prompts are pure noise: dev and test
/// binaries never need the user's real keys. So keychain access is granted only
/// to binaries carrying Runic's own signing identifiers with a real certificate
/// (the packaged app, its helpers, the widget); everything else is
/// environment-only. `RUNIC_ALLOW_KEYCHAIN=1` overrides for deliberate local use.
public enum RunicKeychainAccessPolicy {
    public static var processMayUseKeychain: Bool {
        testingOverride ?? evaluated
    }

    /// Tests that deliberately exercise the keychain (with items they created
    /// themselves, so no ACL prompt) set this to `true` for their duration.
    public nonisolated(unsafe) static var testingOverride: Bool?

    private static let evaluated: Bool = Self.evaluate()

    private static let overrideVariable = "RUNIC_ALLOW_KEYCHAIN"

    /// Runic-signed code: the app (release + debug bundle ids), the widget, and
    /// the bundled helpers. `certificate leaf[subject.CN] exists` rejects ad-hoc
    /// signatures, which carry no certificate at all.
    static let requirement = """
    (identifier "com.sriinnu.athena.runic" or identifier "com.sriinnu.athena.runic.debug" \
    or identifier "com.sriinnu.athena.runic.widget" or identifier "RunicCLI" \
    or identifier "RunicClaudeWatchdog" or identifier "RunicClaudeWebProbe") \
    and certificate leaf[subject.CN] exists
    """

    private static func evaluate() -> Bool {
        if ProcessInfo.processInfo.environment[self.overrideVariable] == "1" { return true }
        #if canImport(Security) && os(macOS)
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return false }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(Self.requirement as CFString, [], &requirement) == errSecSuccess,
              let requirement
        else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
        #else
        return false
        #endif
    }
}
