---
summary: "MiniMax web-only usage fetcher (cookies + local storage token)."
read_when:
  - Working on MiniMax provider fetch/parsing
  - Debugging MiniMax session/cookie handling
---

# MiniMax

MiniMax is web-only. Usage is fetched from the Coding Plan remains API using a session cookie header.

Status: none yet.

## Data sources + fallback order
1) Browser cookie import (automatic).
2) Chromium local storage access token (automatic).
3) Manual session cookie header (optional override).

### Browser cookie import (automatic)
- Cookie order from provider metadata (default: Safari → Chrome → Firefox).
- Merges Chromium profile cookies across primary + Network stores before attempting a request.
- Tries each browser source until the Coding Plan API accepts the cookies.
- Domain filters: `platform.minimax.io`, `minimax.io`.

### Browser local storage access token (Chromium-based)
- Reads `access_token` (and related tokens) from Chromium local storage (LevelDB).
- If decoding fails, falls back to a text-entry scan for `minimax.io` keys/values and filters for MiniMax JWT claims.
- Used automatically; no UI field.
- Also extracts `GroupId` when present (appends query param).

### Manual session cookie header (optional override)
- Stored in Keychain via Preferences → Providers → MiniMax (Cookie header).
- Accepts a raw `Cookie:` header or a full "Copy as cURL" string.
- When a cURL string is pasted, MiniMax extracts:
  - `Cookie:` header
  - `Authorization: Bearer ...`
  - `GroupId=...` query param when present
- CLI/runtime env: `MINIMAX_COOKIE` or `MINIMAX_COOKIE_HEADER`.

## Endpoints
- `GET https://platform.minimax.io/user-center/payment/coding-plan`
  - HTML parse for "Available usage" and plan name.
- `GET https://platform.minimax.io/v1/api/openplatform/coding_plan/remains`
  - Fallback when HTML parsing fails.
  - Sent with `Referer` to the Coding Plan page.
  - Adds `Authorization: Bearer <access_token>` when available.
  - Adds `GroupId` query param when known.

## Cookie capture (optional override)
1) Open the Coding Plan page.
2) DevTools → Network.
3) Select the request to `/v1/api/openplatform/coding_plan/remains`.
4) Copy the Cookie request header (or use "Copy as cURL" and paste the whole line).
5) Paste into Preferences → Providers → MiniMax only if automatic import fails.

## Notes
- Cookies alone often return status `1004` ("cookie is missing, log in again"); the remains API expects a Bearer token.
- MiniMax stores `access_token` in Chromium local storage (LevelDB). Some entries serialize the storage key without a scheme (ex: `minimax.io`), so origin matching must account for host-only keys.
- Raw JWT scan fallback remains as a safety net if Chromium key formats change.
- If local storage keys don’t decode (some Chrome builds), the MiniMax-specific text scan avoids a full raw-byte scan.

## Cookie file paths
- Safari: `~/Library/Cookies/Cookies.binarycookies`
- Chrome/Chromium forks: `~/Library/Application Support/Google/Chrome/*/Cookies`
- Firefox: `~/Library/Application Support/Firefox/Profiles/*/cookies.sqlite`

## Snapshot mapping
- Primary: percent used from `model_remains` (used/total) or HTML "Available usage".
- Window: derived from `start_time`/`end_time` or HTML duration text.
- Reset: derived from `remains_time` (fallback to `end_time`) or HTML "Resets in ...".
- Plan/tier: best-effort from response fields or HTML title.
