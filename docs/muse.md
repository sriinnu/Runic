---
summary: "Muse Code subscription usage from the signed-in CLI, plus separate Meta Model API rate limits."
read_when:
  - Debugging Muse Code subscription usage or Meta Model API rate-limit display
  - Revisiting consumer Muse AI usage if Meta ships a verifiable quota source
---

# Muse Code (Meta) provider

Runic's Auto source uses a locally installed, signed-in `muse` CLI first. It
opens the CLI's read-only `/usage` card and reports its Current and Weekly
subscription windows. This does not send a model prompt or require a Model API
key. Choose CLI explicitly to require that source; when the CLI is installed
but cannot show usage, Runic reports the error instead of relabeling API limits
as subscription usage.

An explicit API source uses Meta's separate, pay-as-you-go Model API
(`https://api.meta.ai/v1`). Keys and billing live at `https://dev.meta.ai`.
Auto uses API only when the CLI is unavailable and an API key is configured.

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

`supportsTokenCost` and `supportsTokenMetrics` are false. Meta's consumer Muse
agent and the Meta AI web assistant are separate from Muse Code. Runic has no
verified source for their remaining quota yet.

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
- `Sources/RunicCore/Providers/Muse/MuseCodeCLIUsageFetcher.swift`
- `Sources/RunicCore/Providers/Muse/MuseUsageFetcher.swift`
- `Sources/Runic/Core/Stores/MuseTokenStore.swift`
- `Tests/RunicTests/MuseCodeCLIUsageFetcherTests.swift`
- `Tests/RunicTests/MuseUsageFetcherTests.swift`
