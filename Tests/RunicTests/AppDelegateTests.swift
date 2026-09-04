import AppKit
import RunicCore
import Testing
@testable import Runic

@MainActor
struct AppDelegateTests {
    @Test
    func `builds status controller after launch`() throws {
        let appDelegate = AppDelegate()
        var factoryCalls = 0

        // Install a test factory that records invocations without touching NSStatusBar.
        StatusItemController.factory = { _, _, _, _, _ in
            factoryCalls += 1
            return DummyStatusController()
        }
        AppDelegate.duplicateInstanceCheckDisabledForTests = true
        defer {
            StatusItemController.factory = StatusItemController.defaultFactory
            AppDelegate.duplicateInstanceCheckDisabledForTests = false
        }

        // Isolated defaults: launching runs provider discovery, which must never
        // write toggles into the developer's real Runic preferences.
        let suite = "AppDelegateTests-launch"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: "providerDetectionCompleted")
        let settings = SettingsStore(
            userDefaults: defaults,
            zaiTokenStore: NoopZaiTokenStore(),
            minimaxTokenStore: NoopMiniMaxTokenStore(),
            minimaxCookieHeaderStore: NoopMiniMaxCookieHeaderStore(),
            minimaxGroupIDStore: NoopMiniMaxGroupIDStore(),
            openRouterTokenStore: NoopOpenRouterTokenStore(),
            groqTokenStore: NoopGroqTokenStore())
        let fetcher = UsageFetcher()
        let store = UsageStore(fetcher: fetcher, settings: settings)
        let account = fetcher.loadAccountInfo()

        // configure should not eagerly construct the status controller
        appDelegate.configure(store: store, settings: settings, account: account, selection: PreferencesSelection())
        #expect(factoryCalls == 0)

        // construction happens once after launch
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        #expect(factoryCalls == 1)

        // idempotent on subsequent calls
        appDelegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        #expect(factoryCalls == 1)
    }
}

@MainActor
private final class DummyStatusController: StatusItemControlling {
    func openMenuFromShortcut() {}
}
