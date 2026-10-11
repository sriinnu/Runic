---
title: "Contributing"
---

# Contributing

## Build and test

```sh
swift build --product Runic      # not --target: only --product relinks the binary
swift test                       # ~735 tests; a handful of known issues are the System theme's light-appearance contrast block
swiftformat Sources Tests --lint
swiftlint lint --strict
```

`./Scripts/compile_and_run.sh` does a release build, replaces `/Applications/Runic.app` and relaunches it. Runic is a singleton, so run it only when you mean to replace the installed app.

## Render a theme without an account

The debug binary can draw the popover from a demo seed and write it to a PNG, with no deposit and no network:

```sh
RUNIC_SCREENSHOT_THEME=sumi \
RUNIC_SCREENSHOT_DEMO=1 \
RUNIC_SCREENSHOT_MENU_PROVIDER=overview \
RUNIC_SCREENSHOT_HEIGHT=1100 \
RUNIC_SCREENSHOT_RENDER=menubar:/tmp/sumi.png \
.build/debug/Runic -selectedFontFamily __theme__ -fontThemeFollowMigrated YES
```

`RUNIC_SCREENSHOT_MENU_PROVIDER` is `codex`, `claude` or `overview`. Always render a skin three times, with `__theme__`, `"JetBrains Mono"` and `__sf_mono__` as the font family: a monospaced pick is what breaks bundled faces, and a render with the right colours is not proof the faces applied. Check the glyphs.

## Add a provider

Every wiring site is listed in `docs/providers.md` and `docs/provider.md`: a descriptor, a fetch strategy, metadata, the enum case, a settings pane entry, and tests. Copy the closest existing provider (opencode is the log-based template, DeepSeek the API-key one) and keep the same shape.

## Add a skin

Read `Sources/Runic/Skins/README.md` first, then `Skins/Sumi/` as the reference implementation.

1. Create `Skins/<Name>/` with the conformance, a kit file (faces by PostScript name, marks, gauges) and one file per page.
2. Register it in `RunicSkinRegistry.skin(for:)` and `.all`.
3. Set `"skin": "<id>"` under `style` in the theme JSON, and in the Swift fallback palette in `RunicTheme+Palette.swift`.
4. Bundle static fonts under `Resources/Fonts/` with their OFL file and a line in `FONT_PROVENANCE.md`.
5. Put `.skinFace()` on every text that uses a bundled face.
6. Render it provider and overview, three font picks, and read the glyphs.
7. Keep `RunicSkinRegistryTests` and `ThemeContrastAuditTests` green. The audit gates the build: text tones must clear 4.5:1 and accents 3:1 on the derived menu fills, which on a light surface forces accents dark.

## Conventions

- Commits are short and imperative, one concern each. PRs squash-merge.
- `version.env` holds `MARKETING_VERSION` and `BUILD_NUMBER`; the marketing version also lives in `RunicVersion.swift`, `package.json` and the `CHANGELOG.md` heading, and a test refuses drift. Bump the build number for every build you install.
- Never print credential material in logs or issues.
