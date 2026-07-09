---
summary: "Auggie provider data sources: Augment analytics daily-usage API with bearer token auth."
read_when:
  - Debugging Auggie usage or auth issues
  - Updating Auggie API endpoints or parsing
---

# Auggie provider

Auggie uses a bearer token to call the Augment Code analytics API for daily usage metrics. No browser cookies.

## Data sources + fallback order

1) **Augment analytics API** (`/analytics/v0/daily-usage`)
   - No fallback — single-source API strategy.

## Credentials (if applicable)

- API token resolved via `ProviderTokenResolver.auggieResolution(environment:)`
- Expected env var: `AUGMENT_API_TOKEN`
- Preferences setting: `auggie.apiToken` (stored in Keychain)

The strategy is only available when a token can be resolved — `isAvailable` returns false if no token is found.

## API endpoints / Probe mechanism

- **Strategy**: `auggie.api` (kind: `.apiToken`)
- **Base URL**: `https://api.augmentcode.com/analytics/v0/daily-usage`
- **Query params**: `window=day&days=1`
- **Timeout**: 20 seconds
- **Headers**:
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`

## Parsing + mapping

The response is parsed as a generic JSON dictionary and recursively searched for known metric keys:

- **Request count**: `requests`, `request_count`, `total_requests`
- **Input tokens**: `input_tokens`, `prompt_tokens`
- **Output tokens**: `output_tokens`, `completion_tokens`
- **Total tokens**: `total_tokens` (or computed as `input + output` fallback)

Values can be numbers or numeric strings. Summing is recursive across all nested dictionaries and arrays — the parser aggregates totals wherever the keys appear.

Snapshot shows used metrics but no quota limit — `usedPercent` is always 0, `hasKnownLimit` is false. The usage summary string shows request count and token counts.

Supports token metrics via `supportsTokenMetrics: true`.

## Key files
- `Sources/RunicCore/Providers/Auggie/AuggieProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Auggie/AuggieUsageFetcher.swift`
