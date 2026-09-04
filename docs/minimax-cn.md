---
summary: "MiniMax (China) provider: separate account/API key for minimaxi.com, tracked alongside the international MiniMax provider."
read_when:
  - Debugging MiniMax China token storage or usage display
---

# MiniMax (China) provider

Sibling of the [MiniMax provider](minimax.md). MiniMax issues separate accounts and API keys for `minimaxi.com` (China) vs `minimax.io` (international) -- this is a distinct `UsageProvider` case (`minimaxCN`).

API-key mode only -- deliberately does not replicate the international provider's web-scraping/cookie-import fallback, since this is a second account slot, not a full re-implementation.

Reuses `MiniMaxUsageFetcher.fetchUsage(apiKey:quotaAPIURL:)` with `quotaAPIURL` set to `https://www.minimaxi.com/v1/token_plan/remains` (mirrors the international `www.minimax.io` path).

## Credentials
Token resolution order:
1) Keychain token (stored from Preferences -> Providers -> MiniMax (China)).
2) Environment variable `MINIMAXI_API_KEY`.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `minimax-cn-api-token`

## Key files
- `Sources/RunicCore/Providers/MiniMax/MiniMaxCNProviderDescriptor.swift`
- `Sources/Runic/Providers/MiniMax/MiniMaxCNProviderImplementation.swift`
- `Sources/Runic/Core/Stores/MiniMaxCNTokenStore.swift`
