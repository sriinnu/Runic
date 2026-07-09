---
summary: "Groq provider data sources: API token in Keychain/env and models list API response parsing."
read_when:
  - Debugging Groq model listing or auth issues
  - Updating Groq API endpoints
---

# Groq provider

Groq is API-token based. No browser cookies.

## Data sources + fallback order

1) **Models API** (sole source)
   - `GET https://api.groq.com/openai/v1/models`
   - Lists available models for the authenticated account.
   - The snapshot shows model count with a preview of the first three model IDs.
   - No usage quota is exposed; `hasKnownLimit` is `false`.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `groq-api-token`

### Environment variable
- `GROQ_API_KEY`

Fallback order: Keychain first, then environment.

### Token store
- `Sources/Runic/Core/Stores/GroqTokenStore.swift` — reads/writes/deletes the Keychain item with `kSecAttrAccessibleAfterFirstUnlock`, supports migration from the Data Protection keychain.

## API endpoint

### `GET https://api.groq.com/openai/v1/models`
- Headers:
  - `Authorization: Bearer <api_key>`
  - `Content-Type: application/json`

## Parsing + mapping

### Models response (`GroqModelsResponse`)
- `data[]` — array of model objects.
  - `id` — model identifier string.

### Snapshot mapping (`toUsageSnapshot`)
- Extracts model IDs from `data[].id`, counts them.
- Builds a summary string: `"Models available: N"` plus a preview of the first 3 IDs.
- Primary: `RateWindow` with `usedPercent: 0`, `hasKnownLimit: false`, `windowMinutes: nil`, `resetsAt: nil`, `resetDescription` set to the summary string.
- Secondary: `nil`.
- Tertiary: `nil`.
- Identity: `nil`.

## Key files
- `Sources/RunicCore/Providers/Groq/GroqProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Groq/GroqUsageFetcher.swift`
- `Sources/Runic/Core/Stores/GroqTokenStore.swift`
