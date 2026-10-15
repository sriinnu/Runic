---
summary: "Design: accounts as the unit (several logins per provider) and quota windows as a self-describing list instead of three fixed slots. Reviewed version."
read_when:
  - Adding a second login for the same provider (two Claude accounts, Codex personal + work, Kimi + Kimi CN)
  - A provider's API changes which windows it reports (Codex Pro 2026-10 dropped the 5h window)
  - Touching ProviderTokenResolver, UsageStore keys, QuotaWindowSlot or metadata.sessionLabel/weeklyLabel/opusLabel
---

# Accounts and windows

Status: reviewed design, 2026-10-15. Version 2, after three independent reviews (data model and migration, credentials and CLI behaviour, product and UX) and the owner's decisions. Phase 0 shipped in 2.11.3. Phase 2 (accounts) goes before phase 1 (windows), because the demand is accounts: people hold two or three Claude Pro plans instead of one Max, a Codex login per org, Kimi plus Kimi CN, and rotate between them by hand.

## The two things the current model cannot say

**"This is my second Claude."** The unit of everything is a `UsageProvider` enum case: one keychain item, one snapshot, one sample file, one ledger, one alert set, one menu tab per case. The CN cases (`kimiCN`, `zaiCN`, `minimaxCN`, `stepfunCN`, `qwenCN`) are accounts disguised as providers, with `brandRoot` / `brandSlots` bolted on so the menu can group them.

**"This window is a week long."** A snapshot is three fixed slots, `primary` / `secondary` / `tertiary`, titled by three fixed metadata strings. When Codex Pro moved its weekly cap into `primary_window` and dropped the 5h window (2026-10), Runic titled a 7-day window "Session". The same mismatch exists for Antigravity, Copilot, Ollama Cloud, Gemini and MiniMax; Kimi's fourth window, Claude's `limits[]`, Codex's extra limits and MiniMax's later models are dropped. Samples are keyed by slot name, so a provider that reorders windows splices two series together.

## Principles

1. **The account is the unit.** `UsageProvider` stays as the *kind* (what Runic knows how to fetch). `AccountID` becomes the key for per-login state.
2. **No migration for the people who have one login.** The default account's id string equals today's provider raw value, keychain items keep their names, file names and ids stay byte-identical.
3. **An account for a CLI-login provider is a credential plus a home directory.** Claude Code honours `CLAUDE_CONFIG_DIR`, Codex `CODEX_HOME`, kimi-cli `KIMI_CODE_HOME`; each dir carries the login, the settings and the session logs, so per-account history falls out of the same split.
4. **Rotation is the feature.** The product is "which account has room right now, and one line to switch to it", not "two cards".
5. **Windows are a list that describes itself** (phase 1): span, scope and kind come from the data; titles are derived; nothing an API returns is dropped silently; history is keyed by window identity.
6. **Shape drift is expected**: recorded live shapes become fixtures and tests.

## Part A — Accounts (phase 2, first)

### Identity

```swift
public struct AccountID: Hashable, Codable, Sendable, RawRepresentable {
    public let kind: UsageProvider
    public let slug: String                 // "default", or an opaque short id for added accounts
    public var rawValue: String { slug == "default" ? kind.rawValue : "\(kind.rawValue)~\(slug)" }
}
extension UsageProvider { public var defaultAccount: AccountID }
```

The raw value is what every store, file name, notification id, relay id and toggle key uses. For the default account it is exactly today's string, so the ledger daily/relay/lock files, cost cache, performance rows, notification ids, alert rules, `providerToggles`, widget selections and sample files need no move. `~` is the separator because `/` and `:` are already load-bearing in paths and relay ids. The slug never appears in the UI; it shows only in `runic env` output and paths.

```swift
public struct ProviderAccount: Codable, Sendable, Identifiable {
    public let id: AccountID
    public var displayName: String          // email local part by default ("sri", "work"); user-renamable
    public var region: ProviderRegion?      // .cn for what used to be the CN enum cases
    public var credential: CredentialRef    // .keychainItem(name) | .oauthDir(URL) | .env(name) | .cookies(storeKey)
    public var isEnabled: Bool
    public var sourceMode: ProviderSourceMode
    public var pinned: Bool                 // menubar icon / widget / CLI default; "auto" when none pinned
}
```

Registry: `~/Library/Application Support/Runic/accounts.json`. Absent file means "one default account per enabled kind", computed, not written, so a downgrade sees nothing new.

### Credentials are the first PR, not the key swap

`ProviderTokenResolver` is 36 static per-kind calls with one keychain account constant each, and `SettingsStore` mirrors that with one typed store and one persisted value per kind. Keying `UsageStore` by account changes nothing until a credential reference flows through the fetch:

- `ProviderFetchContext` gains `account: AccountID` and `credential: CredentialRef`.
- Keychain-backed kinds: the default account keeps its item (`kimi-api-token`); an added account uses `kimi-api-token.<slug>` under the same v2 service (no new ACL prompt). Env fallbacks (`KIMI_API_KEY`, `CODEX_HOME`, `CLAUDE_CONFIG_DIR`) apply to the default account only.
- `.oauthDir` for Claude must derive the CLI's per-directory keychain service: Claude Code 2.1.x names the item `Claude Code-credentials-<first 8 hex of sha256(configDir)>` whenever `CLAUDE_CONFIG_DIR` is set, account `$USER`, falling back to `<dir>/.credentials.json` only when the keychain write failed. Runic reads the unsuffixed item today and would never see a second login. Record the derived service name in the registry at creation and re-derive on failure. The OAuth cache item becomes `claude-oauth-cache.<AccountID>`.
- `.oauthDir` for Codex reads `<dir>/auth.json` (the CLI's default `cli_auth_credentials_store = "file"`); the `ChatGPT-Account-Id` header comes from that file, which is what makes a second workspace a second account.
- Kimi stays on a pasted plan key in phase 2. kimi-cli's `credentials/<name>.json` under `KIMI_CODE_HOME` exists but its shape is unrecorded; add `.oauthDir` for Kimi after installing the CLI and committing a fixture.

### Token refresh is a design requirement

In `~/.claude` the user's own sessions refresh the token. In a directory Runic created, no CLI ever runs, so the access token expires within hours and the account goes dark. Decision: Runic keeps its rule of never holding a Claude refresh token. Before a usage fetch whose cached token is near expiry, Runic runs `claude auth status --json` with `CLAUDE_CONFIG_DIR=<dir>` (verify in implementation that this refreshes; otherwise the existing PTY `/usage` probe does, with the env var injected). Codex keeps in-app refresh, but on the JWT `exp` minus a margin rather than the 8-day `last_refresh` age (the live token lasts 8.14 days, so the old rule had three hours of slack), re-reading `auth.json` immediately before refreshing and merging rather than rewriting the `tokens` object.

### Add account

The menu's existing "switch account" action already runs `claude /login` in a PTY or `codex login` as a process; it becomes the Add-account primitive with the config-dir env injected. The sheet offers three paths in this order:

1. **Sign in** (Claude, Codex): Runic creates `~/Library/Application Support/Runic/accounts/<id>/`, symlinks the content pieces from the default dir (`CLAUDE.md`, `commands/`, `agents/`, `skills/`), copies `settings.json` once, leaves plugins and MCP state to diverge (they are tied to the login), and runs the vendor login into it. One checkbox opts out of the symlinks. The sheet says, before the browser opens, "switch to the account you want in the browser first", because the vendor login lands on whatever account the browser is signed into. Two Codex logins cannot run at once (fixed localhost callback port).
2. **Use an existing config dir** (people already have `~/.claude-work`).
3. **Paste a key** (key providers; region is a field here, replacing "Add China account").

Failure states are designed, not alerted: CLI missing (install hint exists), browser never returned (timeout), token without the profile scope (known Claude case), same email as an existing account (dedupe on `identity.accountEmail`, offer replace), signed in but no usage yet (`RunicEmptyStateView` with the resting Runi).

### What is per account, what stays per kind

Per account on day one: snapshots, errors, source labels, fetch attempts and failure gates, quota and balance samples, alert evaluation and the session-quota "last remaining", MCP rows, widget entries, order within a brand, Codex credits and the OpenAI dashboard state (today singletons on `UsageStore`; a second Codex can never show credits until they move).

Per kind for now: token-cost ledger and relay (Claude's log scanner already merges a list of `CLAUDE_CONFIG_DIR` roots into the kind ledger; per-account cost is a later split because the ledger key is free to change), performance storage, cost cache, exports, context-fill, pricing. Overview and the brand roll-up show cost per kind; the sidebar shows per account once the ledger splits.

`UsageStore` gets one mechanical PR: its 36 provider-keyed dictionaries and the insight loaders' 52 become `[AccountID: …]`, with `subscript(provider:)` returning the default account. Not a second dictionary beside the first; custom providers already show what a parallel keyspace drifts into.

### Menu, icon, widget, CLI, MCP

- **Brand tab with account tabs.** The brand tab shows one account's full card; a small account switcher row sits at its top and the card remembers the last pick. Above the switcher, one line: "Best now: work · 71% left · 5h resets 14:10 · Switch". All accounts refresh in the background (one HTTPS call each per cycle); the "best now" line is why.
- **Switch** copies `export CLAUDE_CONFIG_DIR=…` (or `CODEX_HOME=…`) to the pasteboard. Second step: `runic env <kind/slug>` so `eval "$(runic env claude/work)"` works, and a `runic use` function from `runic shell-init`. Runic never opens a terminal; Terminal, iTerm, Ghostty, Warp and tmux make that a guess.
- **Resets board** already sorts every window soonest-first; with account labels it is the rotation board. No new panel.
- **Overview**: the brand's best headroom and "2 of 3 have room", never an average across accounts.
- **Pin**: per brand, default "auto (best headroom)", explicit account as override, used by the menubar icon, the small widget, the CLI default and the MCP `account` field. In the icon's percent mode the account tag is appended so a gauge that jumps from 12% to 80% when the best account changes does not read as a bug.
- **Alerts** per account, threaded per brand. Depletion names the alternative ("Claude · work: 5h depleted. personal has 71% left"); "restored" is suppressed while any account in the brand has room; "all accounts exhausted, soonest reset 14:10" is a distinct event and the only one with sound.
- **Widget**: `ProviderChoice` becomes an `AppEntity` with a dynamic query over the snapshot's accounts before any enum case is removed, or saved widget configurations die. Entries carry `accountId` and keep `provider`.
- **CLI**: `--provider claude` prints every account of the kind, `--account claude/work` one; JSON gains `accounts[]`. **MCP**: schema stays 1; rows gain optional `accountId`, the state gains `accounts[]`; `runic_limits` gains `account` and keeps `provider` as a kind filter. Schema 2 is reserved for the windows list (Part B).

### Migration and rollback

There is none for one-login users. The CN enum cases stay in the binary as aliases resolving through one table to `AccountID(.kimi, "cn")` with `region = .cn`; the table is the rollback. They are deleted a release after the alias ships. Keychain items are never renamed; where a copy is unavoidable, use the existing read-new-first / copy / verify / delete-legacy pattern, stamped per account, idempotent, and never flag "done" before the work.

### Phase 2 PR sequence

1. `CredentialRef` and `account` on `ProviderFetchContext`; the resolver becomes an instance parametrised by account; the 36 call sites convert. No behaviour change for defaults.
2. `AccountID` and the `UsageStore` key swap with the identity-preserving raw value; Codex credits and dashboard state move into the per-account snapshot.
3. Add account for Claude and Codex: per-dir keychain lookup, the refresh probe, the sheet, the dedupe. Brand tab with account tabs, "best now" line, Switch as a copied line.
4. Alerts per account, pin, widget entity, CLI `--account`, MCP additive fields, `runic env`.
5. CN alias table; then second accounts for key providers (Kimi, z.ai, MiniMax, …).

## Part B — Windows (phase 1, after accounts)

```swift
public struct QuotaWindow: Codable, Sendable, Identifiable {
    public let id: WindowKey            // scope + span + feature; stable across fetches
    public let span: WindowSpan         // .rolling(minutes) | .calendar(.day|.week|.month) | .lifetime | .unknown
    public let scope: WindowScope       // .account | .model(String) | .feature(String) | .apiKey
    public let kind: WindowKind         // .quota(usedPercent) | .counter(used, limit?) | .balance(amount, currency) | .info(String)
    public let resetsAt: Date?
    public let resetDescription: String?
    public let apiLabel: String?        // what the provider called it, verbatim
}
```

`UsageSnapshot.windows` replaces the three slots; `primary` / `secondary` / `tertiary` become computed shims over a **headline rule** (shortest account-scope quota first, next longer second, the rest in "more windows") so the 34 slot consumers migrate one file at a time. Titles come from span and scope ("5h", "Weekly", "Sonnet · weekly", "Key limit"); `sessionLabel` / `weeklyLabel` / `opusLabel` become fallbacks and then go. `Metric.id` and `ResetScheduleEntry.id` key on `WindowKey`. `QuotaSample` gains `window: WindowKey`, written alongside `slot` for one release; the 21-day retention retires slot-only lines. MCP moves to schema 2 here, with `providers[]` mirrored for one release. Antigravity, Copilot, Ollama Cloud, Gemini and MiniMax titles come right as a side effect; the dropped windows reappear in a "more windows" disclosure.

Shape-drift harness: each account writes `diagnostics/<kind>-<slug>-usage-shape.json` after a successful parse; `Tests/Fixtures/live-shapes/<kind>/<date>.json` holds recorded responses (emails redacted) and one parametrised test per kind parses every fixture.

## What each coding-agent API exposes (2026-10)

| Kind | Windows the API gives | Runic shows | Dropped today |
|---|---|---|---|
| Codex OAuth | `primary_window`, `secondary_window` (either may be null; Pro = weekly only), `additional_rate_limits[]`, `credits`, `rate_limit_reset_credits`, `model_usage`, `spend_control`, `code_review_rate_limit` | up to 3 | extra limits past the first, model availability, spend control |
| Claude OAuth | `five_hour`, `seven_day`, `seven_day_sonnet`, `seven_day_opus`, `seven_day_oauth_apps`, `limits[]` (scoped), `extra_usage`, `cedar_ember` | 5h, weekly, one model | the rest of `limits[]`, opus when sonnet exists, oauth-apps |
| Kimi Code | `limits[]` (any count, with durations), `usage` (weekly), `usages.limit_5h`, `limit_month_total` / `limit_month_code` | 3 | fourth window onward |
| Gemini CLI | per-model daily quotas | 3 | models after the third |
| Copilot | premium, completions, chat | 3, mistitled | entitlements, overage |
| Cursor | plan %, on-demand $, auto %, api %, breakdown | 2 | auto, api, breakdown |
| MiniMax | per-model windows with weekly | 3 | models after the first, their weeklies |
| Antigravity | per-model fractions | 3, mistitled | models after the third |
| Ollama Cloud | monthly credits or session + weekly, per-model counts | 1 or 2 | session + weekly when monthly exists |
| Z.ai | several `TOKENS_LIMIT` entries, `TIME_LIMIT` | 2 | all but the last tokens limit |
| OpenRouter, Vercel, DeepSeek, StepFun, Cline | balances, key limits, free-request counters | 1 to 3 | nothing material |

## Open items carried into implementation

- Confirm `claude auth status --json` refreshes an expiring token under a custom `CLAUDE_CONFIG_DIR`; if not, the PTY `/usage` probe with the env var is the refresher.
- Console-key ("sign in without an API key") Claude logins are stored outside the config dir and are not isolated by it; the sheet should say so.
- Whether "auto" pinning moves the menubar gauge silently or only on the next menu open; whether Switch also sets the pin. Default: move on next refresh, and yes.
