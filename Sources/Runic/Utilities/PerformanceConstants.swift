import Foundation

/// **Runic Performance & Resource Management**
///
/// This file centralizes all performance-critical constants and policies.
/// The core philosophy: **Zero Token Leakage, Maximum Efficiency**
enum PerformanceConstants {
    // MARK: - Animation Frame Rates
    
    /// Menubar icon animation (smooth on modern Macs)
    static let menubarFPS: Double = 60
    
    /// Popover menu animations (full detail when user is actively viewing)
    static let popoverFPS: Double = 60
    
    /// Status pulse effect (minimal overhead for subtle feedback)
    static let statusPulseFPS: Double = 15
    
    // MARK: - Data Fetching Policy
    
    /// **Zero Token Leakage**: Maximum pings per session
    /// - Single ping on menu open
    /// - Additional pings only if truly stale (>5min old)
    /// - Use cookies/cached data first
    static let maxPingsPerSession = 1
    
    /// Time before data considered stale (use cookies/cache until then)
    static let staleDuration: TimeInterval = 300 // 5 minutes
    
    /// Delay before first ping after menu opens
    static let menuOpenPingDelay: Duration = .seconds(1.2)
    
    // MARK: - Caching
    
    /// Icon render cache size (prevent redundant GPU work)
    static let iconCacheSize = 64
    
    /// Morph animation cache size
    static let morphCacheSize = 512
    
    // MARK: - Resource Limits
    
    /// Maximum concurrent provider fetches (prevent API spam)
    static let maxConcurrentFetches = 2
    
    /// Network timeout for single ping
    static let networkTimeout: TimeInterval = 10
    
    // MARK: - Animation Lifecycle
    
    /// Animation stops when:
    /// - Data successfully loaded
    /// - Error state reached (stale flag set)
    /// - User manually cancels
    /// - App enters background
    
    /// Blink animation duration (slower "breath" to avoid flicker)
    static let blinkDuration: TimeInterval = 0.8
    
    /// Chance of double-blink effect
    static let doubleBlinkChance: Double = 0.05
    
    // MARK: - Memory Management
    
    /// Auto-cleanup idle resources after this duration
    static let idleCleanupDelay: TimeInterval = 60
}

// MARK: - Performance Annotations

/// Marks methods that are performance-critical and should not be modified
/// without thorough profiling and testing
@propertyWrapper
struct PerformanceCritical<T> {
    private var value: T
    
    init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    var wrappedValue: T {
        get { value }
        set { value = newValue }
    }
}
