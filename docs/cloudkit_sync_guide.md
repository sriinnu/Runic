# CloudKit Sync Integration Guide

## Overview

Runic now includes a complete iCloud CloudKit synchronization infrastructure that enables cross-device syncing of usage data, user preferences, and alert configurations. This guide explains how to enable and use the sync functionality.

## Architecture

The sync infrastructure consists of 6 main components:

### 1. **SyncProtocol.swift** - Core Protocol Definitions
Defines the fundamental protocols and types for synchronization:
- `SyncEngine` - Main protocol for sync operations (sync, push, fetch, delete)
- `SyncableRecord` - Protocol for objects that can be synchronized
- `SyncConflictResolverProtocol` - Protocol for conflict resolution
- `SyncObserver` - Protocol for observing sync events
- Supporting types: `SyncOptions`, `SyncResult`, `ConflictResolutionStrategy`, `SyncError`

### 2. **SyncRecord.swift** - CloudKit Record Types
Defines three syncable record types with CloudKit conversion:
- `UsageSnapshotSyncRecord` - Syncs usage data across devices
- `UserPreferencesSyncRecord` - Syncs user settings and preferences
- `AlertConfigurationSyncRecord` - Syncs alert thresholds and notification settings
- Includes encryption helpers for sensitive data (email addresses)

### 3. **iCloudSyncEngine.swift** - CloudKit Implementation
Actor-based CloudKit sync engine with:
- Bidirectional sync (push and fetch)
- Offline queue for pending operations
- Retry logic with exponential backoff
- Device identification for conflict resolution
- Support for incremental sync with change tokens

### 4. **SyncConflictResolver.swift** - Conflict Resolution
Implements multiple conflict resolution strategies:
- **Last-write-wins** - Most recently modified record wins (default)
- **Prefer local** - Always keep local version
- **Prefer remote** - Always keep remote version
- **Highest version** - Keep record with highest version number
- **Merge** - Custom merge logic per record type
- Tracks conflict statistics for diagnostics

### 5. **BackgroundSyncManager.swift** - Automatic Sync
Manages background synchronization with:
- Configurable sync intervals (active: 5 min, background: 1 hour)
- Lifecycle-aware sync (app launch, foreground, background)
- Observer pattern for sync status notifications
- Sync history and statistics tracking
- iOS background task support

### 6. **SyncUsageExample.swift** - Integration Examples
Contains comprehensive examples of:
- Basic setup and configuration
- Syncing different record types
- Manual vs automatic sync
- Custom conflict resolution
- Observer pattern usage
- Error handling
- Statistics and monitoring

## CloudKit Record Types

The sync engine uses three CloudKit record types that must be configured in your iCloud container:

### 1. UsageSnapshot
```
Record Type: UsageSnapshot
Fields:
  - version: Int64
  - modifiedAt: Date/Time
  - lastModifiedDeviceID: String (optional)
  - providerID: String
  - primaryUsed: Int64
  - primaryLimit: Int64 (optional)
  - secondaryUsed: Int64 (optional)
  - secondaryLimit: Int64 (optional)
  - costUSD: Double (optional)
  - accountEmail: String (encrypted, optional)
  - updatedAt: Date/Time
  - deviceName: String
  - platform: String
```

### 2. UserPreferences
```
Record Type: UserPreferences
Fields:
  - version: Int64
  - modifiedAt: Date/Time
  - lastModifiedDeviceID: String (optional)
  - refreshInterval: Double
  - enabledProviders: List<String>
  - notificationsEnabled: Int64 (0 or 1)
  - autoRefreshEnabled: Int64 (0 or 1)
  - theme: String
  - displayFormat: String
```

### 3. AlertConfiguration
```
Record Type: AlertConfiguration
Fields:
  - version: Int64
  - modifiedAt: Date/Time
  - lastModifiedDeviceID: String (optional)
  - providerID: String
  - warningThreshold: Double
  - criticalThreshold: Double
  - notificationChannels: List<String>
  - enabled: Int64 (0 or 1)
```

## Enabling CloudKit

### 1. Add CloudKit Capability

You need to add CloudKit capability to your app. This requires an entitlements file:

**Create `Runic.entitlements`:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.yourcompany.runic</string>
    </array>
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)com.yourcompany.runic</string>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

### 2. Configure CloudKit Container

1. Sign in to [Apple Developer](https://developer.apple.com)
2. Go to Certificates, Identifiers & Profiles
3. Select your App ID
4. Enable iCloud capability
5. Create or select a CloudKit container (e.g., `iCloud.com.yourcompany.runic`)

### 3. Create CloudKit Schema

In the CloudKit Dashboard:

1. Go to [CloudKit Console](https://icloud.developer.apple.com)
2. Select your container
3. Create the three record types listed above
4. Set appropriate indexes and security settings:
   - **Security**: Set all record types to "Readable and writable by the creator"
   - **Indexes**: Add indexes on `modifiedAt` for efficient querying

### 4. Update Package.swift (Already Done)

The Sync directory exclusion has been removed from Package.swift, enabling the sync infrastructure.

## Integration Steps

### 1. Basic Setup

```swift
import RunicCore

// Initialize sync engine
let syncEngine = iCloudSyncEngine(
    containerIdentifier: "iCloud.com.yourcompany.runic"
)

// Create sync manager with default configuration
let syncManager = BackgroundSyncManager(
    syncEngine: syncEngine,
    config: .default
)

// Start automatic background sync
await syncManager.start()
```

### 2. Custom Configuration

```swift
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

let syncManager = BackgroundSyncManager(
    syncEngine: syncEngine,
    config: config
)
```

### 3. Sync Usage Data

```swift
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

// Or push immediately
let result = await syncEngine.push(records: [usageRecord])
```

### 4. Add Sync Observer

```swift
class MySyncObserver: SyncObserver {
    func syncDidStart() {
        print("Sync started")
    }

    func syncDidProgress(current: Int, total: Int) {
        let percentage = (Double(current) / Double(total)) * 100
        print("Progress: \(Int(percentage))%")
    }

    func syncDidComplete(result: SyncResult) {
        print("Synced \(result.pushedCount + result.fetchedCount) records")
    }

    func syncDidFail(error: SyncError) {
        print("Sync failed: \(error.localizedDescription)")
    }
}

let observer = MySyncObserver()
await syncManager.addObserver(observer)
```

### 5. Manual Sync

```swift
// Perform manual sync with custom options
let options = SyncOptions(
    forceFullSync: true,
    conflictStrategy: .lastWriteWins
)

let result = await syncManager.syncNow(options: options)

switch result {
case .success(let syncResult):
    print("Pushed: \(syncResult.pushedCount)")
    print("Fetched: \(syncResult.fetchedCount)")
    print("Conflicts: \(syncResult.conflictsResolved)")

case .failure(let error):
    print("Sync failed: \(error)")
}
```

### 6. Monitor Sync Statistics

```swift
let stats = await syncManager.statistics

print("Total syncs: \(stats.totalSyncs)")
print("Success rate: \(stats.successRate)%")
print("Average duration: \(stats.averageDuration)s")
print("Last sync: \(stats.lastSyncDate?.description ?? "Never")")
```

## Conflict Resolution

### Default Strategies

1. **Last-write-wins** (default) - Most recently modified record wins
2. **Prefer local** - Always keep local version
3. **Prefer remote** - Always keep remote version
4. **Highest version** - Keep record with highest version number
5. **Merge** - Custom merge logic

### Custom Merge Handlers

The sync engine includes smart merge handlers for each record type:

**UsageSnapshot**: Prefers record with most recent usage data
**UserPreferences**: Merges enabled providers (union of both sets)
**AlertConfiguration**: Uses most conservative thresholds, merges notification channels

You can register custom merge handlers:

```swift
let resolver = SyncConflictResolver()
await resolver.registerDefaultMergeHandlers()

// Custom merge handler for usage snapshots
await resolver.registerMergeHandler(for: CloudKitRecordType.usageSnapshot) { local, remote in
    guard let localUsage = local as? UsageSnapshotSyncRecord,
          let remoteUsage = remote as? UsageSnapshotSyncRecord else {
        return local
    }

    // Custom logic: prefer record with higher usage
    return localUsage.primaryUsed > remoteUsage.primaryUsed ? local : remote
}
```

## Security

### Encryption

Sensitive data (email addresses) is automatically encrypted using AES-GCM before syncing to CloudKit. The encryption key is stored securely in the Keychain.

### Privacy

- All data is stored in the user's private CloudKit database
- Only the user can access their own data
- CloudKit records use user authentication

## Error Handling

The sync engine handles common errors gracefully:

```swift
switch syncError {
case .iCloudAccountUnavailable:
    // User not signed in to iCloud

case .networkUnavailable:
    // Network not available - changes queued for later

case .quotaExceeded:
    // iCloud storage full

case .timeout:
    // Sync operation timed out

case .conflictResolutionFailed(let details):
    // Could not resolve conflict

case .cloudKitError(let ckError):
    // CloudKit-specific error

default:
    // Other errors
}
```

## Testing

### Prerequisites

1. Sign in to iCloud on your test device/simulator
2. Enable iCloud Drive in System Settings
3. Ensure network connectivity

### Manual Testing

1. Install app on Device A
2. Create some usage data
3. Wait for sync or trigger manual sync
4. Install app on Device B (same iCloud account)
5. Verify data appears after sync

### Verifying CloudKit Data

1. Open CloudKit Console
2. Select your container
3. Go to Data > Records
4. View synced records

## Performance Considerations

### Sync Intervals

- **Active sync**: Every 5 minutes when app is active
- **Background sync**: Every hour when app is in background
- **Foreground sync**: When app comes to foreground (if last sync > 5 min ago)

### Batch Sizes

Default batch size is 100 records. Adjust based on your data volume:

```swift
SyncOptions(batchSize: 50)  // For smaller syncs
```

### Offline Queue

Records are automatically queued when offline and synced when connection is restored.

## Troubleshooting

### Common Issues

1. **"iCloud account unavailable"**
   - Check Settings > Apple ID > iCloud
   - Enable iCloud Drive

2. **"Network unavailable"**
   - Check internet connection
   - Changes will sync when online

3. **"Quota exceeded"**
   - User needs more iCloud storage
   - Upgrade iCloud plan

4. **Records not syncing**
   - Check CloudKit Console for errors
   - Verify entitlements are correct
   - Ensure container identifier matches

### Debug Logging

Enable detailed sync logging in DEBUG builds:

```swift
#if DEBUG
print("Sync engine: \(syncEngine)")
print("Pending operations: \(await syncEngine.pendingOperationCount)")
#endif
```

## Migration Notes

If you have existing local data, you'll need to:

1. Create sync records from local data
2. Push to CloudKit on first launch
3. Set appropriate version numbers
4. Handle conflicts carefully during initial sync

## Best Practices

1. **Start sync early** - Initialize sync engine at app launch
2. **Monitor conflicts** - Check conflict statistics regularly
3. **Handle errors gracefully** - Queue operations when offline
4. **Use appropriate priorities** - Critical data should use `.high` priority
5. **Test thoroughly** - Test on multiple devices with same iCloud account
6. **Monitor quota** - Be mindful of CloudKit storage limits

## Compilation Status

✅ **Build Status**: Successfully compiles
- All sync files integrated into RunicCore module
- CloudKit imports working correctly
- Actor isolation properly implemented
- Strict concurrency enabled

### Warnings (Non-critical)

- Codable warnings on `recordType` fields (by design - these are constants)
- Timer isolation warnings (handled with @MainActor)

## Next Steps

1. Create entitlements file for your app
2. Configure CloudKit container in Developer Portal
3. Create CloudKit schema in CloudKit Console
4. Integrate sync manager into your app
5. Test on multiple devices
6. Monitor sync statistics and errors

## Support

For issues or questions about the sync infrastructure:
1. Check CloudKit Console for server-side errors
2. Review sync statistics for client-side issues
3. Enable debug logging for detailed diagnostics
4. Consult SyncUsageExample.swift for integration patterns

---

**Version**: 1.0
**Last Updated**: 2026-01-31
**Status**: Production Ready
