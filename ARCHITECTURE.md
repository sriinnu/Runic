# Runic Multi-Platform Architecture

**Motto**: *Persistence. Intuition. Consciousness.*

---

## Vision

Runic tracks AI provider usage across all your devices and platforms, providing intelligent insights and proactive alerts to prevent service interruptions. Whether you're coding on macOS, working on Windows, or checking status on your iPhone, Runic keeps you aware and in control.

---

## Platform Support

| Platform | Technology | Status | Shared Code |
|----------|-----------|--------|-------------|
| **macOS** | Swift/SwiftUI + AppKit | ✅ Production | RunicCore |
| **CLI** | Swift (multiplatform) | ✅ Production | RunicCore |
| **iOS** | Swift/SwiftUI (native) | 🚧 In Progress | RunicCore |
| **Windows** | React Native for Windows | 📋 Planned | Via API |
| **Android** | React Native | 📋 Planned | Via API |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         RUNIC ECOSYSTEM                          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   macOS App      │  │    iOS App       │  │   CLI Tool       │
│  (SwiftUI +      │  │  (SwiftUI)       │  │  (Swift)         │
│   AppKit)        │  │                  │  │                  │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                      │
         └─────────────────────┼──────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │    RunicCore        │
                    │  (Swift Package)    │
                    │  • Providers        │
                    │  • UsageFetcher     │
                    │  • Models           │
                    │  • OAuth Logic      │
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
┌────────▼─────────┐  ┌────────▼─────────┐  ┌───────▼────────┐
│  MCP Servers     │  │  Sync Service    │  │  AI Providers  │
│  • Persistence   │  │  (iCloud/API)    │  │  • Claude      │
│  • Intuition     │  │                  │  │  • OpenAI      │
│  • Consciousness │  │                  │  │  • Gemini      │
└──────────────────┘  └──────────────────┘  │  • MiniMax     │
                                             │  • ... (11+)   │
                                             └────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│              WINDOWS & ANDROID (React Native)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐              ┌────────────────┐            │
│  │ Windows App    │              │  Android App   │            │
│  │ (React Native  │              │ (React Native) │            │
│  │  for Windows)  │              │                │            │
│  └───────┬────────┘              └───────┬────────┘            │
│          │                               │                      │
│          └───────────────┬───────────────┘                      │
│                          │                                      │
│                  ┌───────▼────────┐                             │
│                  │  Runic REST API │                            │
│                  │  (Optional)     │                            │
│                  │  • Sync State   │                            │
│                  │  • Push Alerts  │                            │
│                  └─────────────────┘                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. RunicCore (Swift Package)

**Shared business logic across macOS, iOS, and CLI:**

```
RunicCore/
├── Models/
│   ├── EnhancedUsageModels.swift    (NEW)
│   │   ├── AccountType
│   │   ├── UsageResetInfo
│   │   ├── ModelUsageInfo
│   │   ├── ProjectInfo
│   │   └── EnhancedUsageSnapshot
│   ├── UsageSnapshot.swift
│   └── ProviderModels.swift
│
├── Providers/
│   ├── Claude/
│   ├── Codex/
│   ├── MiniMax/
│   └── ... (11 providers)
│
├── UsageLedger/
│   ├── ClaudeUsageLogSource.swift
│   ├── CodexUsageLogSource.swift
│   └── EnhancedUsageLogger.swift   (NEW)
│
├── Sync/                            (NEW)
│   ├── SyncEngine.swift
│   ├── iCloudSync.swift
│   └── CrossPlatformSync.swift
│
└── Analytics/                       (NEW)
    ├── UsagePredictor.swift
    ├── AlertEngine.swift
    └── ModelTracker.swift
```

**Platform Compatibility:**
- macOS 14+, iOS 17+
- Linux (for CLI only)
- Thread-safe with Swift 6 concurrency

---

### 2. Platform-Specific Apps

#### macOS App (Existing)
```
Sources/Runic/
├── Controllers/
│   └── StatusItemController.swift   (Menubar)
├── Views/
│   ├── Menu/                        (Dropdown UI)
│   └── Preferences/                 (Settings)
└── Core/
    ├── Stores/
    └── Rendering/
```

**New Features:**
- Display model usage per provider
- Show project association
- Reset countdown timers
- Account type indicators

#### iOS App (New)
```
RuniciOS/
├── App/
│   └── RuniciOSApp.swift
├── Views/
│   ├── ProviderListView.swift       (Main screen)
│   ├── ProviderDetailView.swift     (Per-provider details)
│   ├── ModelUsageView.swift         (Model breakdown)
│   ├── ProjectTrackingView.swift    (Project stats)
│   └── SettingsView.swift
├── Widgets/
│   └── RunicWidget.swift            (Home screen widget)
└── Core/
    ├── iOSUsageStore.swift
    └── NotificationManager.swift
```

**Features:**
- Native SwiftUI interface
- Share Extension (track from other apps)
- WidgetKit widgets (multiple sizes)
- Push notifications for alerts
- iCloud sync with macOS app
- Face ID/Touch ID for settings

#### Windows App (React Native)
```
runic-windows/
├── src/
│   ├── App.tsx
│   ├── components/
│   │   ├── ProviderCard.tsx
│   │   ├── UsageChart.tsx
│   │   └── AlertBanner.tsx
│   ├── screens/
│   │   ├── HomeScreen.tsx
│   │   ├── ProviderDetailScreen.tsx
│   │   └── SettingsScreen.tsx
│   ├── services/
│   │   ├── ApiClient.ts
│   │   ├── SyncService.ts
│   │   └── NotificationService.ts
│   └── stores/
│       └── UsageStore.ts (MobX/Zustand)
│
└── windows/                         (RNW specific)
    ├── RunicWindows.sln
    └── MainPage.xaml
```

**Features:**
- System tray icon
- Native Windows notifications
- Dark/light theme matching
- Auto-launch on startup

#### Android App (React Native)
```
runic-android/
├── src/                             (Shared with Windows)
│   └── [Same as Windows]
│
└── android/
    ├── app/
    │   ├── src/main/
    │   └── build.gradle
    └── settings.gradle
```

**Features:**
- Home screen widget
- Material You theming
- Background sync
- Notification channels

---

## Enhanced Data Tracking

### Usage-Based vs Subscription

```swift
// Account type detection
enum AccountType {
    case usageBased        // Pay-per-token (OpenAI API)
    case subscription      // Monthly unlimited (Claude Pro)
    case freeTier          // Limited free usage
    case enterprise        // Custom limits
}

// Example:
EnhancedUsageSnapshot(
    provider: .claude,
    accountType: .subscription,
    primary: RateWindow(usedPercent: 85, windowMinutes: 300),
    primaryReset: UsageResetInfo(
        resetType: .sessionBased,
        resetAt: Date().addingTimeInterval(3600), // 1 hour
        windowDuration: 5 * 3600 // 5 hours
    )
)
```

### Reset Tracking

```swift
struct UsageResetInfo {
    let resetType: ResetType  // hourly, daily, weekly, monthly, session
    let resetAt: Date?
    let windowDuration: TimeInterval?

    var timeUntilReset: TimeInterval?
    var resetDescription: String  // "Resets in 2h 34m"
}
```

**UI Display:**
- macOS: Show countdown in menubar subtitle
- iOS: Widget with countdown timer
- Windows/Android: Progress ring with time remaining

### Model/Agent Tracking

```swift
struct ModelUsageInfo {
    let modelName: String        // "claude-3-5-sonnet-20241022"
    let modelFamily: ModelFamily // .claude3, .gpt4, etc.
    let tier: ModelTier          // .opus, .sonnet, .haiku
}

// Track recent models used
snapshot.recentModels = [
    ModelUsageInfo(modelName: "claude-opus-4", tier: .opus),
    ModelUsageInfo(modelName: "claude-sonnet-3.5", tier: .sonnet)
]
```

**Analytics:**
- Most-used model per provider
- Cost per model
- Model performance trends

### Project Association

```swift
struct ProjectInfo {
    let projectID: String
    let projectName: String?
    let workspacePath: String?
    let repository: String?      // Git remote
    let tags: [String]
}

// Example:
snapshot.activeProject = ProjectInfo(
    projectID: "runic-ios",
    projectName: "Runic iOS App",
    workspacePath: "/Users/.../RuniciOS",
    repository: "github.com/user/runic",
    tags: ["ios", "swift"]
)
```

**Detection Methods:**
- macOS/CLI: Infer from working directory
- iOS: Manual project selection
- Windows/Android: API sync from primary device

---

## Cross-Platform Sync

### iCloud Sync (macOS ↔ iOS)

```swift
import CloudKit

class iCloudSyncEngine {
    func syncUsageSnapshot(_ snapshot: EnhancedUsageSnapshot)
    func fetchLatestSnapshots() async -> [EnhancedUsageSnapshot]
    func syncAlerts(_ alerts: [UsageAlert])
}
```

**Data Stored:**
- Usage snapshots (last 7 days)
- Alert history
- User preferences
- Model usage stats

### REST API Sync (Windows/Android)

```typescript
// API endpoints
GET  /api/v1/snapshots
POST /api/v1/snapshots
GET  /api/v1/alerts
POST /api/v1/devices/register

// WebSocket for real-time updates
ws://sync.runic.app/ws
```

**Optional self-hosted server** for privacy-conscious users.

---

## MCP Servers Integration

### Updated for Enhanced Tracking

#### Persistence Server
**New tools:**
- `record_enhanced_usage` - Store with model/project info
- `query_by_model` - Filter by model name
- `query_by_project` - Filter by project
- `get_reset_schedule` - List upcoming resets

#### Intuition Server
**New tools:**
- `predict_model_cost` - Forecast cost per model
- `recommend_model` - Suggest cheapest model for task
- `predict_reset_usage` - Forecast usage at reset time

#### Consciousness Server
**New tools:**
- `monitor_reset_timings` - Track reset accuracy
- `check_account_type` - Verify subscription status
- `alert_approaching_reset` - Proactive reset alerts

---

## Platform-Specific Features

### macOS
✅ Menubar with live usage bars
✅ Preferences window with tabs
✅ Sparkle auto-updates
✅ Keyboard shortcuts
🆕 Reset countdown in menubar
🆕 Model usage submenu
🆕 Project-based filtering

### CLI
✅ `runic usage --provider claude`
✅ `runic cost --days 7`
🆕 `runic models --provider claude`
🆕 `runic projects --list`
🆕 `runic alerts --active`
🆕 `runic reset --when claude`

### iOS
🆕 Native SwiftUI interface
🆕 Home screen widgets (small/medium/large)
🆕 Lock screen widgets (circular/inline)
🆕 Live Activities for active sessions
🆕 Push notifications for alerts
🆕 Share Extension to track from other apps
🆕 Shortcuts app integration

### Windows (React Native)
🆕 System tray icon
🆕 Toast notifications
🆕 Auto-launch on startup
🆕 Windows 11 Widgets Dashboard
🆕 Fluent Design UI

### Android (React Native)
🆕 Material You theming
🆕 Home screen widget
🆕 Notification channels
🆕 Quick Settings tile
🆕 Background WorkManager sync

---

## Development Roadmap

### Phase 1: Enhanced Models ✅
- [x] Create enhanced data models
- [x] Update MCP servers
- [x] Architecture documentation

### Phase 2: iOS App (Current)
- [ ] Create Xcode project
- [ ] Implement core views
- [ ] Add WidgetKit widgets
- [ ] Implement iCloud sync
- [ ] TestFlight beta

### Phase 3: React Native Foundation
- [ ] Set up React Native monorepo
- [ ] Create shared components
- [ ] Implement API client
- [ ] Build core screens

### Phase 4: Windows App
- [ ] React Native for Windows setup
- [ ] System tray integration
- [ ] Windows notifications
- [ ] Microsoft Store submission

### Phase 5: Android App
- [ ] Android-specific setup
- [ ] Material You theming
- [ ] Google Play submission

### Phase 6: Sync Infrastructure
- [ ] Optional REST API server
- [ ] WebSocket real-time sync
- [ ] Self-hosted deployment guide

---

## Tech Stack Summary

| Component | Technology | Why |
|-----------|-----------|-----|
| macOS/iOS Core | Swift 6 + SwiftUI | Native performance, shared code |
| Windows/Android | React Native | Cross-platform, native UI |
| CLI | Swift ArgumentParser | Shares RunicCore |
| Sync (Apple) | iCloud CloudKit | Native, private, free |
| Sync (Cross-platform) | REST + WebSocket | Universal, controllable |
| MCP Servers | TypeScript + Node | Standard MCP SDK |
| Database (local) | SQLite | Fast, embedded |
| Database (sync) | PostgreSQL (optional) | Relational, reliable |

---

## Security & Privacy

1. **Credentials**: Keychain (macOS/iOS), EncryptedSharedPreferences (Android), Credential Manager (Windows)
2. **Sync**: End-to-end encrypted via CloudKit or self-hosted
3. **Analytics**: All processing on-device, opt-in only
4. **Open Source**: Core models and sync protocol open for audit

---

## Motto in Action

**Persistence** 🗄️
- Historical data across all devices
- Survives app updates and migrations
- iCloud backup

**Intuition** 🧠
- Predicts limit hits before they happen
- Recommends optimal models for tasks
- Learns usage patterns

**Consciousness** 👁️
- Real-time awareness on all platforms
- Proactive alerts everywhere
- System health monitoring

---

**End of Architecture Document**
