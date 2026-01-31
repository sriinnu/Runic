# Runic Source Code Organization

**Last Updated:** 2026-01-16  
**Version:** v0.16.1+

## 📁 Folder Structure

The Runic codebase is organized into logical modules for maintainability and clarity.

```
Sources/Runic/
├── Core/                          # Core business logic (non-UI)
│   ├── Stores/                    # State management
│   │   ├── UsageStore.swift       # Main usage tracking state (1415 lines)
│   │   ├── UsageStore+*.swift     # Extensions for modular organization
│   │   ├── SettingsStore.swift    # App settings and preferences
│   │   └── *TokenStore.swift      # Provider-specific token storage
│   ├── Login/                     # Authentication flows
│   │   └── *LoginRunner.swift     # Provider-specific login runners
│   └── Rendering/                 # Icon and graphics rendering
│       ├── IconRenderer.swift     # Menu bar icon generation
│       ├── IconView.swift         # SwiftUI icon view wrapper
│       └── ProviderBrandIcon.swift # Provider logo icons
│
├── Views/                         # SwiftUI UI components
│   ├── Menu/                      # Menu bar dropdown UI
│   │   ├── MenuCardView.swift     # Main card component (1093 lines)
│   │   ├── MenuContent.swift      # Menu content builder
│   │   ├── MenuDescriptor.swift   # Menu structure definition
│   │   ├── MenuHighlightStyle.swift # Highlight appearance
│   │   └── *ChartMenuView.swift   # Chart visualizations
│   ├── Preferences/               # Settings panels
│   │   ├── PreferencesView.swift  # Main preferences window
│   │   ├── PreferencesAboutPane.swift
│   │   ├── PreferencesGeneralPane.swift
│   │   ├── PreferencesProvidersPane.swift
│   │   ├── PreferencesAdvancedPane.swift
│   │   └── PreferencesComponents.swift # Reusable UI components
│   └── Components/                # Shared UI components
│       └── UsageProgressBar.swift
│
├── Controllers/                   # AppKit controllers
│   ├── StatusItemController.swift # Main status bar controller
│   ├── StatusItemController+Menu.swift # Menu construction
│   ├── StatusItemController+Actions.swift # User actions
│   └── StatusItemController+Animation.swift # Icon animations
│
├── Providers/                     # Provider implementations
│   ├── Shared/                    # Shared provider code
│   │   ├── ProviderImplementation.swift
│   │   ├── ProviderLoginFlow.swift
│   │   └── ProviderCatalog.swift
│   ├── Claude/                    # Claude-specific code
│   │   ├── ClaudeProviderImplementation.swift
│   │   └── ClaudeLoginFlow.swift
│   ├── Codex/                     # OpenAI Codex
│   ├── Cursor/                    # Cursor IDE
│   ├── Copilot/                   # GitHub Copilot
│   ├── Gemini/                    # Google Gemini
│   ├── Antigravity/               # Google Antigravity
│   ├── Factory/                   # Factory AI
│   ├── Zai/                       # Zai
│   ├── MiniMax/                   # MiniMax
│   ├── OpenRouter/                # OpenRouter
│   └── Groq/                      # Groq
│
├── Utilities/                     # Helper utilities
│   ├── PerformanceConstants.swift # Performance tuning constants
│   ├── LoadingPattern.swift       # Loading animation patterns
│   └── DisplayLink.swift          # Frame-synchronized animations
│
├── Resources/                     # Assets and resources
│   ├── RunicMenubarIcon.svg       # App menubar icon (wave logo)
│   └── ProviderIcon-*.svg         # Provider brand icons
│
└── *.swift                        # Root-level files
    ├── RunicApp.swift             # Main app entry point
    ├── About.swift                # About panel
    ├── AppNotifications.swift     # Notification handling
    └── ...
```

---

## 🎯 Design Principles

### 1. **Separation of Concerns**
- **Core/**: Business logic, no AppKit/SwiftUI dependencies
- **Views/**: Pure SwiftUI, no business logic
- **Controllers/**: AppKit bridge, coordinates Core ↔ Views

### 2. **Provider Isolation**
Each provider has its own folder with:
- `*ProviderImplementation.swift` - Core provider logic
- `*LoginFlow.swift` - Authentication specific to that provider

### 3. **File Size Guidelines**
- **Ideal**: < 300 lines
- **Acceptable**: 300-500 lines
- **Needs splitting**: > 500 lines
- **Large exceptions**: 
  - `UsageStore.swift` (1415 lines) - planned refactor
  - `MenuCardView.swift` (1093 lines) - complex UI layout
  - `StatusItemController+Menu.swift` (1878 lines) - menu construction

### 4. **Naming Conventions**
- **Controllers**: `*Controller.swift`
- **Views**: `*View.swift` or descriptive name
- **Stores**: `*Store.swift`
- **Extensions**: `BaseFile+Extension.swift`
- **Utilities**: Descriptive name (e.g., `DisplayLink.swift`)

---

## 📝 Code Comment Guidelines

### Required Comments

#### 1. **File Headers**
```swift
/// **File Purpose**
/// Brief description of what this file does and when to use it.
///
/// - **Responsibilities:**
///   - Main responsibility 1
///   - Main responsibility 2
///
/// - **Dependencies:**
///   - Key dependency 1
///   - Key dependency 2
```

#### 2. **Complex Functions**
```swift
/// **Performance-Critical**: Brief description
/// 
/// Explain:
/// - Why this approach was chosen
/// - Performance implications
/// - Any gotchas or edge cases
///
/// - Parameters:
///   - param1: Description
///   - param2: Description
/// - Returns: Description
func complexFunction(param1: Type, param2: Type) -> ReturnType {
    // Implementation
}
```

#### 3. **Magic Numbers**
```swift
// Use constants with explanatory names
static let menuOpenPingDelay: Duration = .seconds(1.2)  // Delay before background ping
```

#### 4. **Workarounds**
```swift
// WORKAROUND: macOS 14.x bug - status item flickers without this delay
try? await Task.sleep(for: .milliseconds(100))
```

---

## 🔧 Key Files Reference

### Core Files

| File | Lines | Purpose |
|------|-------|---------|
| `Core/Rendering/IconRenderer.swift` | 882 | Generates menubar icons with usage visualization |
| `Core/Stores/UsageStore.swift` | 1415 | Main state management (needs refactor) |
| `Controllers/StatusItemController.swift` | 318 | Manages menubar status item |
| `Views/Menu/MenuCardView.swift` | 1093 | Rich menu card UI |

### Configuration Files

| File | Purpose |
|------|---------|
| `Utilities/PerformanceConstants.swift` | All performance tuning knobs |
| `Views/Menu/MenuCardMetrics.swift` | UI spacing constants |
| `Views/Preferences/PreferencesComponents.swift` | Reusable UI layouts |

---

## 🚀 Adding New Code

### Adding a New Provider

1. Create folder: `Providers/ProviderName/`
2. Add implementation: `ProviderNameProviderImplementation.swift`
3. Add login flow: `ProviderNameLoginFlow.swift`
4. Add icon: `Resources/ProviderIcon-providername.svg`
5. Register in: `RunicCore/Providers/Providers.swift`

### Adding a New View

1. Determine category: Menu, Preferences, or Components
2. Place in appropriate `Views/` subfolder
3. Follow naming: `*View.swift` suffix
4. Add comprehensive header comments

### Adding Utility Code

1. Place in `Utilities/` if reusable
2. Add to appropriate `Core/` subfolder if business logic
3. Document purpose and usage

---

## 📐 Layout Metrics Quick Reference

### Menu Cards
```swift
MenuCardMetrics.sectionSpacing = 8pt   // Between major sections
MenuCardMetrics.lineSpacing = 4pt      // Between text lines
MenuCardMetrics.horizontalPadding = 12pt
```

### Preferences
```swift
PreferencesLayoutMetrics.paneHorizontal = 35pt
PreferencesLayoutMetrics.paneVertical = 25pt
PreferencesLayoutMetrics.sectionSpacing = 18pt
```

---

## 🎨 Icon System

### Menubar Icons
- **Generated**: `Core/Rendering/IconRenderer.swift`
- **Shows**: Usage bars, stale indicators, provider status
- **Format**: Template images (color adapts to menubar theme)

### Provider Brand Icons
- **Location**: `Resources/ProviderIcon-*.svg`
- **Loaded**: `Core/Rendering/ProviderBrandIcon.swift`
- **Format**: SVG, tinted to provider brand color

### App Icon
- **Source**: `Icon.icon/Assets/runic.png`
- **Built**: `./Scripts/build_icon.sh` → `Icon.icns`
- **Design**: Wave-based logo with usage bars

---

## 🔍 Finding Code

### By Feature
- **Menu bar icon**: `Core/Rendering/IconRenderer.swift`
- **Menu content**: `Views/Menu/MenuCardView.swift`
- **Settings UI**: `Views/Preferences/Preferences*Pane.swift`
- **Usage tracking**: `Core/Stores/UsageStore.swift`
- **Animations**: `Controllers/StatusItemController+Animation.swift`

### By Provider
- **All providers**: `Providers/*/`
- **Provider list**: `RunicCore/Providers/Providers.swift`
- **Provider UI**: `Views/Preferences/PreferencesProvidersPane.swift`

### By Performance
- **Constants**: `Utilities/PerformanceConstants.swift`
- **Animation FPS**: `StatusItemController+Animation.swift:416`
- **Ping logic**: `StatusItemController+Menu.swift:311`

---

## 📊 Code Statistics

| Category | Files | Avg Size | Total Lines |
|----------|-------|----------|-------------|
| Core | ~30 | 250 | ~7,500 |
| Views | ~25 | 400 | ~10,000 |
| Controllers | 4 | 500 | ~2,000 |
| Providers | ~60 | 200 | ~12,000 |
| **Total** | **~119** | **~250** | **~30,000** |

---

## 🛠️ Build Commands

```bash
# Full build and run
RUNIC_SIGNING=adhoc ./Scripts/compile_and_run.sh

# Build only
swift build -c release

# Run tests
swift test

# Generate icon
./Scripts/build_icon.sh
```

---

**Questions?** See `AGENTS.md` for AI agent development guidelines.
