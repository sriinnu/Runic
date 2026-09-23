---
summary: "Cline provider data sources: API key in Keychain/env, balance + usage-record APIs, unit handling."
read_when:
  - Debugging Cline key auth, balance, or spend figures
  - Balances look 100x off (unit divisor)
---

# Cline provider

Cline (app.cline.bot) is API-key based. No browser cookies. Create a key under
Settings → API Keys in the Cline web app.

## What this provider shows

- **Balance** in USD (`ProviderBalance.available`, currency `USD`).
- **Spend today / this month**, summed from the account's usage records
  (`ProviderBalance.reportedSpend`, `thisWeek` nil). Days and months are the
  user's local calendar.
- **Identity**: the account email.

The primary `RateWindow` is informational (`hasKnownLimit: false`): Cline has
no quota window, only a prepaid balance.

## Data sources

All endpoints live on `https://api.cline.bot` with `Authorization: Bearer <key>`.
Every response is wrapped as `{success, error, data}`; `success: false` or a
missing `data` surfaces Cline's `error` string.

1) `GET /api/v1/users/me` → `data {id, email, displayName, organizations[]}`.
   The `id` addresses the next two calls.
2) `GET /api/v1/users/{id}/balance` → `data {balance, userId}`.
3) `GET /api/v1/users/{id}/usages` → `data {items: [...]}` with
   `aiInferenceProviderName, aiModelName, promptTokens, completionTokens,
   totalTokens, costUsd, creditsUsed, createdAt, generationId`.
   Decoded leniently: every field optional, numbers accepted as JSON numbers
   or strings. Best effort: if this call fails, the balance still shows and
   `reportedSpend` is nil.

## Balance units

`balance` has no documented unit, and Cline's own clients disagree: the newer
CLI divides by 1,000,000 (micro-USD), an older webview divided by 10,000.
Runic uses 1,000,000 — it matches the CLI and the usage records, where
`creditsUsed / 1e6 == costUsd`. The divisor is the single constant
`ClineUsageFetcher.balanceUnitsPerUSD`.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `cline-api-token`

### Environment variables
- `CLINE_API_KEY`

Fallback order: Keychain first, then `CLINE_API_KEY`.

## Key files
- `Sources/RunicCore/Providers/Cline/ClineProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Cline/ClineUsageFetcher.swift`
- `Sources/Runic/Core/Stores/ClineTokenStore.swift`
- `Tests/RunicTests/ClineUsageFetcherTests.swift`
