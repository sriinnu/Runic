import Testing
@testable import Runic

struct MenuCardErrorClassifierTests {
    /// The three ways Runic's copied Claude token can fall out from under the
    /// OAuth path all have to keep the card's Reconnect button visible.
    @Test(arguments: [
        "Claude OAuth credentials not found. Run `claude` to authenticate.",
        "Claude OAuth token expired. Run `claude` to refresh.",
        "Claude OAuth request unauthorized. Run `claude` to re-authenticate.",
    ])
    func `claude credential gaps read as auth errors`(message: String) {
        #expect(MenuCardErrorClassifier.isAuthLike(message))
    }

    @Test
    func `parse and network failures are not auth errors`() {
        #expect(!MenuCardErrorClassifier.isAuthLike("Could not parse Claude usage: Missing Current session"))
        #expect(!MenuCardErrorClassifier.isAuthLike("The request timed out."))
    }
}
