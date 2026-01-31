# Runic Quick Reference

**For developers who want to get productive fast.**

---

## 🚀 Quick Start

```bash
# Clone and build
git clone <repo-url>
cd Runic
RUNIC_SIGNING=adhoc ./Scripts/compile_and_run.sh

# Run tests
swift test

# Package app
./Scripts/package_app.sh
```

---

## 📁 Where Is Everything?

| What | Where |
|------|-------|
| **State management** | `Core/Stores/UsageStore.swift` |
| **Menubar icon** | `Core/Rendering/IconRenderer.swift` |
| **Menu UI** | `Views/Menu/MenuCardView.swift` |
| **Settings UI** | `Views/Preferences/Preferences*Pane.swift` |
| **Animations** | `Controllers/StatusItemController+Animation.swift` |
| **Performance config** | `Utilities/PerformanceConstants.swift` |
| **Provider code** | `Providers/{ProviderName}/` |

---

## 🔧 Common Tasks

### Adding a New Provider

1. Create folder: `Providers/ProviderName/`
2. Add files:
   - `ProviderNameProviderImplementation.swift`
   - `ProviderNameLoginFlow.swift`
3. Add icon: `Resources/ProviderIcon-providername.svg`
4. Register: `RunicCore/Providers/Providers.swift`

### Adjusting UI Spacing

```swift
// Menu cards
MenuCardMetrics.sectionSpacing = 8
MenuCardMetrics.lineSpacing = 4

// Preferences
PreferencesLayoutMetrics.paneHorizontal = 35
PreferencesLayoutMetrics.paneVertical = 25
```

### Tuning Performance

Edit `Utilities/PerformanceConstants.swift`:
```swift
static let menubarFPS = 60              // Animation frame rate
static let iconCacheSize = 64           // Icon cache size
static let staleDuration = Duration.seconds(300)  // 5 min stale
```

### Finding Code

```bash
# Search for function/class
grep -r "functionName" Sources/

# Find files by name
find Sources/ -name "*Store*"

# Search with line numbers
grep -rn "MARK:" Sources/Runic/
```

---

## 🎨 UI Layout

### Menubar Icon
- **Size:** 18×18pt (36×36px @2x)
- **Renderer:** `IconRenderer.swift`
- **Shows:** Usage bars, stale indicator, provider status

### Menu Cards
- **Width:** Auto (SwiftUI)
- **Padding:** 12pt horizontal
- **Spacing:** 8pt between sections, 4pt between lines

### Preferences Window
- **Size:** 500×400pt
- **Tabs:** About, General, Providers, Advanced, Help, Debug

---

## ⚡ Performance Guidelines

### Do's ✅
- Use O(1) lookups (Dictionary, Set)
- Cache expensive operations
- Stop animations when not needed
- Use cookies before API calls

### Don'ts ❌
- Never block main thread
- Avoid O(n) operations on large datasets
- Don't leak tokens (always cache first)
- No magic numbers (use constants)

---

## 🐛 Debugging

### Check Logs
```bash
# App logs
log stream --predicate 'process == "Runic"' --level debug

# Build errors
swift build 2>&1 | grep error
```

### Common Issues

| Problem | Solution |
|---------|----------|
| **Stale binary** | `pkill -x Runic && ./Scripts/compile_and_run.sh` |
| **Build fails** | `rm -rf .build && swift build` |
| **Icon not updating** | Clear cache in Debug preferences |
| **Menu not showing** | Check `StatusItemController+Menu.swift` |

---

## 📊 Code Statistics

| Metric | Value |
|--------|-------|
| **Total files** | ~119 |
| **Total lines** | ~30,000 |
| **Avg file size** | ~250 lines |
| **Largest file** | UsageStore.swift (2089 lines) |
| **Providers** | 11 (Claude, Codex, Cursor, etc.) |

---

## 🔗 Key Files Quick Links

### Core (Business Logic)
- [UsageStore.swift](Sources/Runic/Core/Stores/UsageStore.swift) - Main state (2089 lines)
- [IconRenderer.swift](Sources/Runic/Core/Rendering/IconRenderer.swift) - Icon generation (882 lines)
- [PerformanceConstants.swift](Sources/Runic/Utilities/PerformanceConstants.swift) - Config (50 lines)

### UI (SwiftUI)
- [MenuCardView.swift](Sources/Runic/Views/Menu/MenuCardView.swift) - Menu UI (1093 lines)
- [PreferencesView.swift](Sources/Runic/Views/Preferences/PreferencesView.swift) - Settings (200 lines)

### Controllers (AppKit)
- [StatusItemController.swift](Sources/Runic/Controllers/StatusItemController.swift) - Menubar (318 lines)
- [StatusItemController+Menu.swift](Sources/Runic/Controllers/StatusItemController+Menu.swift) - Menu builder (1878 lines)
- [StatusItemController+Animation.swift](Sources/Runic/Controllers/StatusItemController+Animation.swift) - Animations (469 lines)

---

## 🎯 Terminology

| Term | Meaning |
|------|---------|
| **Ping** | Fetch latest usage data from provider |
| **Snapshot** | Point-in-time usage data |
| **Stale** | Data older than 5 minutes |
| **Provider** | AI service (Claude, Codex, etc.) |
| **Status item** | macOS menubar icon |
| **Template image** | Image that adapts to menubar theme |

---

## 🔑 Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧R` | Open Runic menu |
| `⌘,` | Preferences |
| `⌘Q` | Quit |

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| **README.md** | Project overview |
| **AGENTS.md** | AI agent guidelines |
| **FOLDER_STRUCTURE.md** | Code organization guide |
| **RECENT_IMPROVEMENTS.md** | Latest changes |
| **QUICK_REFERENCE.md** | This file |
| **PLAN.md** | Development roadmap |
| **CHANGELOG.md** | Version history |

---

## 💡 Pro Tips

1. **Use folder structure** - Files are organized logically (see FOLDER_STRUCTURE.md)
2. **Read file headers** - Key files have comprehensive documentation
3. **Check PerformanceConstants** - All tuning knobs in one place
4. **Follow AGENTS.md** - Guidelines for consistent development
5. **Always rebuild** - Use `compile_and_run.sh` after changes

---

## 🆘 Getting Help

1. **Read docs** - Start with README.md, then FOLDER_STRUCTURE.md
2. **Check AGENTS.md** - Development guidelines and patterns
3. **Search code** - Use grep/find to locate examples
4. **Check git log** - See how features were implemented
5. **Ask maintainers** - Open an issue or discussion

---

**Updated:** 2026-01-16 | **Version:** v0.16.1 | **Build:** 49
