---
summary: "Muse (Meta Model API) provider data sources: API key in Keychain/env, models list + rate-limit headers, billing errors."
read_when:
  - Debugging Muse / Meta Model API key auth or rate-limit display
  - Revisiting Muse usage reporting if Meta ships a usage endpoint
---

# Muse (Meta) provider

Muse is served through Meta's Model API (`https://api.meta.ai/v1`), API-key based.
Keys and billing live at `https://dev.meta.ai`.

## What this provider can and cannot show

The Model API exposes **no usage, billing, or credits endpoint**: only
`GET /v1/models` (authenticated) and `GET /v1/status` (unauthenticated). So this
tile shows key health plus whatever rate-limit state the models call returns.

- When the response carries `x-ratelimit-*` headers (matched case-insensitively):
  - Primary: requests per minute (`x-ratelimit-limit-requests` /
    `x-ratelimit-remaining-requests`), `windowMinutes: 1`, `hasKnownLimit: true`.
  - Secondary: tokens per minute (`x-ratelimit-limit-tokens` /
    `x-ratelimit-remaining-tokens`), same shape.
  - Only token headers present → tokens become primary.
- No headers → primary is an informational "N models available" line
  (`hasKnownLimit: false`), like Groq and TypeSafe.

`supportsTokenCost` and `supportsTokenMetrics` are false. The dashboard link
goes to dev.meta.ai.

## Errors

- `402` (or any body whose error `type` is `billing_error`) → "Out of Meta Model
  API credits — add billing at dev.meta.ai."
- `401` / `403` → invalid API key.

Mapping is the pure function `MuseAPIError.from(statusCode:body:)`.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `muse-api-token`

### Environment variables (in order)
- `MUSE_API_KEY`
- `META_MODEL_API_KEY`
- `MODEL_API_KEY` (the name Meta's docs use)

Fallback order: Keychain first, then the variables above.

## Key files
- `Sources/RunicCore/Providers/Muse/MuseProviderDescriptor.swift`
- `Sources/RunicCore/Providers/Muse/MuseUsageFetcher.swift`
- `Sources/Runic/Core/Stores/MuseTokenStore.swift`
- `Tests/RunicTests/MuseUsageFetcherTests.swift`
