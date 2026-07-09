---
summary: "Vercel AI provider data sources: AI Gateway API key in Keychain/env, credits balance, and available model listing."
read_when:
  - Debugging Vercel AI Gateway token storage or credits display
  - Updating Vercel AI Gateway API endpoints or parsing
---

# Vercel AI provider

Vercel AI Gateway is API-token based. No browser cookies. Fetches credits balance (with used percent) and available models via two parallel API calls.

## Data sources + fallback order

1) **API token** (single source, one fetch strategy that makes two API calls in parallel).

## Credentials

Token resolution order:
1) Keychain token (stored from Preferences).
2) Environment variable `AI_GATEWAY_API_KEY`.
3) Environment variable `VERCEL_OIDC_TOKEN`.

### Keychain location
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `vercelai-api-token`

## API endpoints

### Credits (authenticated)
- `GET https://ai-gateway.vercel.sh/v1/credits`
- Headers:
  - `Authorization: Bearer <token>`
  - `Content-Type: application/json`
- Timeout: 15 seconds.

### Models (unauthenticated, best-effort)
- `GET https://ai-gateway.vercel.sh/v1/models`
- Headers:
  - `Content-Type: application/json`
- Timeout: 15 seconds.
- Models fetch failure is non-fatal -- credits are still returned if models endpoint fails.

## Parsing + mapping

### Credits response

- `balance` -- remaining credits (decoded from Double or numeric String).
- `total_used` -- consumed credits (decoded from Double or numeric String).
- `totalCredits` computed as `max(0, balance + total_used)`.
- `usedPercent` computed as `min(100, max(0, total_used / totalCredits * 100))`.

### Models response (optional)

- `data[]` -- each entry has `id`, `name`, `type`, `context_window`, `max_tokens`.
- Model IDs are appended to the usage snapshot description as a count with a preview of the first 2 names.

### Usage snapshot

- `usedPercent` reflects actual credit consumption as a percentage of total credits.
- Reset description includes balance, used credits, and model count/preview.
- Identity snapshot includes the token source label (e.g., "API key (keychain)" or "API key (AI_GATEWAY_API_KEY)").

### Credits snapshot

A separate `CreditsSnapshot` is produced with:
- `remaining`: `max(0, balance)`.
- `events`: empty (no event-level detail).
- `updatedAt`: current date.

## Key files
- `Sources/RunicCore/Providers/VercelAI/VercelAIProviderDescriptor.swift`
- `Sources/RunicCore/Providers/VercelAI/VercelAIUsageFetcher.swift`
