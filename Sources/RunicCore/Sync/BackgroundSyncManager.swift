import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Background Sync Manager

/// Manages background synchronization with configurable intervals
///
/// This manager coordinates automatic synchronization operations based on
/// app lifecycle events and configured intervals. It supports:
/// - Active sync (5-minute intervals)
/// - Background sync (hourly intervals)
/// - Manual sync on demand
/// - Lifecycle-aware sync (app launch, foreground, background)
/// - Network reachability monitoring
public actor BackgroundSyncManager {

    // MARK: - Properties

    /// The underlying sync engine
    private let syncEngine: any SyncEngine

    /// Sync configuration
    private let config: SyncConfiguration

    /// Timer for periodic sync operations
    private var syncTimer: Timer?

    /// Indicates if background sync is currently enabled
    private var isEnabled: Bool = false

    /// Last successful sync timestamp
    private var lastSyncDate: Date?

    /// Sync history for diagnostics
    private var syncHistory: [SyncHistoryEntry] = []

    /// Maximum history entries to retain
    private let maxHistoryEntries: Int = 50

    /// Observers registered for sync events
    private var observers: [WeakSyncObserver] = []

    /// Background task identifier (iOS only)
    #if canImport(UIKit)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    #endif

    // MARK: - Initialization

    /// Initializes the background sync manager
    ///
    /// - Parameters:
    ///   - syncEngine: The sync engine to use for operations
    ///   - config: Configuration for sync intervals and behavior
    public init(
        syncEngine: any SyncEngine,
        config: SyncConfiguration = .default
    ) {
        self.syncEngine = syncEngine
        self.config = config

        // Register for app lifecycle notifications
        Task {
            await registerLifecycleObservers()
        }
    }

    // MARK: - Public Methods

    /// Starts background synchronization
    public func start() {
        guard !isEnabled else { return }

        isEnabled = true
        scheduleNextSync()
        notifyObservers { $0.syncDidStart() }
    }

    /// Stops background synchronization
    public func stop() {
        isEnabled = false
        syncTimer?.invalidate()
        syncTimer = nil
    }

    /// Performs a manual sync operation
    ///
    /// - Parameter options: Optional sync options (uses defaults if nil)
    /// - Returns: Result of the sync operation
    @discardableResult
    public func syncNow(options: SyncOptions? = nil) async -> Result<SyncResult, SyncError> {
        let syncOptions = options ?? config.defaultSyncOptions

        notifyObservers { $0.syncDidStart() }

        let result = await syncEngine.sync(options: syncOptions)

        switch result {
        case .success(let syncResult):
            lastSyncDate = Date()
            recordSyncHistory(success: true, result: syncResult)
            notifyObservers { $0.syncDidComplete(result: syncResult) }

        case .failure(let error):
            recordSyncHistory(success: false, error: error)
            notifyObservers { $0.syncDidFail(error: error) }
        }

        return result
    }

    /// Adds an observer for sync events
    ///
    /// - Parameter observer: The observer to add
    public func addObserver(_ observer: SyncObserver) {
        let weakObserver = WeakSyncObserver(observer)
        observers.append(weakObserver)
    }

    /// Removes an observer
    ///
    /// - Parameter observer: The observer to remove
    public func removeObserver(_ observer: SyncObserver) {
        observers.removeAll { $0.observer === observer }
    }

    /// Returns sync statistics
    public var statistics: SyncStatistics {
        SyncStatistics(
            lastSyncDate: lastSyncDate,
            totalSyncs: syncHistory.count,
            successfulSyncs: syncHistory.filter { $0.success }.count,
            failedSyncs: syncHistory.filter { !$0.success }.count,
            averageDuration: calculateAverageDuration(),
            syncHistory: Array(syncHistory.suffix(10))
        )
    }

    /// Updates sync configuration
    ///
    /// - Parameter config: New configuration to apply
    public func updateConfiguration(_ config: SyncConfiguration) async {
        var mutableSelf = self
        await MainActor.run {
            mutableSelf = BackgroundSyncManager(syncEngine: syncEngine, config: config)
        }

        if isEnabled {
            stop()
            start()
        }
    }

    // MARK: - Private Methods

    /// Schedules the next automatic sync
    private func scheduleNextSync() {
        guard isEnabled else { return }

        let interval = determineNextInterval()

        Task { @MainActor in
            syncTimer?.invalidate()
            syncTimer = Timer.scheduledTimer(
                withTimeInterval: interval,
                repeats: false
            ) { [weak self] _ in
                Task {
                    await self?.performScheduledSync()
                }
            }
        }
    }

    /// Determines the appropriate sync interval based on app state
    private func determineNextInterval() -> TimeInterval {
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        return isActive ? config.activeSyncInterval : config.backgroundSyncInterval
        #else
        return config.activeSyncInterval
        #endif
    }

    /// Performs a scheduled background sync
    private func performScheduledSync() async {
        #if canImport(UIKit)
        // Begin background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        #endif

        await syncNow()

        #if canImport(UIKit)
        endBackgroundTask()
        #endif

        // Schedule next sync
        scheduleNextSync()
    }

    #if canImport(UIKit)
    /// Ends the background task
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    #endif

    /// Registers observers for app lifecycle events
    private func registerLifecycleObservers() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleAppBecameActive() }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleAppEnteredBackground() }
        }
        #endif

        #if canImport(AppKit)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleAppBecameActive() }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleAppEnteredBackground() }
        }
        #endif
    }

    /// Handles app becoming active
    private func handleAppBecameActive() async {
        guard config.syncOnForeground else { return }

        // Sync if last sync was more than interval ago
        if shouldSyncOnForeground() {
            await syncNow()
        }
    }

    /// Handles app entering background
    private func handleAppEnteredBackground() async {
        guard config.syncOnBackground else { return }
        await syncNow()
    }

    /// Determines if sync should occur on foreground
    private func shouldSyncOnForeground() -> Bool {
        guard let lastSync = lastSyncDate else { return true }

        let elapsed = Date().timeIntervalSince(lastSync)
        return elapsed >= config.activeSyncInterval
    }

    /// Records sync operation in history
    private func recordSyncHistory(
        success: Bool,
        result: SyncResult? = nil,
        error: SyncError? = nil
    ) {
        let entry = SyncHistoryEntry(
            timestamp: Date(),
            success: success,
            duration: result?.duration ?? 0,
            pushedCount: result?.pushedCount ?? 0,
            fetchedCount: result?.fetchedCount ?? 0,
            error: error?.localizedDescription
        )

        syncHistory.append(entry)

        // Trim history if needed
        if syncHistory.count > maxHistoryEntries {
            syncHistory.removeFirst(syncHistory.count - maxHistoryEntries)
        }
    }

    /// Calculates average sync duration
    private func calculateAverageDuration() -> TimeInterval {
        let successfulSyncs = syncHistory.filter { $0.success && $0.duration > 0 }
        guard !successfulSyncs.isEmpty else { return 0 }

        let totalDuration = successfulSyncs.reduce(0.0) { $0 + $1.duration }
        return totalDuration / Double(successfulSyncs.count)
    }

    /// Notifies all observers
    private func notifyObservers(_ action: (SyncObserver) -> Void) {
        // Clean up deallocated observers
        observers.removeAll { $0.observer == nil }

        // Notify active observers
        for weakObserver in observers {
            if let observer = weakObserver.observer {
                action(observer)
            }
        }
    }
}

// MARK: - Supporting Types

/// Configuration for background sync behavior
public struct SyncConfiguration: Sendable {
    public let activeSyncInterval: TimeInterval
    public let backgroundSyncInterval: TimeInterval
    public let syncOnForeground: Bool
    public let syncOnBackground: Bool
    public let defaultSyncOptions: SyncOptions

    public init(
        activeSyncInterval: TimeInterval = 300,
        backgroundSyncInterval: TimeInterval = 3600,
        syncOnForeground: Bool = true,
        syncOnBackground: Bool = true,
        defaultSyncOptions: SyncOptions = SyncOptions()
    ) {
        self.activeSyncInterval = activeSyncInterval
        self.backgroundSyncInterval = backgroundSyncInterval
        self.syncOnForeground = syncOnForeground
        self.syncOnBackground = syncOnBackground
        self.defaultSyncOptions = defaultSyncOptions
    }

    public static let `default` = SyncConfiguration()
}

/// Statistics about sync operations
public struct SyncStatistics: Sendable {
    public let lastSyncDate: Date?
    public let totalSyncs: Int
    public let successfulSyncs: Int
    public let failedSyncs: Int
    public let averageDuration: TimeInterval
    public let syncHistory: [SyncHistoryEntry]

    public var successRate: Double {
        guard totalSyncs > 0 else { return 0 }
        return Double(successfulSyncs) / Double(totalSyncs) * 100
    }
}

public struct SyncHistoryEntry: Sendable, Codable {
    public let timestamp: Date
    public let success: Bool
    public let duration: TimeInterval
    public let pushedCount: Int
    public let fetchedCount: Int
    public let error: String?
}

private struct WeakSyncObserver {
    weak var observer: SyncObserver?
    init(_ observer: SyncObserver) { self.observer = observer }
}
