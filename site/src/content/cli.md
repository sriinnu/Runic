---
title: "Runic CLI"
---

# Runic CLI

`runic` is the command-line side of Runic. It reads the same data paths as the menu bar app, so you get the same usage, cost and quota numbers in a terminal, a script, CI or a dashboard. On macOS it ships inside the app bundle at `Runic.app/Contents/Helpers/RunicCLI`; a standalone Linux build is published with each release.

## Install

| Method | How |
| --- | --- |
| From the app | **Settings → Performance → Refresh & Safety → Install CLI**. Symlinks `RunicCLI` to `/usr/local/bin/runic` and `/opt/homebrew/bin/runic`. |
| From the repo | `./bin/install-runic-cli.sh` (same symlink targets) |
| Manual | `ln -sf "/Applications/Runic.app/Contents/Helpers/RunicCLI" /usr/local/bin/runic` |
| Linux | Download `RunicCLI-<tag>-linux-<arch>.tar.gz` from [Releases](https://github.com/sriinnu/Runic/releases) (x86_64 and aarch64), extract, run `./runic`. |

Build from source: `swift build -c release --product RunicCLI` (binary at `.build/release/RunicCLI`). Needs Swift 6.2+.

## Commands

| Command | What it does |
| --- | --- |
| `runic` / `runic usage` | Current quota windows, reset times and credits per provider. Text or JSON. |
| `runic cost` | Local token cost for Claude and Codex from Runic's 30-day relay plus today's logs. No network. |
| `runic insights` | Analyze local usage logs: daily, session, blocks, models, projects, compaction, comparative, efficiency. |
| `runic otel-collect` | Local OTLP/HTTP JSON collector for GenAI telemetry from your own apps. |
| `runic mcp …` | Run and manage the local MCP server. See [MCP](/mcp/). |

Global flags: `-h/--help`, `-V/--version`, `-v/--verbose`, `--no-color`, `--log-level <trace|verbose|debug|info|warning|error|critical>`, `--json-output`.

### `runic usage`

```
runic                              # text, honours the app's provider toggles
runic --provider claude            # one provider
runic --provider all               # every enabled provider
runic --format json --pretty       # machine output
runic --status                     # include provider status pages
runic --provider codex --source web --format json --pretty
```

Options:

- `--provider <id|both|all>` — any provider ID below; `both` is Claude + Codex.
- `--format text|json`, `--json`, `--pretty`, `--no-color`.
- `--no-credits` — hide Codex credits in text output.
- `--status` — fetch provider status pages and include them.
- `--source auto|web|cli|oauth` — where to read from (macOS only for `auto`/`web`):
  - `auto` — browser cookies for Codex and Claude, CLI fallback when cookies are missing.
  - `web` — web only, no fallback.
  - `cli` — CLI only (Codex RPC → PTY fallback; Claude PTY).
  - `oauth` — Claude OAuth only, for debugging.
- `--web-timeout <seconds>` (default 60), `--web-debug-dump-html`.

Provider IDs: `codex opencode claude cursor factory gemini antigravity copilot zai glm-cn minimax minimax-cn openrouter vercelai groq deepseek fireworks mistral perplexity kimi kimi-cn stepfun stepfun-cn auggie together cohere xai cerebras sambanova azure bedrock vertexai qwen qwen-cn typesafe cline muse ollama-cloud local-llm`

Sample text output:

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
Plan: Pro
```

JSON output is one object per provider with `provider`, `version`, `source`, `status`, `usage` (`primary`, `secondary`, `tertiary` windows with `usedPercent`, `windowMinutes`, `resetsAt`), `credits`, and provider-specific extras such as `openaiDashboard`.

### `runic cost`

```
runic cost                                     # last 30 days + today
runic cost --provider claude --format json --pretty
runic cost --rebuild                           # repair the relay from JSONL history
```

JSON emits an array, one payload per provider: `provider`, `source`, `updatedAt`, `sessionTokens`, `sessionCostUSD`, `last30DaysTokens`, `last30DaysCostUSD`, `daily[]` (per-day token split, `totalCost`, `modelsUsed`, `modelBreakdowns[]`) and `totals`.

### `runic insights`

```
runic insights --provider claude --view daily
runic insights --provider all --view models --json --pretty
runic insights --provider local-llm --view models --json --pretty
runic insights --view projects --budget
runic insights --view session --with-commits --git-directory ~/code/app/.git
```

Options: `--provider`, `--view`, `--project`, `--timezone`, `--granularity hourly` (daily view), `--git-directory`, `--budget` (projects view), `--with-commits` (links entries to commits in a 5-minute window), `--json`, `--pretty`.

Claude and Codex are read from their local JSONL ledgers. Other providers, including `local-llm`, come in through OpenTelemetry GenAI JSON/JSONL files configured with `RUNIC_OTEL_GENAI_LOG_PATHS` (or a provider-specific variable such as `RUNIC_LOCAL_LLM_OTEL_GENAI_LOG_PATHS`), and from the collector's own daily ledgers at `~/Library/Application Support/Runic/otel-genai/`.

### `runic otel-collect`

A small local OTLP/HTTP JSON endpoint so your own apps can report GenAI usage to Runic. Accepts JSON at `/v1/traces` and `/v1/logs`, keeps only metric fields (tokens, model, project), and never persists prompt or response content. The same process serves a local event stream at `/events` and `/v1/events` (SSE with `Accept: text/event-stream`, NDJSON with `Accept: application/x-ndjson`).

```
runic otel-collect --port 4318
runic otel-collect --once --input ./otel-payload.json
cat payload.json | runic otel-collect --once --input -
curl -N -H 'Accept: text/event-stream' http://127.0.0.1:4318/events
```

Options: `--port` (default 4318), `--host` (default 127.0.0.1), `--output`, `--input`, `--default-provider` (when telemetry omits `gen_ai.system`), `--once`. OTLP JSON only, not protobuf.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | success |
| 1 | unexpected failure |
| 2 | provider binary not on PATH |
| 3 | parse or format error |
| 4 | CLI timeout |

## Notes

- The CLI reuses the app's provider toggles when present; otherwise it defaults to Codex only.
- ANSI colour is on when stdout is a TTY; off with `--no-color`, `NO_COLOR` or `TERM=dumb`.
- Copilot needs `COPILOT_API_TOKEN` (GitHub OAuth token).
- OpenAI web reads need a signed-in `chatgpt.com` session in Safari, Chrome or Firefox. Runic reuses cookies; it never stores passwords. Safari cookie import may need Full Disk Access.
- On Linux, `--source web` and `auto` are not available; the CLI exits non-zero.
