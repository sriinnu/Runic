---
title: "Providers"
---

# Providers

How Runic learns what each provider has used. This is the summary; the per-provider detail is `docs/providers.md` and `docs/<provider>.md` in the repo, which is the source of truth.

Runic tries a provider's strategies **in order** and uses the first that answers. The source label shown in the CLI and in Settings → Providers is one of `openai-web`, `web`, `oauth`, `api`, `local`, `openTelemetry`, or a provider CLI label such as `codex-cli` or `claude`.

## Subscription tools

| Provider | Strategies, in order | Notes |
| --- | --- | --- |
| Codex | Web dashboard → CLI RPC → CLI PTY `/status` | Today's cost comes from `~/.codex/sessions`; older days from the relay. |
| Claude | OAuth API → web API → CLI PTY | See [Claude](/claude/). |
| Gemini | OAuth via the Gemini CLI's credentials | |
| Cursor | Browser cookies → stored WebKit session | On-demand spend shown without a gauge when the plan is unlimited. |
| Droid / Factory | Cookies → stored tokens → local storage → WorkOS | |
| Copilot | Device-flow token → `copilot_internal` API | |
| Antigravity | Local LSP / HTTP probe | |
| Muse Code (Meta) | Local `muse` CLI `/usage` | An explicit API mode uses a pay-as-you-go key. |
| opencode | Local session logs | History only, no live gauge. |

## Keys and balances

| Provider | Source | What you see |
| --- | --- | --- |
| DeepSeek, Kimi, StepFun, OpenRouter, Vercel AI | API key → balance API | Balance, plus spend derived from readings taken every 20 minutes; a "From logs" estimate where the provider can be routed through a coding tool. |
| z.ai, MiniMax, Qwen | API key or web session → quota API | Quota windows. Qwen token and coding plans report usage from local coding-tool logs. |
| Cline | API key → `api.cline.bot` | Credit balance and exact spend today and this month. |
| Ollama Cloud | API key → `ollama.com/api/usage` | Monthly credits, or session and weekly limits. Undocumented, parsed defensively. |
| TypeSafe | API key → `/v1/models` | Key health only; the published API reports no usage. |
| Local LLM | Runtime probe (Ollama, LM Studio, vLLM, llama.cpp, Open WebUI) | Usage comes from OpenTelemetry GenAI or local logs when configured. |

## Two regions

China and international are **separate providers**, not a setting: Kimi, z.ai, MiniMax, Qwen and StepFun each have a CN slot. The tab strip shows one tab per brand and the card stacks a section per configured region, with an "Add China account" or "Add International account" row for the other side.

## Credentials

Keys live in your login Keychain. Runic-signed builds are the only binaries that touch it; the CLI and unsigned test builds read environment variables instead. Nothing is sent anywhere except the provider's own API.
