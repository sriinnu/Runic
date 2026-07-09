---
summary: "Cohere provider data sources: API key in Keychain/env and model listing from Cohere API."
read_when:
  - Debugging Cohere token storage or model display
  - Updating Cohere API endpoints or parsing
---

# Cohere provider

Cohere is API-token based. No browser cookies. No usage quota -- shows model availability only.

## Data sources + fallback order

1) **API token** (single source, one fetch strategy).

## Credentials

Token resolution order:
1) Keychain token (stored from Preferences).
2) Environment variable `COHERE_API_KEY`.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `cohere-api-token`

## API endpoints

- `GET https://api.cohere.ai/v1/models`
- Headers:
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`

## Parsing + mapping

- Response: model records read from both `models[]` and `data[]` fields (combined).
- Each record: model ID resolved from `id` or `name` (first non-nil, trimmed).
- Snapshot: `usedPercent: 0`, `hasKnownLimit: false`. The snapshot surfaces a model count and a preview of the first 3 model names in the reset description.
- No window computation, no reset time, no percentage -- this is an availability check, not a usage meter.
- No model or plan detection beyond listing model IDs.

## Key files
- `Sources/RunicCore/Providers/Cohere/CohereProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Cohere/CohereUsageFetcher.swift`
