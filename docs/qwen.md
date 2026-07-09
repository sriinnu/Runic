---
summary: "Qwen provider data sources: DashScope API key in Keychain/env and per-model token usage from DashScope usage API."
read_when:
  - Debugging Qwen token storage or usage parsing
  - Updating DashScope API endpoints or pricing table
---

# Qwen provider

Qwen (DashScope / Alibaba Cloud) is API-token based. No browser cookies. Fetches per-model token consumption with estimated USD cost.

## Data sources + fallback order

1) **API token** (single source, one fetch strategy).

## Credentials

Token resolution order:
1) Keychain token (stored from Preferences).
2) Environment variable `DASHSCOPE_API_KEY`.

The env var value is cleaned by `QwenSettingsReader`: whitespace trimmed, surrounding quotes stripped.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `qwen-api-token`

## API endpoints

- `GET https://dashscope.aliyuncs.com/api/v1/usage`
- Headers:
  - `Authorization: Bearer <token>`
  - `Accept: application/json`
  - `Content-Type: application/json`
- Timeout: 15 seconds.

## Parsing + mapping

### Response structure

Top-level response (`QwenUsageResponse`):
- `code` -- success check (`nil`, `"200"`, or `"Success"`).
- `message` -- error message on failure.
- `output` -- main usage payload (preferred).
- `usage` -- alternative usage payload (fallback).

Per-model entries from `output.models[]` (or `usage.models[]`):
- `model_id` / `model` -- model identifier.
- `input_tokens`, `output_tokens` -- per-direction token counts.
- `total_tokens` / `tokens` -- total tokens (computed as input+output if both nil).
- `request_count` / `requests` / `calls` -- request count.

### Totals

API-reported totals (preferred over summing model entries):
- `output.total_input_tokens` / `usage.input_tokens` -- total input tokens.
- `output.total_output_tokens` / `usage.output_tokens` -- total output tokens.
- `output.total_tokens` / `usage.total_tokens` -- total tokens.

### Cost estimation

Static pricing table (`QwenModelPricing`) covers 18 models including qwen-turbo, qwen-plus, qwen-max, qwen-vl-*, qwen-long, qwen2.5-* (7b/14b/32b/72b), and qwen2.5-coder-*. Pricing lookup is case-insensitive with fuzzy substring matching as a fallback.

Cost formula: `(input_tokens / 1M) * input_price + (output_tokens / 1M) * output_price`. When only total tokens are available, a 60/40 input/output split is assumed.

### Usage snapshot

- `usedPercent: 0`, `hasKnownLimit: false` -- DashScope reports consumption with no hard cap, so there is no denominator for a percentage.
- Summary text: formatted token count + request count + estimated USD cost (e.g., "12.5K tokens · 47 req · ~$0.03 est.").
- Model entries sorted by total tokens descending for per-model breakdown.

## Key files
- `Sources/RunicCore/Providers/Qwen/QwenProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Qwen/QwenSettingsReader.swift`
- `Sources/RunicCore/Providers/Qwen/QwenUsageStats.swift`
