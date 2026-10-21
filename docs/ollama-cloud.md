---
summary: "Ollama Cloud provider data sources: browser sign-in (settings page) or API key, undocumented /api/usage reply, plan mapping, errors, shape diagnostics."
read_when:
  - Debugging Ollama Cloud key auth or usage display
  - The /api/usage reply changes shape (check the diagnostics file first)
---

# Ollama Cloud provider

Ollama Cloud runs hosted models on `ollama.com`, API-key based. Keys live at
`https://ollama.com/settings/keys`; the dashboard link goes to
`https://ollama.com/settings/usage`.

This is separate from the **Local LLM** provider, which probes a local Ollama
runtime and owns the `ollama` CLI alias. Ollama Cloud's CLI name is
`ollama-cloud` (alias `ollamacloud`). Defaults to disabled.

## Sources (in order)

1) **API key** (`ollamacloud.api`) — only when a key exists (Keychain/env). Below.
2) **Browser sign-in** (`ollamacloud.web`) — Pro/Max accounts sign in on the
   website and have no key. Runic imports the `ollama.com` cookies from the
   browser once — when “Usage from browser sign-in” is turned on in Settings (the one read allowed to
   show the “Chrome Safe Storage” Keychain dialog) — keeps that `Cookie:` header in Runic's own Keychain
   item (`ollama-cloud-web-session`), and on every refresh does `GET https://ollama.com/settings` with it, reading
   the "Session usage" / "Weekly usage" blocks: percent from `NN% used`, reset
   time from `data-time="<ISO8601>"`. Each browser profile with ollama.com
   cookies is tried until one is signed in; none → "Not signed in to ollama.com".
   The parser is label-driven (`OllamaCloudWebParser`) because the real page
   markup has not been captured; if usage shows 0/blank, save the page text and
   adjust the labels there.

## API endpoint

`GET https://ollama.com/api/usage` with `Authorization: Bearer <key>`.
The endpoint is **undocumented**, so the reply is read through
`JSONSerialization` with every field optional; numbers are accepted as JSON
numbers or strings (`"12.34"`, `"$1,234.50"`), booleans are ignored.

Fields read:
- `limits.monthly.usage` (0–1) and `limits.monthly.models: [{name, request_count}]`
  on monthly-credit plans.
- `limits.session.usage` / `limits.weekly.usage` (0–1) on legacy plans, with
  `models: {"<name>": {"request_count": N}}` at the top level or inside `limits`.
- `activity.cost` (dollars, usually a string) over `activity.period`
  (`last_4_weeks`).

No reset timestamps are provided, so no window has `resetsAt`.

## Snapshot mapping

- Monthly plan → primary "Monthly credits", `usage × 100`, `windowMinutes: 43200`.
- Legacy plan → primary "Session" (`300` min), secondary "Weekly" (`10080` min).
  Only weekly present → weekly becomes primary.
- Neither → informational primary "Signed in · no usage limits reported"
  (`hasKnownLimit: false`, no gauge).
- The three busiest models go into the primary window's description:
  `Top: glm-5 (120), qwen3-coder (40)`.
- `activity.cost` → `providerCost` (USD, limit `0`, period "Last 4 weeks").
  A zero limit renders as spend without a gauge in Preferences; the menu card's
  extra-usage section is Claude/Cursor-only, so the menu does not show it.

## Errors

`OllamaCloudAPIError.from(statusCode:)`:
- `401` / `403` → "Ollama rejected the API key".
- `402` → "Ollama Cloud usage limit reached — upgrade or wait for the reset."
- `429` → rate limited.

## Diagnostics

After each successful fetch the reply's **shape** (sorted key paths, arrays as
`key[]`, the per-model map collapsed to `models.*`; never values) is written to
`~/Library/Application Support/Runic/diagnostics/ollama-cloud-usage-shape.json`.

## Credentials

### Keychain
- Service: `com.sriinnu.athena.Runic.provider-credentials.v2`
- Account: `ollama-cloud-api-token`

### Environment variable
- `OLLAMA_API_KEY`

Fallback order: Keychain first, then the variable.

## Key files
- `Sources/RunicCore/Providers/OllamaCloud/OllamaCloudProviderDescriptor.swift`
- `Sources/RunicCore/Providers/OllamaCloud/OllamaCloudUsageFetcher.swift`
- `Sources/Runic/Core/Stores/OllamaCloudTokenStore.swift`
- `Tests/RunicTests/OllamaCloudUsageFetcherTests.swift`
