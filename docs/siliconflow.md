---
summary: "SiliconFlow data sources: console balance via browser sign-in (public balance API retired), API-key health via /v1/models."
read_when:
  - Debugging SiliconFlow key or 410 errors
  - Updating SiliconFlow API endpoints
---

# SiliconFlow provider

SiliconFlow reads the balance from the console with the browser sign-in, and checks an API key when one is set.

## Data sources + fallback order

1) **Console balance (browser sign-in)** — `siliconflow.web`, tried first.
   - SiliconFlow retired the public balance endpoint `GET /v1/user/info` on 2026-08-14
     (`410 {"code":20092}`), but its console still reads the balance from
     `GET https://cloud.siliconflow.com/biz-server/api/v1/user/info`.
   - Auth: the browser's `siliconflow.com` cookies (must include `__SF_auth.session-token`),
     imported in the default browser order, one session per profile.
   - `X-Subject-ID`: tried from `SILICONFLOW_SUBJECT_ID`, then any subject-looking cookie, then without it.
   - Reply: `{code:20000, status:true, data:{balance, chargeBalance, totalBalance, status}}`, money as strings.
     Shown as a limit-less balance in USD (Paid = `chargeBalance`, Bonus = `balance`) plus a credits snapshot.
   - A redirect to `account.siliconflow.*` or 401/403 = signed out; a 200 with a non-20000 code on every
     subject candidate = "needs your user ID" (export `SILICONFLOW_SUBJECT_ID`).
   - Falls back to the API key only when one exists; otherwise its own error shows.

2) **Models API (API key)** — `GET https://api.siliconflow.com/v1/models`: key health only
   ("Key active · N models"), since no public balance API exists any more.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `siliconflow-api-token`

### Environment variable
- `SILICONFLOW_API_KEY`

Fallback order: Keychain first, then environment.

### Token store
- `Sources/Runic/Core/Stores/SiliconFlowTokenStore.swift` — reads/writes/deletes the Keychain item with `kSecAttrAccessibleAfterFirstUnlock`, supports migration from the Data Protection keychain.

## Key files
- `Sources/RunicCore/Providers/SiliconFlow/SiliconFlowProviderDescriptor.swift`
- `Sources/RunicCore/Providers/SiliconFlow/SiliconFlowUsageFetcher.swift`
- `Sources/Runic/Core/Stores/SiliconFlowTokenStore.swift`
