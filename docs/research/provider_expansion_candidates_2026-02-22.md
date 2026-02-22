# Provider Expansion Candidates (2026-02-22)

## Scope

Runic currently tracks: codex, claude, cursor, factory, gemini, antigravity, copilot, zai, minimax, openrouter, groq.

This note identifies additional providers or higher-fidelity data paths with primary-source evidence and implementation fit.

## High-Priority Additions

### 1) Perplexity API
- Why: Official OpenAI-compatible chat/completions endpoint with explicit `usage` object in response.
- Integration path:
  - Auth: API key (Keychain + env fallback)
  - Data: response `usage.prompt_tokens`, `usage.completion_tokens`, `usage.total_tokens`
  - UX: token usage now; spend estimate via local pricing table until billing endpoint is available
- Source:
  - https://docs.perplexity.ai/api-reference/chat-completions-post

### 2) Fireworks AI
- Why: Chat completions API documents a detailed `usage` object, including cached token fields.
- Integration path:
  - Auth: API key
  - Data: `usage.prompt_tokens`, `completion_tokens`, `total_tokens`, cached token details
  - UX: supports richer efficiency metrics (cache hit behavior)
- Source:
  - https://docs.fireworks.ai/api-reference/post-chatcompletions

### 3) DeepSeek API
- Why: API reference includes standard `usage` token fields on chat completion responses.
- Integration path:
  - Auth: API key
  - Data: prompt/completion/total token counters
  - UX: direct compatibility with existing token-based insight pipeline
- Source:
  - https://api-docs.deepseek.com/api/create-chat-completion

### 4) Anthropic Org Cost Path (for Claude)
- Why: Official Admin Usage & Cost API can provide authoritative org-level usage/cost.
- Integration path:
  - Keep existing Claude CLI/Web probes
  - Add optional enterprise path for org admins via Anthropic Admin API
- Source:
  - https://docs.anthropic.com/en/api/usage-cost-api

## Existing Provider Upgrade Opportunity

### OpenRouter (already in Runic): credits + limits enhancement
- Why: Official endpoint provides credits/limits model that can improve remaining/budget accuracy.
- Integration path:
  - Enhance current OpenRouter provider with direct credits fetch and tighter budget telemetry
- Source:
  - https://openrouter.ai/docs/api-reference/limits-and-credits/get-credits

## Medium-Priority (Needs Validation)

### Mistral API
- Known signal: official docs expose enterprise-focused limits/rate-limits pages.
- Gap: we still need a stable public usage/cost endpoint for robust quota accounting.
- Source:
  - https://docs.mistral.ai/deployment/laplateforme/tier/

## Security and Performance Guardrails

- Security:
  - API keys only in Keychain/env; never persisted in plaintext logs
  - Calendar/history views must use aggregated local data only (no raw prompt payloads)
  - Diagnostics copy paths must redact secrets
- Performance:
  - On-demand month fetches only (no always-on scans)
  - TTL cache for month snapshots
  - bounded scan windows (e.g., 90–180 days max)

## Suggested Execution Order

1. Perplexity
2. Fireworks
3. DeepSeek
4. OpenRouter credits enhancement
5. Anthropic Admin usage-cost optional path
