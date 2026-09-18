---
summary: "Claude provider data sources: OAuth API, web API (cookies), CLI PTY, and local cost relay."
read_when:
  - Debugging Claude usage/status parsing
  - Updating Claude OAuth/web endpoints or cookie import
  - Adjusting Claude CLI PTY automation
  - Reviewing local cost relay behavior
---

# Claude provider

Claude supports three usage data paths plus local cost usage relay. Source selection is automatic unless debug override is set.

## Data sources + selection order

### Default selection (debug menu disabled)
1) OAuth API (if Claude CLI credentials include `user:profile` scope).
2) Web API (browser cookies, `sessionKey`), if OAuth missing.
3) CLI PTY (`claude`), if no OAuth and no web session.

### Debug selection (debug menu enabled)
- The Debug pane can force OAuth / Web / CLI.
- Web extras are internal-only (not exposed in the Providers pane).

## OAuth API (preferred)
- Credentials, in order:
  - Runic's own cached copy: service `com.sriinnu.athena.Runic.provider-credentials.v2`, account `claude-oauth-cache` (access token + expiry + scopes + tier; **no refresh token**).
  - Keychain service: `Claude Code-credentials` (written by the CLI), read with user interaction suppressed.
  - File fallback: `~/.claude/.credentials.json`.

### Why the cache exists
`Claude Code-credentials` belongs to the Claude CLI, so its Keychain ACL trusts
that binary and not Runic. Every read from the app can raise the "Runic wants to
use your confidential information" dialog, and because the ACL is bound to the
exact binary, a rebuilt Runic prompts again — and the CLI rewrites the item on
each token refresh, which drops any grant that was given. Worse, in a headless
process the dialog has nobody to click and `SecItemCopyMatching` blocks.

So the refresh path never touches the CLI's item without a guard:
`ClaudeKeychainInteraction.withoutUserInteraction` wraps the read in
`SecKeychainSetUserInteractionAllowed(false)` (deprecated, but the only API that
turns off the legacy ACL dialog — `kSecUseAuthenticationUI: fail` only covers
biometry/passcode items), so it fails fast instead of prompting or hanging. On a
successful read the credentials are copied into Runic's own item, which the app
owns and is never prompted for.

`ClaudeOAuthCredentialsStore.loadAllowingInteraction()` is the one path that may
prompt. It runs after a user-initiated `claude login`, where a single dialog is
expected, and refills the cache.
- Requires `user:profile` scope (CLI tokens with only `user:inference` cannot call usage).
- Endpoint:
  - `GET https://api.anthropic.com/api/oauth/usage`
- Headers:
  - `Authorization: Bearer <access_token>`
  - `anthropic-beta: oauth-2025-04-20`
- Mapping:
  - `five_hour` → session window.
  - `seven_day` → weekly window.
  - `seven_day_sonnet` / `seven_day_opus` → model-specific weekly window.
  - `extra_usage` → Extra usage cost (monthly spend/limit).
- Plan inference: `rate_limit_tier` from credentials maps to Max/Pro/Team/Enterprise.

## Web API (cookies)
- Cookie source order:
  1) Safari: `~/Library/Cookies/Cookies.binarycookies`
  2) Chrome/Chromium forks: `~/Library/Application Support/Google/Chrome/*/Cookies`
  3) Firefox: `~/Library/Application Support/Firefox/Profiles/*/cookies.sqlite`
- Domain: `claude.ai`.
- Cookie name required:
  - `sessionKey` (value prefix `sk-ant-...`).
- API calls (all include `Cookie: sessionKey=<value>`):
  - `GET https://claude.ai/api/organizations` → org UUID.
  - `GET https://claude.ai/api/organizations/{orgId}/usage` → session/weekly/opus.
  - `GET https://claude.ai/api/organizations/{orgId}/overage_spend_limit` → Extra usage spend/limit.
  - `GET https://claude.ai/api/account` → email + plan hints.
- Outputs:
  - Session + weekly + model-specific percent used.
  - Extra usage spend/limit (if enabled).
  - Account email + inferred plan.

## CLI PTY (fallback)
- Runs `claude` in a persistent PTY session (`ClaudeCLISession`).
- Command flow:
  1) Start CLI with `--allowed-tools ""` (no tools).
  2) Auto-respond to first-run prompts (trust files, workspace, telemetry).
  3) Send `/usage`, wait for rendered panel; send Enter retries if needed.
  4) Optionally send `/status` to extract identity fields.
- Parsing (`ClaudeStatusProbe`):
  - Strips ANSI, locates "Current session" + "Current week" headers.
  - Extracts percent left/used and reset text near those headers.
  - Parses `Account:` and `Org:` lines when present.
  - Surfaces CLI errors (e.g. token expired) directly.

## Cost usage relay
- Source roots:
  - `$CLAUDE_CONFIG_DIR` (comma-separated), each root uses `<root>/projects`.
  - Fallback roots:
    - `~/.config/claude/projects`
    - `~/.claude/projects`
- Live files: project JSONLs touched today.
- Historical source:
  - Runic-owned event relay: `~/Library/Application Support/Runic/relay/claude-events.jsonl`
  - Daily materialized cache: `~/Library/Application Support/Runic/ledger-cache/claude-daily.json`
  - One-time seed from legacy scanner cache: `~/Library/Caches/Runic/cost-usage/claude-v1.json`
- Refresh rule:
  - Provider JSONLs before today are not reopened during normal refresh.
  - `runic cost --rebuild --provider claude` is the explicit repair path that reopens Claude JSONL history for the 30-day window.
  - Today's touched project files are parsed, line-filtered to today's timestamps, and normalized into relay events with source fingerprints and scan watermarks.
  - Daily totals are materialized from the newest relay snapshot for each day, then merged into the 30-day token/cost view.
  - Legacy cache days with implausible token/request totals are quarantined before any cache seeding.
- Parsing:
  - Lines with `type: "assistant"` and `message.usage`.
  - Uses per-model token counts (input, cache read/create, output).
  - Deduplicates streaming chunks by `message.id + requestId` (usage is cumulative per chunk).

## Key files
- OAuth: `Sources/RunicCore/Providers/Claude/ClaudeOAuth/*`
- Web API: `Sources/RunicCore/Providers/Claude/ClaudeWeb/ClaudeWebAPIFetcher.swift`
- CLI PTY: `Sources/RunicCore/Providers/Claude/ClaudeStatusProbe.swift`,
  `Sources/RunicCore/Providers/Claude/ClaudeCLISession.swift`
- Cost usage relay: `Sources/RunicCore/CostUsageFetcher.swift`,
  `Sources/RunicCore/UsageLedger/ClaudeUsageLogSource.swift`,
  `Sources/RunicCore/UsageLedger/LedgerCache.swift`
