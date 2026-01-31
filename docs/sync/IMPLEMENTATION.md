# Runic Sync Implementation Checklist

## Overview

This document provides step-by-step instructions for integrating the Runic iCloud sync infrastructure into your application.

## Prerequisites

- [ ] Xcode 15.0 or later
- [ ] macOS 14.0+ or iOS 17.0+ deployment target
- [ ] Active Apple Developer Program membership
- [ ] iCloud entitlements configured

## Setup Steps

### 1. Enable CloudKit Capability

1. Open your Xcode project
2. Select your app target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability" button
5. Add "iCloud" capability
6. Enable "CloudKit" checkbox
7. Select or create a CloudKit container

**Container ID Format**: `iCloud.com.yourcompany.runic`

### 2. Configure CloudKit Schema

Log into [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)

#### Create Record Types

**UsageSnapshot**
```
Fields:
- version (Int64)
- modifiedAt (Date/Time)
- lastModifiedDeviceID (String, optional)
- providerID (String)
- primaryUsed (Int64)
- primaryLimit (Int64, optional)
- secondaryUsed (Int64, optional)
- secondaryLimit (Int64, optional)
- costUSD (Double, optional)
- accountEmail (String, optional) [encrypted]
- updatedAt (Date/Time)
- deviceName (String)
- platform (String)
```

**UserPreferences**
```
Fields:
- version (Int64)
- modifiedAt (Date/Time)
- lastModifiedDeviceID (String, optional)
- refreshInterval (Double)
- enabledProviders (List<String>)
- notificationsEnabled (Int64) [0 or 1]
- autoRefreshEnabled (Int64) [0 or 1]
- theme (String)
- displayFormat (String)
```

**AlertConfiguration**
```
Fields:
- version (Int64)
- modifiedAt (Date/Time)
- lastModifiedDeviceID (String, optional)
- providerID (String)
- warningThreshold (Double)
- criticalThreshold (Double)
- notificationChannels (List<String>)
- enabled (Int64) [0 or 1]
```

#### Set Permissions

For all record types:
- Database: **Private**
- Read/Write: **Owner**

### 3. Update Entitlements File

Ensure your `*.entitlements` file contains:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.yourcompany.runic</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
</dict>
</plist>
```

### 4. Initialize Sync in Your App

#### AppDelegate (UIKit) or App (SwiftUI)

```swift
import RunicCore

class AppDelegate: NSObject, UIApplicationDelegate {
    var syncManager: BackgroundSyncManager?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Task {
            await setupSync()
        }
        return true
    }

    private func setupSync() async {
        let syncEngine = iCloudSyncEngine(
            containerIdentifier: "iCloud.com.yourcompany.runic"
        )

        let config = SyncConfiguration(
            activeSyncInterval: 300,
            backgroundSyncInterval: 3600,
            syncOnForeground: true,
            syncOnBackground: true
        )

        syncManager = BackgroundSyncManager(
            syncEngine: syncEngine,
            config: config
        )

        await syncManager?.start()
    }
}
```

#### SwiftUI App

```swift
import SwiftUI
import RunicCore

@main
struct RunicApp: App {
    @StateObject private var syncCoordinator = SyncCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncCoordinator)
        }
    }
}

@MainActor
class SyncCoordinator: ObservableObject {
    private var syncManager: BackgroundSyncManager?

    init() {
        Task {
            await setupSync()
        }
    }

    private func setupSync() async {
        let syncEngine = iCloudSyncEngine()
        let config = SyncConfiguration.default

        syncManager = BackgroundSyncManager(
            syncEngine: syncEngine,
            config: config
        )

        await syncManager?.start()
    }

    func manualSync() async {
        await syncManager?.syncNow()
    }
}
```

### 5. Integrate with Usage Tracking

#### Sync Usage Snapshots

```swift
// After fetching usage data
func syncUsageData(usage: UsageSnapshot, provider: UsageProvider) async {
    let syncRecord = UsageSnapshotSyncRecord(
        providerID: provider.rawValue,
        primaryUsed: usage.primary.used,
        primaryLimit: usage.primary.limit,
        secondaryUsed: usage.secondary?.used,
        secondaryLimit: usage.secondary?.limit,
        costUSD: usage.providerCost?.totalCostUSD,
        accountEmail: usage.identity?.accountEmail,
        updatedAt: usage.updatedAt,
        deviceName: getDeviceName(),
        platform: getPlatform()
    )

    await syncEngine.enqueue(syncRecord, priority: .normal)
}
```

#### Sync Preferences

```swift
func syncPreferences(settings: AppSettings) async {
    let prefsRecord = UserPreferencesSyncRecord(
        refreshInterval: settings.refreshInterval,
        enabledProviders: settings.enabledProviders,
        notificationsEnabled: settings.notificationsEnabled,
        autoRefreshEnabled: settings.autoRefreshEnabled,
        theme: settings.theme,
        displayFormat: settings.displayFormat
    )

    let result = await syncEngine.push(records: [prefsRecord])
    // Handle result
}
```

### 6. Add Sync Status UI

```swift
import SwiftUI

struct SyncStatusView: View {
    @State private var stats: SyncStatistics?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let stats = stats {
                Text("Last Sync: \(formattedDate(stats.lastSyncDate))")
                Text("Success Rate: \(String(format: "%.1f%%", stats.successRate))")
                Text("Total Syncs: \(stats.totalSyncs)")
            }

            Button("Sync Now") {
                Task {
                    await performManualSync()
                }
            }
        }
        .task {
            await loadStats()
        }
    }

    private func performManualSync() async {
        // Trigger manual sync
    }

    private func loadStats() async {
        // Load sync statistics
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
```

## Testing

### Development Testing

1. Use CloudKit Development environment
2. Test with multiple devices/simulators
3. Verify conflict resolution
4. Test offline scenarios

### Pre-Production Checklist

- [ ] Tested on physical devices (not just simulator)
- [ ] Tested with poor network conditions
- [ ] Tested conflict resolution with concurrent edits
- [ ] Verified encryption of sensitive data
- [ ] Monitored CloudKit quota usage
- [ ] Tested background sync behavior
- [ ] Verified sync recovery after network interruption

### Production Deployment

1. Deploy CloudKit schema to Production
2. Test with TestFlight builds
3. Monitor CloudKit Dashboard for errors
4. Set up CloudKit usage alerts

## Monitoring

### CloudKit Dashboard Metrics

Monitor:
- Request rate
- Error rate
- Storage usage
- Transfer bandwidth

### App Analytics

Track:
- Sync success rate
- Average sync duration
- Conflict frequency
- User engagement with sync features

## Troubleshooting

### Common Issues

**Issue**: "iCloud account unavailable"
- **Solution**: User needs to sign in to iCloud in Settings

**Issue**: Sync taking too long
- **Solution**: Reduce batch size or sync frequency

**Issue**: Conflicts occurring frequently
- **Solution**: Review conflict resolution strategy

**Issue**: Storage quota exceeded
- **Solution**: Implement data pruning or notify user

### Debug Mode

Enable verbose logging:

```swift
let options = SyncOptions(
    conflictStrategy: .lastWriteWins
    // Add logging here if needed
)
```

## Performance Optimization

### Best Practices

1. **Batch Operations**: Group multiple records into single sync
2. **Incremental Sync**: Use change tokens for efficient syncs
3. **Selective Sync**: Only sync changed records
4. **Compression**: Consider compressing large payloads
5. **Caching**: Cache frequently accessed data locally

### Monitoring Performance

```swift
let stats = await syncManager.statistics
print("Average sync duration: \(stats.averageDuration)s")

if stats.averageDuration > 5.0 {
    print("⚠️ Sync performance degraded")
    // Investigate or adjust configuration
}
```

## Security Considerations

1. **Encryption**: Sensitive fields are automatically encrypted
2. **Keychain**: Encryption keys stored in iOS/macOS Keychain
3. **Private Database**: All data in user's private CloudKit database
4. **No Shared Data**: Each user's data is isolated

## Support

For issues or questions:
- Check CloudKit Dashboard for errors
- Review sync statistics
- Enable debug logging
- Contact support with device logs

## Version History

- **v1.0.0**: Initial release with CloudKit sync
- Support for macOS and iOS
- Three record types (Usage, Preferences, Alerts)
- Conflict resolution with multiple strategies
- Background sync with configurable intervals
