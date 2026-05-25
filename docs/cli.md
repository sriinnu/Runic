---
summary: "Runic CLI for fetching usage from the command line."
read_when:
  - "You want to call Runic data from scripts or a terminal."
  - "Adding or modifying Helix-based CLI commands."
  - "Aligning menubar and CLI output/behavior."
---

# Runic CLI

A lightweight Helix-based CLI that mirrors the menubar app’s data paths (Codex web/RPC → PTY fallback; Claude web by default with CLI fallback and OAuth debug; provider/local-LLM history through local ledgers and configured OpenTelemetry GenAI files).
Use it when you need usage numbers in scripts, CI, or dashboards without UI.

## Install
- In the app: **Preferences → Advanced → Install CLI**. This symlinks `RunicCLI` to `/usr/local/bin/runic` and `/opt/homebrew/bin/runic`.
- From the repo: `./bin/install-runic-cli.sh` (same symlink targets).
- Manual: `ln -sf "/Applications/Runic.app/Contents/Helpers/RunicCLI" /usr/local/bin/runic`.

### Linux install
- Download `RunicCLI-<tag>-linux-<arch>.tar.gz` from GitHub Releases (x86_64 + aarch64).
- Extract; run `./runic` (symlink) or `./RunicCLI`.

```
tar -xzf RunicCLI-0.14.1-linux-x86_64.tar.gz
./runic --version
./runic usage --format json --pretty
```

## Build
- `./Scripts/package_app.sh` (or `./Scripts/compile_and_run.sh`) bundles `RunicCLI` into `Runic.app/Contents/Helpers/RunicCLI`.
- Standalone: `swift build -c release --product RunicCLI` (binary at `./.build/release/RunicCLI`).
- Dependencies: Swift 6.2+, Helix package (`https://github.com/sriinnu/Helix`).

## Command
- `runic` defaults to the `usage` command.
  - `--format text|json` (default: text).
- `runic cost` prints local token cost usage (Claude + Codex) without web/CLI access.
  - `--format text|json` (default: text).
  - `--refresh` ignores cached scans.
- `--provider codex|claude|zai|gemini|antigravity|cursor|factory|copilot|vercelai|local-llm|both|all` (default: all registered providers for `usage`, Claude for `insights`, Claude+Codex for `cost`).
  - `--no-credits` (hide Codex credits in text output).
  - `--pretty` (pretty-print JSON).
  - `--status` (fetch provider status pages and include them in output).
  - `--antigravity-plan-debug` (debug: print Antigravity planInfo fields to stderr).
- `--source <auto|web|cli|oauth>` (default: `auto`).
    - `auto` (macOS only): uses browser cookies for Codex + Claude, with CLI fallback only when cookies are missing.
    - `web` (macOS only): web-only; no CLI fallback.
    - `cli`: CLI-only (Codex RPC → PTY fallback; Claude PTY).
    - `oauth`: Claude OAuth only (debug); no fallback. Not supported for Codex.
    - Output `source` reflects the strategy actually used (`openai-web`, `web`, `oauth`, `api`, `local`, or provider CLI label).
    - Codex web: OpenAI web dashboard (usage limits, credits remaining, code review remaining, usage breakdown).
        - `--web-timeout <seconds>` (default: 60)
        - `--web-debug-dump-html` (writes HTML snapshots to `/tmp` when data is missing)
    - Claude web: claude.ai API (session + weekly usage, plus account metadata when available).
    - Linux: `web/auto` are not supported; CLI prints an error and exits non-zero.
- Global flags: `-h/--help`, `-V/--version`, `-v/--verbose`, `--no-color`, `--log-level <trace|verbose|debug|info|warning|error|critical>`, `--json-output`.

### Insights usage sources

`runic insights` reads Claude/Codex local JSONL ledgers directly. Other providers, including `local-llm`, are included when OpenTelemetry GenAI JSON/JSONL files are configured through `RUNIC_OTEL_GENAI_LOG_PATHS`, `RUNIC_OTEL_GENAI_LOG_PATH`, or provider-specific variables such as `RUNIC_LOCAL_LLM_OTEL_GENAI_LOG_PATHS`. Runic also reads daily default collector ledgers at `~/Library/Application Support/Runic/otel-genai/ingest-YYYY-MM-DD.jsonl` automatically when present.

Supported insight views: `daily`, `session`, `blocks`, `models`, `projects`, `compaction`, `comparative`, and `efficiency`.

### Local OTLP JSON collector

`runic otel-collect` gives local apps a simple OTLP/HTTP JSON endpoint for GenAI usage. It accepts JSON at `/v1/traces` and `/v1/logs`, sanitizes spans down to metric fields, and writes JSONL to Runic's default ledger. Prompt and response content is not persisted. The same process exposes one multiplexed local event stream at `/events` and `/v1/events`; use `Accept: text/event-stream` for SSE or `Accept: application/x-ndjson` for streamable HTTP.

```bash
runic otel-collect --port 4318
runic otel-collect --once --input ./otel-payload.json
cat ./otel-payload.json | runic otel-collect --once --input -
curl -N -H 'Accept: text/event-stream' http://127.0.0.1:4318/events
curl -N -H 'Accept: application/x-ndjson' http://127.0.0.1:4318/v1/events
runic insights --provider vercelai --view models --json --pretty
```

Use `--default-provider local-llm` or another provider when the upstream telemetry omits `gen_ai.system`. The collector currently supports OTLP JSON, not protobuf OTLP.

### Cost JSON payload
`runic cost --format json` emits an array of payloads (one per provider).
- `provider`, `source`, `updatedAt`
- `sessionTokens`, `sessionCostUSD`
- `last30DaysTokens`, `last30DaysCostUSD`
- `daily[]`: `date`, `inputTokens`, `outputTokens`, `cacheReadTokens`, `cacheCreationTokens`, `totalTokens`, `totalCost`, `modelsUsed`, `modelBreakdowns[]` (`modelName`, `cost`)
- `totals`: `inputTokens`, `outputTokens`, `cacheReadTokens`, `cacheCreationTokens`, `totalTokens`, `totalCost`

## Example usage
```
runic                          # text, respects app toggles
runic --provider claude        # force Claude
runic --provider all           # query all providers (honors your logins/toggles)
runic --format json --pretty   # machine output
runic --format json --provider both
runic cost                     # local cost usage (last 30 days + today)
runic cost --provider claude --format json --pretty
runic insights --provider local-llm --view models --json --pretty
runic insights --provider all --view compaction --json --pretty
runic otel-collect --port 4318
COPILOT_API_TOKEN=... runic --provider copilot --format json --pretty
runic --status                 # include status page indicator/description
runic --provider codex --source web --format json --pretty
```

### Sample output (text)
```
Codex 0.6.0 (codex-cli)
Session: 72% left
Resets today at 2:15 PM
Weekly: 41% left
Resets Fri at 9:00 AM
Credits: 112.4 left

Claude Code 2.0.58 (web)
Session: 88% left
Resets tomorrow at 1:00 AM
Weekly: 63% left
Resets Sat at 6:00 AM
Sonnet: 95% left
Account: user@example.com
Plan: Pro
```

### Sample output (JSON, pretty)
```json
{
  "provider": "codex",
  "version": "0.6.0",
  "source": "openai-web",
  "status": { "indicator": "none", "description": "Operational", "updatedAt": "2025-12-04T17:55:00Z", "url": "https://status.openai.com/" },
  "usage": {
    "primary": { "usedPercent": 28, "windowMinutes": 300, "resetsAt": "2025-12-04T19:15:00Z" },
    "secondary": { "usedPercent": 59, "windowMinutes": 10080, "resetsAt": "2025-12-05T17:00:00Z" },
    "tertiary": null,
    "updatedAt": "2025-12-04T18:10:22Z",
    "identity": {
      "providerID": "codex",
      "accountEmail": "user@example.com",
      "accountOrganization": null,
      "loginMethod": "plus"
    },
    "accountEmail": "user@example.com",
    "accountOrganization": null,
    "loginMethod": "plus"
  },
  "credits": { "remaining": 112.4, "updatedAt": "2025-12-04T18:10:21Z" },
  "antigravityPlanInfo": null,
  "openaiDashboard": {
    "signedInEmail": "user@example.com",
    "codeReviewRemainingPercent": 100,
    "creditEvents": [
      { "id": "00000000-0000-0000-0000-000000000000", "date": "2025-12-04T00:00:00Z", "service": "CLI", "creditsUsed": 123.45 }
    ],
    "dailyBreakdown": [
      {
        "day": "2025-12-04",
        "services": [{ "service": "CLI", "creditsUsed": 123.45 }],
        "totalCreditsUsed": 123.45
      }
    ],
    "updatedAt": "2025-12-04T18:10:21Z"
  }
}
```

## Exit codes
- 0: success
- 2: provider missing (binary not on PATH)
- 3: parse/format error
- 4: CLI timeout
- 1: unexpected failure

## Notes
- CLI reuses menubar toggles when present (prefers `com.sriinnu.athena.runic{,.debug}` defaults), otherwise defaults to Codex only.
- Text output uses ANSI colors when stdout is a rich TTY; disable with `--no-color` or `NO_COLOR`/`TERM=dumb`.
- Copilot CLI queries require `COPILOT_API_TOKEN` (GitHub OAuth token).
- Prefer Codex RPC first, then PTY fallback; Claude defaults to web with CLI fallback when cookies are missing.
- OpenAI web requires a signed-in `chatgpt.com` session in Safari, Chrome, or Firefox. No passwords are stored; Runic reuses cookies.
- Safari cookie import may require granting Runic Full Disk Access (System Settings → Privacy & Security → Full Disk Access).
- The `openaiDashboard` JSON field is normally sourced from the app’s cached dashboard snapshot; `--source auto|web` refreshes it live via WebKit using a per-account cookie store.
