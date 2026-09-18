---
summary: "TypeSafe (Jev) provider data sources: API key in Keychain/env and models list API response parsing."
read_when:
  - Debugging TypeSafe key auth or model listing
  - Revisiting TypeSafe usage reporting if the API ever exposes spend
---

# TypeSafe provider

TypeSafe (the vendor of the Jev System One model) is API-key based. No browser cookies.

## What this provider can and cannot show

TypeSafe exposes **no usage, billing, credits, or quota endpoint**. Probed 2026-09-18 with a
live key: `GET /v1/models` answers `200`; `/v1/usage`, `/v1/account`, `/v1/credits`,
`/v1/billing`, `/v1/limits`, `/v1/me`, `/v1/organization` all return `404 {"detail":"Not Found"}`.
Token spend is reported per-response (`usage.input_tokens` / `usage.output_tokens`) to the caller
that made the request, and aggregated only in the web console.

So this tile is a **key-health + model-availability** tile, not a spend tile:
`supportsTokenCost: false`, `supportsTokenMetrics: false`, `hasKnownLimit: false`.
The dashboard link goes to the console's Usage page. If TypeSafe ships a usage endpoint later,
`TypeSafeUsageFetcher` is the only file that needs to change.

Rate limits are tokens/second and requests/minute; over-limit requests get `429` with
`retry-after`. There is no endpoint to read the limits themselves.

## Data sources + fallback order

1) **Models API** (sole source)
   - `GET https://api.typesafe.ai/v1/models`
   - Lists the models the authenticated account may send in the `model` field.
   - The snapshot shows model count with a preview of the first three names.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `typesafe-api-token`

### Environment variables
- `TYPESAFE_API_KEY` (what the official SDKs read)
- `JEV_API_KEY` (accepted too — the key is commonly filed under the model's name)

Fallback order: Keychain first, then `TYPESAFE_API_KEY`, then `JEV_API_KEY`.

Note: a `JEV_API_KEY` generic-password item created by `/usr/bin/security` is ACL-bound to
`security`, not to Runic, so reading it from the app would raise a Keychain authorization
dialog. Paste the key into Preferences → Providers → TypeSafe instead — that writes Runic's
own item under the service above, which the app owns and never gets prompted for.

### Token store
- `Sources/Runic/Core/Stores/TypeSafeTokenStore.swift` — reads/writes/deletes the Keychain item with `kSecAttrAccessibleAfterFirstUnlock`, supports migration from the Data Protection keychain.

## API endpoint

### `GET https://api.typesafe.ai/v1/models`
- Headers:
  - `Authorization: Bearer <api_key>`
  - `Content-Type: application/json`

## Parsing + mapping

### Models response (`TypeSafeModelsResponse`)
- `models[]` — array of model cards.
  - `name` — model identifier (e.g. `jev-latest`, `jev-1.13.0`).
  - `description`, `release_date` — decoded but unused by the snapshot.

### Snapshot mapping (`toUsageSnapshot`)
- Extracts names from `models[].name`, counts them.
- Builds a summary string: `"Models available: N"` plus a preview of the first 3 names.
- Primary: `RateWindow` with `usedPercent: 0`, `hasKnownLimit: false`, `windowMinutes: nil`, `resetsAt: nil`, `resetDescription` set to the summary string.
- Secondary / Tertiary / Identity: `nil`.

## Key files
- `Sources/RunicCore/Providers/TypeSafe/TypeSafeProviderDescriptor.swift`
- `Sources/RunicCore/Providers/TypeSafe/TypeSafeUsageFetcher.swift`
- `Sources/Runic/Core/Stores/TypeSafeTokenStore.swift`
