# Runic

<div align="center">

<img src="runic.png" alt="Runic infinity symbol with usage bars" width="144" />

**Local-first AI usage visibility for macOS.**

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000?logo=apple)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
![License MPL-2.0](https://img.shields.io/badge/license-MPL--2.0-blue)

</div>

Runic is a menubar app for seeing AI usage, quota signals, reset windows, cost estimates, context metadata, and local usage history across the providers you enable.

Its job is not to make provider usage look cleaner than it is. Its job is to report what can be known, label what is inferred, and avoid pretending when a provider does not expose the data.

## What We Stand For

**Truth over polish.** Runic should never fake precision. If a number comes from a provider API, local log, browser session, pricing table, heuristic, or fallback, that provenance should be visible in the code and, where useful, in exports.

**Local first.** Usage data belongs on the Mac by default. Runic has no product analytics, no telemetry, and no crash reporting. Network access is limited to the provider/status/update/webhook paths the app needs for enabled features.

**No dark patterns.** Budget warnings, quota labels, exports, and cost estimates should help the user understand their usage, not scare them into a workflow or hide uncertainty.

**Provider reality, not provider mythology.** Context windows are capability labels, not proof that every old token is semantically retained. Costs are best-effort unless provider-reported. Compaction tax is shown only when logs or telemetry explicitly identify compaction work.

**Secrets stay out.** API keys and locally entered credentials belong in macOS Keychain or local provider sessions, not in git, screenshots, docs, diagnostics, or examples.

## What It Does

- Shows enabled provider usage from APIs, local CLIs, web sessions, local probes, and local telemetry where available.
- Tracks token and cost history for Claude and Codex through a compact, self-compacting Runic-owned relay: normal refresh reads today's live logs, history is backfilled automatically on first run, and an explicit rebuild repairs historical JSONL data on demand.
- Reads capability metadata from Kosha-discovery when present, then falls back to bundled context metadata.
- Exports scoped usage data as CSV or JSON with provenance fields where known.
- Provides a CLI for scripts and diagnostics.

Provider behavior is uneven because provider surfaces are uneven. Claude and Codex expose richer local usage signals than most API-only providers. Some providers expose quota windows, some expose spend, some expose model inventory, and some expose almost nothing useful. Runic should make that unevenness visible instead of smoothing it away.

## Privacy Boundary

Runic keeps usage data on this Mac unless you export it, copy diagnostics, enable a configured webhook, or use a provider feature that requires a provider request.

The local OpenTelemetry collector stores sanitized metric JSONL only: provider, model, timestamps, token counts, cache counts, IDs, explicit costs, SDK version, and explicit operation kind. Prompt and response content from upstream telemetry is not persisted.

Local logs and CLI output can include account identity fields such as email addresses. Redact diagnostics before sharing them publicly.

## Install

Download the latest release from [GitHub Releases](https://github.com/sriinnu/Runic/releases/latest), unzip it, and move `Runic.app` to Applications.

Homebrew:

```bash
brew install --cask sriinnu/tap/runic
```

Build from source:

```bash
git clone https://github.com/sriinnu/Runic.git
cd Runic
./Scripts/compile_and_run.sh
```

## CLI

Runic bundles `RunicCLI`:

```bash
runic --provider all --format json --pretty
runic cost --provider codex
runic cost --provider codex --rebuild
runic insights --provider all --view compaction --json --pretty
runic otel-collect --port 4318
```

Install it from Preferences -> Advanced -> Install CLI.

`runic cost` refreshes today's live usage by default. `--rebuild` is the explicit historical repair path and may scan provider JSONL history.

## Docs

- Provider behavior: [docs/providers.md](docs/providers.md)
- CLI details: [docs/cli.md](docs/cli.md)
- Architecture: [docs/architecture.md](docs/architecture.md)
- Refresh loop: [docs/refresh-loop.md](docs/refresh-loop.md)
- UI and widgets: [docs/ui.md](docs/ui.md), [docs/widgets.md](docs/widgets.md)
- Packaging and releases: [docs/packaging.md](docs/packaging.md), [docs/releasing.md](docs/releasing.md)

## Contributors And Agents

Start with [SKILL.md](SKILL.md), [docs/architecture.md](docs/architecture.md), [docs/provider.md](docs/provider.md), and [docs/providers.md](docs/providers.md).

Keep the root README as a statement of truth and project stance. Put detailed provider behavior, screenshots, local paths, feature matrices, research notes, and implementation reports in the right docs or ignored local notes.

Do not commit keys, tokens, browser session dumps, local account screenshots, account emails, org IDs, unredacted diagnostics, or provider secrets.

## Support

Runic is open source. Sponsorship is optional and should fund maintenance, signing, CI, docs, and privacy-first usage features without changing the core promise: honest local usage visibility should stay open.

## License

MPL-2.0. See [LICENSE](LICENSE).

<div align="center">

Built by [Srinivas Pendela](https://github.com/sriinnu)

</div>
