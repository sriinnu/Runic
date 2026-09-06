import Foundation

/// Every test that builds a `SettingsStore` must run on an isolated defaults
/// suite. The standard domain is the developer's live Runic preferences: a
/// test launch once wrote provider toggles into them and read the running
/// app's menu selection back. A swiftlint custom rule (`isolated_settings_store`)
/// rejects test-side settings-store constructions without a `userDefaults:` argument.
enum TestDefaults {
    /// A fresh, empty suite. `providerDetectionCompleted` is pre-set so stores
    /// don't kick off binary detection during construction.
    static func isolated(
        _ name: String = #function,
        detectionCompleted: Bool = true) -> UserDefaults
    {
        let suite = "RunicTests-\(name)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        if detectionCompleted {
            defaults.set(true, forKey: "providerDetectionCompleted")
        }
        return defaults
    }
}
