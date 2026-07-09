---
summary: "DeepSeek provider data sources: API token in Keychain/env and balance API response parsing."
read_when:
  - Debugging DeepSeek balance or auth issues
  - Updating DeepSeek API endpoints
---

# DeepSeek provider

DeepSeek is API-token based. No browser cookies.

## Data sources + fallback order

1) **Balance API** (sole source)
   - `GET https://api.deepseek.com/user/balance`
   - Returns balance information per currency.
   - No usage limit is exposed, so the snapshot shows the balance text with `hasKnownLimit: false`.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `deepseek-api-token`

### Environment variable
- `DEEPSEEK_API_KEY`

Fallback order: Keychain first, then environment.

### Token store
- `Sources/Runic/Core/Stores/DeepSeekTokenStore.swift` — reads/writes/deletes the Keychain item with `kSecAttrAccessibleAfterFirstUnlock`, supports migration from the Data Protection keychain.

## API endpoint

### `GET https://api.deepseek.com/user/balance`
- Headers:
  - `Authorization: Bearer <api_key>`
  - `Content-Type: application/json`

## Parsing + mapping

### Balance response (`DeepSeekBalanceResponse`)
- `balance_infos[]` — array of balance entries per currency.
  - `currency` — currency code (e.g., "USD").
  - `total_balance` — preferred; falls back to `topped_up_balance`, then `granted_balance`.
  - All balance fields are strings parsed as `Double`.

- Preferred balance info: the first entry with `totalBalanceValue > 0`, falling back to the first entry overall.

### Snapshot mapping (`toUsageSnapshot`)
- Primary: `RateWindow` with `usedPercent: 0`, `hasKnownLimit: false`, `windowMinutes: nil`, `resetsAt: nil`, `resetDescription` showing "Balance: X.XX USD".
- Secondary: `nil`.
- Tertiary: `nil`.
- Identity: `nil` (no identity info from the balance API).
- Also produces a `CreditsSnapshot` with `remaining` balance value.

## Key files
- `Sources/RunicCore/Providers/DeepSeek/DeepSeekProviderDescriptor.swift`
- `Sources/RunicCore/Providers/DeepSeek/DeepSeekUsageFetcher.swift`
- `Sources/Runic/Core/Stores/DeepSeekTokenStore.swift`
