# Runic iCloud Sync Infrastructure

Production-ready CloudKit synchronization system for macOS/iOS usage tracking.

## Overview

The Runic Sync infrastructure provides seamless cross-device synchronization of usage data, user preferences, and alert configurations using Apple's CloudKit framework.

## Architecture

### Core Components

1. **SyncProtocol.swift** - Protocol definitions and interfaces
2. **iCloudSyncEngine.swift** - CloudKit integration implementation
3. **SyncConflictResolver.swift** - Conflict resolution logic
4. **SyncRecord.swift** - Data models for CloudKit records
5. **BackgroundSyncManager.swift** - Background sync coordination

## Features

- ✅ **Privacy-First**: AES-GCM encryption for sensitive data
- ✅ **Conflict Resolution**: Last-write-wins with version tracking
- ✅ **Offline Support**: Queue-based pending sync operations
- ✅ **Background Sync**: Automatic sync at configurable intervals
- ✅ **Error Recovery**: Retry logic with exponential backoff
- ✅ **Multi-Platform**: Supports macOS and iOS

## CloudKit Schema

### Record Types

#### UsageSnapshot
- `recordID`: String (unique identifier)
- `version`: Int (for conflict resolution)
- `modifiedAt`: Date (last modification timestamp)
- `providerID`: String (AI provider identifier)
- `primaryUsed`: Int (tokens/requests used)
- `primaryLimit`: Int? (limit if applicable)
- `secondaryUsed`: Int? (secondary metric)
- `costUSD`: Double? (estimated cost)
- `accountEmail`: String (encrypted)
- `deviceName`: String
- `platform`: String

#### UserPreferences
- `recordID`: String (singleton: "user-preferences")
- `version`: Int
- `refreshInterval`: TimeInterval
- `enabledProviders`: [String]
- `notificationsEnabled`: Bool
- `autoRefreshEnabled`: Bool
- `theme`: String
- `displayFormat`: String

#### AlertConfiguration
- `recordID`: String
- `providerID`: String
- `warningThreshold`: Double (0.0-1.0)
- `criticalThreshold`: Double (0.0-1.0)
- `notificationChannels`: [String]
- `enabled`: Bool

## Usage

### Initialize Sync Engine

```swift
import RunicCore

// Initialize the sync engine
let syncEngine = iCloudSyncEngine()

// Create background sync manager
let syncManager = BackgroundSyncManager(
    syncEngine: syncEngine,
    config: .default
)

// Start automatic sync
await syncManager.start()
```

### Manual Sync

```swift
// Perform manual sync
let result = await syncManager.syncNow()

switch result {
case .success(let syncResult):
    print("Synced: \(syncResult.fetchedCount) fetched, \(syncResult.pushedCount) pushed")
case .failure(let error):
    print("Sync failed: \(error.localizedDescription)")
}
```

### Sync Usage Data

```swift
let usageRecord = UsageSnapshotSyncRecord(
    providerID: "claude",
    primaryUsed: 50000,
    primaryLimit: 100000,
    costUSD: 2.50,
    deviceName: "MacBook Pro",
    platform: "macOS"
)

// Queue for sync
await syncEngine.enqueue(usageRecord, priority: .high)
```

### Configure Sync Intervals

```swift
let config = SyncConfiguration(
    activeSyncInterval: 300,      // 5 minutes when active
    backgroundSyncInterval: 3600, // 1 hour in background
    syncOnForeground: true,
    syncOnBackground: true
)

let syncManager = BackgroundSyncManager(
    syncEngine: syncEngine,
    config: config
)
```

### Observe Sync Events

```swift
class MyObserver: SyncObserver {
    func syncDidStart() {
        print("Sync started")
    }

    func syncDidProgress(current: Int, total: Int) {
        print("Progress: \(current)/\(total)")
    }

    func syncDidComplete(result: SyncResult) {
        print("Sync completed: \(result.duration)s")
    }

    func syncDidFail(error: SyncError) {
        print("Sync failed: \(error)")
    }
}

let observer = MyObserver()
await syncManager.addObserver(observer)
```

## Conflict Resolution

The system supports multiple conflict resolution strategies:

### Last-Write-Wins (Default)
```swift
let options = SyncOptions(conflictStrategy: .lastWriteWins)
```

### Prefer Local
```swift
let options = SyncOptions(conflictStrategy: .preferLocal)
```

### Custom Merge
```swift
let resolver = SyncConflictResolver()
await resolver.registerMergeHandler(for: "UsageSnapshot") { local, remote in
    // Custom merge logic
    return local // or merged result
}
```

## Security

### Encryption
Sensitive fields (email addresses, tokens) are encrypted using AES-GCM before syncing:

```swift
// Automatically encrypted
let record = UsageSnapshotSyncRecord(
    accountEmail: "user@example.com", // Encrypted in CloudKit
    // ...
)
```

### Keychain Storage
Encryption keys are stored securely in the macOS/iOS Keychain.

## Error Handling

### Common Errors

- `iCloudAccountUnavailable`: User not signed into iCloud
- `networkUnavailable`: No network connection (queued for retry)
- `quotaExceeded`: iCloud storage quota exceeded
- `conflictResolutionFailed`: Unable to resolve conflict

### Retry Logic

Failed syncs are automatically retried with exponential backoff:
- Initial retry: 2 seconds
- Second retry: 4 seconds
- Third retry: 8 seconds

## Performance

### Sync Statistics

```swift
let stats = await syncManager.statistics

print(stats.summary)
// Output:
// Sync Statistics:
//   Total syncs: 42
//   Successful: 40 (95.2%)
//   Failed: 2
//   Average duration: 1.23s
//   Last sync: 2 minutes ago
```

### Optimization Tips

1. Use appropriate sync intervals (default: 5min active, 1hr background)
2. Batch updates before syncing
3. Enable background sync for seamless experience
4. Monitor sync statistics for issues

## CloudKit Setup

### 1. Enable CloudKit in Xcode

1. Open project settings
2. Select target → Signing & Capabilities
3. Add "iCloud" capability
4. Enable "CloudKit"

### 2. Configure Container

1. Create CloudKit container or use default
2. Add record types via CloudKit Dashboard
3. Set permissions to "Private" database

### 3. Entitlements

Ensure `entitlements` file contains:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.yourcompany.runic</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

## Testing

### Unit Tests

```swift
import XCTest
@testable import RunicCore

class SyncTests: XCTestCase {
    func testConflictResolution() async {
        let resolver = SyncConflictResolver()

        let local = UsageSnapshotSyncRecord(/* ... */)
        let remote = UsageSnapshotSyncRecord(/* ... */)

        let resolved = resolver.resolve(
            local: local,
            remote: remote,
            strategy: .lastWriteWins
        )

        XCTAssertNotNil(resolved)
    }
}
```

### Integration Tests

Test with CloudKit Development environment before production.

## Troubleshooting

### Sync Not Working

1. Check iCloud account status
2. Verify network connectivity
3. Check CloudKit Dashboard for errors
4. Review sync statistics

### Data Not Appearing

1. Ensure sync completed successfully
2. Check conflict resolution logs
3. Verify record types match schema

### Performance Issues

1. Reduce sync frequency
2. Batch operations
3. Check network quality
4. Monitor CloudKit quota

## License

Copyright © 2026 Runic. All rights reserved.
