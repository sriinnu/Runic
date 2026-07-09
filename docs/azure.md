---
summary: "Azure OpenAI provider data sources: REST API deployment inventory via api-key + endpoint."
read_when:
  - Debugging Azure OpenAI usage or auth issues
  - Updating Azure OpenAI API endpoints or parsing
---

# Azure OpenAI provider

Azure OpenAI uses an API key and endpoint to list deployments via the Azure OpenAI REST API. No browser cookies.

## Data sources + fallback order

1) **Azure OpenAI REST API** (`/openai/deployments`)
   - No fallback — single-source API strategy.

## Credentials (if applicable)

**API key resolution** (in order):
1. Preferences setting `azure.apiToken` (stored in Keychain)
2. Environment variable `AZURE_OPENAI_API_KEY`

## API endpoints / Probe mechanism

- **Strategy**: `azure.api` (kind: `.apiToken`)
- **Endpoint construction**: `<endpoint>/openai/deployments?api-version=<version>`
  - Enforces HTTPS — rejects bare `http://` to prevent cleartext token leakage.
  - If endpoint omits the path, `/openai/deployments` is appended.
  - If endpoint includes a path, the path is preserved and `/openai/deployments` is appended after it.
- **Headers**:
  - `api-key: <token>`
  - `Content-Type: application/json`
- **Default API version**: `2024-10-21`

### Configuration resolution (in order)

**Endpoint**:
1. Preferences setting `azure.endpoint`
2. `AZURE_OPENAI_ENDPOINT` env var
3. `AZURE_OPENAI_BASE_URL` env var

**API version** (defaults to `2024-10-21`):
1. Preferences setting `azure.apiVersion`
2. `AZURE_OPENAI_API_VERSION` env var

**Deployment filter** (optional, for UI highlighting):
1. Preferences setting `azure.deployment`
2. `AZURE_OPENAI_DEPLOYMENT` env var

## Parsing + mapping

- Response structure is flexible — accepts `data[]` or `value[]` as the top-level container.
- Each deployment has `id` (or `name`) and `model` (or `modelName`).
- Snapshot shows deployment count, up to 3 unique model names, and the target deployment if specified.
- No quota/rate-limit windows — `usedPercent` is always 0, `hasKnownLimit` is false.
- Primary `RateWindow` label: "Deployments".
- Supports model breakdown via `supportsModelBreakdown: true`.

## Key files
- `Sources/RunicCore/Providers/Azure/AzureProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Azure/AzureUsageFetcher.swift`
