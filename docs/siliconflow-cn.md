---
summary: "SiliconFlow provider data sources: API key in Keychain/env and the /v1/models key-health probe (balance API retired)."
read_when:
  - Debugging SiliconFlow key or 410 errors
  - Updating SiliconFlow API endpoints
---

# SiliconFlow (China) provider

SiliconFlow is API-token based. No browser cookies.

## Data sources + fallback order

1) **Models API** (sole source) — `GET https://api.siliconflow.cn/v1/models`
   - SiliconFlow retired its only balance endpoint, `GET /v1/user/info`, on 2026-08-14:
     it now answers `410 {"code":20092,"message":"This endpoint is deprecated and is no longer available."}`.
     No replacement has been announced, so there is no balance, usage or limit to show.
   - The tile is a key-health tile like Groq's: "Key active · N models (…)", `hasKnownLimit: false`.
     A bad key surfaces as the HTTP status and body.
   - If SiliconFlow ships an account-level balance API, add it here and restore `supportsCredits`.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `siliconflow-cn-api-token`

### Environment variable
- `SILICONFLOW_CN_API_KEY`

Fallback order: Keychain first, then environment.

### Token store
- `Sources/Runic/Core/Stores/SiliconFlowCNTokenStore.swift` — reads/writes/deletes the Keychain item with `kSecAttrAccessibleAfterFirstUnlock`, supports migration from the Data Protection keychain.

## Key files
- `Sources/RunicCore/Providers/SiliconFlow/SiliconFlowCNProviderDescriptor.swift`
- `Sources/RunicCore/Providers/SiliconFlow/SiliconFlowUsageFetcher.swift`
- `Sources/Runic/Core/Stores/SiliconFlowCNTokenStore.swift`
