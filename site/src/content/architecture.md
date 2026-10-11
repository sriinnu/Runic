---
title: "Architecture"
---

# Architecture

Runic is a Swift 6 macOS menu bar app (macOS 14+) with strict concurrency on. The source lives in `Sources/`; the full overview is `docs/architecture.md` in the repo.

## Modules

| Module | What it is |
| --- | --- |
| `Runic` | The app: state (`UsageStore`, `SettingsStore`), the status item and popover, menus, themes and skins, icon rendering. |
| `RunicCore` | Fetch and parse: provider descriptors, Codex RPC, the PTY runner, Claude probes, OpenAI web scraping, the usage ledger, OTLP ingestion. |
| `RunicCLI` | The bundled `runic` command. See [CLI](/cli/). |
| `RunicWidget` | A WidgetKit extension fed by the shared snapshot. |
| `RunicMacros`, `RunicMacroSupport` | SwiftSyntax macros for provider registration. |
| `RunicClaudeWatchdog` | Helper process that keeps Claude CLI PTY sessions stable. |
| `RunicClaudeWebProbe` | A diagnostic CLI for Claude web fetches. |

## Data flow

```
provider probes / local logs / OTLP ─▶ UsageFetcher ─▶ UsageStore ─▶ menu card · icon · widget · CLI
                                                      ▲
                       SettingsStore (refresh cadence, toggles, theme)
```

A background refresh runs each enabled provider's strategies in order until one answers (OAuth, web, CLI, local probe, API token; see [Providers](/providers/)). Results land in `UsageStore`, which feeds the menu bar icon, the popover, the widget and the CLI. Settings toggles flow the other way and change refresh cadence and feature flags.

## The menu

The live menu is an `NSPopover` hosting `MenuPopoverView` in SwiftUI. An older sectioned `NSMenu` path still exists for the status item's context. The popover composes, top to bottom: the provider tabs, the page (a provider card or the overview), the Resets panel, the Explore charts and export, the action rows, and a skin footer. Which of those look like what is decided by the active [Themes and Skins](/themes-and-skins/) skin.

## Usage ledger and relay

Normal refreshes read provider logs as a **today-only** live feed. The relay keeps **one aggregate row per provider per day** (never per log line), which is what the timeline, Explore charts and cost history are built from. Rotated-away days survive in the relay, so history outlives the provider's own logs. The OpenTelemetry collector (`runic otel-collect`) feeds the same ledger with sanitized metric JSONL only: provider, model, timestamp, token and cache counts. Prompts and responses are never stored.

## Singleton and updates

Exactly one `Runic.app` lives in `/Applications` and the app enforces a single running instance. Updates arrive through Sparkle from the appcast on `main`; the Homebrew cask in `sriinnu/homebrew-tap` tracks each release.

## Where to read more

`docs/architecture.md`, `docs/providers.md`, `docs/refresh-loop.md`, `docs/ui.md` in the repo.
