# Screenshot Assets

Only commit sanitized product screenshots.

Before adding images here, replace or hide:
- Real account emails.
- Organization, team, project, or workspace IDs.
- Local filesystem paths.
- API keys, token hints, cookies, bearer strings, or auth state dumps.
- Real usage totals that should not be public.

Use stable filenames such as `menubar-codex.png`, `menubar-codex-details.png`, `menubar-claude.png`, `settings-general.png`, and `settings-performance.png`, then add them to the wiki's `images/` folder, which the root README and runic.srinivas.dev link to.

For app-generated captures, prefer launching Runic with `RUNIC_SCREENSHOT_MODE=1`. That replaces visible account emails in supported Runic views with `demo@runic.srinivas.dev`. Still inspect every screenshot before commit.

For post-capture cleanup, run:

```bash
./Scripts/redact_emails.swift demo@runic.srinivas.dev assets/screenshots/*.png
```
