---
summary: "xAI provider data sources: API key in Keychain/env and model listing from xAI (Grok) API."
read_when:
  - Debugging xAI token storage or model display
  - Updating xAI API endpoints or parsing
---

# xAI provider

xAI (Grok) is API-token based. No browser cookies. No usage quota -- shows model availability only.

## Data sources + fallback order

1) **API token** (single source, one fetch strategy).

## Credentials

Token resolution order:
1) Keychain token (stored from Preferences).
2) Environment variable `XAI_API_KEY`.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `xai-api-token`

## API endpoints

- `GET https://api.x.ai/v1/models`
- Headers:
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`

## Parsing + mapping

- Response: `data[]` -- each entry has an `id` (model name string).
- Snapshot: `usedPercent: 0`, `hasKnownLimit: false`. The snapshot surfaces a model count and a preview of the first 3 model names in the reset description.
- No window computation, no reset time, no percentage -- this is an availability check, not a usage meter.
- No model or plan detection beyond listing model IDs.
- CLI aliases: `grok` (in addition to `xai`).

## Key files
- `Sources/RunicCore/Providers/XAI/XAIProviderDescriptor.swift`
- `Sources/RunicCore/Providers/XAI/XAIUsageFetcher.swift`
