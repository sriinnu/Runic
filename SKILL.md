---
name: runic
description: Work effectively in the Runic repo: a SwiftPM macOS menu bar app and CLI for AI usage, quota, context, and cost visibility across providers.
---

# Runic Skill

Use this skill when an AI agent needs to understand, build, test, document, or safely modify Runic.

## What Runic Is

Runic is a SwiftPM macOS menu bar app with a bundled CLI. It shows AI provider usage, quota windows, context capacity labels, cost estimates, model/project breakdowns, metric provenance, status links, exports, widgets, and alerts.

## First Files To Read

- `README.md`: user-facing product overview, install, privacy, and screenshots.
- `docs/architecture.md`: module map and app data flow.
- `docs/providers.md`: provider fetch strategy overview.
- `docs/provider.md`: provider implementation workflow and guardrails.
- `docs/<provider>.md`: per-provider reference (29 files, one per provider) — auth model, endpoints, parsing, key files. Read the relevant provider doc before touching its code.
- `docs/cli.md`: CLI commands and output contracts.
- `docs/releasing.md`: release, signing, notarization, Sparkle, and Homebrew flow.

## Architecture Map

- `Sources/RunicCore`: provider descriptors, fetchers, parsers, usage ledger, status probes, pricing/cost logic, sync models.
- `Sources/Runic`: macOS app state, settings, menu bar controller, popover/menu UI, preferences, icon rendering.
- `Sources/RunicCLI`: Helix-based `runic` CLI.
- `Sources/RunicWidget`: WidgetKit extension.
- `Sources/RunicMacros` and `Sources/RunicMacroSupport`: provider registration macros.
- `Sources/RunicClaudeWatchdog`: helper for Claude CLI PTY sessions.
- `Tests/RunicTests`: macOS app/core tests.
- `TestsLinux`: Linux-compatible core/CLI tests.

## Build And Test

```bash
swift build
swift test
./Scripts/compile_and_run.sh --wait
./Scripts/package_app.sh release
```

Use `./Scripts/compile_and_run.sh --wait` when the user needs a locally installed `/Applications/Runic.app` build.

## Provider Change Workflow

1. Read `docs/provider.md`, `docs/providers.md`, and the per-provider doc at `docs/<provider>.md`.
2. Keep provider identity siloed: never mix emails, org IDs, plans, login methods, cookies, or tokens across providers.
3. Add or update the provider descriptor/fetcher in `Sources/RunicCore/Providers/<Provider>/`.
4. Add settings UI through provider setting descriptors in `Sources/Runic/Providers/<Provider>/`.
5. Update menu/prefs UI only through existing store and descriptor patterns.
6. Add parser tests with sanitized fixtures.
7. Update `docs/providers.md` and README provider claims if behavior changes.

## Usage Ledger And Provenance

- Claude and Codex have local JSONL ledger scanners.
- Other providers, including `local-llm`, use configured OpenTelemetry GenAI JSON/JSONL paths plus Runic's default sanitized collector ledger for historical token/model/project data.
- `runic otel-collect` accepts OTLP/HTTP JSON at `/v1/traces` and `/v1/logs`, or `--once --input`, and persists sanitized metric JSONL only.
- Every new token or cost path should set `MetricProvenance` honestly: exact, provider-reported, estimated, inferred, or unknown.
- Only mark `UsageLedgerOperationKind.compaction` when a source explicitly says compact/compaction; never infer semantic context loss from max context labels.

## Local LLM

`UsageProvider.localLLM` is a first-class provider. It probes localhost runtimes for presence/model inventory only: Ollama, LM Studio, vLLM, llama.cpp, and Open WebUI. Usage and cost must come from local logs, OpenTelemetry GenAI, or an explicit future user-configured pricing source.

## Context Metadata

Runic prefers Kosha-discovery 1.2.0's local TTL-backed registry at `~/.kosha/registry.json` for model/provider context capacity metadata. If that registry is missing or stale, Runic falls back to `Sources/Runic/Resources/provider-context-windows.json`.

Context labels mean advertised or configured model capacity. They do not prove that all earlier conversation content is semantically retained after provider-side summarization or compaction.

## Privacy Guardrails

- Never log, commit, screenshot, or paste real API keys, cookies, bearer tokens, auth headers, refresh tokens, dashboard HTML, account emails, org IDs, or local private-key paths.
- Treat CLI JSON and diagnostics as potentially containing account identity.
- Screenshot assets must use demo data or be redacted before committing.
- Use macOS Keychain for user-entered secrets.
- Do not persist browser cookies outside the intended per-provider stores.
- Do not persist prompt/response bodies from OpenTelemetry collector ingestion unless a future explicit opt-in raw capture mode exists.
- Prefer GitHub noreply emails in git config.

## Docs Guardrails

- Keep `README.md` user-facing and honest about best-effort provider support.
- Keep auth internals, one-off research, generated reports, local paths, and scratch mockups out of git.
- Prefer `Scripts/` casing in docs.
- Do not mention nonexistent folders or platforms as current functionality.
- Put durable agent/developer workflow notes here or in `docs/`; keep private operational details local.

## Git Workflow

- Never commit directly to `main`.
- Work on a branch and open or update a PR.
- Do not force-push, rewrite history, or delete branches without explicit permission.
- Before committing, run at least `swift build`, focused tests for touched behavior, `git diff --check`, and a secret/PII scan.
