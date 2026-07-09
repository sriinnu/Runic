---
summary: "Kimi provider data sources: Moonshot API key in Keychain/env and account balance from Moonshot balance API."
read_when:
  - Debugging Kimi token storage or balance display
  - Updating Moonshot API endpoints or base URL resolution
---

# Kimi provider

Kimi (Moonshot) is API-token based. No browser cookies. Fetches account balance -- no usage quota tracking.

## Data sources + fallback order

1) **API token** (single source, one fetch strategy).

## Credentials

Token resolution order:
1) Keychain token (stored from Preferences).
2) Environment variable `KIMI_API_KEY`.
3) Environment variable `MOONSHOT_API_KEY`.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `kimi-api-token`

## API base URL resolution

The base URL is configurable because Moonshot has region-specific hosts (e.g., `api.moonshot.ai` for international, `api.moonshot.cn` for China).

Resolution order:
1) Preferences setting `kimi.baseURL`.
2) Environment variable `MOONSHOT_BASE_URL`.
3) Environment variable `KIMI_BASE_URL`.
4) Default: `https://api.moonshot.ai`.

URL normalization: scheme added if missing (`https://`), trailing slash stripped, trailing `/v1` stripped.

## API endpoints

- `GET <baseURL>/v1/users/me/balance`
- Headers:
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- Timeout: 20 seconds.

## Parsing + mapping

### Response structure

```json
{
  "code": 0,
  "data": {
    "available_balance": 123.45,
    "voucher_balance": 50.00,
    "cash_balance": 73.45
  },
  "status": true
}
```

- `data.available_balance` -- total available balance (primary display).
- `data.voucher_balance` -- voucher portion (shown in detail if > 0).
- `data.cash_balance` -- cash portion (shown in detail if > 0).

### Usage snapshot

- `usedPercent: 0`, `hasKnownLimit: false` -- the balance API exposes no limit, so there is no denominator for a percentage.
- Summary displays the formatted balance amount (no currency symbol -- the API returns no currency code and it differs by region: CNY on `.cn`, USD on `.ai`).
- Detail line includes voucher and cash breakdowns when present.
- No model breakdown, no token metrics, no project attribution.

## Key files
- `Sources/RunicCore/Providers/Kimi/KimiProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Kimi/KimiUsageFetcher.swift`
