---
title: "Claude"
---

# Claude

Claude has the most moving parts of any provider, so it has its own page.

## Where the numbers come from

1. **OAuth API**, used when the Claude CLI's login is present. Session, weekly and model windows, the usage-credits `spend` block, banked resets when the login reports them.
2. **Web API** with your claude.ai session, when OAuth is missing.
3. **CLI PTY** (`claude /usage`), when both of the above are unavailable.

When Runic's copy of the CLI login has expired (about every eight hours), usage is read through the CLI and the card shows a **Via CLI** badge with a **Reconnect Claude…** button. CLI-served numbers carry no cost block and no banked resets. Reconnect re-reads the login from Keychain; macOS may ask once.

## What the card shows

| Row | Meaning |
| --- | --- |
| Session, Weekly, model | Plan windows with reset countdowns and pace. |
| **Usage credits** | Pay-as-you-go spend past your plan limit: on or off, spent this month against the monthly limit, and your prepaid balance. |
| **API credits** | The monthly API credit a Max plan includes. See below. |
| Banked resets | One-off "reset your limits" grants, with their expiry. Runic displays them; you redeem them on claude.ai. |

## API credits

Since 7 October 2026, Max plans include a monthly API credit: **$100 on Max 5x, $200 on Max 20x**, spent on the Messages API, the Console and the Agent SDK, not on Claude Code, and expiring at the end of each billing period. Pro and Free get none.

Runic shows it as one line under Usage credits, **only when your plan grants one**:

> API credits $200.00 a month · next grant Nov 3

- The **amount** comes from the plan tier Runic already reads from your Claude login.
- The **date** is the subscription's next charge, read from claude.ai when the claude.ai switch is on. Without it you get the amount alone.
- A plan with no grant shows nothing: no empty row, no "$0".
- The **remaining** balance is not shown. It lives in the Console behind a separate login that Runic does not hold, and claude.ai exposes no endpoint for it.

## The claude.ai switch

**Settings → Providers → Claude → Banked resets from claude.ai** lets Runic read your claude.ai login from your browser once (macOS may ask for your password, only then), keep a copy in its own Keychain item, and fetch banked resets, the prepaid balance and the next charge date with every refresh, without prompting. Turn it off and the card falls back to what the OAuth login alone reports.
