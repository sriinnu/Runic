---
title: "Runic"
---

<p align="center"><img src="/images/icon.png" width="128" alt="Runic icon"></p>

# Runic

AI usage, costs and quota resets in your Mac menu bar.

Runic is an open-source macOS menu bar app for seeing AI usage across the providers you enable. Check quota and reset windows, cost estimates, local token history, model breakdowns, and provider status in one place. Usage stays on your Mac by default.

- [Repository](https://github.com/sriinnu/Runic)
- [Releases](https://github.com/sriinnu/Runic/releases)
- [Runic on Product Hunt](https://www.producthunt.com/products/runic)

## Beyond the menu bar

- **[CLI](/cli/)** — `runic` gives you the same usage, cost and insights in a terminal, a script or CI, plus a local OTLP collector for your own apps.
- **[MCP](/mcp/)** — a local MCP server so Claude Code, Codex, Cursor or any MCP client can ask Runic about your quota and credits, with a package format for adding your own tools.

## Thirteen themes, seven kits

Runic is not one look with thirteen palettes. Sumi is ink on washi, Departures is a split-flap board, Flight deck is an avionics display, Receipt prints every ping on thermal paper. See **[Themes and Skins](/themes-and-skins/)**.

## Under the hood

- **[Providers](/providers/)** — where each provider's numbers come from.
- **[Claude](/claude/)** — OAuth, web and CLI sources, usage credits, banked resets and the monthly API credits on Max plans.
- **[Architecture](/architecture/)** — modules, data flow, the relay ledger.
- **[Contributing](/contributing/)** — build, test, render a theme, add a provider or a skin.
- **[Release and ops](/release-and-ops/)** — how a release ships.

## Screenshots

### Menu bar

| Claude | Codex |
| --- | --- |
| <img src="/images/menu-claude-2.jpg" width="380" alt="Claude card with session and weekly quota, banked resets and pace"> | <img src="/images/menu-codex-2.jpg" width="380" alt="Codex card with session and weekly quota, credits and insights"> |
| Session, weekly and per-model quota with reset countdowns. | Exhausted session, banked resets and their expiry dates. |

### Settings

| General | Analytics |
| --- | --- |
| <img src="/images/settings-general-2.jpg" width="380" alt="General settings: cost summary, OpenAI web access and provider status"> | <img src="/images/settings-analytics-2.jpg" width="380" alt="Analytics settings: usage metrics, menu mode and provider switcher layout"> |
| Refresh rate, chart style, number and date formats, with a live preview. | Usage metrics, menu mode and provider switcher layout. |

### About

<img src="/images/settings-about-2.jpg" width="380" alt="About pane with the app icon, version, links and update controls">

## License

MPL-2.0. See [LICENSE](https://github.com/sriinnu/Runic/blob/main/LICENSE). Bundled third-party software and fonts keep their own licenses, reproduced in [THIRD-PARTY-NOTICES.md](https://github.com/sriinnu/Runic/blob/main/THIRD-PARTY-NOTICES.md) and shipped inside the app bundle.
