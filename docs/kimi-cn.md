---
summary: "Kimi (China) provider: separate account/API key for api.moonshot.cn, tracked alongside the international Kimi provider."
read_when:
  - Debugging Kimi China token storage or balance display
  - Updating the api.moonshot.cn endpoint
---

# Kimi (China) provider

Sibling of the [Kimi provider](kimi.md). Moonshot issues separate accounts and API keys for `api.moonshot.cn` (China) vs `api.moonshot.ai` (international) -- these cannot share one key, so this is a distinct `UsageProvider` case (`kimiCN`) rather than a base-URL override.

Reuses `KimiUsageFetcher.fetchBalance(apiKey:baseURL:)` with `baseURL` hardcoded to `https://api.moonshot.cn`. Same response shape as the international provider.

## Credentials
Token resolution order:
1) Keychain token (stored from Preferences -> Providers -> Kimi (China)).
2) Environment variable `KIMI_CN_API_KEY`.
3) Environment variable `MOONSHOT_CN_API_KEY`.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `kimi-cn-api-token`

## Key files
- `Sources/RunicCore/Providers/Kimi/KimiCNProviderDescriptor.swift`
- `Sources/Runic/Providers/Kimi/KimiCNProviderImplementation.swift`
- `Sources/Runic/Core/Stores/KimiCNTokenStore.swift`
