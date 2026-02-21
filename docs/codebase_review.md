# Runic Codebase Review - Multi-Agent Analysis

**Date**: 2026-01-31
**Methodology**: 5 parallel AI agents exploring different aspects
**Total Files Analyzed**: 165+ Swift files

---

## Executive Summary

Runic is a sophisticated macOS menubar application that monitors AI provider API usage limits across 11 providers (Claude, Codex, MiniMax, Cursor, Gemini, Copilot, etc.). The architecture demonstrates excellent engineering with:

- **Clear separation of concerns** - RunicCore (platform-agnostic) vs Runic (macOS UI)
- **Multi-strategy authentication** - OAuth → Web → CLI fallback chains
- **Performance-first design** - 60 FPS animations, aggressive caching
- **Security-focused** - Keychain credentials, browser cookie isolation

---

## Architecture Overview

### Module Structure

```
Runic/
├── Sources/RunicCore/          (82 files - Business logic)
│   ├── Providers/              (11 AI provider integrations)
│   ├── UsageLedger/            (Local log parsing)
│   ├── OpenAIWeb/              (Web dashboard scraping)
│   └── Host/                   (PTY/CLI execution)
│
├── Sources/Runic/              (83 files - macOS UI)
│   ├── Controllers/            (AppKit menubar integration)
│   ├── Views/                  (SwiftUI components)
│   │   ├── Menu/               (Menubar dropdown UI)
│   │   └── Preferences/        (Settings panels)
│   ├── Core/
│   │   ├── Stores/             (Observable state management)
│   │   ├── Rendering/          (Icon generation)
│   │   └── Login/              (OAuth flows)
│   └── Utilities/              (Performance, animations)
│
├── Sources/RunicCLI/           (Command-line interface)
├── Sources/RunicWidget/        (WidgetKit extension)
└── mcp-servers/                (NEW: MCP integrations)
```

### Technology Stack

- **Swift 6** with strict concurrency
- **SwiftUI + AppKit** hybrid (SwiftUI for views, AppKit for menubar)
- **Observation framework** for reactive state
- **Keychain** for credential storage
- **SQLite** for local caching
- **WebKit** for browser cookie access
- **Sparkle** for auto-updates

---

## Key Findings by Domain

### 1. Provider Integration (Agent: a8931e9)

**11 Providers Supported:**
- **Primary**: Claude, Codex (multi-source auth)
- **API-based**: Copilot, OpenRouter, Groq, Zai, MiniMax
- **Browser-based**: Cursor, Factory, Gemini, Antigravity

**Authentication Patterns:**
1. **OAuth** - Keychain + file storage (Claude, Codex)
2. **API Tokens** - Keychain with environment fallback
3. **Browser Cookies** - Isolated WebKit stores per account
4. **CLI Tools** - PTY sessions with `claude`, `codex`, etc.

**Fetch Strategy Pattern:**
```
Auto mode: OAuth → Web → CLI (with fallback logic)
Provider-specific modes: OAuth only, Web only, CLI only
```

**Data Models:**
- `UsageSnapshot` - Primary/secondary/tertiary rate windows
- `RateWindow` - Usage percent, reset timing
- `ProviderCostSnapshot` - Token costs and spending
- `CreditsSnapshot` - Credit-based providers

### 2. UI Architecture (Agent: a5b0a50)

**Recent Refactoring** - Code reorganized into logical directories:
- `Views/Menu/` - 7 files (MenuCardView, charts)
- `Views/Preferences/` - 9 files (tabbed settings)
- `Controllers/` - 4 files (StatusItemController split)

**SwiftUI + AppKit Hybrid:**
- `NSHostingView` embeds SwiftUI in NSMenu
- `@Environment(\.menuItemHighlighted)` for adaptive styling
- 60 FPS animations via `DisplayLinkDriver`

**Charts Framework:**
- Cost history (bar chart with model breakdown)
- Credits history (line chart with gradient)
- Usage breakdown (stacked bars by service)

**Icon Rendering System:**
- 64 icon cache + 512 morph cache
- Template mode (adapts to theme) vs vibrant mode
- 6 loading animation patterns
- Provider-specific sigil styles

### 3. Data Persistence (Agent: a9bdb7a)

**Storage Mechanisms:**

| Data Type | Storage | Location |
|-----------|---------|----------|
| API Tokens | Keychain | `com.sriinnu.athena.Runic` |
| OAuth Credentials | Keychain + File | `~/.claude`, `~/.codex` |
| Settings | UserDefaults | System preferences |
| Usage Logs | JSONL | `~/.codex/sessions`, `~/.claude/projects` |
| Cost Cache | JSON | `~/Library/Caches/Runic/` |
| Widget Data | JSON | App Group Container |

**Key Patterns:**
- **Debounced Writes** - Token stores delay 350ms to batch changes
- **Atomic Updates** - File writes prevent corruption
- **Incremental Processing** - Cache tracks file mtimes
- **Per-Account Isolation** - WebKit cookies use email-based UUIDs

### 4. Core Infrastructure (Agent: a8e1972)

**Utilities:**
- `DisplayLink.swift` - 60 FPS animation driver
- `LoadingPattern.swift` - 6 animation patterns
- `PerformanceConstants.swift` - Tuning parameters

**Stores:**
- `UsageStore.swift` (2,127 lines) ⚠️ **God class needing refactoring**
- `SettingsStore.swift` (889 lines) - User preferences
- `*TokenStore.swift` (7 files) - Keychain wrappers

**Rendering:**
- `IconRenderer.swift` (886 lines) - Menubar icon generation
- `IconView.swift` - SwiftUI wrapper with animations
- `ProviderBrandIcon.swift` - Cached SVG logos

**Login Flows:**
- PTY-based OAuth automation for Claude, Codex, Gemini, Cursor
- URL detection → browser phase → polling for success

### 5. Overall Architecture (Agent: a0dd8b1)

**Purpose:** Monitor AI provider rate limits to avoid service interruptions

**Entry Points:**
1. `RunicApp.swift` - Main app with keepalive window
2. `AppDelegate` - Creates StatusItemController, Sparkle updater
3. `StatusItemController` - Menubar management (2,500+ LOC across 4 files)

**Data Flow:**
```
User/Timer → UsageStore.refresh()
           → ProviderRegistry.specs()
           → UsageFetcher (multi-strategy)
           → ProviderFetchPlan (OAuth/Web/CLI)
           → UsageSnapshot
           → ObservationTracking → UI update
```

**Performance Philosophy:**
- Zero token leakage (cache-first)
- Single ping per provider per session
- 5-minute stale threshold
- 60 FPS animation cap

---

## Technical Debt Identified

### High Priority
1. **UsageStore God Class** (2,127 lines)
   - Needs split: `UsageStateStore`, `UsageFetchingActor`, `TokenUsageService`

2. **Settings/Usage Circular Dependencies**
   - Tight coupling between stores

### Medium Priority
3. **Multiple Caching Strategies**
   - Icon cache, morph cache, cost cache, settings cache
   - Could be unified under single caching abstraction

4. **StatusItemController Size**
   - 2,500+ lines across 4 files
   - Menu construction logic could be extracted

### Low Priority
5. **Test Coverage**
   - Limited unit tests found
   - UI testing appears manual

---

## Strengths

1. **Extensibility** - Descriptor-based provider registration via macros
2. **Reliability** - Multi-strategy fallback chains ensure data availability
3. **Performance** - Aggressive caching, 60 FPS animations, resource limits
4. **Security** - Keychain storage, per-account isolation, no password storage
5. **Privacy** - On-device parsing, opt-in cookie access
6. **Modern Swift** - Observation framework, strict concurrency, async/await

---

## Recommendations

### Immediate
1. ✅ **Create MCP servers** for external integration (COMPLETED)
2. Refactor `UsageStore` into smaller, focused components
3. Add unit tests for provider fetch logic

### Short-term
4. Document provider addition process
5. Create CI/CD pipeline for automated testing
6. Add telemetry for error tracking

### Long-term
7. Support custom provider definitions (user-extensible)
8. Add export/import for settings and data
9. Consider cross-platform support (iOS widget, web dashboard)

---

## MCP Servers Created

### 1. Persistence Server 🗄️
- Time-series usage storage (SQLite)
- Historical analytics and trends
- Data export/backup capabilities

**Tools:** `record_usage`, `query_usage_history`, `get_usage_trends`, `export_data`

### 2. Intuition Server 🧠
- Usage limit prediction (linear regression)
- Provider recommendations (multi-factor scoring)
- Anomaly detection (z-score analysis)
- Cost optimization suggestions

**Tools:** `predict_usage_limit`, `recommend_provider`, `detect_usage_anomaly`, `optimize_cost`

### 3. Consciousness Server 👁️
- Real-time provider health checks
- System component monitoring
- Proactive alerting
- Root cause diagnostics

**Tools:** `check_provider_health`, `monitor_system_health`, `create_alert`, `diagnose_issues`

---

## Motto Integration

**"Persistence, Intuition, Consciousness"**

- **Persistence** ✅ - Robust data storage (Keychain, logs, cache, MCP server)
- **Intuition** ✅ - Predictive analytics (MCP server)
- **Consciousness** ✅ - Real-time awareness (MCP server, status checks)

The codebase and new MCP servers fully embody this philosophy.

---

## Conclusion

Runic is a well-architected macOS application with excellent separation of concerns, performance optimizations, and security practices. The new MCP servers extend its capabilities into the AI agent ecosystem, enabling Claude and other AI tools to leverage Runic's monitoring data for intelligent decision-making.

**Overall Grade: A-**

Strengths outweigh technical debt. The codebase is production-ready with clear paths for improvement.

---

**Reviewed by:** 5 AI agents (Explore subagent_type)
**Lines of Code:** ~50,000+ (Swift) + ~1,500 (TypeScript MCP servers)
**Agent IDs:**
- Architecture: a0dd8b1
- Providers: a8931e9
- UI/Views: a5b0a50
- Persistence: a9bdb7a
- Core/Utilities: a8e1972
