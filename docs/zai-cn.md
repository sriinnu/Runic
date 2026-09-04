---
summary: "GLM (China) provider: separate account/API key for open.bigmodel.cn, tracked alongside the international z.ai (GLM) provider."
read_when:
  - Debugging GLM China token storage or usage display
  - Verifying/updating the open.bigmodel.cn endpoint path
---

# GLM (China) provider

Sibling of the [z.ai / GLM provider](zai.md). Zhipu AI issues separate accounts and API keys for `open.bigmodel.cn` (China) vs the international `z.ai` brand -- this is a distinct `UsageProvider` case (`zaiCN`).

Reuses `ZaiUsageFetcher.fetchUsage(apiKey:baseURL:)` with `baseURL` set to `https://open.bigmodel.cn/api/monitor/usage`. **Unverified**: this mirrors z.ai's `/quota/limit`, `/model-usage`, `/tool-usage` path shape onto the bigmodel.cn host, but has not been confirmed against a real bigmodel.cn account -- if the endpoint path differs, the fetch will surface an explicit error rather than showing wrong numbers.

## Credentials
Token resolution order:
1) Keychain token (stored from Preferences -> Providers -> GLM (China)).
2) Environment variable `BIGMODEL_API_KEY`.
3) Environment variable `ZHIPU_API_KEY`.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `zai-cn-api-token`

## Key files
- `Sources/RunicCore/Providers/Zai/ZaiCNProviderDescriptor.swift`
- `Sources/Runic/Providers/Zai/ZaiCNProviderImplementation.swift`
- `Sources/Runic/Core/Stores/ZaiCNTokenStore.swift`
