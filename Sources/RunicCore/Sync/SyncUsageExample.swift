import Foundation

// MARK: - Example Usage of Runic Sync Infrastructure

/// This file demonstrates how to integrate and use the Runic sync infrastructure
/// in your macOS/iOS application. These examples are for documentation purposes.

#if DEBUG

// MARK: - Basic Setup Example

func setupSyncExample() async {
    // Initialize sync engine with default CloudKit container
    let syncEngine = iCloudSyncEngine()

    // Create background sync manager with default configuration
    let syncManager = BackgroundSyncManager(
        syncEngine: syncEngine,
        config: .default
    )

    // Start automatic background sync
    await syncManager.start()

    print("Sync infrastructure initialized")
}

// MARK: - Custom Configuration Example

func customConfigurationExample() async {
    // Create custom sync configuration
    let config = SyncConfiguration(
        activeSyncInterval: 180,      // 3 minutes when app is active
        backgroundSyncInterval: 1800, // 30 minutes in background
        syncOnForeground: true,       // Sync when app comes to foreground
        syncOnBackground: true,       // Sync when app goes to background
        defaultSyncOptions: SyncOptions(
            forceFullSync: false,
            batchSize: 50,
            conflictStrategy: .lastWriteWins,
            backgroundMode: true,
            timeout: 30.0,
            encryptSensitiveData: true
        )
    )

    let syncEngine = iCloudSyncEngine()
    let syncManager = BackgroundSyncManager(syncEngine: syncEngine, config: config)

    await syncManager.start()
}

// MARK: - Syncing Usage Data Example

func syncUsageDataExample() async {
    let syncEngine = iCloudSyncEngine()

    // Create usage snapshot record
    let usageRecord = UsageSnapshotSyncRecord(
        providerID: "claude",
        primaryUsed: 75000,
        primaryLimit: 100000,
        secondaryUsed: 50,
        secondaryLimit: 100,
        costUSD: 3.75,
        accountEmail: "user@example.com",
        updatedAt: Date(),
        deviceName: "MacBook Pro",
        platform: "macOS"
    )

    // Queue for high-priority sync
    await syncEngine.enqueue(usageRecord, priority: .high)

    // Perform immediate sync
    let result = await syncEngine.push(records: [usageRecord])

    switch result {
    case .success(let recordIDs):
        print("Successfully synced \(recordIDs.count) records")
    case .failure(let error):
        print("Sync failed: \(error.localizedDescription)")
    }
}

// MARK: - Syncing Preferences Example

func syncPreferencesExample() async {
    let syncEngine = iCloudSyncEngine()

    // Create user preferences record
    let preferences = UserPreferencesSyncRecord(
        refreshInterval: 300,
        enabledProviders: ["claude", "openai", "gemini"],
        notificationsEnabled: true,
        autoRefreshEnabled: true,
        theme: "dark",
        displayFormat: "detailed"
    )

    // Push to CloudKit
    let result = await syncEngine.push(records: [preferences])

    switch result {
    case .success:
        print("Preferences synced successfully")
    case .failure(let error):
        print("Failed to sync preferences: \(error)")
    }
}

// MARK: - Syncing Alert Configuration Example

func syncAlertConfigExample() async {
    let syncEngine = iCloudSyncEngine()

    // Create alert configuration for Claude
    let alertConfig = AlertConfigurationSyncRecord(
        providerID: "claude",
        warningThreshold: 0.75,      // Warn at 75%
        criticalThreshold: 0.90,     // Critical at 90%
        notificationChannels: ["system", "email"],
        enabled: true
    )

    await syncEngine.enqueue(alertConfig, priority: .normal)
}

// MARK: - Manual Sync Example

func manualSyncExample() async {
    let syncEngine = iCloudSyncEngine()
    let syncManager = BackgroundSyncManager(syncEngine: syncEngine)

    // Perform manual sync with custom options
    let options = SyncOptions(
        forceFullSync: true,
        conflictStrategy: .lastWriteWins
    )

    let result = await syncManager.syncNow(options: options)

    switch result {
    case .success(let syncResult):
        print("""
            Sync completed:
            - Pushed: \(syncResult.pushedCount)
            - Fetched: \(syncResult.fetchedCount)
            - Conflicts resolved: \(syncResult.conflictsResolved)
            - Duration: \(syncResult.duration)s
            """)
    case .failure(let error):
        print("Sync failed: \(error)")
    }
}

// MARK: - Conflict Resolution Example

func conflictResolutionExample() async {
    let resolver = SyncConflictResolver()

    // Register default merge handlers
    await resolver.registerDefaultMergeHandlers()

    // Register custom merge handler for usage snapshots
    await resolver.registerMergeHandler(for: CloudKitRecordType.usageSnapshot) { local, remote in
        guard let localUsage = local as? UsageSnapshotSyncRecord,
              let remoteUsage = remote as? UsageSnapshotSyncRecord else {
            return local
        }

        // Custom logic: prefer record with higher usage
        if localUsage.primaryUsed > remoteUsage.primaryUsed {
            return local
        } else {
            return remote
        }
    }

    // Get conflict statistics
    let stats = await resolver.conflictStats
    print(stats.summary)
}

// MARK: - Observer Pattern Example

class SyncProgressObserver: SyncObserver {
    func syncDidStart() {
        print("🔄 Sync started")
    }

    func syncDidProgress(current: Int, total: Int) {
        let percentage = (Double(current) / Double(total)) * 100
        print("📊 Progress: \(Int(percentage))% (\(current)/\(total))")
    }

    func syncDidComplete(result: SyncResult) {
        print("""
            ✅ Sync completed successfully:
               - Duration: \(String(format: "%.2f", result.duration))s
               - Records synced: \(result.pushedCount + result.fetchedCount)
            """)
    }

    func syncDidFail(error: SyncError) {
        print("❌ Sync failed: \(error.localizedDescription)")
    }
}

func observerExample() async {
    let syncEngine = iCloudSyncEngine()
    let syncManager = BackgroundSyncManager(syncEngine: syncEngine)

    let observer = SyncProgressObserver()
    await syncManager.addObserver(observer)

    await syncManager.start()
}

// MARK: - Statistics and Monitoring Example

func statisticsExample() async {
    let syncEngine = iCloudSyncEngine()
    let syncManager = BackgroundSyncManager(syncEngine: syncEngine)

    await syncManager.start()

    // Wait for some syncs to complete...
    try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds

    // Get sync statistics
    let stats = await syncManager.statistics

    print("""
        Sync Statistics:
        ================
        Total syncs: \(stats.totalSyncs)
        Successful: \(stats.successfulSyncs)
        Failed: \(stats.failedSyncs)
        Success rate: \(String(format: "%.1f%%", stats.successRate))
        Average duration: \(String(format: "%.2f", stats.averageDuration))s
        Last sync: \(stats.lastSyncDate?.description ?? "Never")
        """)

    // Check pending operations
    let pendingCount = await syncEngine.pendingOperationCount
    print("Pending operations: \(pendingCount)")
}

// MARK: - Error Handling Example

func errorHandlingExample() async {
    let syncEngine = iCloudSyncEngine()

    let result = await syncEngine.sync(options: SyncOptions())

    switch result {
    case .success(let syncResult):
        // Check for warnings
        if !syncResult.warnings.isEmpty {
            print("⚠️ Sync completed with warnings:")
            for warning in syncResult.warnings {
                print("  - \(warning)")
            }
        }

    case .failure(let error):
        // Handle specific errors
        switch error {
        case .iCloudAccountUnavailable:
            print("Please sign in to iCloud in Settings")

        case .networkUnavailable:
            print("Network unavailable. Changes will sync when online.")

        case .quotaExceeded:
            print("iCloud storage full. Please free up space.")

        case .timeout:
            print("Sync timed out. Please try again.")

        case .conflictResolutionFailed(let details):
            print("Conflict resolution failed: \(details)")

        case .cloudKitError(let ckError):
            print("CloudKit error: \(ckError.localizedDescription)")

        default:
            print("Sync error: \(error.localizedDescription)")
        }
    }
}

#endif
