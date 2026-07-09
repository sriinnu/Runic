---
summary: "OpenRouter provider data sources: API token in Keychain/env, credits + key-info API endpoints."
read_when:
  - Debugging OpenRouter usage or auth issues
  - Updating OpenRouter API endpoints or parsing
---

# OpenRouter provider

OpenRouter is API-token based. No browser cookies.

## Data sources + fallback order

1) **Credits API** (primary)
   - `GET https://openrouter.ai/api/v1/credits`
   - Returns total credits purchased, total usage, and remaining balance.
   - Used to compute a usage percentage and a credits snapshot.

2) **Key info API** (best-effort, parallel)
   - `GET https://openrouter.ai/api/v1/auth/key`
   - Returns key metadata: label, free-tier flag, rate-limit details.
   - Runs in parallel with the credits call; failures are silently ignored.
   - Populates `ProviderIdentitySnapshot` with tier/label/rate-limit info.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `openrouter-api-token`

### Environment variable
- `OPENROUTER_API_KEY`

Fallback order: Keychain first, then environment.

### Token store
- `Sources/Runic/Core/Stores/OpenRouterTokenStore.swift` — reads/writes/deletes the Keychain item with `kSecAttrAccessibleAfterFirstUnlock`, supports migration from the Data Protection keychain.

## API endpoints

### `GET https://openrouter.ai/api/v1/credits`
- Headers:
  - `Authorization: Bearer <api_key>`
  - `Content-Type: application/json`
- Timeout: 15 seconds

### `GET https://openrouter.ai/api/v1/auth/key`
- Headers:
  - `Authorization: Bearer <api_key>`
  - `Content-Type: application/json`
- Timeout: 15 seconds
- Best-effort: errors are logged and the response is treated as `nil`.

## Parsing + mapping

### Credits response (`OpenRouterCreditsResponse`)
- `data.total_credits` (or `data.credits`, or top-level `credits`) -> total credits purchased.
- `data.total_usage` -> total credits consumed.
- `remaining = max(0, totalCredits - totalUsage)`.
- `usedPercent = (totalUsage / totalCredits) * 100`, clamped 0-100.

### Key-info response (`OpenRouterKeyInfoResponse`)
- `data.label` -> key label.
- `data.is_free_tier` -> "Free tier" tag if true.
- `data.rate_limit.requests` + `data.rate_limit.interval` -> "N req/interval" string.
- These are joined into `ProviderIdentitySnapshot.loginMethod`.

### Snapshot mapping (`toUsageSnapshot`)
- Primary: `RateWindow` with `usedPercent` from credits, `windowMinutes: nil`, `resetsAt: nil`, `resetDescription` showing balance + spent amounts.
- Secondary: `nil`.
- Tertiary: `nil`.
- Identity: provider ID `.openrouter` with login method string from key info.
- Also produces a `CreditsSnapshot` with `remaining` balance.

## Key files
- `Sources/RunicCore/Providers/OpenRouter/OpenRouterProviderDescriptor.swift`
- `Sources/RunicCore/Providers/OpenRouter/OpenRouterUsageFetcher.swift`
- `Sources/Runic/Core/Stores/OpenRouterTokenStore.swift`
