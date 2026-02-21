# CloudKit Sync Quick Reference

## One-Minute Setup

```swift
import RunicCore

// 1. Initialize
let syncEngine = iCloudSyncEngine()
let syncManager = BackgroundSyncManager(syncEngine: syncEngine)

// 2. Start
await syncManager.start()

// Done! Sync runs automatically every 5 minutes (active) / 1 hour (background)
```

---

## Common Operations

### Push Usage Data
```swift
let record = UsageSnapshotSyncRecord(
    providerID: "claude",
    primaryUsed: 75000,
    primaryLimit: 100000,
    deviceName: "MacBook Pro",
    platform: "macOS"
)
await syncEngine.push(records: [record])
```

### Sync Preferences
```swift
let prefs = UserPreferencesSyncRecord(
    refreshInterval: 300,
    enabledProviders: ["claude", "openai"],
    notificationsEnabled: true
)
await syncEngine.push(records: [prefs])
```

### Manual Sync
```swift
let result = await syncManager.syncNow()
```

### Force Full Sync
```swift
let options = SyncOptions(forceFullSync: true)
let result = await syncManager.syncNow(options: options)
```

---

## Monitoring

### Check Sync Status
```swift
let stats = await syncManager.statistics
print("Success rate: \(stats.successRate)%")
print("Last sync: \(stats.lastSyncDate)")
```

### Add Observer
```swift
class MySyncObserver: SyncObserver {
    func syncDidStart() { print("Syncing...") }
    func syncDidProgress(current: Int, total: Int) { }
    func syncDidComplete(result: SyncResult) { print("Done!") }
    func syncDidFail(error: SyncError) { print("Failed: \(error)") }
}

await syncManager.addObserver(MySyncObserver())
```

---

## Error Handling

```swift
switch result {
case .success(let syncResult):
    print("Synced \(syncResult.pushedCount + syncResult.fetchedCount) records")

case .failure(let error):
    switch error {
    case .iCloudAccountUnavailable:
        // Show "Sign in to iCloud" message
    case .networkUnavailable:
        // Queue for later, show offline indicator
    case .quotaExceeded:
        // Show "Storage full" message
    default:
        // Generic error handling
    }
}
```

---

## Configuration

### Custom Intervals
```swift
let config = SyncConfiguration(
    activeSyncInterval: 180,      // 3 min
    backgroundSyncInterval: 1800, // 30 min
    syncOnForeground: true,
    syncOnBackground: true
)
let syncManager = BackgroundSyncManager(syncEngine: syncEngine, config: config)
```

### Custom Conflict Strategy
```swift
let options = SyncOptions(
    conflictStrategy: .merge  // or .lastWriteWins, .preferLocal, .preferRemote
)
```

---

## CloudKit Record Types

| Record Type | Purpose | Key Fields |
|------------|---------|------------|
| **UsageSnapshot** | Usage data | providerID, primaryUsed, primaryLimit, costUSD |
| **UserPreferences** | Settings | refreshInterval, enabledProviders, theme |
| **AlertConfiguration** | Alerts | warningThreshold, criticalThreshold, enabled |

---

## Conflict Resolution Strategies

| Strategy | Behavior |
|----------|----------|
| **lastWriteWins** | Most recent modification wins (default) |
| **preferLocal** | Always keep local version |
| **preferRemote** | Always keep remote version |
| **highestVersion** | Highest version number wins |
| **merge** | Custom merge logic (smart defaults included) |

---

## Offline Support

```swift
// Queue for sync when online (automatic)
await syncEngine.enqueue(record, priority: .high)

// Check pending operations
let pending = await syncEngine.pendingOperationCount
```

---

## Security

- ✅ Private CloudKit database (user-specific)
- ✅ AES-GCM encryption for sensitive data
- ✅ Keychain-based key storage
- ✅ User authentication required

---

## Troubleshooting

### "iCloud account unavailable"
→ Settings > Apple ID > iCloud > Enable iCloud Drive

### "Network unavailable"
→ Changes queued automatically, will sync when online

### Records not syncing
1. Check CloudKit Console for errors
2. Verify entitlements include CloudKit
3. Ensure container identifier is correct

---

## Performance Tips

- Default batch size: 100 records (adjust with `SyncOptions.batchSize`)
- Use priority queue for critical data: `.high` or `.critical`
- Monitor statistics to track sync performance
- Sync on foreground disabled if last sync < 5 min ago

---

## Required Setup (One-Time)

1. **Entitlements**: Add CloudKit to `Runic.entitlements`
2. **Container**: Create iCloud container in Developer Portal
3. **Schema**: Create 3 record types in CloudKit Console
4. **Code**: Initialize sync engine at app launch

See `CLOUDKIT_SYNC_GUIDE.md` for detailed setup instructions.

---

## Files

- `SyncProtocol.swift` - Protocols and types
- `SyncRecord.swift` - Record definitions
- `iCloudSyncEngine.swift` - CloudKit implementation
- `SyncConflictResolver.swift` - Conflict resolution
- `BackgroundSyncManager.swift` - Automatic sync
- `SyncUsageExample.swift` - Integration examples

---

## Build Status

✅ **Compiles successfully** with Swift 6 strict concurrency
- Zero errors
- Only non-critical warnings (Codable, Timer isolation)
- Production ready

---

**Version**: 1.0
**Last Updated**: 2026-01-31
**Status**: Ready for integration
