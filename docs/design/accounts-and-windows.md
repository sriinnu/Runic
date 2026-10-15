---
summary: "Design: accounts as the unit (several logins per provider) and quota windows as a self-describing list instead of three fixed slots."
read_when:
  - A provider's API changes which windows it reports (Codex Pro 2026-10 dropped the 5h window)
  - Adding a second login for the same provider (two Claude accounts, Codex personal + work, Kimi + Kimi CN)
  - Touching UsageSnapshot.primary/secondary/tertiary, QuotaWindowSlot or metadata.sessionLabel/weeklyLabel/opusLabel
---

# Accounts and windows

Status: proposal, 2026-10-15. Phase 0 shipped as the Codex weekly-only fix. Nothing else is built yet.

## The two things the current model cannot say

**"This window is a week long."** A snapshot is three fixed slots, `primary` / `secondary` / `tertiary`, titled by three fixed metadata strings, `sessionLabel` / `weeklyLabel` / `opusLabel`. The slot says nothing about what is in it. When Codex Pro stopped reporting a 5h window and put the weekly cap in `primary_window` (2026-10), Runic titled a 7-day window "Session" and showed an empty Weekly row. The same mismatch already exists elsewhere and nobody noticed:

| Provider | Slot content today | Title shown |
|---|---|---|
| Antigravity | models sorted by constraint | "Claude", "Gemini Pro" from metadata, whatever model is there |
| Copilot | `completions` whenever it exists | "Chat" |
| Ollama Cloud | 30-day credits in primary | "Session" |
| Gemini, MiniMax | model windows with their own labels | "Pro"/"Flash", "Plan"/"Cycle" |
| Kimi Code | 5h, weekly, monthly, then anything else | fourth window dropped |
| Claude OAuth | `limits[]` with per-model and per-app windows | first scoped model only, rest dropped |
| Codex OAuth | several `additional_rate_limits` | first one only, looser window dropped |
| MiniMax | per-model quotas | models after the first dropped; web parse drops weekly entirely |

The slot name also keys **history**: `quota-samples/<provider>.jsonl` lines carry `slot: primary`, so when a provider reorders or drops a window the series for that slot splices two different windows together. (The burn chart survives today only because it filters samples by reset moment.)

**"This is my second Claude."** The unit of everything is the `UsageProvider` enum case: one keychain item, one snapshot, one sample file, one ledger, one alert set, one menu tab per case. A second login for the same provider is impossible without adding an enum case, which is exactly what `kimiCN`, `zaiCN`, `minimaxCN`, `stepfunCN`, `qwenCN` are: accounts disguised as providers, with `brandRoot` / `brandSlots` bolted on so the menu can group them. People now routinely hold a personal and a work Claude, a Codex per org, Kimi plus Kimi CN. That is the normal case, not the edge.

## Principles

1. **The account is the unit.** A provider is a *kind*; an account is one login of that kind. Snapshots, samples, ledgers, alerts, order, widget entries and MCP rows are keyed by account.
2. **Windows are a list that describes itself.** Span, scope and kind come from the data. Titles are derived ("5h", "Weekly", "Monthly", "Sonnet · weekly"), the way codex's own `/status` names limits by duration. Metadata strings become fallbacks for the few APIs that return genuinely named pools.
3. **Nothing an API returns is dropped silently.** Beyond the headline windows, everything else lands in a "more windows" disclosure and in diagnostics. A fourth Kimi window or a second Codex extra limit is data, not noise.
4. **History is keyed by window identity**, not by position in a list.
5. **Shape drift is expected.** Every account records the raw shape of its last response; parse tests run against a folder of recorded live shapes, dated.

## Model

```swift
public struct AccountID: Hashable, Codable, Sendable {
    public let kind: ProviderKind      // today's UsageProvider minus the CN cases
    public let slug: String            // "default", "work", "cn" — user-renamable display name lives on the account
}

public struct ProviderAccount: Codable, Sendable, Identifiable {
    public let id: AccountID
    public var displayName: String      // "Claude · work"; defaults from identity email when known
    public var region: ProviderRegion?  // replaces the *CN enum cases
    public var credential: CredentialRef // .keychain(item) | .oauthDir(URL) | .env(name) | .cookies(store)
    public var isEnabled: Bool
    public var sourceMode: ProviderSourceMode
}

public struct QuotaWindow: Codable, Sendable, Identifiable {
    public let id: WindowKey            // scope + span + feature; stable across fetches
    public let span: WindowSpan         // .rolling(minutes) | .calendar(.day|.week|.month) | .lifetime | .unknown
    public let scope: WindowScope       // .account | .model(String) | .feature(String) | .apiKey
    public let kind: WindowKind         // .quota(usedPercent) | .counter(used, limit?) | .balance(amount, currency) | .info(String)
    public let resetsAt: Date?
    public let resetDescription: String?
    public let apiLabel: String?        // what the provider called it, verbatim
}

public struct UsageSnapshot {
    public var windows: [QuotaWindow]   // sorted: account-scope quotas shortest first, then model/feature, then balances/info
    // credits, balance, resetCredits, identity, providerCost, updatedAt stay as they are
}
```

`WindowSpan.title` gives "5h", "Daily", "Weekly", "Monthly", "Lifetime". `QuotaWindow.title` composes scope and span: "Weekly", "Sonnet · weekly", "Key limit", "Premium requests · monthly". A provider that must override (Copilot's "Premium", Cursor's "Plan") does so per window via `apiLabel`, not per slot via metadata.

**Headline rule** (what the gauge, the icon, the widget and the overview show): the shortest account-scope `.quota` window is the headline; the next longer one is the second bar; everything else is "more". For Codex Pro today that yields Weekly alone, no empty second bar. For Claude it yields 5h + Weekly with Sonnet/Opus under "more", which is also where they belong.

**Compatibility shims.** `primary`, `secondary`, `tertiary` become computed properties over `windows` using the headline rule, and `metadata.sessionLabel` and friends become computed from the headline windows. The 34 consumers (inventory 2026-10-15: 9 in Runic/Core, 4 controllers, 5 menu views, 5 preference views, 2 skins, 2 widget, 7 CLI) migrate one file at a time with the shims in place, and the shims are deleted when the last one moves.

**History.** `QuotaSample` gains `window: WindowKey`. The store writes both `slot` and `window` for one release, reads by `window` when present, and the 21-day retention retires the slot-only lines on its own. File path moves to `quota-samples/<kind>/<slug>.jsonl`; the old `<provider>.jsonl` is read as `<kind>/default`.

## Accounts

- **Registry.** `~/Library/Application Support/Runic/accounts.json`. First launch after upgrade creates one account per enabled provider (`kind/default`) and turns each CN case into `kind/cn` with `region = .cn`, moving the keychain item and the sample file. The enum cases stay in the binary for one release as read-only migration sources, then go.
- **Credentials.** Keychain account name is the `AccountID` string. Env-var fallbacks (`KIMI_API_KEY`, `CODEX_HOME`, `CLAUDE_CONFIG_DIR`) apply to the `default` account only. A second Claude or Codex login is a `.oauthDir` credential pointing at its own config dir, which is how both CLIs already model multiple logins; the "Add account" sheet offers "sign in with the CLI into a new config dir" and "paste a key".
- **Identity.** `ProviderIdentitySnapshot.accountEmail` already exists. It names new accounts ("Claude · sri@work.com") and detects the same login added twice.
- **Menu.** The brand tab per kind with account chips under it is what `brandSlots` does for Kimi/Kimi CN today; it generalises to N accounts. The overview averages per account; alerts fire per account; the widget picks accounts, not kinds.
- **MCP / health.** `schemaVersion` 2: `accounts[]` with `windows[]`. `providers[]` is kept as a mirror of each kind's default account for one release so Kosha and the CLI keep working, then dropped.

## What each coding-agent API exposes (2026-10, from the fetchers and live probes)

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

Every "dropped" cell is a row that appears in "more windows" for free once the list model exists.

## Shape drift harness

- Each account writes `diagnostics/<kind>-<slug>-usage-shape.json` after a successful parse: top-level keys, window count, spans. `claude-usage-shape.json` does this already; Codex and Kimi get the same.
- `Tests/Fixtures/live-shapes/<kind>/<date>.json` holds recorded responses (emails redacted). One parametrised test per kind parses every fixture and asserts the window list is non-empty and every window has a title. Adding a fixture is how a shape change becomes a regression test.
- Unknown top-level keys log once per key at info and show as "Provider sent N fields Runic does not read" in the account's diagnostics pane.

## Phases

0. **Codex weekly-only title; reload button** — shipped (build 165).
1. **Windows list.** `QuotaWindow`, headline rule, titles from span, compat shims, samples keyed by `WindowKey`. Antigravity, Copilot, Ollama, Gemini, MiniMax titles come right as a side effect. One PR for the core, then consumer PRs by area (menu, widget, CLI, skins).
2. **Accounts.** Registry, migration from enum + CN cases, keychain naming, "Add account", account chips, MCP schema 2.
3. **Stop dropping.** "More windows" disclosure in the card and the sidebar, fed by everything past the headline.
4. **Drift harness.** Shape recorder for every kind, fixture folder, the parametrised test.

Revert cost: phases 1 and 2 each keep the old on-disk formats readable for one release, so rolling back a build loses nothing but the new accounts' data.
