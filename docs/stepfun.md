---
summary: "StepFun provider(s): API-token balance tracking for the global (stepfun.ai) and China (stepfun.com) platforms as separate accounts."
read_when:
  - Debugging StepFun token storage or balance display
  - Verifying/updating the StepFun /v1/accounts response shape
---

# StepFun provider(s)

Two `UsageProvider` cases: `stepfun` (global, `platform.stepfun.ai`) and `stepfunCN` (China, `platform.stepfun.com`). StepFun issues separate accounts and API keys per region -- a China-issued key only authenticates against the `.com` host.

## Data sources + fallback order
1) **API token** (single source, one fetch strategy per region).

## Endpoint
- `GET <baseURL>/v1/accounts` (`https://api.stepfun.ai` or `https://api.stepfun.com`)
- Headers: `Authorization: Bearer <token>`, `Content-Type: application/json`.

**Unverified response schema.** StepFun's exact JSON shape for `/v1/accounts` is not publicly documented in detail. `StepFunUsageFetcher` parses defensively with `JSONSerialization` and looks for the first numeric value under common balance-shaped keys (`available_balance`, `balance`, `total_balance`, `remaining_balance`, `quota`, `remaining`) rather than a strict `Decodable` struct. If none match, the provider shows "Connected (balance format not recognized -- check dashboard)" instead of failing -- update `StepFunUsageFetcher.balanceKeys` once the real shape is confirmed against a live account.

## Credentials
Token resolution order (global):
1) Keychain token (stored from Preferences -> Providers -> StepFun).
2) Environment variable `STEPFUN_API_KEY`.

Token resolution order (China):
1) Keychain token (stored from Preferences -> Providers -> StepFun (China)).
2) Environment variable `STEPFUN_CN_API_KEY`.

### Keychain locations
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Accounts: `stepfun-api-token`, `stepfun-cn-api-token`

## Key files
- `Sources/RunicCore/Providers/StepFun/StepFunUsageFetcher.swift`
- `Sources/RunicCore/Providers/StepFun/StepFunProviderDescriptor.swift`
- `Sources/RunicCore/Providers/StepFun/StepFunCNProviderDescriptor.swift`
- `Sources/Runic/Providers/StepFun/StepFunProviderImplementation.swift`
- `Sources/Runic/Providers/StepFun/StepFunCNProviderImplementation.swift`
