# Runic Development Guidelines

## Agent Guidelines for Runic Project

This document provides guidelines for AI agents working on Runcin - a multi-platform AI provider usage tracking application.

---

## Project Overview

**Runic** is a macOS menu bar application (v0.16.1) that tracks AI/LLM provider usage and quotas. The codebase is evolving toward cross-platform support (Windows, Linux, Web).

**Current Architecture:**
- **RunicCore** - Pure Swift, cross-platform (~60-70% of code)
- **Runic** - macOS menu bar app (~30-40% of code)
- **RunicCLI** - Cross-platform CLI
- **RunicWidget** - WidgetKit extension

**Providers Supported:** Claude, Codex, Cursor, Gemini, Copilot, Factory, Antigravity, Zai

---

## Core Development Principles

### 1. Always Rebuild Before Testing
After ANY code change (code or docs), rebuild and restart the app:
```bash
./Scripts/compile_and_run.sh
```
This kills old instances, builds, tests, packages, and relaunches.

### 1.5 Performance Is Non-Negotiable
- Menu bar icon animations must run only during active refreshes and cap at 30fps.
- Avoid always-on loops/timers; stop animation when data is loaded or errors are known.
- Prefer cached results and coarse updates for the menu bar.

### 2. Keep RunicCore Pure
- RunicCore must remain platform-agnostic
- No AppKit, UIKit, or platform-specific imports in RunicCore
- Use `#if os(macOS)` guards only at the app layer

### 3. Modern Swift Patterns
- Use `@Observable` macro (iOS 17+/macOS 15+)
- Avoid `ObservableObject`, `@ObservedObject`, `@StateObject`
- Use strict concurrency (Swift 6 features where possible)
- Prefer protocols over concrete types for extensibility

### 4. Provider Data Isolation
- Never display identity/plan fields from one provider for another
- Each provider's data stays in its designated namespace
- This prevents confusion and data leakage

---

## Phase-Specific Guidelines

### Phase 1: Core Enhancements (New Providers)

When adding a new provider:

1. **Follow the established pattern:**
   - `Sources/RunicCore/Providers/{Provider}/{Provider}ProviderDescriptor.swift`
   - `Sources/RunicCore/Providers/{Provider}/{Provider}StatusProbe.swift`

2. **Files to modify:**
   - `Sources/RunicCore/Providers/Providers.swift` - Add to enums
   - `Sources/RunicCore/Providers/ProviderDescriptor.swift` - Register in bootstrap

3. **Icon creation:**
   - Create SVG in `Sources/Runic/Resources/ProviderIcon-{provider}.svg`
   - Follow existing brand icon patterns

4. **Testing:**
   - Add provider-specific tests in `Tests/RunicTests/`
   - Run `swift test` before committing

### Phase 2: Liquid Fluid Display UI

When implementing liquid/visual effects:

1. **Performance first:**
   - Menu bar icon: cap at 30fps
   - Popover menu: 60fps
   - Always-running animations must be battery-efficient

2. **Metal/Shader guidelines:**
   - Keep shader code minimal
   - Use appropriate precision qualifiers
   - Profile on real hardware

3. **Animation patterns:**
   - Use `CADisplayLink` for frame-synced animations
   - Spring animations for UI state changes (`CASpringAnimation`)
   - Particle effects for milestones only

4. **Files reference:**
   - `IconRenderer.swift:957` - Current icon rendering
   - `StatusItemController+Animation.swift:459` - Animation system

### Phase 3: Code Refactoring

When refactoring (especially UsageStore):

1. **Incremental changes:**
   - Don't rewrite everything at once
   - Create new files, migrate gradually
   - Keep existing tests passing

2. **UsageStore split strategy:**
   ```
   Sources/Runic/
   ├── UsageStateStore.swift      # Observable state for UI
   ├── UsageFetchingActor.swift   # Concurrent fetching
   └── TokenUsageService.swift    # Token-based operations
   ```

3. **Error handling:**
   - Replace `fatalError` with throwing functions
   - Create unified error types where appropriate

### Phase 4: Cross-Platform (Windows/Linux)

When working on platform ports:

1. **Platform abstraction pattern:**
   ```swift
   protocol PlatformStatusItem {
       func show()
       func hide()
       func setIcon(_ imageData: Data)
   }

   #if os(macOS)
   final class MacStatusItem: PlatformStatusItem { ... }
   #elseif os(Windows)
   final class WindowsStatusItem: PlatformStatusItem { ... }
   #elseif os(Linux)
   final class LinuxStatusItem: PlatformStatusItem { ... }
   #endif
   ```

2. **Dependency handling:**
   - Silo: Already supports macOS, Linux, Windows
   - Helix: Needs Linux/Windows target additions
   - KeyboardShortcuts: macOS only, needs alternatives

3. **Testing on Linux:**
   ```bash
   swift build --destination generic/linux
   swift test
   ```

4. **CI/CD considerations:**
   - Set up GitHub Actions for Linux/Windows builds
   - Use Docker for consistent Linux testing

### Phase 5: Web Application

When working on the web app:

1. **Architecture pattern:**
   - React + TypeScript frontend
   - FastAPI (Python) backend
   - WebSocket for real-time updates

2. **API design:**
   - Mirror RunicCore's data models in TypeScript
   - Keep endpoint structure consistent with CLI

3. **OAuth flows:**
   - Server-side token exchange
   - Encrypted storage for credentials
   - Automatic token refresh

4. **Responsive design:**
   - Mobile-first approach
   - Dark mode support
   - Progressive enhancement

---

## Build, Test, Run Commands

### Quick Build
```bash
swift build                    # Debug
swift build -c release        # Release
```

### Full Test Suite
```bash
swift test
./Scripts/compile_and_run.sh  # Includes testing
```

### Package Locally
```bash
./Scripts/package_app.sh
pkill -x Runic || pkill -f Runic.app || true
open -n Runic.app
```

### Release Flow
```bash
./Scripts/sign-and-notarize.sh  # Creates notarized zip
./Scripts/make_appcast.sh <zip> <feed-url>
```

---

## Coding Style

### SwiftFormat & SwiftLint
Always run before committing:
```bash
swiftformat Sources Tests
swiftlint --strict
```

### Style Rules
- 4-space indent
- 120-char line limit
- Explicit `self` is intentional
- Use ` MARK:` sections

### Maintainability Constraints
- No file in the repository should grow beyond 450 lines of code without a follow-up split in the same PR.
- Keep every public surface documented with `///` comments, and add inline comments where behavior is non-obvious.
- Prefer `MARK:` groups in large files and move helper-only logic into extensions when practical.

### File Organization
```
Sources/RunicCore/
├── Providers/
│   ├── ProviderName/
│   │   ├── ProviderNameProviderDescriptor.swift
│   │   └── ProviderNameStatusProbe.swift
│   └── [Common files]

Sources/Runic/
├── Menubar/
├── Views/
└── Providers/
```

---

## Testing Guidelines

### Test Locations
- macOS tests: `Tests/RunicTests/`
- Linux tests: `TestsLinux/`
- CLI tests: `Sources/RunicCLI/` tests

### Test Naming
- `FeatureNameTests.swift`
- `test_caseDescription` methods
- Mirror new logic with focused tests

### Test Requirements
- Add/extend XCTest cases for new features
- Add fixtures for parsing/formatting scenarios
- Always run `swift test` before handoff

---

## Commit & PR Guidelines

### Commit Messages
- Short imperative clauses
- Keep commits scoped
- Examples:
  - "Add MiniMax provider integration"
  - "Fix icon dimming on dark menu"
  - "Refactor UsageStore state management"

### PR Requirements
- Summary of changes
- Commands run
- Screenshots/GIFs for UI changes
- Linked issue/reference when relevant

---

## Agent-Specific Notes

### Multi-Agent Workflows
When using multiple agents:

1. **Architecture agent** - Analyzes structure, dependencies
2. **UI/UX agent** - Reviews visual components, animations
3. **Provider agent** - Adds new AI providers
4. **Platform agent** - Handles cross-platform work

### Communication Between Agents
- Use shared context in task descriptions
- Reference file paths explicitly
- Share findings in task output

### When to Use Sub-Agents
- Complex refactoring (>500 line changes)
- New provider integration
- Cross-platform implementation
- Documentation generation

---

## Troubleshooting

### "Stale Binary" Issues
```bash
pkill -x Runic || pkill -f Runic.app || true
cd /Users/sriinnu/Projects/runic && open -n Runic.app
```

### Build Failures
1. Clean build: `rm -rf .build && swift build`
2. Resolve dependencies: `rm Package.resolved && swift package resolve`
3. Check Xcode: `xcode-select --print-path`

### Test Failures
1. Run specific test: `swift test --filter testName`
2. Check platform-specific tests: `swift test -t Linux`

---

## Key File References

### Core Files
| File | Purpose | Lines |
|------|---------|-------|
| `IconRenderer.swift` | Menu bar icon rendering | 957 |
| `UsageStore.swift` | Main state management | 1415 |
| `ProviderDescriptor.swift` | Provider registry | 111 |
| `StatusItemController+Menu.swift` | Menu construction | 1646 |

### Configuration
| File | Purpose |
|------|---------|
| `Package.swift` | SPM manifest |
| `AGENTS.md` | This file |
| `docs/RELEASING.md` | Release process |

### Scripts
| Script | Purpose |
|--------|---------|
| `compile_and_run.sh` | Dev loop |
| `package_app.sh` | Create Runic.app |
| `sign-and-notarize.sh` | Release signing |

---

## Resources

- **Swift.org:** https://www.swift.org/
- **SwiftUI Docs:** https://developer.apple.com/documentation/swiftui
- **Metal Shading Language:** https://developer.apple.com/documentation/metal/shader_language
- **WebView2 (Windows):** https://docs.microsoft.com/en-us/microsoft-edge/webview2/
- **libappindicator (Linux):** https://developer.gnome.org/libappindicator/

---

*Last updated: 2026-01-05*
