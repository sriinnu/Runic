---
summary: "Provider data sources and parsing overview, including shared OpenTelemetry usage ingestion and Local LLM discovery."
read_when:
  - Adding or modifying provider fetch/parsing
  - Adjusting provider labels, toggles, or metadata
  - Reviewing data sources for providers
---

# Providers

## Fetch strategies (current)
Legend: web (browser cookies/WebView), cli (RPC/PTy), oauth (API), api token, local probe, web dashboard.
Source labels (CLI/header): `openai-web`, `web`, `oauth`, `api`, `local`, `openTelemetry`, plus provider-specific CLI labels (e.g. `codex-cli`, `claude`).

| Provider | Strategies (ordered for auto) |
| --- | --- |
| Codex | Web dashboard (`openai-web`) → CLI RPC/PTy (`codex-cli`); app uses CLI usage + optional dashboard scrape. |
| Claude | OAuth API (`oauth`) → Web API (`web`) → CLI PTY (`claude`). |
| Gemini | OAuth API via Gemini CLI credentials (`api`). |
| Antigravity | Local LSP/HTTP probe (`local`). |
| Cursor | Web API via cookies → stored WebKit session (`web`). |
| Droid/Factory | Web cookies → stored tokens → local storage → WorkOS cookies (`web`). |
| MiniMax | Web cookies + Chromium local storage token (`web`). |
| z.ai | API token (Keychain/env) → quota API (`api`). |
| Copilot | API token (device flow/env) → copilot_internal API (`api`). |
| Vercel AI | API token (Keychain/env) → AI Gateway credits API (`api`). |
| Local LLM | Local runtime probe for Ollama/LM Studio/vLLM/llama.cpp/Open WebUI (`local`); usage comes from OpenTelemetry GenAI or local logs when configured. |

## Capability metadata

Usage fetch strategies answer "what did this account use?" Capability metadata answers "what can this model/provider support?" Runic reads Kosha-discovery 1.2.0's local schema-v1 registry at `~/.kosha/registry.json` for model context windows when available, marks records older than 24 hours as stale, and falls back to `Sources/Runic/Resources/provider-context-windows.json`. It does not call provider APIs from menu rendering.

## Shared usage ledger

Claude and Codex have first-class local JSONL scanners. All other built-in providers, including Local LLM, can contribute model/project/token/cost history through configured OpenTelemetry GenAI JSON or JSONL files, plus Runic's default sanitized local collector ledger:

- Shared env: `RUNIC_OTEL_GENAI_LOG_PATHS` or `RUNIC_OTEL_GENAI_LOG_PATH`.
- Provider env: `RUNIC_<PROVIDER>_OTEL_GENAI_LOG_PATHS`, `RUNIC_<PROVIDER>_OTEL_GENAI_LOG_PATH`, `RUNIC_<PROVIDER>_OTEL_LOG_PATHS`, or `RUNIC_<PROVIDER>_OTEL_LOG_PATH`.
- Provider names use uppercase raw values with dashes converted to underscores, for example `RUNIC_LOCAL_LLM_OTEL_GENAI_LOG_PATHS`.
- Default collector ledger: `~/Library/Application Support/Runic/otel-genai/ingest.jsonl`.

Ledger entries carry token/cost provenance where known: exact local log, provider-reported telemetry, estimated pricing table, inferred cumulative counter, or unknown. Runic only marks compaction tax when the source explicitly flags compaction/compact work; it does not infer semantic context loss.

`runic otel-collect` accepts OTLP/HTTP JSON at `/v1/traces` and `/v1/logs`. The collector persists sanitized metric JSONL only: provider, model, timestamp, token/cache counts, project/session/request/message IDs, explicit cost, SDK version, and explicit operation kind. It does not write prompt or response bodies.

## Codex
- Web dashboard (when enabled): `https://chatgpt.com/codex/settings/usage` via WebView + browser cookies.
- CLI RPC default: `codex ... app-server` JSON-RPC (`account/read`, `account/rateLimits/read`).
- CLI PTY fallback: `/status` scrape.
- Local cost usage: scans `~/.codex/sessions/**/*.jsonl` (last 30 days).
- Status: Statuspage.io (OpenAI).
- Details: `docs/codex.md`.

## Claude
- OAuth API (preferred when CLI credentials exist).
- Web API (browser cookies) fallback when OAuth missing.
- CLI PTY fallback when OAuth + web are unavailable.
- Local cost usage: scans `~/.config/claude/projects/**/*.jsonl` (last 30 days).
- Status: Statuspage.io (Anthropic).
- Details: `docs/claude.md`.

## z.ai
- API token from Keychain or `Z_AI_API_KEY` env var.
- `GET https://api.z.ai/api/monitor/usage/quota/limit`.
- Status: none yet.
- Details: `docs/zai.md`.

## Gemini
- OAuth-backed quota API (`retrieveUserQuota`) using Gemini CLI credentials.
- Token refresh via Google OAuth if expired.
- Tier detection via `loadCodeAssist`.
- Status: Google Workspace incidents (Gemini product).
- Details: `docs/gemini.md`.

## Antigravity
- Local Antigravity language server (internal protocol, HTTPS on localhost).
- `GetUserStatus` primary; `GetCommandModelConfigs` fallback.
- Status: Google Workspace incidents (Gemini product).

## Cursor
- Web API via browser cookies (`cursor.com` + `cursor.sh`).
- Fallback: stored WebKit session.
- Status: Statuspage.io (Cursor).

## Droid (Factory)
- Web API via Factory cookies, bearer tokens, and WorkOS refresh tokens.
- Multiple fallback strategies (cookies → stored tokens → local storage → WorkOS cookies).
- Status: `https://status.factory.ai`.

## MiniMax
- Web-only. Uses browser cookies plus a Chromium local storage access token.
- Primary endpoint: `https://platform.minimax.io/user-center/payment/coding-plan` (HTML parse).
- Fallback endpoint: `https://platform.minimax.io/v1/api/openplatform/coding_plan/remains`.
- Status: none yet.

## Copilot
- GitHub device flow OAuth token + `api.github.com/copilot_internal/user`.
- Status: Statuspage.io (GitHub).
- Details: `docs/copilot.md`.

## Vercel AI
- API token from Keychain, `AI_GATEWAY_API_KEY`, or `VERCEL_OIDC_TOKEN`.
- Credits endpoint: `GET https://ai-gateway.vercel.sh/v1/credits`.
- Model availability endpoint: `GET https://ai-gateway.vercel.sh/v1/models` (best effort).
- Status: none yet.

## Local LLM
- No API key.
- Runtime discovery probes localhost endpoints for Ollama (`11434`), LM Studio (`1234`), vLLM (`8000`), llama.cpp (`8080`), and Open WebUI (`3000`).
- Status shows discovered runtime/model count. Token/cost usage stays empty unless local logs, OpenTelemetry GenAI files, or the local collector expose usage.
- API cost is not applicable; any spend shown for Local LLM must come from an explicit telemetry/log field or a future configured local pricing source.

See also: `docs/provider.md` for architecture notes.
