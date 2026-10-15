---
summary: "Kimi provider data sources: Moonshot API key in Keychain/env; account balance from the Moonshot balance API, or Kimi Code plan usage when the key/host is the kimi.com / kimi.ai plan platform."
read_when:
  - Debugging Kimi token storage, balance display, or Kimi Code plan usage
  - Updating Moonshot / Kimi Code API endpoints or base URL resolution
---

# Kimi provider

Kimi is API-token based. No browser cookies. One slot, two very different keys:

- **Moonshot Open Platform** (pay-as-you-go, `platform.moonshot.ai` / `.cn`): fetches account balance -- no usage quota tracking.
- **Kimi Code plan** (the Kimi membership subscription, keys from `kimi.com/code/console`): fetches plan usage windows (5h rolling + monthly pool). The plan platform has no balance route.

## Data sources + fallback order

1) **API token** (single source, one fetch strategy; which endpoint it hits depends on the host, below).

## Credentials

Token resolution order:
1) Keychain token (stored from Preferences).
2) Environment variable `KIMI_API_KEY`.
3) Environment variable `MOONSHOT_API_KEY`.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `kimi-api-token`

## API base URL resolution

The base URL is configurable because Moonshot has region-specific hosts (`api.moonshot.ai` international, `api.moonshot.cn` China) and the Kimi Code plan lives on its own hosts (`api.kimi.com` China-side, `api.kimi.ai` overseas; the same plan key works on both).

Resolution order:
1) Preferences setting `kimi.baseURL`.
2) Environment variable `MOONSHOT_BASE_URL`.
3) Environment variable `KIMI_BASE_URL`.
4) Default: `https://api.moonshot.ai`.

URL normalization: scheme added if missing (`https://`), trailing slash stripped, trailing `/v1` stripped. For a Kimi Code host only scheme, host and port are kept; path, query and fragment are dropped, so a pasted full endpoint cannot double up.

## Endpoint selection (`KimiUsageFetcher.fetchSnapshot`)

1) If the resolved base URL is a **Kimi Code host** (exactly `api.kimi.com` or `api.kimi.ai`, `KimiCodeUsageFetcher.isKimiCodeHost`; `www.kimi.com` is the web app and is not one), skip the balance route entirely and fetch plan usage on that host: `GET <scheme>://<host>[:port]/coding/v1/usages`.
2) Otherwise `GET <baseURL>/v1/users/me/balance` (Moonshot balance).
3) If the balance route answers 401 or 403, or 404 **from a Kimi-operated host** (`*.moonshot.ai`, `*.moonshot.cn`, `*.kimi.com`, `*.kimi.ai`; `KimiCodeUsageFetcher.isKimiOperatedHost`), the key may be a plan key on the wrong host: try plan usage at `KIMI_CODE_BASE_URL` (kimi-cli's variable) or the default `https://api.kimi.com/coding/v1` + `/usages`. If that is rejected too (401/403), the original balance error surfaces. A 404 from a third-party gateway surfaces as-is; the key is never retried on a host the user did not configure.

Before 2026-10-15 step 3 only fired on 401/403, so a user who had pointed the base URL at `https://api.kimi.ai/coding/` saw `Kimi API returned status code 404: {"error":{"type":"resource_not_found_error"…}}` forever. Step 1 is the fix; the 404 in step 3 is the belt.

Headers on both routes: `Authorization: Bearer <token>` (balance also sends `Content-Type: application/json`). Timeout: 20 seconds.

## Parsing + mapping

### Moonshot balance response

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
- `usedPercent: 0`, `hasKnownLimit: false` -- the balance API exposes no limit, so there is no denominator for a percentage. Summary shows the raw amount; currency is inferred from the host (CNY on `.cn`, USD on `.ai`, unknown on a custom gateway).
- No model breakdown, no token metrics, no project attribution.

### Kimi Code plan usage response (live shape 2026-10-15)

```json
{ "limits": [ { "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
                "detail": { "limit": "100", "used": "15", "remaining": "85",
                            "resetTime": "2026-10-15T14:18:14.197162Z" } } ],
  "usages": { "limit_5h": { "used_ratio": 0.1539, "reset_time": "2026-10-15T14:18:13Z" },
              "limit_month_total": { "used_ratio": 0.0042, "reset_time": "2026-11-15T09:19:24Z" },
              "limit_month_code":  { "used_ratio": 0.0042, "reset_time": "2026-11-15T09:19:24Z" } } }
```

- `limits[]` count windows (shortest first) become `RateWindow`s with a real `usedPercent`; the 5h one is primary.
- A top-level `usage` block (legacy plans' weekly pool) becomes a "Weekly" window. New plans (Go/Plus/Pro) have none.
- `usages.limit_5h` fills the 5h window only when no count window covered it; `usages.limit_month_total` (falling back to `limit_month_code`) becomes the "Monthly" window.
- Numbers arrive as strings or numbers. Timestamps are RFC 3339 with up to nanosecond fractions.

## Kimi Code plan reference (docs re-read 2026-10-15, https://www.kimi.com/code/docs/en/)

Model ids on the plan: `k3` (K3, 1M ctx on Pro/Allegretto+, else 256k), `k3-256k`, `kimi-for-coding` (K2.8 Preview since 2026-09-11, 1M ctx), `kimi-for-coding-highspeed` (K2.7 Code HighSpeed, 256k, Pro/Allegretto+, ~6x speed at 3x quota). Quota: one 5h rolling window + one monthly pool shared by every device and key on the account. Console: https://www.kimi.com/code/console.

## Key files
- `Sources/RunicCore/Providers/Kimi/KimiProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Kimi/KimiUsageFetcher.swift` (balance + `fetchSnapshot` routing)
- `Sources/RunicCore/Providers/Kimi/KimiCodeUsageFetcher.swift` (plan usage)
- `Tests/RunicTests/KimiCodeUsageParsingTests.swift`
