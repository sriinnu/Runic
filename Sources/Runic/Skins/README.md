# Skins

A theme is tokens (colours, type families, shape, motion, density — the JSON
under `Resources/Themes/`). A **skin** is the kit those tokens are drawn
with: how the pages are composed and what the chrome looks like. Several
themes can share one skin and differ only in tokens.

No view in `Views/Menu/` may branch on a theme id. The shared surfaces ask
the skin for each slot through `@Environment(\.runicSkin)`; a skin returns
`nil` for any slot it leaves standard.

## The contract (`RunicSkin.swift`)

| Slot | What it is | Standard rendering |
| --- | --- | --- |
| `providerPage` | The provider card: windows, balance, cost, insights | `UsageMenuCardView.standardBody` |
| `frontPage` | The overview of every provider | `OverviewMenuView.standardBody` |
| `resetsPage` | Windows counting down, banked resets | `ResetScheduleMenuView` |
| `panel` | A section container | `MenuPopoverSurfaceCard` (bordered card) |
| `tabs` | The provider strip | `ProviderTabBarView` |
| `chip` | A selectable chip (Explore) | `MenuPopoverChip` |
| `actionRow` | Ping now / Settings… / CSV | `MenuPopoverActionButton` |
| `sectionHeader` | "Resets", "Explore" | `RetroSectionHeader` |
| `note` | A line of copy in an action section | plain text |
| `footer` | The closing line of the panel | none |
| `popoverChrome` | Corner, border of the popover | theme shape + chrome tokens |
| `panelInset` | Inset between a panel edge and its content | theme density |
| `showsTabTray` | Whether the tab strip sits in an outlined tray | `true` |

Every slot takes plain value types (`RunicSkinChip`, `RunicSkinActionRow`,
`RunicSkinResets`, `RunicSkinFooterContext`) so a skin never reaches into a
view's state.

## Adding a skin

1. `Skins/<Name>/` with `<Name>Skin.swift` (the conformance), a kit file
   (faces by PostScript name, marks, rules, gauges) and one file per page.
2. Register it in `RunicSkinRegistry.skin(for:)` and `RunicSkinRegistry.all`.
3. `"skin": "<id>"` under `style` in the theme JSON (and the Swift fallback
   palette in `RunicTheme+Palette.swift`).
4. Fonts: bundle **static** weights under `Resources/Fonts/` with the OFL,
   note them in `FONT_PROVENANCE.md`, and address them with
   `Font.custom("<PostScriptName>", fixedSize:)`. Variable fonts do not
   resolve under `NSHostingView`.
5. Put `.skinFace()` on every text that uses a bundled face (and
   `.fontDesign(nil)` on each run of a concatenated `Text`). It clears the
   font design a monospaced picker pushes through the panel; `.default` is
   not the same thing and breaks some faces.
6. Render it before calling it done — see `screenshot-demo-renders` in the
   project memory: `RUNIC_SCREENSHOT_THEME=<id>`, the provider and overview
   pages, and the `__theme__`, `"JetBrains Mono"` and `__sf_mono__` picks.
   Never run the binary in `/Applications` for a render.
7. `RunicSkinRegistryTests` must stay green: the theme must resolve to the
   skin it names.

## Kits today

- `Standard` — the default; every slot nil. System, Dark, Glass, Terminal,
  Relief and Yantra draw with it until they get a kit.
- `Gazette` — the printed edition (`RunicGazetteChrome.swift`,
  `GazetteMenuCardViews.swift`). Pages and footer are on the kit; its chip,
  tab and action-row styling still live inside the standard views under
  `isGazette` and move here next.
- `Sumi` — ink on washi. The reference implementation: read it first.
- `Drafting` — blueprint as an engineering sheet: dimensioned bars, hatching, callouts, title block.
- `Instrument` — retro as a bench instrument: VU meters, LCDs, keycaps, lamps, screws. Adds the `stageOverlay` slot.
- `Departures` — a split-flap board; resets are departures.
- `FlightDeck` — a primary flight display; pace is the attitude indicator.
- `Receipt` — thermal paper; every ping prints one.
