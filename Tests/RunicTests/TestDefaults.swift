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
        self.track(suite)
        if detectionCompleted {
            defaults.set(true, forKey: "providerDetectionCompleted")
        }
        return defaults
    }

    // A unique suite per call keeps parallel tests apart, but each one is a
    // plist in ~/Library/Preferences: 200+ piled up across runs. Remove every
    // suite this process created when it exits.
    private static let lock = NSLock()
    private nonisolated(unsafe) static var suites: [String] = []
    private nonisolated(unsafe) static var cleanupRegistered = false

    static func track(_ suite: String) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.suites.append(suite)
        guard !self.cleanupRegistered else { return }
        self.cleanupRegistered = true
        atexit { TestDefaults.removeTrackedSuites() }
    }

    static func removeTrackedSuites() {
        self.lock.lock()
        let suites = self.suites
        self.suites.removeAll()
        self.lock.unlock()
        // Emptying the domain doesn't reliably remove its plist, so delete the file too.
        let preferences = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Preferences", isDirectory: true)
        for suite in suites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
            if let file = preferences?.appendingPathComponent("\(suite).plist") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
