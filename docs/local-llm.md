---
summary: "Local LLM provider data sources: localhost HTTP probes to Ollama, LM Studio, vLLM, llama.cpp, Open WebUI."
read_when:
  - Debugging Local LLM detection or model reporting
  - Adding a new local runtime endpoint
---

# Local LLM provider

Local LLM probes known localhost endpoints for running AI runtimes. No credentials, no browser cookies — detection is purely local HTTP.

## Data sources + fallback order

1) **Localhost HTTP probes** (tried in order, first success wins):
   1. **Ollama** — `GET http://127.0.0.1:11434/api/tags` (Ollama-specific response format)
   2. **LM Studio** — `GET http://127.0.0.1:1234/v1/models` (OpenAI-compatible format)
   3. **vLLM** — `GET http://127.0.0.1:8000/v1/models` (OpenAI-compatible format)
   4. **llama.cpp** — `GET http://127.0.0.1:8080/v1/models` (OpenAI-compatible format)
   5. **Open WebUI** — `GET http://127.0.0.1:3000/api/models` (OpenAI-compatible format)

## Credentials (if applicable)

None — all endpoints are unauthenticated localhost.

## API endpoints / Probe mechanism

- **Strategy**: `local-llm.local` (kind: `.localProbe`)
- **Request timeout**: 1.5 seconds per endpoint
- **Headers**: `Accept: application/json`
- Probes endpoints sequentially; stops at the first responding runtime.

## Parsing + mapping

Two response formats are handled:

**Ollama** (`/api/tags`):
- `models[]` with `name` or `model` fields
- Model names deduplicated case-insensitively, sorted alphabetically

**OpenAI-compatible** (`/v1/models` or `/api/models`):
- `data[]` with `id` or `name` fields
- Same deduplication + sort logic

Snapshot shows:
- Primary window: runtime name + model count + first model name (or "No models reported")
- No quota/rate-limit windows — `usedPercent` is always 0, `hasKnownLimit` is false
- Identity: provider ID `.localLLM`, base URL as organization, runtime name as login method

Supports model breakdown (`supportsModelBreakdown: true`), token metrics (`supportsTokenMetrics: true`), and project attribution (`supportsProjectAttribution: true`).

## Key files
- `Sources/RunicCore/Providers/LocalLLM/LocalLLMProviderDescriptor.swift`
