---
summary: "SiliconFlow provider data sources: API token in Keychain/env and balance API response parsing."
read_when:
  - Debugging SiliconFlow balance or auth issues
  - Updating SiliconFlow API endpoints
---

# SiliconFlow provider

SiliconFlow is API-token based. No browser cookies.

## Data sources + fallback order

1) **Balance API** (sole source)
   - `GET https://api.siliconflow.com/v1/user/info`
   - Returns balance information per currency.
   - No usage limit is exposed, so the snapshot shows the balance text with `hasKnownLimit: false`.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `siliconflow-api-token`

### Environment variable
- `SILICONFLOW_API_KEY`

Fallback order: Keychain first, then environment.

### Token store
- `Sources/Runic/Core/Stores/SiliconFlowTokenStore.swift` — reads/writes/deletes the Keychain item with `kSecAttrAccessibleAfterFirstUnlock`, supports migration from the Data Protection keychain.

## API endpoint

### `GET https://api.siliconflow.com/v1/user/info`
- Headers:
  - `Authorization: Bearer <api_key>`
  - `Content-Type: application/json`

## Parsing + mapping

### Response (`SiliconFlowBalanceResponse`)
- `data.totalBalance` — remaining balance (granted + topped-up); falls back to `balance + chargeBalance`.
- `data.balance` — granted/bonus, `data.chargeBalance` — topped-up (paid). Strings or numbers.
- `data.status == "normal"` feeds `apiCallsAllowed`.
- Currency is USD on the international (`.com`) platform. The China platform is a separate provider slot, `siliconflowCN` (see `siliconflow-cn.md`).

### Snapshot mapping
- Primary: limit-less `RateWindow` (`hasKnownLimit: false`) with "Balance: X.XX USD"; also a `CreditsSnapshot`.

> The response shape is taken from the SiliconFlow API docs and has not been probed with a live key.

## Key files
- `Sources/RunicCore/Providers/SiliconFlow/SiliconFlowProviderDescriptor.swift`
- `Sources/RunicCore/Providers/SiliconFlow/SiliconFlowUsageFetcher.swift`
- `Sources/Runic/Core/Stores/SiliconFlowTokenStore.swift`
