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
| Kimi / Kimi (China) | API key (Keychain/env) → Moonshot balance API on `api.moonshot.ai` / `api.moonshot.cn` (`api`); optional custom gateway on the international slot. |
| z.ai (China) | API key (Keychain/env) → `open.bigmodel.cn` monitor API mirrored from z.ai (`api`). |
| MiniMax (China) | API key (Keychain/env) → `minimaxi.com` token-plan API (`api`); no web fallback on the China slot. |
| Qwen / Qwen (China) | API key (Keychain/env) → DashScope usage API (`api`, plan-dependent: token/coding plans 404 and usage comes from coding-tool logs); optional base URL per slot. |
| StepFun / StepFun (China) | API key (Keychain/env) → `/v1/accounts` balance on `api.stepfun.ai` / `api.stepfun.com` (`api`; response parsed defensively). |
| DeepSeek | API key (Keychain/env) → balance API (`api`). |
| opencode | Local session logs (`local`); history-only, no live gauge. |
| Local LLM | Local runtime probe for Ollama/LM Studio/vLLM/llama.cpp/Open WebUI (`local`); usage comes from OpenTelemetry GenAI or local logs when configured. |

## Capability metadata

Usage fetch strategies answer "what did this account use?" Capability metadata answers "what can this model/provider support?" Runic reads Kosha-discovery 1.2.0's local schema-v1 registry at `~/.kosha/registry.json` for model context windows when available, marks records older than 24 hours as stale, and falls back to `Sources/Runic/Resources/provider-context-windows.json`. It does not call provider APIs from menu rendering.

## Shared usage ledger

Claude and Codex have first-class local JSONL scanners, but normal refreshes treat provider logs as a today-only live feed. Runic stores normalized usage events and scan watermarks in its own relay JSONL files under `~/Library/Application Support/Runic/relay/`, materializes daily totals from the newest snapshot for each day, then merges that view with today's live scan for menu, CLI cost, and history charts. Historical provider JSONLs are only reopened by the explicit repair path, `runic cost --rebuild`. All other built-in providers, including Local LLM, can contribute model/project/token/cost history through configured OpenTelemetry GenAI JSON or JSONL files, plus Runic's default sanitized local collector ledger:

- Shared env: `RUNIC_OTEL_GENAI_LOG_PATHS` or `RUNIC_OTEL_GENAI_LOG_PATH`.
- Provider env: `RUNIC_<PROVIDER>_OTEL_GENAI_LOG_PATHS`, `RUNIC_<PROVIDER>_OTEL_GENAI_LOG_PATH`, `RUNIC_<PROVIDER>_OTEL_LOG_PATHS`, or `RUNIC_<PROVIDER>_OTEL_LOG_PATH`.
- Provider names use uppercase raw values with dashes converted to underscores, for example `RUNIC_LOCAL_LLM_OTEL_GENAI_LOG_PATHS`.
- Default collector ledger: `~/Library/Application Support/Runic/otel-genai/ingest-YYYY-MM-DD.jsonl`.

Ledger entries carry token/cost provenance where known: exact local log, provider-reported telemetry, estimated pricing table, inferred cumulative counter, or unknown. Runic only marks compaction tax when the source explicitly flags compaction/compact work; it does not infer semantic context loss.

`runic otel-collect` accepts OTLP/HTTP JSON at `/v1/traces` and `/v1/logs`. The collector persists sanitized metric JSONL only: provider, model, timestamp, token/cache counts, project/session/request/message IDs, explicit cost, SDK version, and explicit operation kind. It does not write prompt or response bodies.

## Codex
- Web dashboard (when enabled): `https://chatgpt.com/codex/settings/usage` via WebView + browser cookies.
- CLI RPC default: `codex ... app-server` JSON-RPC (`account/read`, `account/rateLimits/read`).
- CLI PTY fallback: `/status` scrape.
- Local cost usage: scans today's `~/.codex/sessions/YYYY/MM/DD/*.jsonl`; older days come from Runic event relay history.
- Status: Statuspage.io (OpenAI).
- Details: `docs/codex.md`.

## Claude
- OAuth API (preferred when CLI credentials exist).
- Web API (browser cookies) fallback when OAuth missing.
- CLI PTY fallback when OAuth + web are unavailable.
- Local cost usage: scans Claude project files touched today; older days come from Runic event relay history.
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

## Regional pairs (China / international)
Kimi, z.ai, MiniMax, Qwen, and StepFun run separate platforms for mainland China and the rest of the world — separate accounts, keys, and hosts — so each China platform is its own `UsageProvider` slot (`kimiCN`, `zaiCN`, `minimaxCN`, `qwenCN`, `stepfunCN`). `UsageProvider.chinaSibling` / `regionalParent` in RunicCore is the single pairing table; provider order pins a China slot directly after its sibling, the Providers pane shows one row per brand (nested in list layout, an International | China switch in the sidebar), the menu switcher labels them "Kimi CN" style, and a China slot stays out of the menu until it has a key. Env vars: `KIMI_CN_API_KEY`, `BIGMODEL_API_KEY`, `MINIMAXI_API_KEY`, `DASHSCOPE_CN_API_KEY`, `STEPFUN_API_KEY`, `STEPFUN_CN_API_KEY`. Details: `docs/kimi-cn.md`, `docs/glm-cn.md`, `docs/minimax-cn.md`, `docs/qwen-cn.md`, `docs/stepfun.md`, `docs/stepfun-cn.md`.

## Auto-enable
A provider the user never toggled switches on when evidence appears: an API key in the environment at launch (Copilot excluded — its resolver accepts a generic `GITHUB_TOKEN`), a key saved in Preferences, or usage attributed to it from coding-tool logs. A saved "off" is never overridden. Keychain reads at launch are deliberately skipped (see `RunicKeychainAccessPolicy`).

## Local LLM
- No API key.
- Runtime discovery probes localhost endpoints for Ollama (`11434`), LM Studio (`1234`), vLLM (`8000`), llama.cpp (`8080`), and Open WebUI (`3000`).
- Status shows discovered runtime/model count. Token/cost usage stays empty unless local logs, OpenTelemetry GenAI files, or the local collector expose usage.
- API cost is not applicable; any spend shown for Local LLM must come from an explicit telemetry/log field or a future configured local pricing source.

See also: `docs/provider.md` for architecture notes.
