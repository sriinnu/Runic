---
summary: "Qwen (China) provider: separate account/API key for dashscope.aliyuncs.com, tracked alongside the international Qwen provider."
read_when:
  - Debugging Qwen China token storage or usage display
  - Updating the dashscope.aliyuncs.com endpoint
---

# Qwen (China) provider

Sibling of the [Qwen provider](qwen.md). Alibaba Cloud DashScope issues separate accounts and API keys for the China platform (`dashscope.aliyuncs.com`) vs the international platform -- these cannot share one key, so this is a distinct `UsageProvider` case (`qwenCN`) rather than a base-URL override on the international provider.

Reuses `QwenUsageFetcher.fetchUsage(apiKey:baseURL:)`. The base URL resolves from Preferences (or the `DASHSCOPE_CN_BASE_URL` env var); when unset, the fetcher uses its default host. Same response shape as the international provider.

## Credentials
Token resolution order:
1) Keychain token (stored from Preferences -> Providers -> Qwen (China)).
2) Environment variable `DASHSCOPE_CN_API_KEY`.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `qwen-cn-api-token`

## Key files
- `Sources/RunicCore/Providers/Qwen/QwenCNProviderDescriptor.swift`
- `Sources/Runic/Providers/Qwen/QwenCNProviderImplementation.swift`
- `Sources/Runic/Core/Stores/QwenCNTokenStore.swift`
